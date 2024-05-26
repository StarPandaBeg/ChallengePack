extends "./patch.gd"

const STPND_CHALLENGEPACK_LOG := "StarPanda-ChallengePack:MainPatch"
const CPGameConfig = preload("../util/CPGameConfig.gd")

var applied_main = false

func _init():
	scene_name = "main"
	repeatable = true

func _apply(root: Node):
	if (applied_main && applied):
		return
	ModLoaderLog.debug("Apply phase started", STPND_CHALLENGEPACK_LOG)
	
	_register_death_listener(root)
	_spawn_protectors(root)
	_replace_shell_animations(root)
	
	ModLoaderLog.debug("Apply phase finished", STPND_CHALLENGEPACK_LOG)
	applied_main = true
	return true
	
func _spawn_protectors(root: Node):
	var item_mode = ProjectSettings.get_setting("challengepack_item", 0)
	if (item_mode != CPGameConfig.ItemMode.HIDDEN):
		return
	
	var parent = root.get_node("tabletop parent/main tabletop")
	var protector = preload("../instances/protector.tscn")
	
	var protectorObj = protector.instantiate()
	parent.add_child(protectorObj)
	ModLoaderLog.debug("Item covers instantiated", STPND_CHALLENGEPACK_LOG)
	
	_register_item_steal_listener(root)
	
func _register_death_listener(root: Node):
	var deathManager = root.get_node("standalone managers/death manager")
	deathManager.connect("cp_death", _on_deathmanager_death)
	ModLoaderLog.debug("Death signal connected", STPND_CHALLENGEPACK_LOG)
	
func _register_item_steal_listener(root: Node):
	var itemManager = root.get_node("standalone managers/item manager")
	itemManager.connect("cp_steal_start", func(): _on_itemmanager_steal_start(root))
	itemManager.connect("cp_steal_end", func(): _on_itemmanager_steal_end(root))
	ModLoaderLog.debug("Item steal signal connected", STPND_CHALLENGEPACK_LOG)
	
func _replace_shell_animations(root: Node):
	var shellSpawner = root.get_node("standalone managers/shell spawner")
	var animationPlayer = shellSpawner.anim_compartment
	var animationLibrary = animationPlayer.get_animation_library("")
	
	var currentMode = ProjectSettings.get_setting("challengepack_mode", 0)
	if (currentMode != CPGameConfig.GameMode.HIDDEN):
		if (animationLibrary.has_animation("show shells blocked")):
			animationLibrary.rename_animation("show shells blocked", "show shells")
		if (animationLibrary.has_animation("hide shells blocked")):
			animationLibrary.rename_animation("hide shells blocked", "hide shells")
		ModLoaderLog.debug("Shell animations restored", STPND_CHALLENGEPACK_LOG)
	else:
		if (animationLibrary.has_animation("show shells")):
			animationLibrary.rename_animation("show shells", "show shells blocked")
		if (animationLibrary.has_animation("hide shells")):
			animationLibrary.rename_animation("hide shells", "hide shells blocked")
		ModLoaderLog.debug("Shell animations replaced", STPND_CHALLENGEPACK_LOG)
	
	
func _on_deathmanager_death():
	ModLoaderLog.debug("Player died. Need to reload main patch!", STPND_CHALLENGEPACK_LOG)
	applied_main = false
	
func _on_itemmanager_steal_start(root: Node):
	ModLoaderLog.debug("Steal started!", STPND_CHALLENGEPACK_LOG)
	var protector = root.get_node("tabletop parent/main tabletop/Protectors")
	protector.visible = false
	
func _on_itemmanager_steal_end(root: Node):
	ModLoaderLog.debug("Steal ended!", STPND_CHALLENGEPACK_LOG)
	var protector = root.get_node("tabletop parent/main tabletop/Protectors")
	protector.visible = true
