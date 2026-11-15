extends RefCounted

const PATH = "user://challengepack.cfg"
const LIMITS = {"shells": 3, "items": 2, "shuffle": 2, "turn": 3}
const DEFAULTS = {"shells": 0, "items": 0, "shuffle": 0, "turn": 0}
var values = DEFAULTS.duplicate()

func load_settings(path: String = PATH) -> void:
	var cfg = ConfigFile.new()
	values = DEFAULTS.duplicate()
	if cfg.load(path) != OK:
		return
	for key in LIMITS:
		var value = cfg.get_value("rules", key, 0)
		if typeof(value) == TYPE_INT and value >= 0 and value < LIMITS[key]:
			values[key] = value

func cycle(key: String, path: String = PATH) -> Error:
	values[key] = (values[key] + 1) % LIMITS[key]
	return save_settings(path)

func save_settings(path: String = PATH) -> Error:
	var cfg = ConfigFile.new()
	for key in LIMITS:
		cfg.set_value("rules", key, values[key])
	return cfg.save(path)

func snapshot() -> Dictionary:
	return values.duplicate()
