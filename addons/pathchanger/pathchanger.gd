@tool
extends EditorPlugin

var build_tree_rep = preload("build_tree_representation.gd").new()
var diffr = preload("diffr.gd").new()
var prompter = preload("prompter.gd").new()
var script_ref = preload("script_ref.gd").new()

var current_scene_root: Node
var _previous_rep: Dictionary

func _enable_plugin() -> void:
	# Add autoloads here.
	pass


func _disable_plugin() -> void:
	# Remove autoloads here.
	pass


func _enter_tree() -> void:
	# Initialization of the plugin goes here.
	scene_changed.connect(_on_change_scene)

	var ur = get_undo_redo()
	ur.history_changed.connect(_on_scene_modified)

	var edited_root = get_editor_interface().get_edited_scene_root()
	if edited_root:
		_on_change_scene(edited_root)

func _on_change_scene(scene_root: Node) -> void:
	if scene_root == null:
		print("scene root null!")
		return
	print("Scene changed!")
	#if scene_root and scene_root.tree_changed.is_connected(_on_tree_changed):
	#	current_scene_root.tree_changed.disconnect(_on_tree_changed)
	current_scene_root = scene_root
	_previous_rep = build_tree_rep.build(scene_root)

	#current_scene_root.tree_changed.connect(_on_tree_changed)

func _on_scene_modified():
	if current_scene_root == null:
		return

	var new_rep := build_tree_rep.build(current_scene_root)
	var changes := diffr.diff(_previous_rep, new_rep)
	_previous_rep = new_rep
	if changes.is_empty():
		return

	var scripts := script_ref.get_scripts(current_scene_root)
	for change in changes:
		print("Change: ", change)
		if change.type == diffr.ChangeType.Deleted:
			await _handle_deleted(change, scripts)
		elif change.type == diffr.ChangeType.Moved:
			await _handle_moved(change, scripts)

## handles deleted nodes
func _handle_deleted(change: Dictionary, scripts: Array[Script]) -> void:
	var references := script_ref.find_script_ref_wo_dynamics(
		current_scene_root,
		scripts,
		change.path
	)

	for reference in references:
		print("found reference: ", reference)
		if await prompter.prompt("Path Changer", "It seems you have deleted a referenced object. " + "(" + reference.path + ")", "Go to Reference", "Cancel"):
			var parsed := _parse_reference_path(reference.path)
			EditorInterface.edit_script(load(parsed.script_path), parsed.line)
		else:
			return # this is intentional so that it doesn't spam pop-ups

## handles moved/renamed nodes
func _handle_moved(change: Dictionary, scripts: Array[Script]) -> void:
	var references := script_ref.find_script_ref_wo_dynamics(
		current_scene_root,
		scripts,
		change.old_path
	)

	var moved_node := _node_from_scene_path(change.new_path)
	if moved_node == null:
		return

	for reference in references:
		print("found reference: ", reference)

		# get_child(index) refs are slot based not path based so skip them
		if reference.text.find("get_child(") != -1:
			continue

		var parsed := _parse_reference_path(reference.path)
		var script: Script = load(parsed.script_path)

		if not await prompter.prompt("Path Changer", "It seems you have moved/renamed a referenced object. Update the script to use the new path? (" + reference.path + ")", "Change Path", "Cancel"):
			return # this is intentional so that it doesn't spam pop-ups

		# owners in different spots need different relative paths to the same target
		var owners := script_ref.get_owners(current_scene_root, script)
		var new_relative_path := ""
		var conflict := false
		for owner in owners:
			var candidate_path := String(owner.get_path_to(moved_node))
			if new_relative_path == "":
				new_relative_path = candidate_path
			elif candidate_path != new_relative_path:
				conflict = true
				break

		# a script used by other scenes might rely on the old path meaning something else there
		if not conflict:
			var old_relative_path := _extract_relative_path(reference.text)
			if old_relative_path != "":
				conflict = _has_conflict_in_other_scenes(script, old_relative_path, new_relative_path)

		if conflict:
			var choice := await prompter.prompt_with_extra(
				"Path Changer",
				"%s is attached to nodes elsewhere in the project that need a different path to reach the moved node. This reference cant be updated automatically. (%s)" % [parsed.script_path, reference.path],
				"Go to Reference",
				"Cancel",
				"Replace Anyway"
			)
			if choice == "extra":
				_apply_replacement(script, parsed.line, reference.text, new_relative_path)
			elif choice == "yes":
				EditorInterface.edit_script(script, parsed.line)
			continue

		_apply_replacement(script, parsed.line, reference.text, new_relative_path)

## builds the replacement text and applies it, no-op if the text style is unrecognized
func _apply_replacement(script: Script, line: int, old_text: String, new_relative_path: String) -> void:
	var new_text := _build_replacement_text(old_text, new_relative_path)
	if new_text == "":
		return

	_replace_reference_line(script, line, old_text, new_text)

## checks every other scene in the project for owners of this script that would break
## if old_relative_path got swapped for new_relative_path
func _has_conflict_in_other_scenes(script: Script, old_relative_path: String, new_relative_path: String) -> bool:
	var current_scene_path := current_scene_root.scene_file_path

	for scene_path in _find_all_scenes():
		if scene_path == current_scene_path:
			continue

		var packed: PackedScene = load(scene_path)
		if packed == null:
			continue

		var instance := packed.instantiate()
		if instance == null:
			continue

		var scene_conflict := false
		for owner in script_ref.get_owners(instance, script):
			var owner_node: Node = owner
			var old_target: Node = owner_node.get_node_or_null(old_relative_path)
			# if the old path never resolved here it wasnt actually working in this scene
			if old_target == null:
				continue

			var new_target: Node = owner_node.get_node_or_null(new_relative_path)
			if old_target != new_target:
				scene_conflict = true
				break

		instance.free()

		if scene_conflict:
			return true

	return false

## pulls the bare node path out of a $"..." or get_node("...") style reference
func _extract_relative_path(text: String) -> String:
	if text.begins_with("$"):
		var rest := text.substr(1).strip_edges()
		if rest.begins_with("\"") and rest.ends_with("\""):
			return rest.substr(1, rest.length() - 2)
		return rest

	var start := text.find("(")
	var end := text.rfind(")")
	if start == -1 or end == -1:
		return ""

	var inner := text.substr(start + 1, end - start - 1).strip_edges()
	if inner.begins_with("\"") and inner.ends_with("\""):
		return inner.substr(1, inner.length() - 2)
	return ""

## finds every .tscn file in the project
func _find_all_scenes() -> Array[String]:
	var result: Array[String] = []
	_scan_dir_for_scenes("res://", result)
	return result

func _scan_dir_for_scenes(path: String, result: Array[String]) -> void:
	var dir := DirAccess.open(path)
	if dir == null:
		return

	dir.list_dir_begin()
	var entry := dir.get_next()
	while entry != "":
		# skip hidden dirs like .git and .godot
		if entry.begins_with("."):
			entry = dir.get_next()
			continue

		var full_path := path.path_join(entry)
		if dir.current_is_dir():
			_scan_dir_for_scenes(full_path, result)
		elif entry.ends_with(".tscn"):
			result.append(full_path)

		entry = dir.get_next()

	dir.list_dir_end()

## splits a script:line ref path into its parts, strips res:// first since it breaks the split
func _parse_reference_path(ref_path: String) -> Dictionary:
	var stripped := ref_path.replace("res://", "")
	var parts := stripped.split(":")
	return {"script_path": parts[0], "line": int(parts[1])}

## finds the actual node in the current scene at an absolute scene path
func _node_from_scene_path(scene_path: String) -> Node:
	if current_scene_root == null:
		return null

	var prefix := "/" + str(current_scene_root.name)
	if scene_path == prefix:
		return current_scene_root
	if not scene_path.begins_with(prefix + "/"):
		return null

	return current_scene_root.get_node_or_null(scene_path.substr(prefix.length() + 1))

## rebuilds a reference call/shorthand with a new relative path, keeps the original call style
func _build_replacement_text(old_text: String, new_relative_path: String) -> String:
	if old_text.begins_with("$"):
		return "$\"%s\"" % new_relative_path
	if old_text.find("get_node_or_null") != -1:
		return "get_node_or_null(\"%s\")" % new_relative_path
	if old_text.find("get_node") != -1:
		return "get_node(\"%s\")" % new_relative_path
	return ""

## swaps the old reference text for the new one right in the open script editor tab
## this leaves it as an unsaved change instead of writing straight to disk
func _replace_reference_line(script: Script, line: int, old_text: String, new_text: String) -> void:
	EditorInterface.edit_script(script, line)

	var code_edit := _get_open_code_edit()
	if code_edit == null:
		return

	var line_index := line - 1
	if line_index < 0 or line_index >= code_edit.get_line_count():
		return

	code_edit.set_line(line_index, code_edit.get_line(line_index).replace(old_text, new_text))

## gets the CodeEdit control behind the script editor tab thats currently focused
func _get_open_code_edit() -> CodeEdit:
	var current_editor := EditorInterface.get_script_editor().get_current_editor()
	if current_editor == null:
		return null
	return current_editor.get_base_editor() as CodeEdit

func _exit_tree() -> void:
	# Clean-up of the plugin goes here.
	var ur = get_undo_redo()
	if ur:
		ur.history_changed.disconnect(_on_scene_modified)
