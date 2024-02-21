extends "./patch.gd"

const GameConfig = preload("../util/CPGameConfig.gd")
const customShellSpawner = preload("../util/CPShellSpawner.gd")
const customShellLoader = preload("../util/CPShellLoader.gd")

const STPND_CHALLENGEPACK_LOG := "StarPanda-ChallengePack:MainPatch"

func _init():
	scene_name = "main"
	
func _apply(root: Node):		
	var originalSpawner = root.get_node("standalone managers/shell spawner")
	var originalLoader = root.get_node("standalone managers/shell loader")
	var newSpawner = _init_custom_spawner(originalSpawner)
	var newLoader = _init_custom_loader(originalLoader)

	_inject_custom(root, newSpawner, newLoader)
	_spawn_protectors(root)
	
	originalSpawner.queue_free()
	originalLoader.queue_free()
	ModLoaderLog.info("Applied main patch!", STPND_CHALLENGEPACK_LOG)
	return true
	
func _init_custom_spawner(original: ShellSpawner) -> ShellSpawner:
	var target = customShellSpawner.new()
	
	target.name = "challengepack shell spawner"
	target.dialogue = original.dialogue
	target.anim_compartment = original.anim_compartment
	target.roundManager = original.roundManager
	target.camera = original.camera
	target.shellInstance = original.shellInstance
	target.shellLocationArray = original.shellLocationArray
	target.spawnParent = original.spawnParent
	target.healthCounter = original.healthCounter
	target.soundArray_latchOpen = original.soundArray_latchOpen
	target.speaker_latchOpen = original.speaker_latchOpen
	target.speaker_audioIndicator = original.speaker_audioIndicator
	target.soundArray_indicators = original.soundArray_indicators
	
	return target
	
func _init_custom_loader(original: ShellLoader) -> ShellLoader:
	var target = customShellLoader.new()
	
	target.name = "challengepack shell loader"
	target.perm = original.perm
	target.camera = original.camera
	target.roundManager = original.roundManager
	target.speaker_loadShell = original.speaker_loadShell
	target.speaker_rackShotgun = original.speaker_rackShotgun
	target.animator_shotgun = original.animator_shotgun
	target.dialogue = original.dialogue
	target.cursor = original.cursor
	target.playerData = original.playerData
	target.shotgunHand_L = original.shotgunHand_L
	target.shotgunHand_R = original.shotgunHand_R
	target.animator_dealerHands = original.animator_dealerHands
	target.animator_dealerHandRight = original.animator_dealerHandRight
	target.dealerAI = original.dealerAI
	target.introductionDialogues = original.introductionDialogues
	target.loadingDialogues = original.loadingDialogues
	
	return target
	
func _inject_custom(root: Node, spawner: ShellSpawner, loader: ShellLoader):
	var managersRoot = root.get_node("standalone managers")
	managersRoot.add_child(spawner)
	managersRoot.add_child(loader)
	
	var roundManager = managersRoot.get_node("round manager")
	var deathManager = managersRoot.get_node("death manager")
	var dealerAi = managersRoot.get_node("dealer intelligence")
	var shotgun = managersRoot.get_node("shotgun shooting")
	var shellExamine = managersRoot.get_node("shell examine")
	var shellEject1 = root.get_node("s/shell eject manager")
	var shellEject2 = root.get_node("shell parent_ejecting enemy side/shell eject manager")
	
	roundManager.shellSpawner = spawner
	dealerAi.shellSpawner = spawner
	shotgun.shellSpawner = spawner
	shellExamine.shellSpawner = spawner
	shellEject1.shellSpawner = spawner
	shellEject2.shellSpawner = spawner
	ModLoaderLog.debug("CustomShellSpawner injected!", STPND_CHALLENGEPACK_LOG)
	
	roundManager.shellLoader = loader
	dealerAi.shellLoader = loader
	deathManager.shellLoader = loader
	ModLoaderLog.debug("CustomShellLoader injected!", STPND_CHALLENGEPACK_LOG)
	
func _spawn_protectors(root: Node):
	var item_mode = ProjectSettings.get_setting("challengepack_item", 0)
	if (item_mode != GameConfig.ItemMode.HIDDEN):
		return
	
	var parent = root.get_node("tabletop parent/main tabletop")
	var protector = preload("../instances/protector.tscn")
	
	var protectorA = protector.instantiate()
	var protectorB = protector.instantiate()
	
	protectorA.position = Vector3(-4.198, -0.128, 5.254)
	protectorB.position = Vector3(-4.198, -0.128, -5.254)
	
	parent.add_child(protectorA)
	parent.add_child(protectorB)
	
