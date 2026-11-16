extends RefCounted

const Contracts = preload("contracts.gd")
const LIMITS = {"shells": 3, "items": 2, "shuffle": 2, "turn": 3, "health": 2, "mirror": 2, "pocket": 3, "contract": 2, "heal": 2}
const DEFAULTS = {"shells": 0, "items": 0, "shuffle": 0, "turn": 0, "health": 0, "mirror": 0, "pocket": 0, "contract": 0, "heal": 0, "contract_pool": Contracts.ALL_IDS, "contract_chance": 30, "heal_chance": 30}
