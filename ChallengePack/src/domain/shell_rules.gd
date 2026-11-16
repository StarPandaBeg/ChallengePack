extends RefCounted

const LIVE = "live"
const BLANK = "blank"
const HEAL = "heal"
const LETHAL = "lethal"

static func invert(shell: String) -> String:
	return {LIVE: BLANK, BLANK: LIVE, HEAL: LETHAL, LETHAL: HEAL}.get(shell, shell)

static func strength(base_damage: int, doubled: bool) -> int:
	return maxi(2, base_damage) if doubled else base_damage

static func health_after(shell: String, hp: int, maximum: int, damage: int) -> int:
	match shell:
		HEAL: return mini(maximum, hp + damage)
		LIVE: return maxi(0, hp - damage)
		LETHAL: return 0
	return hp

static func choose_contract(pool: Array, chance: int, rng: RandomNumberGenerator) -> int:
	if pool.is_empty() or rng.randf() >= float(chance) / 100.0: return 0
	return pool[rng.randi_range(0, pool.size() - 1)]
