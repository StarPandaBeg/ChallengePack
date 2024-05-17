extends "res://scripts/ShellLoader.gd"

const CPGameConfig = preload("res://mods-unpacked/StarPanda-ChallengePack/util/CPGameConfig.gd")

var modePhrases := {
	CPGameConfig.GameMode.QUANTITY: ["Some of them are live.", "Now this is a real game."],
	CPGameConfig.GameMode.HIDDEN: ["You won't know their real number.", "Now this is a real game."]
}
var dealerFirstMessageShown := false
var rnd = RandomNumberGenerator.new()
var lastTurn := 1

func LoadShells():
	var current_mode = ProjectSettings.get_setting("challengepack_mode", 0)
	
	# ORIGINAL CODE
	camera.BeginLerp("enemy")
	if (!roundManager.shellLoadingSpedUp): await get_tree().create_timer(.8, false).timeout
	await(DealerHandsGrabShotgun())
	await get_tree().create_timer(.2, false).timeout
	animator_shotgun.play("grab shotgun_pointing enemy")
	await get_tree().create_timer(.45, false).timeout
	# END ORIGINAL CODE
	
	_cpIntroductionPhrases(current_mode)
	
	# ORIGINAL CODE
	var numberOfShells = roundManager.roundArray[roundManager.currentRound].amountBlank + roundManager.roundArray[roundManager.currentRound].amountLive
	# END ORIGINAL CODE
	if (current_mode == CPGameConfig.GameMode.HIDDEN):
		numberOfShells = 8
		
	# ORIGINAL CODE
	for i in range(numberOfShells):
		speaker_loadShell.play()
		animator_dealerHandRight.play("load single shell")
		if(roundManager.shellLoadingSpedUp): await get_tree().create_timer(.17, false).timeout
		else: await get_tree().create_timer(.32, false).timeout
		pass
	animator_dealerHandRight.play("RESET")
	dealerAI.Speaker_HandCrack()
	if (roundManager.shellLoadingSpedUp): await get_tree().create_timer(.17, false).timeout
	else: await get_tree().create_timer(.42, false).timeout
	#INTRODUCTION DIALOGUE
	if (roundManager.roundArray[roundManager.currentRound].hasIntroductoryText):
		dialogue.ShowText_Forever(introductionDialogues[0])
		await get_tree().create_timer(1.9, false).timeout
		dialogue.ShowText_Forever(introductionDialogues[1])
		await get_tree().create_timer(3, false).timeout
		dialogue.ShowText_Forever(introductionDialogues[2])
		await get_tree().create_timer(3, false).timeout
		dialogue.ShowText_Forever(introductionDialogues[3])
		await get_tree().create_timer(3, false).timeout
		dialogue.ShowText_Forever(introductionDialogues[4])
		await get_tree().create_timer(3, false).timeout
		dialogue.ShowText_Forever(introductionDialogues[5])
		await get_tree().create_timer(3.7, false).timeout
		dialogue.ShowText_Forever(introductionDialogues[6])
		await get_tree().create_timer(3.7, false).timeout
		dialogue.ShowText_Forever(introductionDialogues[7])
		await get_tree().create_timer(3.7, false).timeout
		dialogue.ShowText_Forever(introductionDialogues[8])
		await get_tree().create_timer(2.5, false).timeout
		roundManager.playerData.hasReadIntroduction = true
		dialogue.HideText()
	#RACK SHOTGUN, PLACE ON TABLE
	#speaker_rackShotgun.play()
	animator_shotgun.play("enemy rack shotgun start")
	await get_tree().create_timer(.8, false).timeout
	animator_shotgun.play("enemy put down shotgun")
	DealerHandsDropShotgun()
	# END ORIGINAL CODE
	
	_cpResolveNextTurn()
	
func _cpIntroductionPhrases(current_mode: int):
	if (current_mode == CPGameConfig.GameMode.DEFAULT):
		# ORIGINAL CODE (from LoadShells)
		if (roundManager.playerData.numberOfDialogueRead < 3):	
			if (diaindex == loadingDialogues.size()):
				diaindex = 0
			var stringshow
			if (diaindex == 0): stringshow = tr("SHELL INSERT1")
			if (diaindex == 1): stringshow = tr("SHELL INSERT2")
			dialogue.ShowText_ForDuration(stringshow, 3)
			diaindex += 1
			await get_tree().create_timer(3, false).timeout
			roundManager.playerData.numberOfDialogueRead += 1
		# END ORIGINAL CODE
		return
		
	var phrases = modePhrases[current_mode]
	var phrasesAmount = phrases.size()
	
	# TODO: Replace 3 with actual phrase amount
	if (roundManager.playerData.numberOfDialogueRead < 3):
		if (diaindex == phrasesAmount):
			diaindex = 0
		dialogue.ShowText_ForDuration(phrases[diaindex], 3)
		diaindex += 1
		await get_tree().create_timer(3, false).timeout
		roundManager.playerData.numberOfDialogueRead += 1

func _cpResolveNextTurn():
	var turn_mode = ProjectSettings.get_setting("challengepack_turn", 0)
	if (turn_mode == CPGameConfig.TurnMode.ALWAYS_FIRST):
		await _cpTurnPlayer()
		return
	
	var next_turn = 1 if (lastTurn == 0) else 0
	if (turn_mode == CPGameConfig.TurnMode.RANDOM):
		next_turn = rnd.randi_range(0, 1)
	
	if (next_turn == 0):
		await _cpTurnPlayer()
	else:
		await _cpTurnDealer()
	lastTurn = next_turn
		
func _cpTurnPlayer() -> void:
	# ORIGINAL CODE (from LoadShells)
	camera.BeginLerp("home")
	#ALLOW INTERACTION
	roundManager.playerCurrentTurnItemArray = []
	await get_tree().create_timer(.6, false).timeout
	perm.SetStackInvalidIndicators()
	cursor.SetCursor(true, true)
	perm.SetIndicators(true)
	perm.SetInteractionPermissions(true)
	roundManager.SetupDeskUI()
	# END ORIGINAL CODE

func _cpTurnDealer() -> void:
	await get_tree().create_timer(.6, false).timeout
	if (!dealerFirstMessageShown):
		dialogue.ShowText_Forever("I'll be the first")
		await get_tree().create_timer(1.9, false).timeout
		dialogue.HideText()
		dealerFirstMessageShown = true
	dealerAI.BeginDealerTurn()
