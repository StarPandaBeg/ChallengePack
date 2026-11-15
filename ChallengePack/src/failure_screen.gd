extends CanvasLayer

var port: Node
var panel: Control
var title: Label
var reason: Label
var explanation: Label
var return_button: Button
var shown = false
var returning = false
var previous_paused = false
var contract_key = ""

func setup(owner_port: Node):
	port = owner_port
	layer = 130
	process_mode = Node.PROCESS_MODE_ALWAYS
	panel = Control.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(panel)
	var background = ColorRect.new()
	background.color = Color(0.025, 0.015, 0.015, 0.96)
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.add_child(background)
	var center = CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.add_child(center)
	var column = VBoxContainer.new()
	column.custom_minimum_size.x = 640
	column.add_theme_constant_override("separation", 24)
	center.add_child(column)
	title = label(column, 32, Color("c97b6d"))
	reason = label(column, 23, Color("e4d5ba"))
	explanation = label(column, 17, Color("a79e8e"))
	return_button = Button.new()
	return_button.custom_minimum_size.y = 44
	return_button.add_theme_font_size_override("font_size", 20)
	return_button.focus_mode = Control.FOCUS_ALL
	return_button.pressed.connect(request_return)
	column.add_child(return_button)
	panel.hide()

func label(parent: Node, font_size: int, color: Color) -> Label:
	var result = Label.new()
	result.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	result.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	result.add_theme_font_size_override("font_size", font_size)
	result.add_theme_color_override("font_color", color)
	parent.add_child(result)
	return result

func refresh():
	title.text = port.localization.text("CP_FAILURE_TITLE")
	reason.text = port.localization.text("CP_FAILURE_REASON", [port.localization.text(contract_key)])
	explanation.text = port.localization.text("CP_FAILURE_EXPLANATION")
	return_button.text = port.localization.text("CP_FAILURE_RETURN")

func open(key: String):
	if shown:
		return
	contract_key = key
	previous_paused = get_tree().paused
	shown = true
	returning = false
	refresh()
	panel.show()
	port.challenge_hud.hide()
	port.notice_until = 0
	port.notice_label.hide()
	get_tree().paused = true
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	return_button.disabled = true
	# Do not dismiss the result with the input that caused the failed action.
	await get_tree().create_timer(0.4, true, false, true).timeout
	if shown and not returning:
		return_button.disabled = false
		return_button.grab_focus()

func request_return():
	if not shown or returning or return_button.disabled:
		return
	returning = true
	return_button.disabled = true
	call_deferred("return_to_menu")

func return_to_menu():
	var result = get_tree().change_scene_to_file("res://scenes/menu.tscn")
	if result != OK:
		explanation.text = port.localization.text("CP_FAILURE_MENU_ERROR", [result])
		returning = false
		return_button.disabled = false
		return
	get_tree().paused = previous_paused
	shown = false
	panel.hide()

func _input(event):
	if shown and (event.is_action_pressed("ui_cancel") or event.is_action_pressed("exit game")):
		request_return()
		get_viewport().set_input_as_handled()

func _notification(what):
	if what == NOTIFICATION_TRANSLATION_CHANGED and shown:
		refresh()

func _exit_tree():
	if shown:
		get_tree().paused = previous_paused
