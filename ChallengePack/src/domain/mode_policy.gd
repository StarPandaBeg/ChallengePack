extends RefCounted

const Contracts = preload("contracts.gd")
const Shells = preload("shell_rules.gd")

static func solo_strength(contract: int, base_damage: int) -> int:
	# In solo the contract strengthens both player and dealer.
	return Shells.strength(base_damage, contract == Contracts.Contract.TWO_FOR_ONE)

static func multiplayer_effect(contract: int, socket: int, actual: int, shell: String, saw: bool, hp: int, maximum: int) -> Dictionary:
	# In multiplayer the shooter's personal contract owns the bonus.
	var damage = Shells.strength(2 if saw else 1, contract == Contracts.Contract.TWO_FOR_ONE)
	return {"target": actual, "strength": damage, "health": Shells.health_after(shell, hp, maximum, damage), "keep_turn": actual == socket and shell in [Shells.BLANK, Shells.HEAL]}
