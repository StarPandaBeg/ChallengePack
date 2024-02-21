class_name HSGameOptionsMenuManager extends Node

var menu_manager: MenuManager
var real_start_button: ButtonClass
var menu_items: Array[Control]
var menu_buttons: Array[ButtonClass]
var shown: bool

func show():
	menu_manager.ResetButtons()
	menu_manager.Buttons(false)
	menu_manager.Show("e")
	_set_menu_visibility(true)
	
func hide():
	_set_menu_visibility(false)
	menu_manager.Return()

func _init(root: Node, real_start: ButtonClass):
	name = "hiddenshell menu manager"
	real_start_button = real_start
	_configure(root)

func _ready():
	var managers_root = get_parent()
	menu_manager = managers_root.get_node("menu manager")
	
func _configure(root: Node):
	_create_return_button(root)
	_reinit_start_button(root)

func _create_return_button(root: Node):
	var ui_root = root.get_node("Camera/dialogue UI/menu ui")
	var label = HSButtonUtil.createButtonLabel()
	var button = HSButtonUtil.createButton()
	var logic = HSButtonUtil.createButtonLogic(root, label)
	
	label.name = "button_hiddenshell_exit custom"
	label.text = "return"
	label.position = Vector2(0, 424)
	
	button.name = "true button_hiddenshell_return custom"
	button.position = Vector2(439, 430)
	button.scale = Vector2(10.154, 2.807)
	logic.name = "button class_hiddenshell_return custom"
	
	button.add_child(logic)
	ui_root.add_child(label)
	ui_root.add_child(button)
	logic.connect("is_pressed", hide)
	
	HSButtonUtil.setState(logic, false)
	menu_items.append(label)
	menu_buttons.append(logic)
	
func _reinit_start_button(root: Node):
	real_start_button.ui.position = Vector2(0, 394)
	real_start_button.ui_control.position = Vector2(439, 400)
	
	real_start_button.connect("is_pressed", func(): _set_menu_visibility(false))
	menu_buttons.append(real_start_button)
	menu_items.append(real_start_button.ui)
	
func _set_menu_visibility(state: bool):
	for logic in menu_buttons:
		HSButtonUtil.setState(logic, state)
	
