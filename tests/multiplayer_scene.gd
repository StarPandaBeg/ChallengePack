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
	check(port.mp.ui.open_button.get_parent() == port.mp.lobby_ui.ui_parent_lobby_home, "Entry follows native lobby visibility")
	check(port.mp.ui.ready_button.get_parent() == port.mp.lobby_ui.ui_parent_lobby_home, "Ready is a lobby action, outside the settings submenu")
	for language in ["en", "ru"]:
		TranslationServer.set_locale(language)
		port.mp.ui.toggle()
		port.mp.ui.refresh()
		port.mp.ui.status.text = "Host: ready\nGuest 1: ready\nGuest 2: ready\nGuest 3: ready"
		await process_frame
		check(root.get_visible_rect().encloses(port.mp.ui.panel.get_global_rect()), "Lobby menu fits " + language)
		check(port.mp.ui.choices.size() == 9, "All nine settings")
		check(port.mp.ui.backdrop.visible, "Settings block pointer input to the underlying lobby")
		check(not port.mp.ui.ready_button.visible, "Lobby ready action stays outside modal settings")
		check(root.get_visible_rect().encloses(port.mp.ui.ready_button.get_global_rect()), "Lobby ready action fits " + language)
		check(port.mp.ui.choices.shells.get_theme_color("font_color") == Color(0, 1, 0), "Native green lobby theme")
		port.mp.ui.open_editor()
		await process_frame
		check(root.get_visible_rect().encloses(port.mp.ui.editor.get_global_rect()), "Contract editor fits " + language)
		check(port.mp.ui.checks.size() == 12, "All twelve contracts")
		port.mp.ui.toggle()
		check(port.mp.ui.ready_button.visible, "Ready available after closing settings")
	change_scene_to_file("res://multiplayer/scenes/mp_main.tscn")
	await process_frame
	await process_frame
	port.mp.set_process(false)
	check(not port.mp.ui.ready_button.visible, "No readiness action during a match")
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
	port.mp.rules.settings.items = 1
	port.mp.presentation()
	check(port.mp.covers.is_empty(), "Protectors wait for deferred player initialization")
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
	for local_socket in 4:
		for p in handler.instance_property_array: p.is_active = p.socket_number == local_socket
		port.mp.presentation()
		check(port.mp.covers.size() == 3 and not port.mp.covers.has(local_socket), "Only rivals covered from seat %s" % local_socket)
		for p in handler.instance_property_array:
			if p.is_active: continue
			var holder = port.mp.covers[p.socket_number]
			check(holder.is_visible_in_tree(), "Protectors visible from seat %s" % local_socket)
			check(holder.get_parent() == p.item_manager.item_spawn_parent_local.get_parent(), "Inventory cleanup cannot delete protectors")
			check(holder.transform == p.item_manager.item_spawn_parent_local.transform, "Protector anchor matches seat transform")
	for p in handler.instance_property_array: p.is_active = p.socket_number == 0
	port.mp.presentation()
	var removed_cover = port.mp.covers[1]
	removed_cover.queue_free()
	await process_frame
	port.mp.presentation()
	check(is_instance_valid(port.mp.covers[1]), "Deleted protector is recreated")
	port.mp.rules.state(1).contract = port.mp.rules.Catalog.Contract.NO_INVERSION
	port.mp.ui.refresh()
	await process_frame
	check(port.mp.ui.bomb.visible and port.mp.ui.bomb.size == Vector2(20, 20), "Contract bomb remains a 20px HUD icon")
	check(root.get_visible_rect().encloses(port.mp.ui.bomb.get_global_rect()), "Contract icon stays within screen")
	port.mp.rules.state(1).contract = 0
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
	# Run actual first/third person animations and their method tracks, not stubs.
	var actor = handler.instance_property_array[0]
	game.MAIN_active_current_turn_socket = 0
	game.MAIN_active_round_index = 0
	actor.has_turn = true
	actor.health_current = 1
	actor.health_counter.prev_health = 1
	port.mp.rules.state(0).contract = port.mp.rules.Catalog.Contract.TWO_FOR_ONE
	port.mp.rules.state(0).used = 2
	port.mp.rules.last_actor = 0
	game.MAIN_active_sequence_dict.sequence_in_shotgun = ["heal", "blank", "live"]
	port.mp.resolve_shot(null, {"sent_from_socket": 0, "socket_to_shoot": 0})
	await create_timer(4.4).timeout
	check(actor.health_current == 3, "Actual green shot heals twice")
	check(actor.has_turn, "Actual healing self-shot preserves turn")
	check(port.mp.rules.state(0).used == 2, "Extra turn preserves pocket usage")
	check(game.MAIN_active_sequence_dict.sequence_in_shotgun == ["blank", "live"], "One shell consumed")
	var rival = handler.instance_property_array[1]
	rival.health_current = 3
	game.MAIN_active_sequence_dict.sequence_in_shotgun = ["lethal", "blank", "live"]
	port.mp.resolve_shot(null, {"sent_from_socket": 0, "socket_to_shoot": 1})
	await create_timer(4.4).timeout
	check(rival.health_current == 0, "Actual black shot kills immediately")
	check(game.MAIN_active_sequence_dict.sequence_in_shotgun == ["blank", "live"], "Black shot consumes once")
	var remaining = game.MAIN_active_sequence_dict.sequence_in_shotgun.duplicate()
	port.mp.punish(2)
	await create_timer(5.5).timeout
	check(handler.instance_property_array[2].health_current == 0, "Contract penalty kills violator")
	check(game.MAIN_active_sequence_dict.sequence_in_shotgun == remaining, "Contract penalty preserves charge")
	for p in handler.instance_property_array:
		p.health_counter.speaker_increase_health.stop()
	current_scene.queue_free()
	await process_frame
	await process_frame
	check(not is_instance_valid(port.mp.ui) and not is_instance_valid(port.mp.game), "Network UI and managers cleared on exit")
	port.queue_free()
	await process_frame
	print("CP_MULTIPLAYER_SCENE: failures=", failures)
	quit(1 if failures else 0)
