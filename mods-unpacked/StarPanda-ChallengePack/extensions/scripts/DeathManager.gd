extends "res://scripts/DeathManager.gd"

const STPND_CHALLENGEPACK_LOG := "StarPanda-ChallengePack:DeathManager"

signal cp_death

func MainDeathRoutine():
	await super()
	cp_death.emit()
