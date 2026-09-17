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

## handles deleted nodes
func _handle_deleted(change: Dictionary, scripts: Array[Script]) -> void:
	var references := script_ref.find_script_ref_wo_dynamics(
		current_scene_root,
		scripts,
		change.path
	)

	for reference in references:
		print("found reference: ", reference)
		if await prompter.prompt("Path Changer", "It seems you have deleted a referenced object.", "Go to Reference", "Cancel"):
			var ref_path: String = reference.path
			print("ref_path: ", ref_path)
			# the ref_path starts with res://, malforming the path parts split
			ref_path = ref_path.replace("res://", "")
			var path_parts := ref_path.split(":")
			var script_path := path_parts[0]
			var line := int(path_parts[1])
			print("script_path: ", script_path, " line: ", line)
			EditorInterface.edit_script(load(script_path), line)

func _exit_tree() -> void:
	# Clean-up of the plugin goes here.
	var ur = get_undo_redo()
	if ur:
		ur.history_changed.disconnect(_on_scene_modified)
