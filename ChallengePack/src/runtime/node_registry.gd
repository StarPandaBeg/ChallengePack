extends RefCounted

static func track(node: Node, entries: Dictionary, entry: Dictionary):
	var id = node.get_instance_id()
	entry["ref"] = weakref(node)
	entries[id] = entry
	node.tree_exiting.connect(func():
		entries.erase(id), CONNECT_ONE_SHOT)

static func prune(entries: Dictionary):
	for id in entries.keys():
		if entries[id].ref.get_ref() == null: entries.erase(id)
