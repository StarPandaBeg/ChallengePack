extends ShellLoader

var modePhrases := {
	"DEFAULT": loadingDialogues,
	"QUANTITY": ["Some of them are live.", "Now this is a real game."],
	"HIDDEN": ["You won't know their real number.", "Now this is a real game."]
}

func LoadShells():
	var current_mode_s = ProjectSettings.get_setting("hiddenshell_mode", "DEFAULT")
	
	camera.BeginLerp("enemy")
	if (!roundManager.shellLoadingSpedUp): await get_tree().create_timer(.8, false).timeout
	await(DealerHandsGrabShotgun())
	await get_tree().create_timer(.2, false).timeout
	animator_shotgun.play("grab shotgun_pointing enemy")
	await get_tree().create_timer(.45, false).timeout
	
	var phrases = modePhrases[current_mode_s]
	var phrasesAmount = len(phrases)
	
	if (roundManager.playerData.numberOfDialogueRead < phrasesAmount):
		if (diaindex >= phrasesAmount):
			diaindex = 0
		dialogue.ShowText_ForDuration(phrases[diaindex], 3)
		diaindex += 1
		await get_tree().create_timer(3, false).timeout
		roundManager.playerData.numberOfDialogueRead += 1
		
	var numberOfShells = roundManager.roundArray[roundManager.currentRound].amountBlank + roundManager.roundArray[roundManager.currentRound].amountLive
	if (current_mode_s == "HIDDEN"):
		numberOfShells = 8
	
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
	camera.BeginLerp("home")
	#ALLOW INTERACTION
	await get_tree().create_timer(.6, false).timeout
	perm.SetStackInvalidIndicators()
	cursor.SetCursor(true, true)
	perm.SetIndicators(true)
	perm.SetInteractionPermissions(true)
	pass
