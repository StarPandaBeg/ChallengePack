class_name CPGameOptionsMenuManager extends Node

const GameConfig = preload("./CPGameConfig.gd")
const CPButtonUtil = preload("../util/CPButtonUtil.gd")

var totalGameModes = len(GameConfig.GameMode.keys())

var menu_manager: MenuManager
var real_start_button: ButtonClass
var menu_items: Array[Control]
var menu_buttons: Array[ButtonClass]
var shown: bool

var button_return_config := {
	"ui_root": "Camera/dialogue UI/menu ui",
	"label_text": "return",
	"label_name": "button_challengepack_exit custom",
	"button_name": "true button_challengepack_return custom",
	"logic_name": "button class_challengepack_return custom",
	"label_position": Vector2(0, 424),
	"button_position": Vector2(439, 430),
	"button_scale": Vector2(10.154, 2.807),
}

var button_mode_config := {
	"ui_root": "Camera/dialogue UI/menu ui",
	"label_name": "button_challengepack_mode custom",
	"button_name": "true button_challengepack_mode custom",
	"logic_name": "button class_challengepack_mode custom",
	"label_position": Vector2(0, 224),
	"button_position": Vector2(280, 230),
	"button_scale": Vector2(50, 3),
}

func show() -> void:
	menu_manager.ResetButtons()
	menu_manager.Buttons(false)
	menu_manager.Show("e")
	_set_menu_visibility(true)
	
func hide() -> void:
	_set_menu_visibility(false)
	menu_manager.Return()

func _init(root: Node, real_start: ButtonClass):
	name = "challengepack menu manager"
	real_start_button = real_start
	_configure(root)

func _ready():
	var managers_root = get_parent()
	menu_manager = managers_root.get_node("menu manager")
	_set_menu_visibility(false)
	
func _configure(root: Node) -> void:
	_create_title(root)
	_create_buttons(root)
	_reinit_start_button(root)
	
func _create_title(root: Node) -> void:
	var label = CPButtonUtil.createButtonLabel()
	var parent = root.get_node("Camera/dialogue UI/menu ui")
	
	label.name = "challengepack_title"
	label.text = "game configuration"
	label.position = Vector2(0, 100)
	label.set("theme_override_font_sizes/font_size", 36)
	
	parent.add_child(label)
	menu_items.append(label)	

func _create_buttons(root: Node) -> void:
	var btn_return_logic = CPButtonUtil.createButtonWithConfig(root, button_return_config)
	var btn_mode_logic = CPButtonUtil.createButtonWithConfig(root, button_mode_config)
	
	btn_return_logic.connect("is_pressed", hide)
	btn_mode_logic.connect("is_pressed", func(): _on_mode_button_click(btn_mode_logic))
	_register_button(btn_return_logic)
	_register_button(btn_mode_logic)
	
	var mode_id = ProjectSettings.get_setting("challengepack_mode", 0)
	btn_mode_logic.ui.text = "shell visibility: " + GameConfig.GameMode.keys()[mode_id]
	
func _reinit_start_button(root: Node) -> void:
	real_start_button.ui.position = Vector2(0, 394)
	real_start_button.ui_control.position = Vector2(439, 400)
	
	real_start_button.connect("is_pressed", func(): _set_menu_visibility(false))
	menu_buttons.append(real_start_button)
	menu_items.append(real_start_button.ui)
	
func _set_menu_visibility(state: bool) -> void:
	for logic in menu_buttons:
		CPButtonUtil.setState(logic, state)
	for item in menu_items:
		item.visible = state
		
func _register_button(logic: ButtonClass) -> void:
	menu_items.append(logic.ui)
	menu_buttons.append(logic)
	
func _on_mode_button_click(sender: ButtonClass) -> void:
	var mode_id = ProjectSettings.get_setting("challengepack_mode", 0)
	var next_mode = (mode_id + 1) if (mode_id + 1 < totalGameModes) else 0
	
	sender.ui.text = "shell visibility: " + GameConfig.GameMode.keys()[next_mode]
	ProjectSettings.set_setting("challengepack_mode", next_mode)
