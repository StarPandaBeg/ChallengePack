extends CanvasLayer

# Set to 1 to show the news on every launch, even after it was read.
const FORCE_SHOW = 0
const STATE_PATH = "user://challengepack_news.cfg"
const CARDS = ["shells", "items", "shuffle", "turn", "health", "mirror", "pocket", "contract", "heal"]
var state_path = STATE_PATH
var force_show = FORCE_SHOW
var port: Node
var manager: Node
var panel: Control
var scroll: ScrollContainer
var heading: Label
var subtitle: Label
var close_button: Button
var cards = []
var shown = false

func setup(owner_port: Node, menu_manager: Node):
	port = owner_port
	manager = menu_manager
	layer = 125
	panel = Control.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(panel)
	var background = ColorRect.new()
	background.color = Color("13110ff5")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.add_child(background)
	var margin = MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for edge in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + edge, 24)
	panel.add_child(margin)
	var column = VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	margin.add_child(column)
	heading = make_label(column, 28, Color("e4d5ba"))
	subtitle = make_label(column, 17, Color("aaa18f"))
	scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	column.add_child(scroll)
	var list = VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 12)
	scroll.add_child(list)
	for key in CARDS:
		var card = PanelContainer.new()
		card.focus_mode = Control.FOCUS_ALL
		var style = StyleBoxFlat.new()
		style.bg_color = Color("25221e")
		style.set_content_margin_all(14)
		card.add_theme_stylebox_override("panel", style)
		var focus = style.duplicate()
		focus.bg_color = Color.TRANSPARENT
		focus.border_color = Color("c9b78e")
		focus.set_border_width_all(2)
		card.add_theme_stylebox_override("focus", focus)
		list.add_child(card)
		var row = HBoxContainer.new()
		row.add_theme_constant_override("separation", 18)
		card.add_child(row)
		var picture = PanelContainer.new()
		picture.custom_minimum_size = Vector2(180, 106)
		var picture_style = StyleBoxFlat.new()
		picture_style.bg_color = Color("151512")
		picture_style.border_color = Color("605949")
		picture_style.set_border_width_all(1)
		picture.add_theme_stylebox_override("panel", picture_style)
		row.add_child(picture)
		var texture = screenshot(key)
		var placeholder: Label
		if texture != null:
			var image = TextureRect.new()
			image.texture = texture
			image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			picture.add_child(image)
		else:
			placeholder = make_label(picture, 14, Color("8d8575"))
			placeholder.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		var text = VBoxContainer.new()
		text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		text.add_theme_constant_override("separation", 8)
		row.add_child(text)
		var title = make_label(text, 21, Color("e4d5ba"))
		var description = make_label(text, 18, Color("bfb5a3"))
		cards.append({"key": key, "control": card, "title": title, "description": description, "placeholder": placeholder})
	close_button = Button.new()
	close_button.custom_minimum_size.y = 40
	close_button.add_theme_font_size_override("font_size", 20)
	close_button.pressed.connect(close)
	column.add_child(close_button)
	var navigation = []
	for card in cards:
		navigation.append(card.control)
	navigation.append(close_button)
	for i in navigation.size():
		var control = navigation[i]
		var previous = control.get_path_to(navigation[(i - 1 + navigation.size()) % navigation.size()])
		var next = control.get_path_to(navigation[(i + 1) % navigation.size()])
		control.focus_previous = previous
		control.focus_neighbor_top = previous
		control.focus_next = next
		control.focus_neighbor_bottom = next
	panel.hide()
	refresh()

func make_label(parent: Node, font_size: int, color: Color) -> Label:
	var result = Label.new()
	result.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	result.add_theme_font_size_override("font_size", font_size)
	result.add_theme_color_override("font_color", color)
	parent.add_child(result)
	return result

func screenshot(key: String) -> Texture2D:
	var path = port.mod_directory.path_join("assets/news/%s.png" % key)
	if not FileAccess.file_exists(path):
		return null
	# Raw images work in the installed mod without editor-generated imports.
	var image = Image.load_from_file(path)
	return null if image == null else ImageTexture.create_from_image(image)

func should_show() -> bool:
	if force_show == 1:
		return true
	var config = ConfigFile.new()
	return config.load(state_path) != OK or config.get_value("news", "seen_version", "") != port.VERSION

func _process(_delta):
	if port == null or port.news_checked or manager.viewing_intro or port.options_open():
		return
	port.news_checked = true
	if should_show():
		open()

func refresh():
	heading.text = port.localization.text("CP_NEWS_TITLE", [port.VERSION])
	subtitle.text = port.localization.text("CP_NEWS_SUBTITLE")
	close_button.text = port.localization.text("CP_NEWS_CLOSE")
	for card in cards:
		card.title.text = port.localization.text("CP_NEWS_" + card.key.to_upper() + "_TITLE")
		card.description.text = port.localization.text("CP_NEWS_" + card.key.to_upper())
		if card.placeholder != null:
			card.placeholder.text = port.localization.text("CP_NEWS_SCREENSHOT")

func open():
	if shown:
		return
	shown = true
	manager.Buttons(false)
	manager.set_process_input(false)
	manager.parent_main.hide()
	refresh()
	panel.show()
	scroll.scroll_vertical = 0
	close_button.grab_focus()
	manager.controller.previousFocus = close_button

func close():
	if not shown:
		return
	var config = ConfigFile.new()
	config.set_value("news", "seen_version", port.VERSION)
	var result = config.save(state_path)
	if result != OK:
		push_warning("[ChallengePack] Could not save news state: %s" % result)
	shown = false
	panel.hide()
	manager.set_process_input(true)
	manager.Buttons(true)
	manager.Show("main")
	manager.ResetButtons()
	manager.firstFocus_main.grab_focus()
	manager.controller.previousFocus = manager.firstFocus_main

func _input(event):
	if shown and (event.is_action_pressed("ui_cancel") or event.is_action_pressed("exit game")):
		close()
		get_viewport().set_input_as_handled()

func _notification(what):
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_instance_valid(close_button):
		refresh()
