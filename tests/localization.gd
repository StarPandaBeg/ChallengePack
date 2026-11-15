extends SceneTree

func _initialize():
	call_deferred("run")

func run():
	var directory = get_script().resource_path.get_base_dir().get_base_dir().path_join("ChallengePack/src")
	var original_locale = TranslationServer.get_locale()
	var original_start = TranslationServer.translate("START")
	var localization = load(directory.path_join("localization.gd")).new()
	localization.setup(directory)
	check(TranslationServer.translate("START") == original_start, "Vanilla translations were modified")
	TranslationServer.set_locale("en")
	check(localization.text("CP_TITLE") == "game configuration")
	TranslationServer.set_locale("ru")
	check(localization.text("CP_TITLE") == "настройка игры")
	check(localization.text("CP_DEALER_FIRST") == "Я начну первым.")
	check(localization.text("CP_VERSION", ["2.0.0"]) == "ChallengePack 2.0.0 / одиночная игра")
	check(localization.text("CP_ERROR_SCRIPT", ["ShellLoader"]).ends_with("ShellLoader"))
	var english = localization.catalogs.en
	var russian = localization.catalogs.ru
	check(english.size() == russian.size(), "Catalogs differ in size")
	for key in english:
		check(russian.has(key), "Missing Russian key: " + key)
		check(english[key].count("%s") == russian.get(key, "").count("%s"), "Placeholder mismatch: " + key)
	TranslationServer.set_locale("ru_RU")
	check(localization.text("CP_TITLE") == "настройка игры")
	localization.catalogs.ru.erase("CP_REAL_GAME")
	check(localization.text("CP_REAL_GAME") == english.CP_REAL_GAME, "Missing entry did not fall back")
	TranslationServer.set_locale("de")
	check(localization.text("CP_TITLE") == english.CP_TITLE, "Unsupported language did not fall back")
	check(localization.text("CP_UNKNOWN") == "CP_UNKNOWN", "Unknown key must remain diagnosable")
	TranslationServer.set_locale(original_locale)
	print("CP_LOCALIZATION_OK: Russian, regions, formatting, catalog coverage, fallback, vanilla isolation")
	quit()

func check(condition: bool, message: String = "Check failed"):
	if not condition:
		push_error(message)
		quit(1)
