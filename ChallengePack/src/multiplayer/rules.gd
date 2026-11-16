extends RefCounted

const Catalog = preload("../domain/contracts.gd")
const Defaults = preload("../domain/settings_schema.gd")
const ITEM_NAMES = {1: "handsaw", 2: "magnifying glass", 3: "handcuffs", 4: "cigarettes", 5: "beer", 6: "burner phone", 7: "expired medicine", 8: "adrenaline", 9: "inverter", 10: "remote"}
const LIMITS = {"shells": 3, "items": 2, "shuffle": 2, "turn": 4, "health": 2, "mirror": 2, "pocket": 3, "contract": 2, "heal": 2}
var rng = RandomNumberGenerator.new()
var settings = Defaults.DEFAULTS.duplicate(true)
var players = {}
var charge = 0
var turn = 0
var previous_starter = -1
var last_actor = -1

func _init():
	rng.randomize()
	settings["first_player"] = 0

static func validate(value) -> bool:
	return Defaults.validate(value, true)

func reset():
	players.clear()
	charge = 0
	turn = 0
	previous_starter = -1
	last_actor = -1

func state(socket: int) -> Dictionary:
	if not players.has(socket):
		players[socket] = {"contract": 0, "used": 0, "history": [], "failed": false}
	return players[socket]

func begin_charge(alive: Array, has_items: bool):
	charge += 1
	last_actor = -1
	var pool = []
	for id in settings.contract_pool:
		if has_items or not Catalog.CATALOG[id].requires_items:
			pool.append(id)
	for socket in alive:
		var entry = state(socket)
		entry.used = 0
		entry.history = []
		entry.failed = false
		entry.contract = 0
		if settings.contract == 1 and not pool.is_empty() and rng.randf() < float(settings.contract_chance) / 100.0:
			entry.contract = pool[rng.randi_range(0, pool.size() - 1)]

func begin_turn(socket: int):
	if last_actor != socket:
		turn += 1
		state(socket).used = 0
		last_actor = socket

func item_result(socket: int, item: int, stolen: bool) -> String:
	var entry = state(socket)
	if entry.failed:
		return "failed"
	var name = ITEM_NAMES.get(item, "")
	if name in Catalog.CATALOG[entry.contract].items:
		return "contract"
	if entry.contract == Catalog.Contract.NO_INSURANCE:
		if (item == 2 and 3 in entry.history) or (item == 3 and 2 in entry.history):
			return "contract"
	if not stolen and settings.pocket > 0 and entry.used >= settings.pocket:
		return "pocket"
	return "ok"

func accept_item(socket: int, item: int, stolen: bool):
	var entry = state(socket)
	if not stolen:
		entry.used += 1
	if not item in entry.history:
		entry.history.append(item)

func target(socket: int, selected: int, alive: Array) -> int:
	if state(socket).contract != Catalog.Contract.LEAKY_GUN:
		return selected
	if selected != socket:
		return socket
	var others = alive.duplicate()
	others.erase(socket)
	return socket if others.is_empty() else others[rng.randi_range(0, others.size() - 1)]

func shot_effect(socket: int, actual: int, shell: String, saw: bool, hp: int, maximum: int) -> Dictionary:
	var Shells = preload("../domain/shell_rules.gd")
	var strength = Shells.strength(2 if saw else 1, state(socket).contract == Catalog.Contract.TWO_FOR_ONE)
	return {"target": actual, "strength": strength, "health": Shells.health_after(shell, hp, maximum, strength), "keep_turn": actual == socket and shell in ["blank", "heal"]}

func sequences(original: Array) -> Dictionary:
	var shown = original.duplicate()
	if settings.heal == 1 and "blank" in shown and rng.randf() < float(settings.heal_chance) / 100.0:
		var indices = []
		for i in range(shown.size()):
			if shown[i] == "blank": indices.append(i)
		shown[indices[rng.randi_range(0, indices.size() - 1)]] = "heal"
	shuffle(shown)
	var loaded = shown.duplicate()
	if settings.shuffle == 0: shuffle(loaded)
	return {"visible": shown, "loaded": loaded}

func shuffle(array: Array):
	for i in range(array.size() - 1, 0, -1):
		var j = rng.randi_range(0, i)
		var swap = array[i]
		array[i] = array[j]
		array[j] = swap

func starter(alive: Array, host_socket: int, direction: String, vanilla: int, fixed_socket: int) -> int:
	if alive.is_empty(): return vanilla
	var result = vanilla
	var ordered = alive.duplicate()
	ordered.sort()
	if direction == "CCW": ordered.reverse()
	if settings.turn == 1:
		result = fixed_socket if fixed_socket in alive else next_socket(fixed_socket, ordered)
	elif settings.turn == 2:
		result = host_socket if previous_starter == -1 and host_socket in alive else next_socket(previous_starter, ordered)
	elif settings.turn == 3:
		result = alive[rng.randi_range(0, alive.size() - 1)]
	previous_starter = result
	return result

func next_socket(current: int, ordered: Array) -> int:
	for offset in range(1, 5):
		var candidate = posmod(current + (offset if ordered.size() < 2 or ordered[0] < ordered[1] else -offset), 4)
		if candidate in ordered: return candidate
	return ordered[0]

func mirror_pool(resources: Array, count: int, wanted: int) -> Array:
	var result = []
	var counts = {}
	for _i in range(mini(wanted, 8)):
		var eligible = []
		for res in resources:
			var n = counts.get(res.id, 0) + 1
			if res.enabled and n <= res.per_player and n * count <= res.global_max and not (count == 2 and res.id == 10):
				eligible.append(res.id)
		if eligible.is_empty(): break
		var item = eligible[rng.randi_range(0, eligible.size() - 1)]
		result.append(item)
		counts[item] = counts.get(item, 0) + 1
	return result

static func snapshot_shape(data: Dictionary) -> bool:
	for key in ["charge", "turn", "last_actor", "current"]:
		if typeof(data.get(key)) != TYPE_INT: return false
	for key in ["players", "health", "inventories"]:
		if not data.get(key) is Dictionary: return false
	return data.charge >= 0 and data.turn >= 0 and data.get("direction") in ["CW", "CCW"] and typeof(data.get("sawed")) == TYPE_BOOL

static func valid_snapshot(data: Dictionary, roster: Dictionary) -> bool:
	if not snapshot_shape(data): return false
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
		if typeof(player.get("contract")) != TYPE_INT or not Catalog.CATALOG.has(player.contract): return false
		if typeof(player.get("used")) != TYPE_INT or player.used < 0: return false
		if typeof(player.get("failed")) != TYPE_BOOL or not player.get("history") is Array: return false
		for item in player.history:
			if typeof(item) != TYPE_INT or item < 1 or item > 10: return false
	return true
