extends CanvasLayer

const ContractEditor = preload("contract_editor.gd")
const LABELS = preload("domain/settings_schema.gd").LABELS
var controller: RefCounted
var port: Node
var manager: Node
var panel: Control
var buttons = {}
var start_button: Button
var status: Label
var title: Label
var version: Label
var return_button: Button
var shown = false
var edit_button: Button
var editor: CanvasLayer
var heal_edit_button: Button
var heal_editor: CanvasLayer

func setup(owner_port: Node, menu_manager: Node):
	port = owner_port
	controller = preload("ui/settings_controller.gd").new(port.settings.snapshot, port.save_preferences, port.settings.LIMITS)
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
	column.custom_minimum_size = Vector2(840, 0)
	column.add_theme_constant_override("separation", 5)
	var font = load("res://fonts/fake receipt.otf")
	if font != null:
		column.theme = Theme.new()
		column.theme.default_font = font
		column.theme.default_font_size = 18
	center.add_child(column)
	title = Label.new()
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 24)
	column.add_child(title)
	var grid = GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 20)
	grid.add_theme_constant_override("v_separation", 6)
	column.add_child(grid)
	for key in LABELS:
		var cell = HBoxContainer.new()
		cell.custom_minimum_size.x = 410
		cell.add_theme_constant_override("separation", 4)
		grid.add_child(cell)
		var button = make_button(cell, "")
		button.custom_minimum_size = Vector2(0, 48)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.pressed.connect(change.bind(key))
		buttons[key] = button
		if key == "contract":
			edit_button = make_button(cell, "")
			edit_button.add_theme_font_size_override("font_size", 16)
			edit_button.pressed.connect(open_editor)
		if key == "heal":
			heal_edit_button = make_button(cell, "")
			heal_edit_button.add_theme_font_size_override("font_size", 16)
			heal_edit_button.pressed.connect(open_heal_editor)
	status = Label.new()
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status.custom_minimum_size = Vector2(840, 0)
	status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status.add_theme_font_size_override("font_size", 16)
	column.add_child(status)
	start_button = make_button(column, "")
	start_button.pressed.connect(start)
	return_button = make_button(column, "")
	return_button.pressed.connect(close)
	version = Label.new()
	version.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	version.add_theme_font_size_override("font_size", 14)
	column.add_child(version)
	editor = ContractEditor.new()
	add_child(editor)
	editor.setup(port, self)
	heal_editor = preload("heal_editor.gd").new()
	add_child(heal_editor)
	heal_editor.setup(port.localization, editor.box.theme, set_heal_chance, close_heal_editor)
	heal_editor.box.add_theme_stylebox_override("panel", editor.box.get_theme_stylebox("panel").duplicate())
	panel.hide()
	refresh()

func configure_focus():
	var choices = buttons.values()
	for i in range(choices.size()):
		var button = choices[i]
		var across = i + 1 if i % 2 == 0 else i - 1
		var horizontal = choices[across] if across < choices.size() else button
		button.focus_neighbor_left = button.get_path_to(horizontal)
		button.focus_neighbor_right = button.get_path_to(horizontal)
		button.focus_neighbor_top = button.get_path_to(choices[i - 2] if i >= 2 else return_button)
		button.focus_neighbor_bottom = button.get_path_to(choices[i + 2] if i + 2 < choices.size() else start_button)
	start_button.focus_neighbor_top = start_button.get_path_to(choices.back())
	start_button.focus_neighbor_bottom = start_button.get_path_to(return_button)
	return_button.focus_neighbor_top = return_button.get_path_to(start_button)
	return_button.focus_neighbor_bottom = return_button.get_path_to(choices[0])
	for button in [start_button, return_button]:
		button.focus_neighbor_left = button.get_path_to(button)
		button.focus_neighbor_right = button.get_path_to(button)
	var navigation = choices + [start_button, return_button]
	for i in range(navigation.size()):
		var button = navigation[i]
		button.focus_previous = button.get_path_to(navigation[(i - 1 + navigation.size()) % navigation.size()])
		button.focus_next = button.get_path_to(navigation[(i + 1) % navigation.size()])
	if edit_button.visible:
		buttons.contract.focus_neighbor_right = buttons.contract.get_path_to(edit_button)
		edit_button.focus_neighbor_left = edit_button.get_path_to(buttons.contract)
		edit_button.focus_neighbor_right = edit_button.get_path_to(buttons.pocket)
		edit_button.focus_neighbor_top = edit_button.get_path_to(buttons.mirror)
		edit_button.focus_neighbor_bottom = edit_button.get_path_to(start_button)
		edit_button.focus_previous = edit_button.get_path_to(buttons.contract)
		edit_button.focus_next = edit_button.get_path_to(buttons.heal)
		buttons.contract.focus_next = buttons.contract.get_path_to(edit_button)
		buttons.heal.focus_previous = buttons.heal.get_path_to(edit_button)
	if heal_edit_button.visible:
		buttons.heal.focus_neighbor_right = buttons.heal.get_path_to(heal_edit_button)
		buttons.heal.focus_next = buttons.heal.get_path_to(heal_edit_button)
		heal_edit_button.focus_neighbor_left = heal_edit_button.get_path_to(buttons.heal)
		heal_edit_button.focus_neighbor_top = heal_edit_button.get_path_to(buttons.pocket)
		heal_edit_button.focus_neighbor_bottom = heal_edit_button.get_path_to(start_button)
		heal_edit_button.focus_previous = heal_edit_button.get_path_to(buttons.heal)
		heal_edit_button.focus_next = heal_edit_button.get_path_to(start_button)
		start_button.focus_previous = start_button.get_path_to(heal_edit_button)

func open_heal_editor():
	if shown and controller.values().heal == 1:
		heal_editor.open()
		manager.controller.previousFocus = heal_editor.slider

func close_heal_editor():
	heal_edit_button.grab_focus()
	manager.controller.previousFocus = heal_edit_button

func set_heal_chance(value: int):
	var result = controller.set_value("heal_chance", value)
	refresh()
	if result != OK:
		status.text = port.localization.text("CP_SAVE_ERROR", [result])
		status.show()

func open_editor():
	if shown and controller.values().contract == 1:
		editor.open()

func make_button(column: Control, text: String) -> Button:
	var button = Button.new()
	button.text = text
	button.flat = true
	button.custom_minimum_size.y = 28
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
	title.text = port.localization.text("CP_TITLE")
	version.text = port.localization.text("CP_VERSION", [port.VERSION])
	# Reuse vanilla translation keys for existing game actions.
	start_button.text = tr("START")
	return_button.text = tr("RETURN")
	start_button.tooltip_text = port.localization.text("CP_TIP_START")
	return_button.tooltip_text = port.localization.text("CP_TIP_RETURN")
	var preferences = controller.values()
	var chance_percent = preferences.contract_chance
	for key in buttons:
		var values = LABELS[key][1]
		var value_key = values[preferences[key]]
		var value = port.localization.text(value_key) if value_key.begins_with("CP_") else tr(value_key)
		var caption = port.localization.text(LABELS[key][0])
		if key == "contract":
			caption += " (%d%%)" % chance_percent
		if key == "heal" and preferences.heal == 1:
			caption += " (%d%%)" % preferences.heal_chance
		buttons[key].text = caption + ":\n" + value
		buttons[key].tooltip_text = port.localization.text("CP_TIP_" + key.to_upper(), [chance_percent] if key == "contract" else [])
	edit_button.text = port.localization.text("CP_EDIT_CONTRACTS")
	edit_button.tooltip_text = port.localization.text("CP_TIP_EDIT_CONTRACTS")
	edit_button.visible = preferences.contract == 1
	heal_edit_button.text = port.localization.text("CP_EDIT_CONTRACTS")
	heal_edit_button.visible = preferences.heal == 1
	heal_editor.refresh(preferences.heal_chance)
	configure_focus()
	start_button.disabled = not port.compatible
	status.text = "" if port.compatible else port.localization.text("CP_CANNOT_START", [port.compatibility_message()])
	status.visible = not port.compatible

func _notification(what):
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_instance_valid(version) and port != null:
		refresh()

func change(key: String):
	var result = controller.cycle(key)
	refresh()
	if result != OK:
		status.text = port.localization.text("CP_SAVE_ERROR", [result])
		status.show()

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
	if heal_editor.shown:
		heal_editor.close()
		return
	if editor.shown:
		editor.close()
		return
	if not shown:
		return
	shown = false
	panel.hide()
	manager.set_process_input(true)
	manager.Buttons(true)
	manager.Show("main")
	manager.ResetButtons()

func start():
	if not port.compatible or editor.shown or heal_editor.shown:
		return
	port.active = port.settings.snapshot()
	shown = false
	panel.hide()
	# Keep the original menu input suspended throughout its start animation.
	manager.cp_start_game()

func _input(event):
	if editor.shown or heal_editor.shown:
		return
	if shown and (event.is_action_pressed("ui_cancel") or event.is_action_pressed("exit game")):
		close()
		get_viewport().set_input_as_handled()
