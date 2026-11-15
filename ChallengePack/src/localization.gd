extends RefCounted

# Separate catalogs keep mod messages out of the game's translation namespace.
var directory: String
var catalogs = {}

func setup(mod_directory: String):
	directory = mod_directory.path_join("locales")
	catalogs.clear()
	catalogs["en"] = load_catalog("en")

func load_catalog(language: String) -> Dictionary:
	var path = directory.path_join(language + ".json")
	if not FileAccess.file_exists(path):
		return {}
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not parsed is Dictionary:
		push_warning("[ChallengePack] Invalid translation catalog: " + path)
		return {}
	var strings = {}
	for key in parsed:
		if parsed[key] is String and not parsed[key].is_empty():
			strings[key] = parsed[key]
	return strings

func text(key: String, arguments: Array = []) -> String:
	var language = TranslationServer.get_locale().replace("-", "_").to_lower().get_slice("_", 0)
	if not catalogs.has(language):
		catalogs[language] = load_catalog(language)
	var value: String = catalogs[language].get(key, catalogs.get("en", {}).get(key, key))
	return value if arguments.is_empty() else value % arguments
