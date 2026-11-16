extends CanvasLayer

var port: Node
var options: Node
var panel: Control
var box: PanelContainer
var title: Label
var chance_label: Label
var chance_slider: HSlider
var select_all: Button
var select_none: Button
var close_button: Button
var empty_label: Label
var checks = {}
var shown = false

func setup(owner_port: Node, owner_options: Node):
	port = owner_port
	options = owner_options
	layer = 115
	panel = Control.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(panel)
	var shade = ColorRect.new()
	shade.color = Color(0.015, 0.012, 0.01, 0.96)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.add_child(shade)
	var center = CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.add_child(center)
	box = PanelContainer.new()
	box.custom_minimum_size.x = 800
	var style = StyleBoxFlat.new()
	style.bg_color = Color("25221e")
	style.border_color = Color("706251")
	style.set_border_width_all(1)
	style.set_content_margin_all(16)
	box.add_theme_stylebox_override("panel", style)
	box.theme = Theme.new()
	box.theme.default_font_size = 17
	var font = load("res://fonts/fake receipt.otf")
	if font != null:
		box.theme.default_font = font
	center.add_child(box)
	var column = VBoxContainer.new()
	column.add_theme_constant_override("separation", 6)
	box.add_child(column)
	title = Label.new()
	title.add_theme_font_size_override("font_size", 23)
	column.add_child(title)
	var scroll = ScrollContainer.new()
	scroll.custom_minimum_size.y = 194
	scroll.follow_focus = true
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(scroll)
	var grid = GridContainer.new()
	grid.columns = 2
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 16)
	grid.add_theme_constant_override("v_separation", 3)
	scroll.add_child(grid)
	for id in port.challenges.ALL_IDS:
		var check = CheckBox.new()
		check.custom_minimum_size = Vector2(366, 28)
		check.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		check.toggled.connect(toggle.bind(id))
		grid.add_child(check)
		checks[id] = check
	var selection_actions = HBoxContainer.new()
	column.add_child(selection_actions)
	select_all = button(selection_actions)
	select_all.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	select_all.pressed.connect(choose_all)
	select_none = button(selection_actions)
	select_none.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	select_none.pressed.connect(choose_none)
	chance_label = Label.new()
	column.add_child(chance_label)
	chance_slider = HSlider.new()
	chance_slider.min_value = 0
	chance_slider.max_value = 100
	chance_slider.step = 1
	chance_slider.custom_minimum_size.y = 24
	chance_slider.value_changed.connect(change_chance)
	column.add_child(chance_slider)
	empty_label = Label.new()
	empty_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	empty_label.add_theme_font_size_override("font_size", 15)
	empty_label.add_theme_color_override("font_color", Color("c9a183"))
	column.add_child(empty_label)
	close_button = button(column)
	close_button.pressed.connect(close)
	var navigation = checks.values() + [select_all, select_none, chance_slider, close_button]
	for i in navigation.size():
		var control = navigation[i]
		control.focus_previous = control.get_path_to(navigation[(i - 1 + navigation.size()) % navigation.size()])
		control.focus_next = control.get_path_to(navigation[(i + 1) % navigation.size()])
		control.focus_neighbor_top = control.get_path_to(navigation[i - 2] if i < checks.size() and i >= 2 else navigation[(i - 1 + navigation.size()) % navigation.size()])
		control.focus_neighbor_bottom = control.get_path_to(navigation[i + 2] if i + 2 < checks.size() else navigation[(i + 1) % navigation.size()])
		if i < checks.size():
			var across = i + 1 if i % 2 == 0 else i - 1
			control.focus_neighbor_left = control.get_path_to(navigation[across])
			control.focus_neighbor_right = control.get_path_to(navigation[across])
	# Horizontal input belongs to the slider, not to focus navigation.
	select_all.focus_neighbor_right = select_all.get_path_to(select_none)
	select_none.focus_neighbor_left = select_none.get_path_to(select_all)
	chance_slider.focus_neighbor_left = chance_slider.get_path_to(chance_slider)
	chance_slider.focus_neighbor_right = chance_slider.get_path_to(chance_slider)
	panel.hide()
	refresh()

func button(parent: Node) -> Button:
	var result = Button.new()
	result.custom_minimum_size.y = 28
	parent.add_child(result)
	return result

func refresh():
	var values = options.controller.values()
	title.text = port.localization.text("CP_CONTRACT_EDITOR_TITLE", [values.contract_pool.size(), checks.size()])
	for id in checks:
		checks[id].text = port.localization.text(port.challenges.contract_key(id))
		checks[id].tooltip_text = port.localization.text(port.challenges.CATALOG[id].detail)
		checks[id].set_pressed_no_signal(id in values.contract_pool)
	select_all.text = port.localization.text("CP_SELECT_ALL")
	select_none.text = port.localization.text("CP_SELECT_NONE")
	chance_label.text = port.localization.text("CP_CONTRACT_CHANCE", [values.contract_chance])
	chance_slider.set_value_no_signal(values.contract_chance)
	chance_slider.tooltip_text = port.localization.text("CP_TIP_CONTRACT", [values.contract_chance])
	empty_label.text = port.localization.text("CP_CONTRACT_EMPTY")
	empty_label.visible = values.contract_pool.is_empty()
	close_button.text = port.localization.text("CP_DONE")

func save(result: Error = OK):
	refresh()
	options.refresh()
	if result != OK:
		empty_label.text = port.localization.text("CP_SAVE_ERROR", [result])
		empty_label.show()

func toggle(pressed: bool, id: int):
	save(options.controller.toggle_contract(pressed, id))

func choose_all():
	save(options.controller.select_all(true))

func choose_none():
	save(options.controller.select_all(false))

func change_chance(value: float):
	save(options.controller.set_value("contract_chance", roundi(value)))

func open():
	if shown:
		return
	shown = true
	refresh()
	panel.show()
	checks.values()[0].grab_focus()
	options.manager.controller.previousFocus = checks.values()[0]

func close():
	if not shown:
		return
	shown = false
	panel.hide()
	options.refresh()
	var target = options.edit_button if options.edit_button.visible else options.buttons.contract
	target.grab_focus()
	options.manager.controller.previousFocus = target

func _input(event):
	if shown and (event.is_action_pressed("ui_cancel") or event.is_action_pressed("exit game")):
		close()
		get_viewport().set_input_as_handled()

func _notification(what):
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_instance_valid(close_button):
		refresh()
