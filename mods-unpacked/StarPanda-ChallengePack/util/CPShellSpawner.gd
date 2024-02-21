extends ShellSpawner

const GameConfig = preload("./CPGameConfig.gd")

func SpawnShells(numberOfShells : int, numberOfLives : int, numberOfBlanks : int, shufflingArray : bool):
	super.SpawnShells(numberOfShells, numberOfLives, numberOfBlanks, shufflingArray)
	
	var current_mode = ProjectSettings.get_setting("challengepack_mode", 0)
	if (current_mode == GameConfig.GameMode.DEFAULT):
		return
	roundManager.playerData.skippingShellDescription = true
	
	if (current_mode == GameConfig.GameMode.QUANTITY):
		for shell in spawnedShellObjectArray:
			var branch = shell.get_child(0)
			branch.mesh.set_surface_override_material(1, branch.mat_blank)
			
func MainShellRoutine():
	var current_mode = ProjectSettings.get_setting("challengepack_mode", 0)
	
	if (roundManager.playerData.currentBatchIndex != 0):
		roundManager.shellLoadingSpedUp = true
	#CLEAR PREVIOUS SHELL SEQUENCE ARRAY
	sequenceArray = []
	#CHECK IF CONSOLE TEXT EXISTS. SHOW CONSOLE TEXT
	
	#INITIAL CAMERA SOCKET. HEALTH COUNTER FUNCTIONALITY
	if (roundManager.roundArray[roundManager.currentRound].bootingUpCounter):
		camera.BeginLerp("health counter")
		await get_tree().create_timer(.5, false).timeout
		healthCounter.Bootup()
		await get_tree().create_timer(1.4, false).timeout
	#await get_tree().create_timer(2, false).timeout #NEW
	camera.BeginLerp("shell compartment")
	await get_tree().create_timer(.5, false).timeout
	#SHELL SPAWNING
	var temp_nr = roundManager.roundArray[roundManager.currentRound].amountBlank + roundManager.roundArray[roundManager.currentRound].amountLive
	var temp_live = roundManager.roundArray[roundManager.currentRound].amountLive
	var temp_blank = roundManager.roundArray[roundManager.currentRound].amountBlank
	var temp_shuf = roundManager.roundArray[roundManager.currentRound].shufflingArray
	SpawnShells(temp_nr, temp_live, temp_blank, temp_shuf)
	seq = sequenceArray
	
	if (current_mode != GameConfig.GameMode.HIDDEN):
		anim_compartment.play("show shells")
		PlayLatchSound()
		PlayAudioIndicators()
		await get_tree().create_timer(1, false).timeout
	roundManager.ignoring = false
	
	#DIALOGUE
	var text_lives
	var text_blanks
	if (temp_live == 1): text_lives = "LIVE ROUND."
	else: text_lives = "LIVE ROUNDS."
	if (temp_blank == 1): text_blanks = "BLANK."
	else: text_blanks = "BLANKS."
	var finalstring : String = str(temp_live) + " " + text_lives + " " + str(temp_blank) + " " + text_blanks
	var maindur = 1.3
	if (roundManager.playerData.currentBatchIndex == 2):
		roundManager.playerData.skippingShellDescription = true
	if (!roundManager.playerData.skippingShellDescription): dialogue.ShowText_Forever(finalstring)
	if (roundManager.playerData.skippingShellDescription && !skipDialoguePresented):
		var text = "YOU KNOW THE DRILL." if (current_mode != GameConfig.GameMode.HIDDEN) else "NOTHING HERE FOR YOUR EYES"
		dialogue.ShowText_Forever(text)
		maindur = 2.5
		skipDialoguePresented = true
	if(!roundManager.playerData.skippingShellDescription): await get_tree().create_timer(2.5, false).timeout
	else: await get_tree().create_timer(maindur, false).timeout
	dialogue.HideText()
	#HIDE SHELLS
	
	if (current_mode != GameConfig.GameMode.HIDDEN):
		anim_compartment.play("hide shells")
		PlayLatchSound()
		if(roundManager.shellLoadingSpedUp): await get_tree().create_timer(.2, false).timeout
		else: await get_tree().create_timer(.5, false).timeout
	#CHECK IF INSERTING INTO CHAMBER IN RANDOM ORDER.
	if (roundManager.roundArray[roundManager.currentRound].insertingInRandomOrder):
		sequenceArray.shuffle()
		sequenceArray.shuffle()
	roundManager.LoadShells()
	return
	pass
