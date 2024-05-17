extends "res://scripts/ShellSpawner.gd"

const CPGameConfig = preload("res://mods-unpacked/StarPanda-ChallengePack/util/CPGameConfig.gd")

func SpawnShells(numberOfShells : int, numberOfLives : int, numberOfBlanks : int, shufflingArray : bool):
	var current_mode = ProjectSettings.get_setting("challengepack_mode", 0)
	var shuffle_mode = ProjectSettings.get_setting("challengepack_shuffle", 0)
	var needShuffle = shufflingArray if (shuffle_mode == CPGameConfig.ShuffleMode.YES) else false;
	
	super(numberOfShells, numberOfLives, numberOfBlanks, needShuffle)
	
	if (current_mode != CPGameConfig.GameMode.DEFAULT):
		roundManager.playerData.skippingShellDescription = true
	if (current_mode == CPGameConfig.GameMode.QUANTITY):
		_cpRecolorShells()
		
func MainShellRoutine():
	var shuffleRound = roundManager.roundArray[roundManager.currentRound].insertingInRandomOrder
	var shuffle_mode = ProjectSettings.get_setting("challengepack_shuffle", 0)
	var needShuffle = shuffleRound if (shuffle_mode == CPGameConfig.ShuffleMode.YES) else false;
	
	if not needShuffle:
		roundManager.roundArray[roundManager.currentRound].insertingInRandomOrder = false
	await super()
		
func PlayLatchSound():
	var current_mode = ProjectSettings.get_setting("challengepack_mode", 0)
	if (current_mode == CPGameConfig.GameMode.HIDDEN):
		return
	super()
	
func PlayAudioIndicators():
	var current_mode = ProjectSettings.get_setting("challengepack_mode", 0)
	if (current_mode == CPGameConfig.GameMode.HIDDEN):
		return
	await super()

func _cpRecolorShells():
	for shell in spawnedShellObjectArray:
		var branch = shell.get_child(0)
		branch.mesh.set_surface_override_material(1, branch.mat_blank)
