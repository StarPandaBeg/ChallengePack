extends SceneTree

var port: Node
var directory: String

func _initialize():
	call_deferred("run")

func run():
	# Keep fixtures isolated from a mod already installed beside the game.
	var installed = root.get_node_or_null("ChallengePack")
	if installed != null:
		root.remove_child(installed)
		installed.free()
	directory = get_script().resource_path.get_base_dir().get_base_dir().path_join("ChallengePack/src")
	port = load(directory.path_join("challengepack.gd")).new()
	port.name = "ChallengePack"
	port.news_checked = true # News has its own first-launch fixture.
	root.add_child(port)
	check(port.compatible, port.compatibility_error)
	change_scene_to_file("res://scenes/menu.tscn")
	await process_frame
	var scene = current_scene
	var manager = scene.get_node("standalone managers/menu manager")
	manager.SkipIntro()
	check(manager.has_meta("challengepack_hooked"))
	manager.Start()
	check(port.options_open())
	check(port.options.start_button.disabled == false)
	check(port.options.buttons.shells.has_focus())
	await process_frame
	await process_frame
	check(port.options.buttons.size() == 9)
	var viewport_rect = root.get_visible_rect()
	check(port.options.buttons.items.position.x > port.options.buttons.shells.position.x, "Settings are not in two columns")
	check(is_equal_approx(port.options.buttons.items.position.y, port.options.buttons.shells.position.y))
	var saved_values = port.settings.snapshot()
	for language in ["en", "ru"]:
		TranslationServer.set_locale(language)
		for key in port.options.buttons:
			var arguments = [roundi(port.challenges.activation_chance * 100)] if key == "contract" else []
			check(port.options.buttons[key].get_tooltip().begins_with(port.localization.text("CP_TIP_" + key.to_upper(), arguments)), "Missing or stale setting tooltip: " + key)
		check(port.options.start_button.get_tooltip() == port.localization.text("CP_TIP_START"))
		check(port.options.return_button.get_tooltip() == port.localization.text("CP_TIP_RETURN"))
		for key in port.options.buttons:
			for value in range(port.Settings.LIMITS[key]):
				port.settings.values[key] = value
				port.options.refresh()
				if key == "contract" and value > 1:
					check(port.options.buttons.contract.tooltip_text.contains(port.localization.text(port.challenges.CATALOG[value - 1].detail)), "Contract tooltip omits its rule")
				await process_frame
				await process_frame
				for button in port.options.buttons.values() + [port.options.start_button, port.options.return_button]:
					check(viewport_rect.encloses(button.get_global_rect()), "Two-column menu overflows: " + button.text)
	port.settings.values = saved_values
	var previous_chance = port.challenges.activation_chance
	for language in ["en", "ru"]:
		TranslationServer.set_locale(language)
		for chance in [0.0, 0.30, 1.0]:
			port.challenges.activation_chance = chance
			port.options.refresh()
			var percent = "%d%%" % roundi(chance * 100)
			check(port.options.buttons.contract.text.contains(percent), "Contract caption has a stale probability")
			check(port.options.buttons.contract.tooltip_text.contains(percent), "Contract tooltip has a stale probability")
	port.challenges.activation_chance = previous_chance
	port.options.refresh()
	check(port.options.buttons.shells.get_node(port.options.buttons.shells.focus_neighbor_right) == port.options.buttons.items)
	check(port.options.buttons.shells.get_node(port.options.buttons.shells.focus_neighbor_bottom) == port.options.buttons.shuffle)
	check(port.options.buttons.heal.get_node(port.options.buttons.heal.focus_neighbor_bottom) == port.options.start_button)
	for button in port.options.buttons.values() + [port.options.start_button, port.options.return_button]:
		check(viewport_rect.encloses(button.get_global_rect()), "Challenge menu extends beyond the viewport: %s %s in %s" % [button.text, button.get_global_rect(), viewport_rect])
	var original_locale = TranslationServer.get_locale()
	TranslationServer.set_locale("en")
	await process_frame
	check(port.options.title.text == "game configuration")
	TranslationServer.set_locale("ru")
	await process_frame
	await process_frame
	for button in port.options.buttons.values() + [port.options.start_button, port.options.return_button]:
		check(viewport_rect.encloses(button.get_global_rect()), "Russian challenge menu extends beyond the viewport")
	check(port.options.title.text == "настройка игры")
	check(port.options.buttons.shells.text.begins_with("видимость патронов:\n"))
	check(port.options.start_button.text == TranslationServer.translate("START"))
	check(port.options.return_button.text == TranslationServer.translate("RETURN"))
	check(port.options.version.text == "ChallengePack 2.1.0 / одиночная игра")
	TranslationServer.set_locale(original_locale)
	port.close_options()
	check(not port.options_open())
	manager.StartMultiplayer()
	check(current_scene == scene)
	check(port.notice_until > Time.get_ticks_msec())
	var lobby = scene.get_node("standalone managers/mp_lobby manager")
	lobby.join_lobby(123)
	lobby.CreateLobby()
	scene.get_node("standalone managers/mp_command line checker").JoinGameOutsideLobby(123)
	check(current_scene == scene)
	var board = port.guard.scripts[port.guard.BOARD].new()
	board.cp_port = port
	board.UploadScore(3, 100, 100)
	board.UploadScore_Deprecated(3, 100, 100)
	board.free()
	port.compatible = false
	port.compatibility_error = "Test incompatibility"
	manager.Start()
	check(port.options.start_button.disabled)
	port.close_options()
	port.compatible = true
	var weak_menu = weakref(port.options)
	scene.queue_free()
	await process_frame
	check(weak_menu.get_ref() == null)
	current_scene = null
	change_scene_to_file("res://scenes/menu.tscn")
	await process_frame
	var scene2 = current_scene
	check(port.options != null and port.options != weak_menu.get_ref())
	scene2.queue_free()
	await process_frame
	port.queue_free()
	await process_frame
	print("CP_SMOKE_OK: real menu hooks, focus, online block, scene recreation")
	quit()

func check(condition: bool, message: String = "Check failed"):
	if not condition:
		push_error(message)
		quit(1)
