func get_scripts(root_node: Node) -> Array[Script]:
	var scripts: Array[Script] = []
	for child in root_node.get_children():
		var script := child.get_script()

		if script and not scripts.has(script):
			scripts.append(script)

		scripts.append_array(get_scripts(child))

	return scripts
