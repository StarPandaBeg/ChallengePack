extends SceneTree

var failures = 0
var port: Node

func _initialize(): call_deferred("run")

func check(ok: bool, reason: String):
	if not ok:
		failures += 1
		push_error(reason)

func run():
	var globals = root.get_node("GlobalVariables")
	var steam = root.get_node("GlobalSteam")
	var installed = root.get_node_or_null("ChallengePack")
	if installed != null:
		root.remove_child(installed)
		installed.free()
	var directory = get_script().resource_path.get_base_dir().get_base_dir().path_join("ChallengePack/src")
	port = load(directory.path_join("challengepack.gd")).new()
	port.name = "ChallengePack"
	root.add_child(port)
	check(port.mp.compatible, port.mp.error)
	change_scene_to_file("res://multiplayer/scenes/mp_lobby.tscn")
	await process_frame
	await process_frame
	check(is_instance_valid(port.mp.ui), "Lobby settings UI created")
	port.mp.set_process(false) # Never create/join real lobbies from a fixture.
	for language in ["en", "ru"]:
		TranslationServer.set_locale(language)
		port.mp.ui.toggle()
		port.mp.ui.refresh()
		await process_frame
		check(root.get_visible_rect().encloses(port.mp.ui.panel.get_global_rect()), "Lobby menu fits " + language)
		check(port.mp.ui.choices.size() == 9, "All nine settings")
		port.mp.ui.open_editor()
		await process_frame
		check(root.get_visible_rect().encloses(port.mp.ui.editor.get_global_rect()), "Contract editor fits " + language)
		check(port.mp.ui.checks.size() == 12, "All twelve contracts")
		port.mp.ui.toggle()
	change_scene_to_file("res://multiplayer/scenes/mp_main.tscn")
	await process_frame
	await process_frame
	port.mp.set_process(false)
	globals.mp_debugging = true # Suppress Steam sends, use actual scene resources.
	globals.timeouts_enabled = false
	steam.HOST_ID = steam.STEAM_ID
	steam.LOBBY_MEMBERS = [{"steam_id": steam.STEAM_ID, "steam_name": "Host"}]
	var game = port.mp.game
	var handler = game.instance_handler
	var players = []
	for i in 4:
		players.append({"socket_number": i, "user_id": steam.STEAM_ID if i == 0 else i, "user_name": "Fixture %s" % i, "cpu_enabled": false})
	handler.SetupInstances_test(players)
	await process_frame
	await process_frame
	for p in handler.instance_property_array:
		p.health_current = 3
		p.health_counter.prev_health = 3
		p.health_on_round_start = 4
	check(handler.instance_property_array.size() == 4, "Four player instances")
	port.mp.rules.settings.mirror = 1
	game.MAIN_active_num_of_items_to_grab = 4
	port.mp.prepare_mirror(game.round_manager)
	var expected = handler.instance_property_array[0].user_inventory
	for p in handler.instance_property_array:
		check(p.user_inventory == expected, "Mirrored inventories match")
		check(p.shotgun.has_meta("challengepack_hooked"), "Shotgun adapter attached")
	port.mp.rules.settings.items = 1
	port.mp.presentation()
	check(port.mp.covers.size() == 3, "One protector pair per rival")
	port.mp.rules.settings.shells = 2
	game.MAIN_active_sequence_dict = {"sequence": ["live", "blank", "blank"], "sequence_visible": ["live", "blank", "blank"], "sequence_in_shotgun": ["live", "blank", "blank"]}
	port.mp.rules.settings.heal = 1
	port.mp.rules.settings.shuffle = 1
	port.mp.generate_sequence(game.round_manager)
	check(game.MAIN_active_sequence_dict.sequence_in_shotgun.has("heal"), "Healing shell in host charge")
	check(not game.MAIN_active_sequence_dict_send.has("sequence_in_shotgun"), "Hidden order not broadcast")
	check(game.MAIN_active_sequence_dict_send.sequence_visible.is_empty(), "Hidden charge redacted")
	game.round_manager.shell_loader.SpawnShells()
	for mesh in game.round_manager.shell_loader.shell_instance_array:
		check(not mesh.visible, "Hidden loader shows no shells")
	var before = port.mp.snapshot()
	port.mp.apply_snapshot(before)
	check(port.mp.snapshot() == before, "Snapshot round trip")
	for p in handler.instance_property_array:
		p.health_counter.speaker_increase_health.stop()
	current_scene.queue_free()
	await process_frame
	port.queue_free()
	await process_frame
	print("CP_MULTIPLAYER_SCENE: failures=", failures)
	quit(1 if failures else 0)
