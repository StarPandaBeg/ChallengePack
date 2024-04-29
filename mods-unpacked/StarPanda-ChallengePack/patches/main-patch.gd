extends "./patch.gd"

const CPGameConfig = preload("../util/CPGameConfig.gd")
const STPND_CHALLENGEPACK_LOG := "StarPanda-ChallengePack:MainPatch"

func _init():
	scene_name = "main"
	repeatable = false
	
func _apply(root: Node):
	var patched = !root.has_node("standalone managers/shell spawner")
	if (patched):
		return
	_spawn_protectors(root)
	
	ModLoaderLog.info("Applied main patch!", STPND_CHALLENGEPACK_LOG)
	return true
	
func _spawn_protectors(root: Node):
	var item_mode = ProjectSettings.get_setting("challengepack_item", 0)
	if (item_mode != CPGameConfig.ItemMode.HIDDEN):
		return
	
	var parent = root.get_node("tabletop parent/main tabletop")
	var protector = preload("../instances/protector.tscn")
	
	var protectorObj = protector.instantiate()
	parent.add_child(protectorObj)
	
