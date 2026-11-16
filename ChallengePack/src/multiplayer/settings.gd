extends RefCounted

const Rules = preload("rules.gd")
const PATH = "user://challengepack_multiplayer.cfg"
var values = Rules.new().settings.duplicate(true)

func load_settings(path: String = PATH):
	var cfg = ConfigFile.new()
	if cfg.load(path) == OK:
		var saved = cfg.get_value("multiplayer", "rules", {})
		# Old preferences have no probability field; network rules remain strict.
		if saved is Dictionary and not saved.has("heal_chance"):
			saved["heal_chance"] = Rules.Defaults.DEFAULTS.heal_chance
		if Rules.validate(saved): values = saved.duplicate(true)

func save_settings(path: String = PATH) -> Error:
	if not Rules.validate(values): return ERR_INVALID_DATA
	var cfg = ConfigFile.new()
	cfg.set_value("multiplayer", "rules", values)
	return cfg.save(path)
