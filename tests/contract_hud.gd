extends "gameplay.gd"

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
	var f = fixture()
	root.add_child(f.root)
	f.items.set_process(false)
	check(port.challenges.hud_data().is_empty(), "HUD appeared before a round started")
	for language in ["en", "ru"]:
		TranslationServer.set_locale(language)
		for has_items in [false, true]:
			f.rm.roundArray[0].usingItems = has_items
			for selection in range(port.challenges.LEGACY_SETTING_COUNT):
				choose_contract(selection)
				port.active.pocket = 2
				var before = f.loader.dialogue.texts.size()
				port.contract_effects.armed.stop()
				arm_contract()
				await port.challenges.begin_round(f.rm)
				var entry = port.challenges.state(f.rm)
				check(port.contract_effects.armed.playing == (entry.contract != 0), "Arming sound did not match an actual contract")
				if not has_items:
					var eligible = selection in [1, 3, 12, 13]
					check(entry.contract in [2, 11, 12] if selection == 1 else entry.contract == (selection - 1 if eligible else 0))
					check(entry.paused_contract == (selection - 1 if selection > 1 and not eligible else 0))
					check(f.loader.dialogue.texts.size() - before == (1 if eligible else 0), "Announced an irrelevant contract")
				else:
					check(entry.paused_contract == 0, "Item contract did not resume")
					check(entry.contract in range(1, 13) if selection == 1 else entry.contract == maxi(0, selection - 1))
				var data = port.challenges.hud_data()
				if not data.is_empty():
					check(data.limit == (2 if has_items else 0))
				port.challenge_hud.refresh(data, port.localization)
				await process_frame
				await process_frame
				var panel = port.challenge_hud
				check(panel.bomb.visible == (entry.contract != 0), "Bomb is shown for an inactive or suspended contract")
				check(panel.visible == not data.is_empty())
				check(panel.position == Vector2(8, 8) and panel.size.x <= 224 and panel.size.y <= 70, "HUD exceeds its compact corner bounds: " + str(panel.size))
				for node in panel.find_children("*", "Control", true, false):
					check(node.mouse_filter == Control.MOUSE_FILTER_IGNORE, "HUD intercepts gameplay input")
	# No-item random selection must never return an item restriction.
	port.active.contract = 1
	for i in range(100):
		check(port.challenges.select_contract(false) in [0, 2, 11, 12])
	# The suspended fixed rule returns when the same manager enters an item round.
	choose_contract(2)
	f.rm.roundArray[0].usingItems = false
	arm_contract()
	await port.challenges.begin_round(f.rm)
	check(not port.challenges.item_breaks_contract(f.rm, "cigarettes"))
	f.rm.roundArray[0].usingItems = true
	arm_contract()
	await port.challenges.begin_round(f.rm)
	check(port.challenges.item_breaks_contract(f.rm, "cigarettes"))
	port.challenges.state(f.rm).used = 2
	port.challenge_hud.refresh(port.challenges.hud_data(), port.localization)
	check(port.challenge_hud.pocket.text.contains("0 / 2"))
	# The insurance title changes with charge history, without growing the HUD.
	var entry = port.challenges.state(f.rm)
	entry.contract = 10
	for language in ["en", "ru"]:
		TranslationServer.set_locale(language)
		for history in [[], ["magnifying glass"], ["handcuffs"]]:
			entry.used_items = history.duplicate()
			port.challenge_hud.refresh(port.challenges.hud_data(), port.localization)
			await process_frame
			await process_frame
			check(port.challenge_hud.size.x <= 224 and port.challenge_hud.size.y <= 70, "Insurance HUD grew beyond compact bounds")
	f.root.queue_free()
	await process_frame
	await process_frame
	check(port.challenges.hud_data().is_empty(), "HUD retained a dead scene")
	port.challenge_hud.refresh({}, port.localization)
	check(not port.challenge_hud.visible)
	port.queue_free()
	Engine.time_scale = 1
	await process_frame
	print("CP_CONTRACT_HUD_OK: item applicability, suspension/resumption, random filtering, EN/RU bounds and input passthrough")
	quit()
