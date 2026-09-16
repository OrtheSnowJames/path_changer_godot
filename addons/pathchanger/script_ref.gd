extends RefCounted

func get_scripts(root_node: Node) -> Array[Script]:
	var scripts: Array[Script] = []
	_collect_scripts(root_node, scripts)
	return scripts

## visits each node once (including root_node) and only appends unique scripts
func _collect_scripts(node: Node, scripts: Array[Script]) -> void:
	var script := node.get_script()
	if script and not scripts.has(script):
		scripts.append(script)

	for child in node.get_children():
		_collect_scripts(child, scripts)

# find_script_ref without dynamic references
func find_script_ref_wo_dynamics(root_node: Node, scripts: Array[Script], look_for: Node) -> Array[Dictionary]:
	var script_refs := find_script_ref(root_node, scripts, look_for)
	var result: Array[Dictionary] = []

	for ref in script_refs:
		if not ref.dynamic:
			result.append(ref)

	return result

## finds every place in the scene's scripts that references `look_for`
## `stripped` holds the resolved node's absolute path within the scene, e.g.
## "/Node2D/Enemy/Weapon". It is "" for dynamic references we can't resolve.
##
## Returns an Array of Dictionaries, ex:
## {path: "res://file.gd:50", text: "get_node(\"../object\")", dynamic: false,
##  stripped: "/Node2D/Enemy/Weapon"}
func find_script_ref(root_node: Node, scripts: Array[Script], look_for: Node) -> Array[Dictionary]:
	var result: Array[Dictionary] = []

	# map each script to the node(s) in the scene that use it
	var nodes_by_script := _get_nodes_by_script(root_node)

	for script in scripts:
		if script == null:
			continue

		var owners: Array = nodes_by_script.get(script, [])
		if owners.is_empty():
			continue

		# collect every candidate reference from the script
		var candidates := _collect_candidates(script.source_code)

		for candidate in candidates:
			# Dynamic references can't be resolved statically, so we can't prove
			# they point at look_for. Report them anyway so the caller can inspect.
			if candidate.dynamic:
				result.append({
					"path": "%s:%d" % [script.resource_path, candidate.line],
					"text": candidate.text,
					"dynamic": true,
					"stripped": "",
				})
				continue

			if _any_owner_resolves(owners, candidate, look_for):
				result.append({
					"path": "%s:%d" % [script.resource_path, candidate.line],
					"text": candidate.text,
					"dynamic": false,
					"stripped": _absolute_scene_path(root_node, look_for),
				})

	return result

# reference patterns for regexing scripts and getting references
const _REFERENCE_PATTERNS := [
	{
		# get_node(...) and get_node_or_null(...).
		"pattern": "\\b(?:get_node_or_null|get_node)\\s*\\((?<arg>[^)]*)\\)",
		"mode": "arg",
	},
	{
		# $ shorthand: $"Path/To/Node" or $Path/To/Node.
		"pattern": "\\$\\s*(?:\"(?<path>[^\"]*)\"|(?<path2>[A-Za-z_][A-Za-z0-9_/]*))",
		"mode": "path",
	},
	{
		# get_child(index).
		"pattern": "\\bget_child\\s*\\(\\s*(?<index>\\d+)\\s*\\)",
		"mode": "index",
	},
]

## parses source code to find node references
func _collect_candidates(source: String) -> Array[Dictionary]:
	var candidates: Array[Dictionary] = []

	var matchers: Array[Dictionary] = []
	for entry in _REFERENCE_PATTERNS:
		var regex := RegEx.new()
		regex.compile(entry.pattern)
		matchers.append({"regex": regex, "mode": entry.mode})

	var lines := source.split("\n")
	for line_index in lines.size():
		var line: String = lines[line_index]
		for matcher in matchers:
			for m in matcher.regex.search_all(line):
				var path := ""
				var index := -1
				var dynamic := false

				match matcher.mode:
					"arg":
						var arg: String = m.get_string("arg")
						# Empty call like get_node() -> nothing to reference.
						if arg.strip_edges() == "":
							continue
						var parsed := _parse_arg_path(arg)
						path = parsed.path
						dynamic = parsed.dynamic
					"path":
						path = m.get_string("path")
						if path == "":
							path = m.get_string("path2")
					"index":
						index = m.get_string("index").to_int()

				if path == "" and index < 0 and not dynamic:
					continue

				candidates.append({
					"text": m.get_string(),
					"line": line_index + 1,
					"path": path,
					"index": index,
					"dynamic": dynamic,
				})

	return candidates

# parses call arg to node path and dynamic flag
func _parse_arg_path(arg: String) -> Dictionary:
	var literal_regex := RegEx.new()
	literal_regex.compile("\\^?\"([^\"]*)\"")

	var path := ""
	var remainder := arg
	for m in literal_regex.search_all(arg):
		path += m.get_string(1)
		remainder = remainder.replace(m.get_string(), "")

	remainder = remainder.replace("+", "").strip_edges()

	return {"path": path, "dynamic": remainder != ""}

## maps script -> nodes under root_node
func _get_nodes_by_script(root_node: Node) -> Dictionary:
	var map: Dictionary = {}
	_collect_nodes_by_script(root_node, map)
	return map

func _collect_nodes_by_script(node: Node, map: Dictionary) -> void:
	var script := node.get_script()
	if script:
		if not map.has(script):
			map[script] = []
		map[script].append(node)

	for child in node.get_children():
		_collect_nodes_by_script(child, map)

## find if any owner has a node that matches candidate
## Returns true if any owner node resolves the candidate reference to look_for.
func _any_owner_resolves(owners: Array, candidate: Dictionary, look_for: Node) -> bool:
	for owner in owners:
		if owner == null or not is_instance_valid(owner):
			continue

		if candidate.index >= 0:
			if candidate.index < owner.get_child_count() and owner.get_child(candidate.index) == look_for:
				return true
		elif candidate.path != "" and owner.get_node_or_null(candidate.path) == look_for:
			return true

	return false

## Builds a node's absolute path within the scene, rooted at root_node, e.g.
## "/Node2D/Enemy/Weapon".
func _absolute_scene_path(root_node: Node, node: Node) -> String:
	if node == null:
		return ""
	if node == root_node:
		return "/" + str(root_node.name)
	return "/" + str(root_node.name) + "/" + str(root_node.get_path_to(node))
