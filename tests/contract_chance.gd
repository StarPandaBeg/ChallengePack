extends "gameplay.gd"

var failures = 0

func check(condition: bool, message: String = "Check failed"):
	if not condition:
		failures += 1
		push_error(message)

func run():
	var installed = root.get_node_or_null("ChallengePack")
	if installed != null:
		root.remove_child(installed)
		installed.free()
	directory = get_script().resource_path.get_base_dir().get_base_dir().path_join("ChallengePack/src")
	port = load(directory.path_join("challengepack.gd")).new()
	root.add_child(port)
	check(port.compatible, port.compatibility_error)
	factory = port.factory
	# Exercise release probability even when the developer forces local contracts.
	port.challenges.activation_chance = 0.30
	for has_items in [false, true]:
		for selection in range(port.Settings.LIMITS.contract):
			port.active.contract = selection
			port.challenges.rng.seed = 82371
			var active_count = 0
			var seen = {}
			for i in range(4000):
				var contract = port.challenges.select_contract(has_items)
				if contract != 0:
					active_count += 1
					seen[contract] = seen.get(contract, 0) + 1
					check(contract in range(1, 13))
					check(has_items or contract in [2, 11, 12], "No-item round received an item restriction")
					check(selection == 1 or contract == selection - 1, "Fixed restriction changed its type")
			var eligible = selection != 0 and (has_items or selection in [1, 3, 12, 13])
			if eligible:
				check(active_count > 1000 and active_count < 1400, "Contract frequency is outside 25–35%: " + str(active_count))
				check(seen.size() == ((12 if has_items else 3) if selection == 1 else 1))
				if selection == 1 and has_items:
					for count in seen.values():
						check(count > 55 and count < 150, "Random contract weighting is uneven")
			else:
				check(active_count == 0)
	Engine.time_scale = 100
	var f = fixture()
	root.add_child(f.root)
	f.items.set_process(false)
	f.rm.roundArray[0].usingItems = true
	port.active = port.Settings.DEFAULTS.duplicate()
	port.active.contract = 2
	arm_contract()
	await port.challenges.begin_round(f.rm)
	check(port.challenges.state(f.rm).contract == 1)
	check(port.challenges.item_breaks_contract(f.rm, "cigarettes"))
	var probe = RandomNumberGenerator.new()
	for candidate in range(100):
		probe.seed = candidate
		if probe.randf() >= port.challenges.activation_chance:
			port.challenges.rng.seed = candidate
			break
	var dialogue_count = f.dialogue.texts.size()
	await port.challenges.begin_round(f.rm)
	check(port.challenges.state(f.rm).contract == 0, "Previous contract remained active after a failed roll")
	check(not port.challenges.item_breaks_contract(f.rm, "cigarettes"))
	check(f.dialogue.texts.size() == dialogue_count, "Inactive contract was announced")
	check(port.challenges.hud_data().is_empty(), "Inactive contract still appears in HUD")
	f.root.queue_free()
	await process_frame
	port.queue_free()
	Engine.time_scale = 1
	await process_frame
	print("CP_CONTRACT_CHANCE: %s failures; 112000 rolls at 30%%, twelve equally weighted contracts, fixed modes, no-item filtering, expiry and silent rounds" % failures)
	quit(1 if failures else 0)
