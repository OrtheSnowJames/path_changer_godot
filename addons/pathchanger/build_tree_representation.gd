extends RefCounted
class_name BuildTreeRepresentation
func recurse_build(to_recurse: Node) -> Dictionary:
	var output: Dictionary = {}

	for node in to_recurse.get_children():
		output[node.name] = recurse_build(node)

	return output
