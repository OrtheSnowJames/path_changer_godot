extends RefCounted
enum ChangeType {
	Changed,
	Deleted
}

## For now, only handles one difference
## ex: {Moved, "/Node2D/Enemy/Weapon", "Node2D/Enemy/Inventory/Weapon"}
func diff_scn_one(old_rep: Dictionary, new_rep: Dictionary) -> Array:
	var keys := old_rep.keys()
	for key in keys:
		if new_rep.has(key):
			if old_rep[key] != new_rep[key]:
				return [ChangeType.Changed, key, old_rep[key], new_rep[key]]
		else:
			return [ChangeType.Deleted, key]

	# if no difference
	return []
