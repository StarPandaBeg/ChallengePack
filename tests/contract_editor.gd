extends "gameplay.gd"

var failures = 0

func check(condition: bool, message: String = "Check failed"):
	if not condition:
		failures += 1
		push_error(message)

func action(name: String):
	var event = InputEventAction.new()
	event.action = name
	event.pressed = true
	root.push_input(event, true)
	await process_frame
	event = InputEventAction.new()
	event.action = name
	root.push_input(event, true)
	await process_frame

func click(control: Control):
	control.grab_focus()
	await process_frame
	await process_frame
	for pressed in [true, false]:
		var event = InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.position = control.get_global_rect().get_center()
		event.global_position = event.position
		event.pressed = pressed
		root.push_input(event, true)
		await process_frame

func run():
	var installed = root.get_node_or_null("ChallengePack")
	if installed != null:
		root.remove_child(installed)
		installed.free()
	directory = get_script().resource_path.get_base_dir().get_base_dir().path_join("ChallengePack/src")
	var path = get_script().resource_path.get_base_dir().path_join(".scratch/contract-editor.cfg")
	var Settings = load(directory.path_join("settings.gd"))
	var settings = Settings.new()
	settings.storage_path = path
	check(settings.values.contract_pool.size() == 12 and settings.values.contract_chance == 30, "Wrong new-install defaults")
	for old in range(14):
		var legacy = ConfigFile.new()
		legacy.set_value("rules", "contract", old)
		legacy.set_value("rules", "turn", 2)
		check(legacy.save(path) == OK)
		settings.load_settings()
		check(settings.values.contract == (0 if old == 0 else 1), "Legacy toggle migration failed")
		check(settings.values.contract_pool == (settings.Contracts.ALL_IDS if old <= 1 else [old - 1]), "Legacy fixed contract changed")
		check(settings.values.contract_chance == 30 and settings.values.turn == 2, "Migration lost defaults/other rules")
		var migrated = settings.snapshot()
		check(settings.save_settings() == OK)
		settings.load_settings()
		check(settings.values == migrated, "Migration did not round-trip")
	for pool in [[], [2, 11], settings.Contracts.ALL_IDS]:
		for chance in [0, 30, 100]:
			settings.values.contract_pool = pool.duplicate()
			settings.values.contract_chance = chance
			check(settings.save_settings() == OK)
			settings.load_settings()
			check(settings.values.contract_pool == pool and settings.values.contract_chance == chance, "Pool/chance did not round-trip")
	var frozen = settings.snapshot()
	settings.values.contract_pool.clear()
	check(frozen.contract_pool.size() == 12 and Settings.DEFAULTS.contract_pool.size() == 12, "Party snapshot or defaults share mutable arrays")
	for invalid in ["all", [0], [13], [1.0], [true], [2, "bad"]]:
		var config = ConfigFile.new()
		config.set_value("contracts", "schema", 1)
		config.set_value("contracts", "pool", invalid)
		config.set_value("contracts", "chance", 101)
		config.save(path)
		settings.load_settings()
		check(settings.values.contract_pool == settings.Contracts.ALL_IDS and settings.values.contract_chance == 30, "Invalid config did not fall back")
	var config = ConfigFile.new()
	config.set_value("contracts", "schema", 1)
	config.set_value("contracts", "pool", [12, 2, 12])
	config.set_value("contracts", "chance", 30.0)
	config.save(path)
	settings.load_settings()
	check(settings.values.contract_pool == [2, 12] and settings.values.contract_chance == 30, "Pool normalization failed")
	port = load(directory.path_join("challengepack.gd")).new()
	port.name = "ChallengePack"
	port.news_checked = true
	root.add_child(port)
	check(port.compatible, port.compatibility_error)
	port.settings.storage_path = path
	port.settings.values = Settings.DEFAULTS.duplicate(true)
	port.settings.values.contract = 1
	port.settings.values.contract_pool = [11, 12]
	port.settings.values.contract_chance = 100
	port.active = port.settings.snapshot()
	port.settings.values.contract_pool = [1]
	var seen = {}
	for i in range(3000):
		var result = port.challenges.select_contract(false)
		check(result in [11, 12], "Runtime selected an unchecked contract or changed the frozen party")
		seen[result] = seen.get(result, 0) + 1
	check(seen.size() == 2 and abs(seen[11] - seen[12]) < 300, "Subset selection is biased")
	port.active.contract_pool = []
	check(port.challenges.select_contract(true) == 0, "Empty pool activated a contract")
	port.active.contract_pool = [1, 3]
	check(port.challenges.select_contract(false) == 0, "No-item round activated an inapplicable rule")
	port.active.contract_pool = [2]
	port.active.contract_chance = 0
	check(port.challenges.select_contract(false) == 0, "Zero chance activated a contract")
	port.active.contract_chance = 100
	check(port.challenges.select_contract(false) == 2, "Single selected contract did not activate")
	port.active.contract = 0
	check(port.challenges.select_contract(false) == 0, "Off ignores the toggle")
	port.settings.values = Settings.DEFAULTS.duplicate(true)
	port.settings.save_settings()
	change_scene_to_file("res://scenes/menu.tscn")
	await process_frame
	var manager = current_scene.get_node("standalone managers/menu manager")
	manager.SkipIntro()
	manager.Start()
	var menu = port.options
	var editor = menu.editor
	check(not menu.edit_button.visible, "Edit is visible while contracts are off")
	await click(menu.buttons.contract)
	check(port.settings.values.contract == 1 and menu.edit_button.visible, "On did not reveal Edit")
	await click(menu.edit_button)
	check(editor.shown and editor.checks[1].has_focus(), "Modal did not open with checkbox focus")
	menu.start()
	check(editor.shown and menu.shown, "Start escaped the modal")
	for language in ["en", "ru", "pl"]:
		TranslationServer.set_locale(language)
		await process_frame
		await process_frame
		check(root.get_visible_rect().encloses(editor.box.get_global_rect()), "Editor overflows in " + language + ": " + str(editor.box.get_global_rect()))
		for id in editor.checks:
			check(editor.checks[id].get_minimum_size().x <= 376, "Checkbox text is too wide in " + language)
			check(not editor.checks[id].tooltip_text.begins_with("CP_"), "Checkbox lacks explanation")
		check(root.get_visible_rect().encloses(menu.version.get_global_rect()), "Russian menu footer is outside viewport")
	await action("ui_accept")
	check(not editor.checks[1].button_pressed and not 1 in port.settings.values.contract_pool, "Accept did not toggle a checkbox")
	await click(editor.checks[2])
	check(not 2 in port.settings.values.contract_pool, "Mouse did not toggle a checkbox")
	await click(editor.select_all)
	check(port.settings.values.contract_pool.size() == 12, "Select all omitted contracts")
	editor.chance_slider.value = 37
	check(port.settings.values.contract_chance == 37 and editor.chance_label.text.contains("37%"), "Slider percentage is stale")
	editor.chance_slider.grab_focus()
	await action("ui_right")
	check(port.settings.values.contract_chance == 38, "Keyboard/controller cannot change the slider")
	settings.load_settings(path)
	check(settings.values.contract_chance == 38 and settings.values.contract_pool.size() == 12, "Modal edits were not saved")
	await click(editor.select_none)
	await process_frame
	await process_frame
	check(editor.empty_label.visible and port.settings.values.contract_pool.is_empty(), "Empty selection has no explanation")
	settings.load_settings(path)
	check(settings.values.contract_pool.is_empty(), "Deselect all did not persist")
	check(root.get_visible_rect().encloses(editor.box.get_global_rect()), "Empty-selection message overflows")
	await action("ui_cancel")
	check(not editor.shown and menu.shown and menu.edit_button.has_focus(), "Back closed the parent menu or lost focus")
	await click(menu.edit_button)
	await click(editor.close_button)
	check(not editor.shown and menu.shown, "Done closed the whole menu")
	check(not menu.heal_edit_button.visible, "Healing editor hidden while disabled")
	await click(menu.buttons.heal)
	await click(menu.heal_edit_button)
	check(menu.heal_editor.shown and menu.heal_editor.slider.has_focus(), "Healing modal opens with slider focus")
	for language in ["en", "ru", "pl"]:
		TranslationServer.set_locale(language)
		await process_frame
		await process_frame
		check(root.get_visible_rect().encloses(menu.heal_editor.box.get_global_rect()), "Healing modal fits " + language)
	menu.heal_editor.slider.value = 47
	await action("ui_right")
	check(port.settings.values.heal_chance == 48, "Healing slider supports keyboard/controller")
	settings.load_settings(path)
	check(settings.values.heal_chance == 48, "Healing chance saved")
	await action("ui_cancel")
	check(not menu.heal_editor.shown and menu.shown and menu.heal_edit_button.has_focus(), "Healing Back preserves the menu and focus")
	await action("ui_cancel")
	check(not menu.shown and manager.is_processing_input(), "Menu did not restore vanilla input")
	current_scene.queue_free()
	current_scene = null
	await process_frame
	await process_frame
	port.queue_free()
	await process_frame
	DirAccess.remove_absolute(path)
	print("CP_CONTRACT_EDITOR: %s failures; legacy migration, validation, snapshots, subset/chance selection, EN/RU bounds, mouse/accept/back, slider, select all, persistence and modal lifecycle" % failures)
	quit(1 if failures else 0)
