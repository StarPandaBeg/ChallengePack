extends RefCounted

const Contracts = preload("../domain/contracts.gd")
var _data: Dictionary

func _init(data: Dictionary): _data = data.duplicate(true)
func to_dictionary() -> Dictionary: return _data.duplicate(true)

static func has_shape(data: Dictionary) -> bool:
	for key in ["charge", "turn", "last_actor", "current"]:
		if typeof(data.get(key)) != TYPE_INT: return false
	for key in ["players", "health", "inventories"]:
		if not data.get(key) is Dictionary: return false
	return data.charge >= 0 and data.turn >= 0 and data.get("direction") in ["CW", "CCW"] and typeof(data.get("sawed")) == TYPE_BOOL

static func valid(data: Dictionary, roster: Dictionary) -> bool:
	if not has_shape(data): return false
	if data.health.size() != roster.size() or data.inventories.size() != roster.size(): return false
	if data.current != -1 and not roster.has(data.current): return false
	if data.last_actor != -1 and not roster.has(data.last_actor): return false
	for socket in roster:
		var hp = data.health.get(socket)
		if typeof(hp) != TYPE_INT or hp < 0 or hp > roster[socket]: return false
		var inventory = data.inventories.get(socket)
		if not inventory is Array or inventory.size() != 8: return false
		for item in inventory:
			if typeof(item) != TYPE_INT or item < 0 or item > 10: return false
	for socket in data.players:
		if not roster.has(socket): return false
		var player = data.players[socket]
		if not player is Dictionary: return false
		if typeof(player.get("contract")) != TYPE_INT or not Contracts.CATALOG.has(player.contract): return false
		if typeof(player.get("used")) != TYPE_INT or player.used < 0: return false
		if typeof(player.get("failed")) != TYPE_BOOL or not player.get("history") is Array: return false
		for item in player.history:
			if typeof(item) != TYPE_INT or item < 1 or item > 10: return false
	return true
