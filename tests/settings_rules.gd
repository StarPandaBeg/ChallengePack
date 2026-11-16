extends SceneTree

func _initialize():
	call_deferred("run")

func run():
	# Keep fixtures isolated from a mod already installed beside the game.
	var installed = root.get_node_or_null("ChallengePack")
	if installed != null:
		root.remove_child(installed)
		installed.free()
	var directory = get_script().resource_path.get_base_dir().get_base_dir().path_join("ChallengePack/src")
	var settings_script = load(directory.path_join("settings.gd"))
	var settings = settings_script.new()
	var test_path = ProjectSettings.globalize_path("res://../ChallengePack/tests/.scratch/settings.cfg")
	DirAccess.make_dir_recursive_absolute(test_path.get_base_dir())
	settings.values.merge({"shells": 2, "items": 1, "shuffle": 1, "turn": 2, "health": 1, "mirror": 1, "pocket": 2, "contract": 4, "heal": 1}, true)
	check(settings.save_settings(test_path) == OK)
	var reloaded = settings_script.new()
	reloaded.load_settings(test_path)
	check(reloaded.values == settings.values)
	check(settings_script.LIMITS.contract == 14)
	for choice in range(14):
		settings.values.contract = choice
		check(settings.save_settings(test_path) == OK)
		reloaded.load_settings(test_path)
		check(reloaded.values.contract == choice, "Old/new contract selection changed after reload")
	settings.values.contract = 4
	reloaded.values = settings.snapshot()
	var snapshot = reloaded.snapshot()
	check(reloaded.cycle("shells", test_path) == OK)
	check(reloaded.values.shells == 0 and snapshot.shells == 2)
	var previous_config = ConfigFile.new()
	for key in ["shells", "items", "shuffle", "turn"]:
		previous_config.set_value("rules", key, settings.values[key])
	check(previous_config.save(test_path) == OK)
	reloaded.load_settings(test_path)
	check(reloaded.values.shells == 2 and reloaded.values.turn == 2)
	for key in ["health", "mirror", "pocket", "contract", "heal"]:
		check(reloaded.values[key] == 0, "Existing configs must leave new modes disabled")
	var malformed = ConfigFile.new()
	malformed.set_value("rules", "shells", "hidden")
	malformed.set_value("rules", "items", -1)
	malformed.set_value("rules", "shuffle", 2)
	malformed.set_value("rules", "turn", 2.0)
	malformed.set_value("rules", "contract", 14)
	check(malformed.save(test_path) == OK)
	reloaded.load_settings(test_path)
	check(reloaded.values == settings_script.DEFAULTS)
	DirAccess.remove_absolute(test_path)
	reloaded.load_settings(test_path)
	check(reloaded.values == settings_script.DEFAULTS)
	var rules_script = load(directory.path_join("rules.gd"))
	var rules = rules_script.new()
	for i in range(20):
		check(rules.next_starter(1) == i % 2)
	for i in range(20):
		check(rules.next_starter(0) == 0)
	rules.rng.seed = 1234
	var seen = {}
	for i in range(100):
		seen[rules.next_starter(2)] = true
	check(seen.size() == 2)
	check(rules_script.new().next_starter(1) == 0)
	var factory = load(directory.path_join("patch_factory.gd")).new()
	check(factory.prepare(directory))
	check(factory.scripts.size() == factory.TARGETS.size())
	# Anchor failure must invalidate the entire prepared batch.
	check(factory.replace_once("changed", "expected", "replacement") == "")
	check(not factory.error.is_empty() and factory.scripts.is_empty())
	print("CP_SETTINGS_OK: persistence, validation, snapshots, cyclic/random turns, atomic adapter failure")
	quit()

func check(condition: bool, message: String = "Check failed"):
	if not condition:
		push_error(message)
		quit(1)
