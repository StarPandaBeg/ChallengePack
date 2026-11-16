extends SceneTree

var failures = 0

func _initialize():
	call_deferred("run")

func check(ok: bool, reason: String):
	if not ok:
		failures += 1
		push_error(reason)

func run():
	var installed = root.get_node_or_null("ChallengePack")
	if installed != null:
		root.remove_child(installed)
		installed.free()
	var directory = get_script().resource_path.get_base_dir().get_base_dir().path_join("ChallengePack/src")
	var R = load(directory.path_join("multiplayer/rules.gd"))
	if R == null or not R.can_instantiate(): quit(1); return
	var rules = R.new()
	check(R.validate(rules.settings), "Defaults must validate")
	var bad = rules.settings.duplicate(true)
	bad.turn = 4
	check(not R.validate(bad), "Reject invalid turn")
	for count in [2, 3, 4]:
		var alive = range(count)
		for shuffle in [0, 1]:
			for heal in [0, 1]:
				rules.settings.shuffle = shuffle
				rules.settings.heal = heal
				for _i in 100:
					var seq = rules.sequences(["live", "live", "blank", "blank"])
					check(seq.visible.count("heal") == heal, "One healing shell")
					if shuffle == 1: check(seq.visible == seq.loaded, "No shuffle preserves order")
		for id in R.Catalog.ALL_IDS:
			rules.settings.contract = 1
			rules.settings.contract_chance = 100
			rules.settings.contract_pool = [id]
			rules.begin_charge(alive, true)
			for socket in alive:
				check(rules.state(socket).contract == id, "Fixed contract pool")
				for item in R.ITEM_NAMES:
					rules.state(socket).history = []
					var banned = R.ITEM_NAMES[item] in R.Catalog.CATALOG[id].items
					check((rules.item_result(socket, item, false) == "contract") == banned, "Item restriction " + str(id))
					check((rules.item_result(socket, item, true) == "contract") == banned, "Stolen item restriction " + str(id))
			rules.begin_charge(alive, false)
			check((rules.state(0).contract != 0) == (not R.Catalog.CATALOG[id].requires_items), "Itemless eligibility")
		var C = R.Catalog.Contract
		rules.state(0).contract = C.NO_INSURANCE
		for order in [[2, 3], [3, 2]]:
			rules.state(0).history = []
			check(rules.item_result(0, order[0], true) == "ok", "First insurance item")
			rules.accept_item(0, order[0], true)
			check(rules.item_result(0, order[0], true) == "ok", "Repeat same insurance item")
			check(rules.item_result(0, order[1], true) == "contract", "Second insurance item")
		rules.state(0).contract = C.LEAKY_GUN
		for _i in 50:
			check(rules.target(0, 0, alive) in alive.slice(1), "Leaky random opponent")
			check(rules.target(0, count - 1, alive) == 0, "Leaky opponent becomes self")
		rules.settings.turn = 2
		rules.previous_starter = -1
		for socket in alive: check(rules.starter(alive, 0, "CW", 0, 0) == socket, "Round robin")
		var items = rules.mirror_pool([{"id": 3, "enabled": true, "per_player": 1, "global_max": 1}, {"id": 2, "enabled": true, "per_player": 2, "global_max": 8}], count, 8)
		check(not 3 in items and items.size() == 2, "Mirror limits")
	# Every public setting combination is valid and generates a coherent charge.
	var combinations = 1
	for key in R.LIMITS: combinations *= R.LIMITS[key]
	for count in [2, 3, 4]:
		for code in combinations:
			var value = code
			for key in R.LIMITS:
				rules.settings[key] = value % R.LIMITS[key]
				value = int(value / R.LIMITS[key])
			check(R.validate(rules.settings), "Valid settings matrix")
			var sequence = rules.sequences(["live", "blank", "blank"])
			if rules.settings.shuffle == 1: check(sequence.visible == sequence.loaded, "Matrix preserves layout")
			rules.begin_charge(range(count), false)
			for socket in range(count):
				check(rules.state(socket).contract in [0, R.Catalog.Contract.NO_SELF_SHOTS, R.Catalog.Contract.TWO_FOR_ONE, R.Catalog.Contract.LEAKY_GUN], "Matrix itemless contracts")
	for doubled in [false, true]:
		for saw in [false, true]:
			rules.state(0).contract = R.Catalog.Contract.TWO_FOR_ONE if doubled else 0
			for hp in [1, 2, 4]:
				for target in [0, 1]:
					for shell in ["live", "blank", "heal", "lethal"]:
						var effect = rules.shot_effect(0, target, shell, saw, hp, 4)
						var strength = 2 if doubled or saw else 1
						check(effect.strength == strength, "Saw never stacks with contract")
						if shell == "heal": check(effect.health == mini(4, hp + strength), "Healing and HP cap")
						if shell == "lethal": check(effect.health == 0, "Black instant kill")
						check(effect.keep_turn == (target == 0 and shell in ["blank", "heal"]), "Actual target determines extra turn")
	var settings = load(directory.path_join("multiplayer/settings.gd")).new()
	settings.values.turn = 3
	check(settings.save_settings("user://cp_mp_test.cfg") == OK, "Save MP preferences")
	var restored = load(directory.path_join("multiplayer/settings.gd")).new()
	restored.load_settings("user://cp_mp_test.cfg")
	check(restored.values == settings.values, "Restore MP preferences")
	DirAccess.remove_absolute("user://cp_mp_test.cfg")
	for file in ["session.gd", "menu.gd", "factory.gd"]:
		var script = load(directory.path_join("multiplayer/" + file))
		check(script != null and script.can_instantiate(), "Compile " + file)
	var factory = load(directory.path_join("multiplayer/factory.gd")).new()
	check(factory.prepare(directory), "Compile all multiplayer adapters: " + factory.error)
	print("CP_MULTIPLAYER_CHECKS: failures=", failures)
	quit(1 if failures else 0)
