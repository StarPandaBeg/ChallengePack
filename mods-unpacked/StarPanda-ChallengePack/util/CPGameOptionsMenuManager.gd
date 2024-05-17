class_name CPGameOptionsMenuManager extends Node

const ButtonClass = preload("res://scripts/ButtonClass.gd")
const MenuManager = preload("res://scripts/MenuManager.gd")
const CPModConfig = preload("./CPModConfig.gd")
const CPGameConfig = preload("./CPGameConfig.gd")
const CPButtonUtil = preload("../util/CPButtonUtil.gd")

var totalGameModes = len(CPGameConfig.GameMode.keys())
var totalItemModes = len(CPGameConfig.ItemMode.keys())
var totalShuffleModes = len(CPGameConfig.ShuffleMode.keys())
var totalTurnModes = len(CPGameConfig.TurnMode.keys())

var menu_manager: MenuManager
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
var button_start_config := {
	"ui_root": "Camera/dialogue UI/menu ui",
	"label_text": "start",
	"label_name": "button_challengepack_start_game custom",
	"button_name": "true button_challengepack_start_game custom",
	"logic_name": "button class_challengepack_start_game custom",
	"label_position": Vector2(0, 394),
	"button_position": Vector2(439, 400),
	"button_scale": Vector2(10.154, 2.807),
}

var button_mode_config := {
	"ui_root": "Camera/dialogue UI/menu ui",
	"label_name": "button_challengepack_mode custom",
	"button_name": "true button_challengepack_mode custom",
	"logic_name": "button class_challengepack_mode custom",
	"label_position": Vector2(0, 204),
	"button_position": Vector2(280, 210),
	"button_scale": Vector2(50, 3),
}
var button_items_config := {
	"ui_root": "Camera/dialogue UI/menu ui",
	"label_name": "button_challengepack_items custom",
	"button_name": "true button_challengepack_items custom",
	"logic_name": "button class_challengepack_items custom",
	"label_position": Vector2(0, 234),
	"button_position": Vector2(280, 240),
	"button_scale": Vector2(50, 3),
}
var button_shuffle_config := {
	"ui_root": "Camera/dialogue UI/menu ui",
	"label_name": "button_challengepack_shuffle custom",
	"button_name": "true button_challengepack_shuffle custom",
	"logic_name": "button class_challengepack_shuffle custom",
	"label_position": Vector2(0, 264),
	"button_position": Vector2(280, 270),
	"button_scale": Vector2(50, 3),
}
var button_turn_config := {
	"ui_root": "Camera/dialogue UI/menu ui",
	"label_name": "button_challengepack_turn custom",
	"button_name": "true button_challengepack_turn custom",
	"logic_name": "button class_challengepack_turn custom",
	"label_position": Vector2(0, 324),
	"button_position": Vector2(280, 330),
	"button_scale": Vector2(50, 3),
}

func show() -> void:
	menu_manager.Show("e")
	_set_menu_visibility(true)
	
func hide() -> void:
	_set_menu_visibility(false)
	menu_manager.Show("main")
	menu_manager.ResetButtons()

func _init(root: Node):
	name = "challengepack menu manager"
	_configure(root)

func _ready():
	var managers_root = get_parent()
	menu_manager = managers_root.get_node("menu manager")
	_set_menu_visibility(false)
	
func _configure(root: Node) -> void:
	_create_title(root)
	_create_version_label(root)
	_create_buttons(root)
	# _reinit_start_button(root)
	
func _create_title(root: Node) -> void:
	var label = CPButtonUtil.createButtonLabel()
	var parent = root.get_node("Camera/dialogue UI/menu ui")
	
	label.name = "challengepack_title"
	label.text = "game configuration"
	label.position = Vector2(0, 100)
	label.set("theme_override_font_sizes/font_size", 36)
	
	parent.add_child(label)
	menu_items.append(label)
	
func _create_version_label(root: Node) -> void:
	var label = CPButtonUtil.createButtonLabel()
	var parent = root.get_node("Camera/dialogue UI/menu ui")
	
	label.name = "challengepack_version"
	label.text = "ChallengePack v" + CPModConfig.get_version()
	label.position = Vector2(-93, 515)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	label.set("theme_override_colors/font_color", Color.WEB_GRAY)
	label.set("theme_override_font_sizes/font_size", 16)
	
	parent.add_child(label)
	menu_items.append(label)	

func _create_buttons(root: Node) -> void:
	var btn_return_logic = CPButtonUtil.createButtonWithConfig(root, button_return_config)
	var btn_start_logic = CPButtonUtil.createButtonWithConfig(root, button_start_config)
	var btn_mode_logic = CPButtonUtil.createButtonWithConfig(root, button_mode_config)
	var btn_items_logic = CPButtonUtil.createButtonWithConfig(root, button_items_config)
	var btn_shuffle_logic = CPButtonUtil.createButtonWithConfig(root, button_shuffle_config)
	var btn_turn_logic = CPButtonUtil.createButtonWithConfig(root, button_turn_config)
	
	btn_start_logic.connect("is_pressed", func(): _on_start_click())
	btn_return_logic.connect("is_pressed", hide)
	btn_mode_logic.connect("is_pressed", func(): _on_mode_button_click("challengepack_mode", totalGameModes))
	btn_items_logic.connect("is_pressed", func(): _on_mode_button_click("challengepack_item", totalItemModes))
	btn_shuffle_logic.connect("is_pressed", func(): _on_mode_button_click("challengepack_shuffle", totalShuffleModes))
	btn_turn_logic.connect("is_pressed", func(): _on_mode_button_click("challengepack_turn", totalTurnModes))
	
	_register_button(btn_return_logic)
	_register_button(btn_mode_logic)
	_register_button(btn_items_logic)
	_register_button(btn_shuffle_logic)
	_register_button(btn_turn_logic)
	_register_button(btn_start_logic)
	_update_labels()
	
func _on_start_click() -> void:
	_set_menu_visibility(false)
	menu_manager.Start()
	
func _set_menu_visibility(state: bool) -> void:
	for logic in menu_buttons:
		CPButtonUtil.setState(logic, state)
	for item in menu_items:
		item.visible = state
		
func _register_button(logic: ButtonClass) -> void:
	menu_items.append(logic.ui)
	menu_buttons.append(logic)
	
func _on_mode_button_click(setting_name, total_modes, default_value = 0) -> void:
	var mode_id = ProjectSettings.get_setting(setting_name, default_value)
	var next_mode = (mode_id + 1) if (mode_id + 1 < total_modes) else 0
	ProjectSettings.set_setting(setting_name, next_mode)
	_update_labels()
	
func _update_labels():
	var mode_id = ProjectSettings.get_setting("challengepack_mode", 0)
	var item_mode_id = ProjectSettings.get_setting("challengepack_item", 0)
	var shuffle_mode_id = ProjectSettings.get_setting("challengepack_shuffle", 0)
	var turn_mode_id = ProjectSettings.get_setting("challengepack_turn", 0)
	
	menu_buttons[1].ui.text = "shell visibility: " + CPGameConfig.GameMode.keys()[mode_id]
	menu_buttons[2].ui.text = "items visibility: " + CPGameConfig.ItemMode.keys()[item_mode_id]
	menu_buttons[3].ui.text = "shuffle bullets: " + CPGameConfig.ShuffleMode.keys()[shuffle_mode_id]
	menu_buttons[4].ui.text = "first turn: " + CPGameConfig.TurnMode.keys()[turn_mode_id].replace("_", " ")
