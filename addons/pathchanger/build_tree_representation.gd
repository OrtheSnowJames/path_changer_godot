extends EditorPlugin

func recurse_build(to_recurse: Node) -> Dictionary:
	var output: Dictionary = {}
	for node in to_recurse.get_children():
		if node.get_children().is_empty():
			output[node.name] = {}
		else:
			output[node.name] = recurse_build(node)

	return output

#func build_tree_representation(tree_root: Node) # I realize i can just use recurse build
#	var dict_rep: Dict = _recurse_build(tree_root)
