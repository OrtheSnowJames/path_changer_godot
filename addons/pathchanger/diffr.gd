extends RefCounted

enum ChangeType {
	Moved,
	Deleted,
}

## diffs two flat scene reps and returns every change at any depth
func diff(old_rep: Dictionary, new_rep: Dictionary) -> Array[Dictionary]:
	var changes: Array[Dictionary] = []

	for id in old_rep:
		var old_info: Dictionary = old_rep[id]

		if not new_rep.has(id):
			changes.append({
				"type": ChangeType.Deleted,
				"id": id,
				"name": old_info.name,
				"path": old_info.path,
				"has_script": old_info.has_script,
			})
			continue

		var new_info: Dictionary = new_rep[id]
		if old_info.path != new_info.path:
			changes.append({
				"type": ChangeType.Moved,
				"id": id,
				"name": new_info.name,
				"old_path": old_info.path,
				"new_path": new_info.path,
				"has_script": new_info.has_script,
			})

	return changes
