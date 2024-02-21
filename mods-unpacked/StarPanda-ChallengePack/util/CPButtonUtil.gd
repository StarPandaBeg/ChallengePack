class_name CPButtonUtil

static var font = load("res://fonts/fake receipt.otf")

static func createButtonLogic(root: Node, label: Label) -> ButtonClass:
	var cursor_manager = root.get_node("standalone managers/cursor manager")
	var button_logic = ButtonClass.new()
	
	button_logic.cursor = cursor_manager
	button_logic.isActive = true
	button_logic.playing = true
	button_logic.isDynamic = true
	button_logic.ui = label
	button_logic.speaker_press = root.get_node("speaker_press")
	button_logic.speaker_hover = root.get_node("speaker_hover")
	return button_logic
	
static func createButton() -> Button:
	var button = Button.new()
	
	button.size = Vector2(8, 8)
	button.modulate = Color.TRANSPARENT
	button.self_modulate = Color.TRANSPARENT
	button.mouse_filter = Control.MOUSE_FILTER_STOP
	return button
	
static func createButtonLabel() -> Label:
	var label = Label.new()
	
	label.size = Vector2(960, 35)
	label.scale = Vector2(0.76, 1)
	label.pivot_offset = Vector2(480, 0)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.set("theme_override_colors/font_shadow_color", Color.BLACK)
	label.set("theme_override_fonts/font", font)
	label.set("theme_override_font_sizes/font_size", 26)
	return label
	
static func setState(button: ButtonClass, state: bool) -> void:
	button.SetFilter("stop" if state else "ignore")
	button.isActive = state
	button.ui.visible = state
	
static func createButtonWithConfig(root: Node, config: Dictionary) -> ButtonClass:
	var uiRoot = _resolveNode(config["ui_root"], root)
	
	var label = createButtonLabel()
	var button = createButton()
	var logic = createButtonLogic(root, label)
	
	label.name = config.get("label_name", "button_label")
	label.text = config.get("label_text", "")
	label.position = config.get("label_position", Vector2())
	label.horizontal_alignment = config.get("label_align", HORIZONTAL_ALIGNMENT_CENTER)
	
	button.name = config.get("button_name", "button")
	button.position = config.get("button_position", Vector2())
	button.scale = config.get("button_scale", Vector2())
	logic.name = config.get("logic_name", "logic")
	
	button.add_child(logic)
	uiRoot.add_child(button)
	uiRoot.add_child(label)	
	setState(logic, config.get("state", false))
	
	return logic
	
static func _resolveNode(node, root: Node) -> Node:
	if (node is Node):
		return node
	return root.get_node(node)
