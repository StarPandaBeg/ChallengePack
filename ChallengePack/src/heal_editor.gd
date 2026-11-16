extends CanvasLayer

var localization
var panel: Control
var box: PanelContainer
var title: Label
var description: Label
var chance_label: Label
var slider: HSlider
var done: Button
var changed: Callable
var dismissed: Callable
var shown = false

func setup(localizer, theme: Theme, change: Callable, dismiss: Callable):
	localization = localizer
	changed = change
	dismissed = dismiss
	layer = 116
	panel = Control.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(panel)
	var shade = ColorRect.new()
	shade.color = Color(0, 0, 0, 0.96)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.add_child(shade)
	var center = CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.add_child(center)
	box = PanelContainer.new()
	box.custom_minimum_size.x = 650
	box.theme = theme
	center.add_child(box)
	var column = VBoxContainer.new()
	column.add_theme_constant_override("separation", 14)
	box.add_child(column)
	title = Label.new()
	title.add_theme_font_size_override("font_size", 23)
	column.add_child(title)
	description = Label.new()
	description.custom_minimum_size.x = 600
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(description)
	chance_label = Label.new()
	column.add_child(chance_label)
	slider = HSlider.new()
	slider.max_value = 100
	slider.step = 1
	slider.custom_minimum_size.y = 28
	slider.value_changed.connect(func(value): changed.call(roundi(value)))
	column.add_child(slider)
	done = Button.new()
	done.pressed.connect(close)
	column.add_child(done)
	slider.focus_neighbor_left = slider.get_path_to(slider)
	slider.focus_neighbor_right = slider.get_path_to(slider)
	slider.focus_neighbor_bottom = slider.get_path_to(done)
	done.focus_neighbor_top = done.get_path_to(slider)
	panel.hide()

func refresh(value: int, editable: bool = true):
	title.text = localization.text("CP_HEAL_BULLETS")
	description.text = localization.text("CP_HEAL_CHANCE_DESCRIPTION")
	chance_label.text = localization.text("CP_HEAL_CHANCE", [value])
	slider.set_value_no_signal(value)
	slider.editable = editable
	done.text = localization.text("CP_DONE")

func open():
	shown = true
	panel.show()
	(slider if slider.editable else done).grab_focus()

func close():
	if not shown: return
	shown = false
	panel.hide()
	dismissed.call()

func _input(event):
	if shown and (event.is_action_pressed("ui_cancel") or event.is_action_pressed("exit game")):
		close()
		get_viewport().set_input_as_handled()
