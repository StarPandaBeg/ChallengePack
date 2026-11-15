extends SceneTree

var port: Node
var directory: String

func _initialize():
	call_deferred("run")

func run():
	directory = get_script().resource_path.get_base_dir().get_base_dir().path_join("ChallengePack/src")
	port = load(directory.path_join("challengepack.gd")).new()
	port.name = "ChallengePack"
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
	var original_locale = TranslationServer.get_locale()
	TranslationServer.set_locale("en")
	await process_frame
	check(port.options.title.text == "game configuration")
	TranslationServer.set_locale("ru")
	await process_frame
	check(port.options.title.text == "настройка игры")
	check(port.options.buttons.shells.text.begins_with("видимость патронов: "))
	check(port.options.start_button.text == TranslationServer.translate("START"))
	check(port.options.return_button.text == TranslationServer.translate("RETURN"))
	check(port.options.version.text == "ChallengePack 2.0.0 / одиночная игра")
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
