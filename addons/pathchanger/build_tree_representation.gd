extends RefCounted
class_name BuildTreeRepresentation

## flat map of every node under root keyed by instance id so nodes stay identifiable after renames or moves
func build(root: Node) -> Dictionary:
	var output: Dictionary = {}
	_recurse(root, root, output)
	return output

func _recurse(root: Node, node: Node, output: Dictionary) -> void:
	for child in node.get_children():
		output[child.get_instance_id()] = {
			"name": child.name,
			"path": scene_path(root, child),
			"has_script": child.get_script() != null,
		}
		_recurse(root, child, output)

## absolute path of a node within the scene like /Root/Enemy/Weapon
func scene_path(root: Node, node: Node) -> String:
	if node == root:
		return "/" + str(root.name)
	return "/" + str(root.name) + "/" + str(root.get_path_to(node))
