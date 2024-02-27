extends "./patch.gd"

const STPND_CHALLENGEPACK_LOG := "StarPanda-ChallengePack:MenuPatch2"

const ButtonClass = preload("res://scripts/ButtonClass.gd")
const CPButtonUtil = preload("../util/CPButtonUtil.gd")
const CPGameOptionsMenuManager = preload("../util/CPGameOptionsMenuManager.gd")

var manager: CPGameOptionsMenuManager
var menu_custom_start_button: ButtonClass
var menu_real_start_button: ButtonClass

var button_fake_start_config := {
	"ui_root": "Camera/dialogue UI/menu ui",
	"label_text": "start",
	"label_name": "button_challengepack_start custom",
	"button_name": "true button_challengepack_start custom",
	"logic_name": "button class_challengepack_start custom",
	"label_position": Vector2(0, 336),
	"button_position": Vector2(447, 339),
	"button_scale": Vector2(8.182, 3.012),
}

func _init():
	scene_name = "menu"
	
func _apply(root: Node) -> bool:
	_create_custom_start_btn(root)
	_inject_custom_menu(root)
	_instantiate_custom_manager(root)
	
	ModLoaderLog.info("Applied menu patch!", STPND_CHALLENGEPACK_LOG)
	return true
	
func _create_custom_start_btn(root: Node):
	menu_custom_start_button = CPButtonUtil.createButtonWithConfig(root, button_fake_start_config)
	menu_custom_start_button.connect("is_pressed", func(): _on_custom_start_click(root))
	ModLoaderLog.debug("Fake 'Start' button created", STPND_CHALLENGEPACK_LOG)
		
func _inject_custom_menu(root: Node) -> void:
	var menu_manager = root.get_node("standalone managers/menu manager")
	
	menu_real_start_button = menu_manager.buttons[0]
	CPButtonUtil.setState(menu_real_start_button, false)
	CPButtonUtil.setState(menu_custom_start_button, true)
	
	menu_manager.buttons[0] = menu_custom_start_button
	menu_manager.screen_main[4] = menu_custom_start_button.ui

func _on_custom_start_click(root: Node) -> void:
	manager.show()
	
func _instantiate_custom_manager(root: Node) -> void:
	var parent = root.get_node("standalone managers")
	var manager = CPGameOptionsMenuManager.new(root, menu_real_start_button)
	parent.add_child(manager)
	self.manager = manager
	
