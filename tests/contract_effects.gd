extends "gameplay.gd"

var failures = 0

func check(condition: bool, message: String = "Check failed"):
	if not condition:
		failures += 1
		push_error(message)

func real_room() -> Node:
	var scene = load("res://scenes/main.tscn").instantiate()
	# Bypass only the unrelated scene notification and prefill the round normally
	# assigned by MainBatchSetup. All shot animations and exported links are real.
	for node in scene.find_children("*", "Node", true, false):
		var script = node.get_script()
		if script != null and script.resource_path == "res://scripts/SceneChangeNotification.gd":
			node.set_script(null)
	var manager = scene.get_node("standalone managers/round manager")
	var round_data = load("res://scripts/RoundClass.gd").new()
	round_data.usingItems = true
	manager.roundArray.assign([round_data])
	root.add_child(scene)
	current_scene = scene
	Engine.time_scale = 10
	return scene

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
	port.news_checked = true
	var effects = port.contract_effects
	check(effects.armed.stream is AudioStreamWAV and effects.armed.stream.get_length() > 0, "Arming beep did not load without import")
	check(effects.breach.stream is AudioStreamWAV and effects.breach.stream.get_length() > 0, "Breach sound did not load without import")
	check(port.challenge_hud.bomb.texture != null, "C4 image did not load without import")
	var forbidden_items = {1: "cigarettes", 3: "handcuffs", 4: "burner phone", 5: "beer", 6: "handsaw", 7: "adrenaline", 8: "beer", 9: "inverter", 10: "handcuffs"}
	for contract in range(1, 11):
		var scene = real_room()
		var manager = scene.get_node("standalone managers/round manager")
		var shooting = manager.dealerAI.shotgunShooting
		manager.endless = contract % 2 == 0
		manager.health_player = 3
		manager.shellSpawner.sequenceArray.assign(["heal", "blank"])
		var shots = manager.playerData.stat_shotsFired
		var entry = port.challenges.state(manager)
		entry.contract = contract
		entry.started = true
		entry.has_items = true
		port.challenges.track(manager)
		port.challenge_hud.refresh(port.challenges.hud_data(), port.localization)
		check(port.challenge_hud.bomb.visible, "Active contract has no bomb")
		port.contract_effects.announce(manager)
		check(effects.armed.playing, "Contract activation did not beep")
		if contract == 2:
			shooting.Shoot("self") # Actual adapter must intercept before consuming a shell.
		else:
			if contract == 10:
				check(port.challenges.allow_pickup(manager.itemManager.interaction, "magnifying glass"))
			manager.itemManager.interaction.PickupItemFromTable(null, forbidden_items[contract])
		check(entry.failed and effects.executing and paused, "Violation did not enter the paused cinematic")
		check(not port.failure_screen.shown, "Result appeared before the shot")
		check(effects.breach.playing and not effects.armed.playing, "Violation warning did not replace arming sound")
		check(shooting.animator_shotgun.current_animation == "player grab shotgun", "Actual grab animation did not play")
		port.challenges.fail_contract(manager)
		var ticket = effects.sequence
		check(not port.challenges.allow_shot(manager, "dealer"), "Failed run accepts another shot")
		await create_timer(0.85, true).timeout
		check(effects.sequence == ticket and effects.executing, "Duplicate violation restarted the cinematic")
		check(shooting.animator_shotgun.current_animation == "player shoot self", "Actual self-shot animation did not play")
		check(not port.failure_screen.shown, "Result interrupted aiming")
		await create_timer(2.5, true).timeout
		check(effects.gunshot.playing, "Live gunshot sound did not play")
		check(effects.gunshot.stream == shooting.speaker_live.stream, "Penalty depends on chamber shell type")
		check(effects.blackout.color.a > 0, "Shot did not fade to black")
		await create_timer(0.8, true).timeout
		check(not effects.executing and port.failure_screen.shown and paused, "Shot did not lead to result")
		check(not port.failure_screen.previous_paused, "Result inherited a pause that it cannot release")
		check(manager.health_player == 3 and manager.shellSpawner.sequenceArray == ["heal", "blank"], "Cinematic mutated HP or shells")
		check(manager.playerData.stat_shotsFired == shots, "Cinematic updated shot statistics")
		check(shooting.animator_shotgun.process_mode == Node.PROCESS_MODE_INHERIT, "Animation process mode leaked")
		await create_timer(0.45, true, false, true).timeout
		port.failure_screen.request_return()
		await process_frame
		await process_frame
		check(not paused and not port.failure_screen.shown, "Return left the game paused")
		check(current_scene.scene_file_path == "res://scenes/menu.tscn", "Result did not return to menu")
		current_scene.queue_free()
		current_scene = null
		await process_frame
		await process_frame
	# Interrupting a scene or removing the mod cancels pending timers and sound.
	for remove_mod in [false, true]:
		var scene = real_room()
		var manager = scene.get_node("standalone managers/round manager")
		port.challenges.state(manager).contract = 2
		port.challenges.fail_contract(manager)
		check(effects.executing and paused, "Cleanup fixture did not start")
		if remove_mod:
			port.queue_free()
		scene.queue_free()
		current_scene = null
		await process_frame
		await process_frame
		check(not paused, "Interrupted cinematic left the tree paused")
		await create_timer(1.1, true, false, true).timeout
		if not remove_mod:
			check(not effects.executing and not port.failure_screen.shown and not effects.gunshot.playing, "Interrupted sequence resumed in another scene")
	Engine.time_scale = 1
	print("CP_CONTRACT_EFFECTS: %s failures; import-free assets, ten real-room violations, grab/self-shot, warning/gunshot/fade/result, duplicate actions, unchanged rules, scene/mod cleanup" % failures)
	quit(1 if failures else 0)
