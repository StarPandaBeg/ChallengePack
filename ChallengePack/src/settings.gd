extends RefCounted

const PATH = "user://challengepack.cfg"
const Contracts = preload("challenges.gd")
const LIMITS = {"shells": 3, "items": 2, "shuffle": 2, "turn": 3, "health": 2, "mirror": 2, "pocket": 3, "contract": 2, "heal": 2}
const DEFAULTS = {"shells": 0, "items": 0, "shuffle": 0, "turn": 0, "health": 0, "mirror": 0, "pocket": 0, "contract": 0, "heal": 0, "contract_pool": Contracts.ALL_IDS, "contract_chance": 30}
var values = DEFAULTS.duplicate(true)
var storage_path = PATH

func load_settings(path: String = ""):
	var cfg = ConfigFile.new()
	values = DEFAULTS.duplicate(true)
	if cfg.load(storage_path if path.is_empty() else path) != OK:
		return
	for key in LIMITS:
		var value = cfg.get_value("rules", key, 0)
		if typeof(value) == TYPE_INT and value >= 0 and value < LIMITS[key]:
			values[key] = value
	if cfg.get_value("contracts", "schema", 0) != 1:
		# Migrate the original Off/Random/Fixed selector without changing its rule.
		var old = cfg.get_value("rules", "contract", 0)
		if typeof(old) == TYPE_INT and old >= 2 and old < Contracts.LEGACY_SETTING_COUNT:
			values.contract = 1
			values.contract_pool = [old - 1]
		return
	var pool = cfg.get_value("contracts", "pool", Contracts.ALL_IDS)
	if pool is Array:
		var valid = true
		for id in pool:
			if typeof(id) != TYPE_INT or not id in Contracts.ALL_IDS:
				valid = false
		if valid:
			values.contract_pool = []
			for id in Contracts.ALL_IDS:
				if id in pool:
					values.contract_pool.append(id)
	var chance = cfg.get_value("contracts", "chance", 30)
	if typeof(chance) == TYPE_INT and chance >= 0 and chance <= 100:
		values.contract_chance = chance

func cycle(key: String, path: String = "") -> Error:
	values[key] = (values[key] + 1) % LIMITS[key]
	return save_settings(path)

func save_settings(path: String = "") -> Error:
	var cfg = ConfigFile.new()
	for key in LIMITS:
		cfg.set_value("rules", key, values[key])
	cfg.set_value("contracts", "schema", 1)
	cfg.set_value("contracts", "pool", values.contract_pool)
	cfg.set_value("contracts", "chance", values.contract_chance)
	return cfg.save(storage_path if path.is_empty() else path)

func snapshot() -> Dictionary:
	return values.duplicate(true)
