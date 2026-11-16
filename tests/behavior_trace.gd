extends SceneTree

func _initialize(): call_deferred("run")

func run():
	var directory = get_script().resource_path.get_base_dir().get_base_dir().path_join("ChallengePack/src")
	var rules = load(directory.path_join("multiplayer/rules.gd")).new()
	rules.rng.seed = 20261116
	rules.settings.heal = 1
	rules.settings.heal_chance = 30
	rules.settings.contract = 1
	rules.settings.contract_chance = 100
	var trace = []
	for charge in 8:
		rules.begin_charge([0, 1, 2, 3], true)
		rules.begin_turn(charge % 4)
		var sequence = rules.sequences(["live", "live", "blank", "blank"])
		var item = rules.item_result(charge % 4, 2, false)
		if item == "ok": rules.accept_item(charge % 4, 2, false)
		var effect = rules.shot_effect(charge % 4, charge % 4, sequence.loaded[0], false, 2, 4)
		trace.append({"charge": rules.charge, "turn": rules.turn, "players": rules.players.duplicate(true), "sequence": sequence, "item": item, "shot": effect})
	var encoded = JSON.stringify(trace)
	var expected = FileAccess.get_file_as_string(get_script().resource_path.get_base_dir().path_join("fixtures/behavior_trace.json")).strip_edges()
	if expected.is_empty():
		print("CP_TRACE_CAPTURE:", encoded)
		quit(1)
		return
	if JSON.parse_string(encoded) != JSON.parse_string(expected):
		push_error("Behavior trace differs from pre-refactor baseline")
		quit(1)
		return
	print("CP_BEHAVIOR_TRACE_OK: seeded charge, contract, item, health and turn results")
	quit()
