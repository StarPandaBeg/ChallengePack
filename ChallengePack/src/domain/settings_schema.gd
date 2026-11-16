extends RefCounted

const Contracts = preload("contracts.gd")
const LIMITS = {"shells": 3, "items": 2, "shuffle": 2, "turn": 3, "health": 2, "mirror": 2, "pocket": 3, "contract": 2, "heal": 2}
const DEFAULTS = {"shells": 0, "items": 0, "shuffle": 0, "turn": 0, "health": 0, "mirror": 0, "pocket": 0, "contract": 0, "heal": 0, "contract_pool": Contracts.ALL_IDS, "contract_chance": 30, "heal_chance": 30}

const LABELS = {
	"shells": ["CP_SHELL_VISIBILITY", ["CP_DEFAULT", "CP_QUANTITY", "CP_HIDDEN"]],
	"items": ["CP_ITEM_VISIBILITY", ["CP_DEFAULT", "CP_HIDDEN"]],
	"shuffle": ["CP_SHUFFLE", ["YES", "NO"]],
	"turn": ["CP_FIRST_TURN", ["CP_ALWAYS_FIRST", "CP_ROUND_ROBIN", "CP_RANDOM"]],
	"health": ["CP_HEALTH_VISIBILITY", ["CP_DEFAULT", "CP_HIDDEN"]],
	"mirror": ["CP_MIRROR_ITEMS", ["NO", "YES"]],
	"pocket": ["CP_LIMITED_POCKET", ["CP_UNLIMITED", "CP_ONE_ITEM", "CP_TWO_ITEMS"]],
	"contract": ["CP_ROUND_CONTRACT", ["CP_OFF", "CP_ON"]],
	"heal": ["CP_HEAL_BULLETS", ["NO", "YES"]]
}

static func validate(value, multiplayer: bool = false) -> bool:
	if not value is Dictionary or value.size() != DEFAULTS.size() + (1 if multiplayer else 0):
		return false
	for key in LIMITS:
		if not value.has(key) or typeof(value[key]) != TYPE_INT or value[key] < 0 or value[key] >= (4 if multiplayer and key == "turn" else LIMITS[key]):
			return false
	if multiplayer and (typeof(value.get("first_player")) != TYPE_INT or value.first_player < 0):
		return false
	if typeof(value.get("contract_chance")) != TYPE_INT or value.contract_chance < 0 or value.contract_chance > 100:
		return false
	if typeof(value.get("heal_chance")) != TYPE_INT or value.heal_chance < 0 or value.heal_chance > 100:
		return false
	if not value.get("contract_pool") is Array:
		return false
	var seen = []
	for id in value.contract_pool:
		if typeof(id) != TYPE_INT or not id in Contracts.ALL_IDS or id in seen:
			return false
		seen.append(id)
	return true
