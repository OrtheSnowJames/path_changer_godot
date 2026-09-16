@tool
extends EditorPlugin

var build_tree_rep = preload("build_tree_representation.gd").new()
var diffr = preload("diffr.gd").new()
var prompter = preload("prompter.gd").new()

var current_scene_root: Node
var _previous_tree: Dictionary

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
	# print(build_tree_rep)
	# print(typeof(build_tree_rep))
	var new_tree = build_tree_rep.recurse_build(scene_root)
	_previous_tree = new_tree

	#current_scene_root.tree_changed.connect(_on_tree_changed)

func _on_scene_modified():
	if current_scene_root == null:
		return
	print("tree changed!")
	var new_tree = build_tree_rep.recurse_build(current_scene_root)
	var change = diffr.diff_scn_one(_previous_tree, new_tree)
	_previous_tree = new_tree
	if change == []:
		return
	var change_type = change[0]
	var referenced_object = change[1]
	print("Change: ", change_type, " -> ", referenced_object)

func _exit_tree() -> void:
	# Clean-up of the plugin goes here.
	var ur = get_undo_redo()
	if ur:
		ur.history_changed.disconnect(_on_scene_modified)
