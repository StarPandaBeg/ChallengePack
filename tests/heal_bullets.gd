extends "challenges.gd"

var failures = 0

func check(condition: bool, message: String = "Check failed"):
	if not condition:
		failures += 1
		push_error(message)

func adapted(name: String, additions: String = "") -> Node:
	var script = GDScript.new()
	var body = factory.scripts["res://scripts/%s.gd" % name].source_code
	for line in additions.split("\n"):
		if line.begins_with("func "):
			var override_name = line.trim_prefix("func ").get_slice("(", 0)
			if body.contains("func " + override_name + "("):
				body = body.replace(factory.method(body, override_name), "")
	script.source_code = body + additions
	check(script.reload() == OK, "Cannot compile fixture " + name)
	var node = script.new()
	node.cp_port = port
	return node

func shell_mesh() -> MeshInstance3D:
	var model = load("res://instances/shell.tscn").instantiate()
	var mesh = model.get_child(0).mesh.duplicate()
	model.free()
	return mesh

func ejector(f: Dictionary) -> Node:
	var eject = adapted("ShellEjectManager", "\nfunc _ready():\n\tpass\n")
	eject.shellSpawner = f.spawner
	eject.ai = f.ai
	eject.mesh = child(f.root, shell_mesh())
	eject.mat_blank = StandardMaterial3D.new()
	eject.mat_live = StandardMaterial3D.new()
	eject.animator_fader = animator(f.root, ["RESET", "fade out shell"])
	eject.animator = animator(f.root, ["ejecting shell_player1", "eject shell", "eject shell beer"])
	return child(f.root, eject)

func run():
	var installed = root.get_node_or_null("ChallengePack")
	if installed != null:
		root.remove_child(installed)
		installed.free()
	directory = get_script().resource_path.get_base_dir().get_base_dir().path_join("ChallengePack/src")
	port = load(directory.path_join("challengepack.gd")).new()
	port.name = "ChallengePack"
	root.add_child(port)
	check(port.compatible, port.compatibility_error)
	factory = port.factory
	Engine.time_scale = 100
	TranslationServer.set_locale("en")
	var translation = Translation.new()
	translation.locale = "en"
	for key in ["LIVEROUND", "LIVEROUNDS", "BLANKROUND", "BLANKROUNDS"]:
		translation.add_message(key, "%s shells")
	TranslationServer.add_translation(translation)
	port.active = port.Settings.DEFAULTS.duplicate()
	port.active.heal = 1
	port.active.heal_chance = 100
	# Presentation, charge size, no-shuffle order, and hidden loading gestures.
	for visibility in range(3):
		for shuffle in range(2):
			port.active.shells = visibility
			port.active.shuffle = shuffle
			var f = fixture()
			root.add_child(f.root)
			f.items.set_process(false)
			await f.spawner.MainShellRoutine()
			var sequence = f.spawner.sequenceArray.duplicate()
			check(sequence.size() == 5 and sequence.count("live") == 2 and sequence.count("blank") == 2 and sequence.count("heal") == 1, "Heal charge composition changed")
			var shown = []
			var greens = 0
			for shell in f.spawner.spawnedShellObjectArray:
				var branch = shell.get_child(0)
				var color = branch.mesh.get_surface_override_material(1).albedo_color
				var green = color == Color("37ba59")
				greens += int(green)
				shown.append("heal" if green else ("live" if branch.isLive else "blank"))
				check(branch.mat_blank.albedo_color != Color("37ba59"), "Shared blank material was recolored")
				if visibility == 1:
					check(color == branch.mat_blank.albedo_color, "Quantity leaked green shells")
			check(greens == (1 if visibility == 0 else 0))
			if shuffle == 1 and visibility == 0:
				check(shown == sequence, "Heal conversion broke displayed loading order")
			if visibility == 0:
				check(f.dialogue.texts.has(port.heal_bullets.composition(sequence)), "Composition dialogue omits heal shells")
			else:
				check(not f.dialogue.texts.has(port.heal_bullets.composition(sequence)), "Hidden composition leaked")
			await f.loader.LoadShells()
			check(f.recording.motions == (8 if visibility == 2 else 5))
			check(f.spawner.sequenceArray == sequence)
			f.root.queue_free()
			await process_frame
	port.active.shells = 0
	var f = fixture()
	root.add_child(f.root)
	f.items.set_process(false)
	f.rm.roundArray[0].startingHealth = 4
	var counter = child(f.root, stub("HealthCounter", {"UpdateDisplay": "calls += 1"}, "var calls = 0\n"))
	counter.speaker_beep = child(f.root, AudioStreamPlayer3D.new())
	counter.speaker_beep.stream = AudioStreamGenerator.new()
	# Test health limits, doubled saw healing, severed wires and no resurrection.
	f.rm.currentShotgunDamage = 2
	for player in [false, true]:
		var key = "health_player" if player else "health_opponent"
		var wire = "wireIsCut_player" if player else "wireIsCut_dealer"
		for health in [0, 1, 3, 4]:
			for cut in [false, true]:
				f.rm.set(key, health)
				f.rm.set(wire, cut)
				counter.speaker_beep.stop()
				port.heal_bullets.apply(f.rm, "player" if player else "dealer", counter)
				check(f.rm.get(key) == (mini(4, health + 2) if health > 0 and health < 4 and not cut else health), "Healing bypassed a limit")
				check(counter.speaker_beep.playing == (health > 0 and health < 4 and not cut), "Healing sound did not match restored HP")
		f.rm.set(wire, false)
	f.rm.currentShotgunDamage = 1
	# Player shot: real adapted Shoot and ejection; stub only presentation/final turn.
	var eject = ejector(f)
	var shooting = adapted("ShotgunShooting", '\nvar finishes = []\nvar cp_eject\nfunc MainSlowDownRoutine(_who, _from_dealer):\n\tpass\nfunc PlayShootingSound():\n\tpass\nfunc FinalizeShooting(again, _place, _revive, _delay):\n\tfinishes.append(again)\n\tcp_eject.EjectShell()\n')
	shooting.roundManager = f.rm
	shooting.shellSpawner = f.spawner
	shooting.healthCounter = counter
	shooting.cp_eject = eject
	shooting.ejectionManager_player = eject
	shooting.cursorManager = f.loader.cursor
	shooting.camera = f.spawner.camera
	shooting.animator_shotgun = animator(f.root, ["player shoot self", "player shoot dealer", "player eject shell", "player eject shell2"])
	child(f.root, shooting)
	for target in ["self", "dealer"]:
		f.rm.health_player = 2
		f.rm.health_opponent = 2
		f.spawner.sequenceArray.assign(["heal", "live"])
		f.ai.sequenceArray_knownShell.assign([false, false])
		var before = shooting.finishes.size()
		counter.speaker_beep.stop()
		await shooting.Shoot(target)
		# Vanilla dispatches ShootingDealerEjection without awaiting its animation.
		await create_timer(3, false).timeout
		check(shooting.finishes.size() == before + 1 and shooting.finishes.back() == (target == "self"), "Healing shot lost or duplicated a turn")
		check(f.rm.health_player == (3 if target == "self" else 2))
		check(f.rm.health_opponent == (3 if target == "dealer" else 2))
		check(f.spawner.sequenceArray == ["live"] and f.ai.sequenceArray_knownShell.size() == 1, "Healing shot did not eject exactly one shell")
		check(eject.mesh.get_surface_override_material(1).albedo_color == Color("37ba59"))
	# Dealer shots and informed choice with beer + handsaw available.
	var ai = adapted("DealerIntelligence", '\nvar finishes = []\nvar cp_eject\nfunc EndDealerTurn(again):\n\tfinishes.append(again)\n\tcp_eject.EjectShell()\n')
	ai.roundManager = f.rm
	ai.shellSpawner = f.spawner
	ai.healthCounter = counter
	ai.ejectManager = eject
	ai.shotgunShooting = shooting
	ai.cp_eject = eject
	ai.itemManager = f.items
	ai.animator_shotgun = animator(f.root, ["enemy shoot self", "enemy shoot player", "enemy eject shell_from self", "enemy eject shell_from player"])
	child(f.root, ai)
	for target in ["self", "player"]:
		f.rm.health_player = 2
		f.rm.health_opponent = 2
		f.spawner.sequenceArray.assign(["heal", "live"])
		f.ai.sequenceArray_knownShell.assign([false, false])
		counter.speaker_beep.stop()
		await ai.Shoot(target)
		check(ai.finishes.back() == (target == "self"))
		check(f.rm.health_player == (3 if target == "player" else 2))
		check(f.rm.health_opponent == (3 if target == "self" else 2))
		check(f.spawner.sequenceArray == ["live"])
	f.items.itemSpawnParent.add_child(item_node("handsaw", false))
	f.items.itemSpawnParent.add_child(item_node("beer", false))
	f.spawner.sequenceArray.assign(["heal"])
	f.ai.sequenceArray_knownShell.assign([false])
	ai.sequenceArray_knownShell.assign([false])
	f.rm.barrelSawedOff = false
	f.rm.health_opponent = 2
	ai.dealerHoldingShotgun = true
	var count_before = ai.finishes.size()
	await ai.DealerChoice()
	await create_timer(6, false).timeout
	check(ai.finishes.size() == count_before + 1 and ai.finishes.back(), "Dealer did not shoot known heal at itself")
	check(f.rm.health_opponent == 3 and not f.rm.barrelSawedOff)
	# Three-type deduction must not grant knowledge of an unknown mixed chamber.
	f.spawner.sequenceArray.assign(["heal", "blank", "live"])
	ai.sequenceArray_knownShell.assign([false, false, false])
	check(not ai.FigureOutShell(), "AI deduced a shell from mixed unknown types")
	ai.sequenceArray_knownShell.assign([false, true, true])
	check(ai.FigureOutShell())
	# Magnifier reveals green even in hidden presentation; phone names it correctly.
	var examine = adapted("ShellExamine")
	examine.shellSpawner = f.spawner
	examine.shellParent = child(f.root, Node3D.new())
	examine.mesh = child(f.root, shell_mesh())
	examine.mat_blank = StandardMaterial3D.new()
	examine.mat_live = StandardMaterial3D.new()
	child(f.root, examine)
	port.active.shells = 2
	examine.SetupShell()
	check(examine.mesh.get_surface_override_material(1).albedo_color == Color("37ba59"))
	var phone = adapted("BurnerPhone")
	phone.sh = f.spawner
	phone.dia = f.dialogue
	child(f.root, phone)
	f.spawner.sequenceArray.assign(["live", "heal"])
	for language in ["en", "ru"]:
		TranslationServer.set_locale(language)
		await phone.SendDialogue()
		check(f.dialogue.texts.back().contains(port.localization.text("CP_HEAL_ROUND")))
	# Exercise both inverter pairs through the real item-use branch.
	var interaction = adapted("ItemInteraction", '\nfunc PlaySound(_sound):\n\tpass\nfunc EnablePermissions():\n\tpass\nfunc CheckAchievement_koni():\n\tpass\nfunc CheckAchievement_full():\n\tpass\n')
	interaction.roundManager = f.rm
	interaction.amounts = child(f.root, load("res://scripts/ItemAmounts.gd").new())
	interaction.animator_playerHands = animator(f.root, ["player use inverter"])
	child(f.root, interaction)
	for shell in ["heal", "lethal", "blank", "live"]:
		f.spawner.sequenceArray.assign([shell])
		await interaction.InteractWith("inverter")
		check(f.spawner.sequenceArray[0] == {"heal": "lethal", "lethal": "heal", "blank": "live", "live": "blank"}[shell], "Inverter mishandled " + shell)
	port.active.health = 1
	var hidden_counter = health_counter(f)
	port.heal_bullets.apply(f.rm, "player", hidden_counter)
	check(f.rm.health_player == 3 and not hidden_counter.uiparent.visible, "Healing revealed hidden health")
	# Beer discards healing rounds without applying HP; no blanks means no insertion.
	f.rm.health_player = 2
	for action in ["BeerEjection_player", "BeerEjection_dealer", "DeathEjection"]:
		f.spawner.sequenceArray.assign(["heal", "blank"])
		f.ai.sequenceArray_knownShell.assign([false, false])
		eject.call(action)
		check(f.spawner.sequenceArray == ["blank"] and f.rm.health_player == 2)
	f.spawner.SpawnShells(2, 2, 0, true)
	check(not f.spawner.sequenceArray.has("heal"))
	port.active.heal = 0
	f.spawner.SpawnShells(5, 2, 3, true)
	check(not f.spawner.sequenceArray.has("heal"), "Disabled heal mode changed vanilla shells")
	port.active.heal = 1
	port.active.shells = 2
	port.heal_bullets.rng.seed = 177
	for chance in [0, 30, 100]:
		port.active.heal_chance = chance
		var green = 0
		for i in 1000:
			f.spawner.sequenceArray.assign(["blank", "live"])
			port.heal_bullets.seed_charge(f.spawner)
			green += f.spawner.sequenceArray.count("heal")
		check(green == 0 if chance == 0 else (green == 1000 if chance == 100 else green > 200 and green < 400), "Solo healing probability")
	f.root.queue_free()
	await process_frame
	port.queue_free()
	Engine.time_scale = 1
	await process_frame
	print("CP_HEAL_BULLETS: %s failures; visibility/order/loading, player/dealer shots, AI, HP caps, saw, phone, magnifier and ejection" % failures)
	quit(1 if failures else 0)
