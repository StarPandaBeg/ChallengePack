extends "heal_bullets.gd"

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
	port.active = port.Settings.DEFAULTS.duplicate()
	Engine.time_scale = 100
	var f = fixture()
	root.add_child(f.root)
	f.items.set_process(false)
	var eject = ejector(f)
	eject.smoke = child(f.root, stub("SmokeController", {"SpawnSmoke": "pass"}))
	var death = child(f.root, stub("DeathManager", {"Kill": 'events.append([who, rm.health_player if who == "player" else rm.health_opponent])\nejectManager_player.DeathEjection()'}, "var events = []\n"))
	death.rm = f.rm
	death.ejectManager_player = eject
	var shooting = adapted("ShotgunShooting", "\nfunc MainSlowDownRoutine(_who, _from):\n\tpass\n")
	shooting.roundManager = f.rm
	shooting.shellSpawner = f.spawner
	shooting.death = death
	shooting.ejectionManager_player = eject
	shooting.cursorManager = f.loader.cursor
	shooting.camera = f.spawner.camera
	shooting.smoke = eject.smoke
	shooting.cameraShaker = child(f.root, stub("CameraShaker", {"Shake": "pass"}))
	shooting.healthCounter = child(f.root, stub("HealthCounter", {"UpdateDisplay": "pass"}))
	shooting.animator_shotgun = animator(f.root, ["player shoot self", "player shoot dealer"])
	shooting.speaker_live = child(f.root, AudioStreamPlayer2D.new())
	shooting.speaker_blank = child(f.root, AudioStreamPlayer2D.new())
	shooting.animator_muzzleFlash = animator(f.root, ["muzzle flash fire"])
	shooting.animator_muzzleFlash_model = animator(f.root, ["fire"])
	child(f.root, shooting)
	var ai = adapted("DealerIntelligence", "\nfunc GrabShotgun():\n\tdealerHoldingShotgun = true\n")
	ai.roundManager = f.rm
	ai.shellSpawner = f.spawner
	ai.shotgunShooting = shooting
	ai.death = death
	ai.ejectManager = eject
	ai.smoke = eject.smoke
	ai.cameraShaker = shooting.cameraShaker
	ai.itemManager = f.items
	ai.animator_shotgun = animator(f.root, ["enemy shoot self", "enemy shoot player", "enemy eject shell_from self", "enemy eject shell_from player"])
	child(f.root, ai)
	var shots = 0
	for dealer in [false, true]:
		for target in ["self", "opponent"]:
			for hp in [1, 3, 6]:
				for damage in [1, 2]:
					f.rm.health_player = hp
					f.rm.health_opponent = hp
					f.rm.currentShotgunDamage = damage
					f.rm.barrelSawedOff = damage == 2
					f.spawner.sequenceArray.assign(["lethal", "blank"])
					f.ai.sequenceArray_knownShell.assign([false, false])
					var before = death.events.size()
					var fired_before = f.rm.playerData.stat_shotsFired
					if dealer:
						await ai.Shoot("self" if target == "self" else "player")
					else:
						await shooting.Shoot("self" if target == "self" else "dealer")
					var hit_player = (dealer and target == "opponent") or (not dealer and target == "self")
					check(death.events.size() == before + 1, "Death ran more or less than once")
					check(death.events.back() == ["player" if hit_player else "dealer", 0], "Lethal shot left HP or hit the wrong target")
					check(f.rm.health_player == (0 if hit_player else hp))
					check(f.rm.health_opponent == (hp if hit_player else 0))
					check(f.rm.currentShotgunDamage == damage, "Lethal shell changed future shotgun damage")
					check(f.spawner.sequenceArray == ["blank"] and f.ai.sequenceArray_knownShell.size() == 1, "Lethal shell was not ejected exactly once")
					check(eject.mesh.get_surface_override_material(1).albedo_color == Color("101010"))
					check(f.rm.playerData.stat_shotsFired == fired_before + 1, "Black shell used the blank sound/flash branch")
					shots += 1
	# A subsequent ordinary shell keeps its original damage.
	f.rm.health_player = 6
	f.rm.health_opponent = 6
	f.rm.currentShotgunDamage = 1
	f.spawner.sequenceArray.assign(["live", "blank"])
	f.ai.sequenceArray_knownShell.assign([false, false])
	await shooting.Shoot("dealer")
	check(f.rm.health_opponent == 5 and f.rm.health_player == 6)
	# The dealer recognizes known black shells as lethal, without wasting a saw.
	f.rm.health_player = 6
	f.rm.health_opponent = 6
	f.rm.endless = true
	f.spawner.sequenceArray.assign(["lethal", "blank"])
	f.ai.sequenceArray_knownShell.assign([true, false])
	ai.sequenceArray_knownShell.assign([true, false])
	ai.dealerHoldingShotgun = true
	await ai.DealerChoice()
	await create_timer(8, false).timeout
	check(f.rm.health_player == 0 and f.rm.health_opponent == 6, "Dealer fired a known black shell at itself")
	# A known healing shell plus inverter becomes a lethal attack.
	var inverter = item_node("inverter", false)
	f.items.itemSpawnParent.add_child(inverter)
	ai.hands = child(f.root, stub("HandManager", {"PickupItemFromTable": "calls += 1"}, "var calls = 0\n"))
	ai.amounts = child(f.root, load("res://scripts/ItemAmounts.gd").new())
	f.rm.health_player = 6
	f.rm.health_opponent = 6
	f.spawner.sequenceArray.assign(["heal", "blank"])
	f.ai.sequenceArray_knownShell.assign([true, false])
	ai.sequenceArray_knownShell.assign([true, false])
	ai.dealerHoldingShotgun = false
	await ai.DealerChoice()
	await create_timer(12, false).timeout
	check(ai.hands.calls == 1 and f.rm.health_player == 0 and f.rm.health_opponent == 6, "Dealer inverter did not create/use a lethal shell")
	f.spawner.sequenceArray.assign(["lethal", "heal", "live", "blank"])
	ai.sequenceArray_knownShell.assign([false, false, false, false])
	check(not ai.FigureOutShell(), "AI deduced a mixed unknown chamber")
	ai.sequenceArray_knownShell.assign([false, true, true, true])
	check(ai.FigureOutShell())
	# Information items show the true black shell even with Hidden enabled.
	port.active.shells = 2
	var examine = adapted("ShellExamine")
	examine.shellSpawner = f.spawner
	examine.shellParent = child(f.root, Node3D.new())
	examine.mesh = child(f.root, shell_mesh())
	examine.mat_blank = StandardMaterial3D.new()
	examine.mat_live = StandardMaterial3D.new()
	child(f.root, examine)
	examine.SetupShell()
	check(examine.mesh.get_surface_override_material(1).albedo_color == Color("101010"))
	check(examine.mat_blank.albedo_color != Color("101010"), "Shared material was recolored")
	var phone = adapted("BurnerPhone")
	phone.sh = f.spawner
	phone.dia = f.dialogue
	child(f.root, phone)
	f.spawner.sequenceArray.assign(["live", "lethal"])
	for language in ["en", "ru"]:
		TranslationServer.set_locale(language)
		await phone.SendDialogue()
		check(f.dialogue.texts.back().contains(port.localization.text("CP_LETHAL_ROUND")))
	# Beer removes a black shell safely; black shells never appear in new charges.
	for action in ["BeerEjection_player", "BeerEjection_dealer"]:
		f.rm.health_player = 6
		f.rm.health_opponent = 6
		f.spawner.sequenceArray.assign(["lethal", "blank"])
		f.ai.sequenceArray_knownShell.assign([false, false])
		eject.call(action)
		check(f.spawner.sequenceArray == ["blank"] and f.rm.health_player == 6 and f.rm.health_opponent == 6)
	for heal in range(2):
		port.active.heal = heal
		for visibility in range(3):
			port.active.shells = visibility
			for shuffle in range(2):
				port.active.shuffle = shuffle
				f.spawner.SpawnShells(5, 2, 3, true)
				check(not f.spawner.sequenceArray.has("lethal"), "Black shell spawned naturally")
				check(f.spawner.sequenceArray.count("heal") == heal)
	f.root.queue_free()
	await process_frame
	port.queue_free()
	Engine.time_scale = 1
	await process_frame
	print("CP_LETHAL_BULLETS: %s failures; %s shots, instant kill, unchanged future damage, dealer inversion/knowledge, black materials, phone and no natural spawns" % [failures, shots])
	quit(1 if failures else 0)
