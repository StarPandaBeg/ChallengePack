extends "./patch.gd"

const CPGameOptionsMenuManager = preload("../util/CPGameOptionsMenuManager.gd")
const STPND_CHALLENGEPACK_LOG := "StarPanda-ChallengePack:MenuPatch"

var manager: CPGameOptionsMenuManager

func _init():
	scene_name = "menu"

func _apply(root: Node):
	ModLoaderLog.debug("Apply phase started", STPND_CHALLENGEPACK_LOG)
	self.manager = _create_custom_manager(root)
	ModLoaderLog.debug("Custom menu created", STPND_CHALLENGEPACK_LOG)
	
	var menu_manager = root.get_node("standalone managers/menu manager")
	var mod_manager = self.manager
	
	menu_manager.buttons[0].disconnect("is_pressed", menu_manager.Start);
	menu_manager.buttons[0].connect("is_pressed", _on_custom_start_click)
	ModLoaderLog.debug("Start button rebind successfull", STPND_CHALLENGEPACK_LOG)
	ModLoaderLog.debug("Apply phase finished", STPND_CHALLENGEPACK_LOG)
	return true

func _on_custom_start_click():
	ModLoaderLog.debug("Trying to show mod menu", STPND_CHALLENGEPACK_LOG)
	self.manager.show()

func _create_custom_manager(root: Node):
	var parent = root.get_node("standalone managers")
	var manager = CPGameOptionsMenuManager.new(root)
	parent.add_child(manager)
	return manager
