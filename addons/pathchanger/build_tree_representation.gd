extends RefCounted
class_name BuildTreeRepresentation
func recurse_build(to_recurse: Node, ids: bool = false) -> Dictionary:
	var output: Dictionary = {}

	for node in to_recurse.get_children():
		output[node.name] = recurse_build(node)

	return output

func recurse_id_paths(to_recurse: Node) -> Dictionary:
	var output: Dictionary = {
		to_recurse.get_instance_id(): to_recurse.get_path()
	}

	var children := to_recurse.get_children()

	for child in to_recurse.get_children():
		output.merge(recurse_id_paths(child))

	return output
