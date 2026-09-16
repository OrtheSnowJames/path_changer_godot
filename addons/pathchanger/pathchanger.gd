@tool
extends EditorPlugin

@onready var build_tree_rep = preload("build_tree_representation.gd").new() # yes this is contradictory but it works
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
	_previous_tree = build_tree_rep.recurse_build(scene_root)

	#current_scene_root.tree_changed.connect(_on_tree_changed)

func _on_scene_modified():
	print("tree changed!")


func _exit_tree() -> void:
	# Clean-up of the plugin goes here.
	var ur = get_undo_redo()
	if ur:
		ur.history_changed.disconnect(_on_scene_modified)
