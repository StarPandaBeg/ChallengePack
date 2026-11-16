extends SceneTree

var failures = 0

func _initialize():
	call_deferred("run")

func check(condition: bool, message: String):
	if not condition:
		failures += 1
		push_error(message)

func run():
	var installed = root.get_node_or_null("ChallengePack")
	if installed != null:
		root.remove_child(installed)
		installed.free()
	var repository = get_script().resource_path.get_base_dir().get_base_dir()
	var directory = repository.path_join("ChallengePack/src")
	var scratch = repository.path_join("tests/.scratch/news")
	DirAccess.make_dir_recursive_absolute(scratch.path_join("assets/news"))
	var state_path = scratch.path_join("state.cfg")
	if FileAccess.file_exists(state_path):
		DirAccess.remove_absolute(state_path)
	var port = load(directory.path_join("challengepack.gd")).new()
	port.name = "ChallengePack"
	root.add_child(port)
	check(port.compatible, port.compatibility_error)
	change_scene_to_file("res://scenes/menu.tscn")
	await process_frame
	var manager = current_scene.get_node("standalone managers/menu manager")
	var news = port.news
	news.state_path = state_path
	news.force_show = 0 # Isolate persistence checks from the local preview flag.
	check(not news.shown and not port.news_checked, "News interrupted the intro")
	check(news.should_show(), "First launch did not qualify")
	manager.SkipIntro()
	await process_frame
	await process_frame
	check(news.shown and port.news_checked, "First entry did not open news")
	check(not manager.is_processing_input(), "Vanilla input is active behind news")
	check(news.close_button.has_focus(), "Close button did not receive focus")
	manager.Start()
	check(not port.options_open(), "Start opened settings behind news")
	check(news.cards.size() == 9, "Missing challenge cards")
	for locale in ["en", "ru", "pl"]:
		TranslationServer.set_locale(locale)
		news.refresh()
		await process_frame
		await process_frame
		check(root.get_visible_rect().encloses(news.close_button.get_global_rect()), "Close button overflows in " + locale)
		check(root.get_visible_rect().encloses(news.scroll.get_global_rect()), "Scroll area overflows in " + locale)
		check(news.scroll.get_v_scroll_bar().max_value > news.scroll.size.y, "Cards are not scrollable")
		for card in news.cards:
			check(not card.description.text.begins_with("CP_"), "Missing news translation")
			check(card.control.size.x <= news.scroll.size.x, "Card overflows horizontally")
			check(card.description.size.y >= card.description.get_minimum_size().y, "Clipped card text")
		news.cards[-1].control.grab_focus()
		await process_frame
		await process_frame
		check(news.scroll.scroll_vertical > 0, "Focus did not scroll to last card")
	news.close_button.grab_focus()
	var down = InputEventKey.new()
	down.keycode = KEY_DOWN
	down.pressed = true
	root.push_input(down, true)
	check(news.cards[0].control.has_focus(), "Arrow navigation did not wrap to the first card")
	var released = InputEventKey.new()
	released.keycode = KEY_DOWN
	root.push_input(released, true)
	var cancel = InputEventAction.new()
	cancel.action = "ui_cancel"
	cancel.pressed = true
	root.push_input(cancel, true)
	check(not news.shown and manager.is_processing_input(), "Back did not restore menu input")
	check(manager.firstFocus_main.has_focus(), "Main menu focus was not restored")
	check(not news.should_show(), "Read state was not persisted")
	var config = ConfigFile.new()
	config.load(state_path)
	check(config.get_value("news", "seen_version") == port.VERSION, "Wrong version saved")
	config.set_value("news", "seen_version", "older")
	config.save(state_path)
	check(news.should_show(), "A new version did not qualify")
	news.open()
	news.close_button.pressed.emit()
	check(not news.shown and not news.should_show(), "Close button did not acknowledge news")
	news.force_show = 1
	check(news.should_show(), "Forced preview ignored the debug parameter")
	await process_frame
	check(not news.shown, "Forced preview reopened during the same launch")
	port.news_checked = false # Simulate the next application launch.
	await process_frame
	await process_frame
	check(news.shown, "Forced preview did not open on next launch")
	news.close()
	var original_directory = port.mod_directory
	port.mod_directory = scratch
	var image = Image.create(320, 180, false, Image.FORMAT_RGBA8)
	image.fill(Color.DARK_RED)
	image.save_png(scratch.path_join("assets/news/heal.png"))
	var texture = news.screenshot("heal")
	check(texture != null and texture.get_width() == 320, "Raw PNG screenshot requires editor import")
	check(news.screenshot("missing") == null, "Missing screenshot did not fall back")
	port.mod_directory = original_directory
	change_scene_to_file("res://scenes/menu.tscn")
	await process_frame
	await process_frame
	manager = current_scene.get_node("standalone managers/menu manager")
	port.news.state_path = state_path
	port.news.force_show = 1
	manager.SkipIntro()
	await process_frame
	await process_frame
	check(not port.news.shown, "News reappeared after returning to the menu")
	print("CP_NEWS_OK: first entry, version persistence, forced preview, nine localized cards, scroll/focus, modal input, raw PNG, scene lifecycle; failures: ", failures)
	quit(1 if failures else 0)
