extends CanvasLayer

const LABELS = {
	"shells": ["shell visibility", ["DEFAULT", "QUANTITY", "HIDDEN"]],
	"items": ["items visibility", ["DEFAULT", "HIDDEN"]],
	"shuffle": ["shuffle bullets", ["YES", "NO"]],
	"turn": ["first turn", ["ALWAYS FIRST", "ROUND ROBIN", "RANDOM"]]
}
var port: Node
var manager: Node
var panel: Control
var buttons = {}
var start_button: Button
var status: Label
var shown = false

func setup(owner_port: Node, menu_manager: Node):
	port = owner_port
	manager = menu_manager
	layer = 110
	panel = Control.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(panel)
	var background = ColorRect.new()
	background.color = Color(0.025, 0.025, 0.025, 0.98)
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.add_child(background)
	var center = CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.add_child(center)
	var column = VBoxContainer.new()
	column.custom_minimum_size = Vector2(660, 0)
	column.add_theme_constant_override("separation", 10)
	var font = load("res://fonts/fake receipt.otf")
	if font != null:
		column.theme = Theme.new()
		column.theme.default_font = font
		column.theme.default_font_size = 26
	center.add_child(column)
	var title = Label.new()
	title.text = "game configuration"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 36)
	column.add_child(title)
	for key in LABELS:
		var button = make_button(column, "")
		button.pressed.connect(change.bind(key))
		buttons[key] = button
	status = Label.new()
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status.custom_minimum_size = Vector2(660, 50)
	status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status.add_theme_font_size_override("font_size", 18)
	column.add_child(status)
	start_button = make_button(column, "start")
	start_button.pressed.connect(start)
	make_button(column, "return").pressed.connect(close)
	var navigation = []
	for child in column.get_children():
		if child is Button:
			navigation.append(child)
	for i in range(navigation.size()):
		var button = navigation[i]
		button.focus_neighbor_top = button.get_path_to(navigation[(i - 1 + navigation.size()) % navigation.size()])
		button.focus_neighbor_bottom = button.get_path_to(navigation[(i + 1) % navigation.size()])
	var version = Label.new()
	version.text = "ChallengePack 2.0.0 — TEST BUILD / single-player only"
	version.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	version.add_theme_font_size_override("font_size", 16)
	column.add_child(version)
	panel.hide()
	refresh()

func make_button(column: Control, text: String) -> Button:
	var button = Button.new()
	button.text = text
	button.flat = true
	button.custom_minimum_size.y = 35
	button.focus_mode = Control.FOCUS_ALL
	column.add_child(button)
	button.mouse_entered.connect(button.grab_focus)
	button.pressed.connect(play_click)
	return button

func play_click():
	var speaker = manager.get_parent().get_parent().get_node_or_null("speaker_press")
	if speaker != null:
		speaker.play()

func refresh():
	for key in buttons:
		buttons[key].text = LABELS[key][0] + ": " + LABELS[key][1][port.settings.values[key]]
	start_button.disabled = not port.compatible
	status.text = "" if port.compatible else "Cannot start: " + port.compatibility_error

func change(key: String):
	var result = port.settings.cycle(key)
	refresh()
	if result != OK:
		status.text = "Could not save settings (error %s). Selection applies to this session." % result

func open():
	if shown:
		return
	shown = true
	manager.Buttons(false)
	manager.set_process_input(false)
	manager.parent_main.hide()
	panel.show()
	refresh()
	buttons.shells.grab_focus()
	manager.controller.previousFocus = buttons.shells

func close():
	if not shown:
		return
	shown = false
	panel.hide()
	manager.set_process_input(true)
	manager.Buttons(true)
	manager.Show("main")
	manager.ResetButtons()

func start():
	if not port.compatible:
		return
	port.active = port.settings.snapshot()
	shown = false
	panel.hide()
	# Keep the original menu input suspended throughout its start animation.
	manager.cp_start_game()

func _input(event):
	if shown and (event.is_action_pressed("ui_cancel") or event.is_action_pressed("exit game")):
		close()
		get_viewport().set_input_as_handled()
