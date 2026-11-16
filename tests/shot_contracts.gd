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
	f.rm.roundArray[0].startingHealth = 6
	var entry = port.challenges.state(f.rm)
	var eject = ejector(f)
	eject.smoke = child(f.root, stub("SmokeController", {"SpawnSmoke": "pass"}))
	var death = child(f.root, stub("DeathManager", {"Kill": 'events.append([who, rm.health_player if who == "player" else rm.health_opponent])\nejectManager_player.DeathEjection()'}, "var events = []\n"))
	death.rm = f.rm
	death.ejectManager_player = eject
	var shooting = adapted("ShotgunShooting", '\nvar finishes = []\nvar cp_eject\nfunc MainSlowDownRoutine(_who, _from):\n\tpass\nfunc CheckAchievement_coinflip():\n\tpass\nfunc CheckAchievement_why():\n\tpass\nfunc CheckAchievement_style():\n\tpass\nfunc FinalizeShooting(again, _place, _revive, _delay):\n\tfinishes.append(again)\n\tcp_eject.EjectShell()\n')
	shooting.roundManager = f.rm
	shooting.shellSpawner = f.spawner
	shooting.death = death
	shooting.ejectionManager_player = eject
	shooting.cp_eject = eject
	shooting.cursorManager = f.loader.cursor
	shooting.camera = f.spawner.camera
	shooting.smoke = eject.smoke
	shooting.cameraShaker = child(f.root, stub("CameraShaker", {"Shake": "pass"}))
	shooting.healthCounter = child(f.root, stub("HealthCounter", {"UpdateDisplay": "pass"}))
	shooting.healthCounter.speaker_beep = child(f.root, AudioStreamPlayer3D.new())
	shooting.healthCounter.speaker_beep.stream = AudioStreamGenerator.new()
	shooting.animator_shotgun = animator(f.root, ["player shoot self", "player shoot dealer", "player eject shell", "player eject shell2"])
	shooting.speaker_live = child(f.root, AudioStreamPlayer2D.new())
	shooting.speaker_blank = child(f.root, AudioStreamPlayer2D.new())
	shooting.animator_muzzleFlash = animator(f.root, ["muzzle flash fire"])
	shooting.animator_muzzleFlash_model = animator(f.root, ["fire"])
	child(f.root, shooting)
	var ai = adapted("DealerIntelligence", '\nvar finishes = []\nvar cp_eject\nfunc EndDealerTurn(again):\n\tfinishes.append(again)\n\tif not shellSpawner.sequenceArray.is_empty() and shellSpawner.sequenceArray[0] in ["heal", "blank"]:\n\t\tcp_eject.EjectShell()\n')
	ai.roundManager = f.rm
	ai.shellSpawner = f.spawner
	ai.shotgunShooting = shooting
	ai.healthCounter = shooting.healthCounter
	ai.ejectManager = eject
	ai.cp_eject = eject
	ai.itemManager = f.items
	ai.death = death
	ai.smoke = eject.smoke
	ai.cameraShaker = shooting.cameraShaker
	ai.animator_shotgun = animator(f.root, ["enemy shoot self", "enemy shoot player", "enemy eject shell_from self", "enemy eject shell_from player"])
	child(f.root, ai)
	var animations = []
	shooting.animator_shotgun.animation_started.connect(func(name):
		if name in ["player shoot self", "player shoot dealer"]:
			animations.append(String(name)))
	var shots = 0
	for contract in [0, 11, 12]:
		entry.contract = contract
		for dealer in [false, true]:
			for selected_self in [false, true]:
				for shell in ["live", "blank", "heal", "lethal"]:
					for saw in [false, true]:
						var actual_self = not selected_self if contract == 12 and not dealer else selected_self
						var hit_player = not actual_self if dealer else actual_self
						var initial = 2 if shell == "heal" else 6
						var strength = 2 if saw or contract == 11 else 1
						f.rm.health_player = initial
						f.rm.health_opponent = initial
						f.rm.currentShotgunDamage = 2 if saw else 1
						f.rm.barrelSawedOff = saw
						f.spawner.sequenceArray.assign([shell, "live"])
						f.ai.sequenceArray_knownShell.assign([false, false])
						var deaths_before = death.events.size()
						var finishes_before = ai.finishes.size() if dealer else shooting.finishes.size()
						animations.clear()
						shooting.healthCounter.speaker_beep.stop()
						if dealer:
							await ai.Shoot("self" if selected_self else "player")
						else:
							await shooting.Shoot("self" if selected_self else "dealer")
						# The game's player ejection is dispatched without awaiting it.
						await create_timer(3, false).timeout
						var context = "contract %s dealer %s self %s shell %s saw %s" % [contract, dealer, selected_self, shell, saw]
						var health = initial
						if shell == "live": health -= strength
						if shell == "heal": health += strength
						if shell == "lethal": health = 0
						check(f.rm.health_player == (health if hit_player else initial), "Wrong player HP: " + context)
						check(f.rm.health_opponent == (initial if hit_player else health), "Wrong dealer HP: " + context)
						check(f.spawner.sequenceArray == ["live"] and f.ai.sequenceArray_knownShell.size() == 1, "Shell ejected incorrectly: " + context)
						check(f.rm.currentShotgunDamage == (2 if saw else 1), "Contract changed persistent damage: " + context)
						if not dealer:
							check(animations == ["player shoot self" if actual_self else "player shoot dealer"], "Animation missed actual target: " + context)
						if shell in ["heal", "blank"]:
							var finishes = ai.finishes if dealer else shooting.finishes
							check(finishes.size() == finishes_before + 1 and finishes.back() == actual_self, "Wrong extra turn: " + context)
							check(death.events.size() == deaths_before, "Non-damaging shot entered death: " + context)
						else:
							check(death.events.size() == deaths_before + 1, "Wrong death handler count: " + context)
							check(death.events.back() == ["player" if hit_player else "dealer", health], "Wrong death target: " + context)
						shots += 1
	# A new charge removes both modifiers without mutating the stored saw state.
	for contract in [11, 12]:
		entry.contract = contract
		f.rm.currentShotgunDamage = 1
		port.active.contract = 0
		await port.challenges.begin_round(f.rm)
		check(port.challenges.shot_strength(f.rm) == 1 and port.challenges.player_target(f.rm, "dealer") == "dealer", "Shot modifier leaked into next charge")
	f.root.queue_free()
	await process_frame
	await process_frame
	port.queue_free()
	Engine.time_scale = 1
	await process_frame
	print("CP_SHOT_CONTRACTS: %s failures; %s actual player/dealer shots, four shells, both targets, saw stacking/healing, actual-target animations/turns, death/ejection and charge expiry" % [failures, shots])
	quit(1 if failures else 0)
