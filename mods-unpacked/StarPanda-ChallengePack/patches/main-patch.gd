extends "./patch.gd"

const STPND_CHALLENGEPACK_LOG := "StarPanda-ChallengePack:MainPatch"
const CPGameConfig = preload("../util/CPGameConfig.gd")

var applied_main = false

func _init():
	scene_name = "main"
	repeatable = true

func _apply(root: Node):
	if (applied_main):
		return
	ModLoaderLog.debug("Apply phase started", STPND_CHALLENGEPACK_LOG)
	
	_register_death_listener(root)
	_spawn_protectors(root)
	
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
	
func _register_death_listener(root: Node):
	var deathManager = root.get_node("standalone managers/death manager")
	deathManager.connect("cp_death", _on_deathmanager_death)
	ModLoaderLog.debug("Death signal connected", STPND_CHALLENGEPACK_LOG)
	
func _on_deathmanager_death():
	ModLoaderLog.debug("Player died. Need to reload main patch!", STPND_CHALLENGEPACK_LOG)
	applied_main = false
