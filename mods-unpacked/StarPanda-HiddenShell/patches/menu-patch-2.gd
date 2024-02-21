extends "./patch.gd"

const STPND_HIDDENSHELL_LOG := "StarPanda-HiddenShell:MenuPatch2"

var manager: HSGameOptionsMenuManager
var menu_custom_start_button: ButtonClass
var menu_real_start_button: ButtonClass

func _init():
	scene_name = "menu"
	
func _apply(root: Node) -> bool:
	var label = _create_custom_start_label(root)
	_create_custom_start_button(root, label)
	
	_inject_custom_menu(root)
	_instantiate_custom_manager(root)
	
	ModLoaderLog.info("Applied menu 2 patch!", STPND_HIDDENSHELL_LOG)
	return true
	
func _create_custom_start_label(root: Node) -> Label:
	var label = HSButtonUtil.createButtonLabel()
	var parent = root.get_node("Camera/dialogue UI/menu ui")
	
	label.position = Vector2(0, 336)
	label.text = "START"
	label.name = "button_hiddenshell_start"
	
	parent.add_child(label)
	ModLoaderLog.debug("Fake 'Start' button label created", STPND_HIDDENSHELL_LOG)
	return label
	
func _create_custom_start_button(root: Node, label: Label) -> void:
	var button = HSButtonUtil.createButton()
	var button_logic = HSButtonUtil.createButtonLogic(root, label)
	var parent = root.get_node("Camera/dialogue UI/menu ui")
	
	button.position = Vector2(447, 339)
	button.scale = Vector2(8.182, 3.012)
	button.name = "true button_hiddenshell_mode"
	button_logic.name = "button class_hiddenshell_start"
	
	button.add_child(button_logic)
	parent.add_child(button)
	ModLoaderLog.debug("Fake 'Start' button created", STPND_HIDDENSHELL_LOG)
	
	menu_custom_start_button = button_logic
	
func _inject_custom_menu(root: Node) -> void:
	var menu_manager = root.get_node("standalone managers/menu manager")
	
	menu_real_start_button = menu_manager.buttons[0]
	HSButtonUtil.setState(menu_real_start_button, false)
	HSButtonUtil.setState(menu_custom_start_button, true)
	
	menu_manager.buttons[0] = menu_custom_start_button
	menu_manager.screen_main[4] = menu_custom_start_button.ui
	
	menu_custom_start_button.connect("is_pressed", func(): _on_custom_start_click(root))

func _on_custom_start_click(root: Node) -> void:
	manager.show()
	
func _instantiate_custom_manager(root: Node) -> void:
	var parent = root.get_node("standalone managers")
	var manager = HSGameOptionsMenuManager.new(root, menu_real_start_button)
	parent.add_child(manager)
	self.manager = manager
	
