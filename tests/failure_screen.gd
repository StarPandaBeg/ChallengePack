extends "gameplay.gd"

var failures = 0

func check(condition: bool, message: String = "Check failed"):
	if not condition:
		failures += 1
		push_error(message)

func press_action(action: String):
	var event = InputEventAction.new()
	event.action = action
	event.pressed = true
	root.push_input(event, true)
	await process_frame
	event = InputEventAction.new()
	event.action = action
	event.pressed = false
	root.push_input(event, true)
	await process_frame

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
	for language in ["en", "ru"]:
		TranslationServer.set_locale(language)
		for contract in [1, 2, 3]:
			TranslationServer.set_locale(language)
			port.active = port.Settings.DEFAULTS.duplicate()
			port.active.contract = contract + 1
			var f = fixture()
			root.add_child(f.root)
			current_scene = f.root
			f.items.set_process(false)
			f.rm.roundArray[0].usingItems = true
			arm_contract()
			await port.challenges.begin_round(f.rm)
			f.rm.health_player = 3
			f.spawner.sequenceArray.assign(["heal", "blank"])
			f.items.interaction.roundManager = f.rm
			if contract == 2:
				check(not port.challenges.allow_shot(f.rm, "self"))
			else:
				check(not port.challenges.allow_pickup(f.items.interaction, "cigarettes" if contract == 1 else "handcuffs"))
			var screen = port.failure_screen
			check(screen.shown and paused, "Failure did not stop the game")
			check(current_scene == f.root, "Failure immediately replaced the game scene")
			check(not port.challenge_hud.visible)
			check(screen.reason.text.contains(port.localization.text(port.challenges.contract_key(contract))))
			check(screen.title.text == port.localization.text("CP_FAILURE_TITLE"))
			check(not port.challenges.allow_shot(f.rm, "dealer"), "Failed run still allows shots")
			check(not port.challenges.allow_pickup(f.items.interaction, "beer"), "Failed run still allows items")
			port.challenges.fail_contract(f.rm)
			check(port.get_children().filter(func(node): return node == screen).size() == 1, "Duplicate failure screens")
			screen.request_return()
			await process_frame
			check(screen.shown and current_scene == f.root, "Failure input guard was bypassed")
			await create_timer(0.45, true, false, true).timeout
			check(not screen.return_button.disabled and screen.return_button.has_focus())
			check(f.rm.health_player == 3 and f.spawner.sequenceArray == ["heal", "blank"], "Forbidden action modified the game")
			check(root.get_visible_rect().encloses(screen.return_button.get_global_rect()), "Result button is outside the viewport")
			if contract == 1:
				# Mouse click through the actual full-screen GUI, not its signal.
				var event = InputEventMouseButton.new()
				event.button_index = MOUSE_BUTTON_LEFT
				event.position = screen.return_button.get_global_rect().get_center()
				event.global_position = event.position
				event.pressed = true
				root.push_input(event, true)
				Input.flush_buffered_events()
				await process_frame
				event = event.duplicate()
				event.pressed = false
				root.push_input(event, true)
				Input.flush_buffered_events()
			elif contract == 2:
				await press_action("ui_accept")
			else:
				await press_action("ui_cancel")
			await process_frame
			await process_frame
			check(not paused and not screen.shown, "Return left the game paused or screen visible")
			check(current_scene != null and current_scene.scene_file_path == "res://scenes/menu.tscn", "Result did not return to the menu")
			if paused:
				quit(1)
				return
			if current_scene != null:
				current_scene.queue_free()
				current_scene = null
			await process_frame
	# Removing an open result screen must release the pause it owns.
	var f = fixture()
	root.add_child(f.root)
	f.items.set_process(false)
	port.challenges.state(f.rm).contract = 2
	port.challenges.fail_contract(f.rm)
	check(paused)
	port.queue_free()
	await process_frame
	check(not paused, "Removing the mod left the tree paused")
	f.root.queue_free()
	Engine.time_scale = 1
	await create_timer(0.45, true, false, true).timeout
	await process_frame
	print("CP_FAILURE_SCREEN: %s failures; EN/RU, pause, reason, blocked actions, input guard, mouse/accept/back, menu and cleanup" % failures)
	quit(1 if failures else 0)
