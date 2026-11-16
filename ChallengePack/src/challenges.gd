extends RefCounted

enum Contract { NONE, NO_HEALING, NO_SELF_SHOTS, NO_CUFFS, NO_HINTS, UNTOUCHABLE_CHARGE, FAIR_CALIBER, NO_STEALING, DRY_LAW, NO_INVERSION, NO_INSURANCE, TWO_FOR_ONE, LEAKY_GUN }
# IDs and setting values are append-only: old saved choices keep their meaning.
const SETTING_COUNT = Contract.LEAKY_GUN + 2
const CATALOG = {
	Contract.NONE: {"key": "CP_OFF", "hud": "CP_OFF", "detail": "CP_TIP_CONTRACT", "items": [], "requires_items": false},
	Contract.NO_HEALING: {"key": "CP_NO_HEALING", "hud": "CP_HUD_NO_HEALING", "detail": "CP_HUD_HEALING_DETAIL", "items": ["cigarettes", "expired medicine"], "requires_items": true},
	Contract.NO_SELF_SHOTS: {"key": "CP_NO_SELF_SHOTS", "hud": "CP_HUD_NO_SELF_SHOTS", "detail": "CP_HUD_SELF_DETAIL", "items": [], "requires_items": false},
	Contract.NO_CUFFS: {"key": "CP_NO_CUFFS", "hud": "CP_HUD_NO_CUFFS", "detail": "CP_HUD_CUFFS_DETAIL", "items": ["handcuffs"], "requires_items": true},
	Contract.NO_HINTS: {"key": "CP_NO_HINTS", "hud": "CP_HUD_NO_HINTS", "detail": "CP_DETAIL_NO_HINTS", "items": ["magnifying glass", "burner phone"], "requires_items": true},
	Contract.UNTOUCHABLE_CHARGE: {"key": "CP_UNTOUCHABLE_CHARGE", "hud": "CP_HUD_UNTOUCHABLE_CHARGE", "detail": "CP_DETAIL_UNTOUCHABLE_CHARGE", "items": ["beer", "inverter"], "requires_items": true},
	Contract.FAIR_CALIBER: {"key": "CP_FAIR_CALIBER", "hud": "CP_HUD_FAIR_CALIBER", "detail": "CP_DETAIL_FAIR_CALIBER", "items": ["handsaw"], "requires_items": true},
	Contract.NO_STEALING: {"key": "CP_NO_STEALING", "hud": "CP_HUD_NO_STEALING", "detail": "CP_DETAIL_NO_STEALING", "items": ["adrenaline"], "requires_items": true},
	Contract.DRY_LAW: {"key": "CP_DRY_LAW", "hud": "CP_HUD_DRY_LAW", "detail": "CP_DETAIL_DRY_LAW", "items": ["beer"], "requires_items": true},
	Contract.NO_INVERSION: {"key": "CP_NO_INVERSION", "hud": "CP_HUD_NO_INVERSION", "detail": "CP_DETAIL_NO_INVERSION", "items": ["inverter"], "requires_items": true},
	Contract.NO_INSURANCE: {"key": "CP_NO_INSURANCE", "hud": "CP_HUD_NO_INSURANCE", "detail": "CP_DETAIL_NO_INSURANCE", "items": [], "requires_items": true},
	Contract.TWO_FOR_ONE: {"key": "CP_TWO_FOR_ONE", "hud": "CP_HUD_TWO_FOR_ONE", "detail": "CP_DETAIL_TWO_FOR_ONE", "items": [], "requires_items": false},
	Contract.LEAKY_GUN: {"key": "CP_LEAKY_GUN", "hud": "CP_HUD_LEAKY_GUN", "detail": "CP_DETAIL_LEAKY_GUN", "items": [], "requires_items": false}
}
const CONTRACT_CHANCE = 0.30
var activation_chance = CONTRACT_CHANCE
var port: Node
var managers = {}
var current: WeakRef
var rng = RandomNumberGenerator.new()

static func menu_keys() -> Array:
	var result = ["CP_OFF", "CP_RANDOM"]
	for id in CATALOG:
		if id != Contract.NONE:
			result.append(CATALOG[id].key)
	return result

static func contract_key(id: int) -> String:
	return CATALOG[id].key

static func hud_key(id: int, used_items: Array = []) -> String:
	if id == Contract.NO_INSURANCE:
		if "magnifying glass" in used_items:
			return "CP_HUD_INSURANCE_NO_CUFFS"
		if "handcuffs" in used_items:
			return "CP_HUD_INSURANCE_NO_GLASS"
	return CATALOG[id].hud

func _init(owner_port: Node):
	port = owner_port
	rng.randomize()

func mode(key: String) -> int:
	return port.active.get(key, 0)

func state(manager: Node) -> Dictionary:
	var id = manager.get_instance_id()
	if not managers.has(id):
		managers[id] = {"ref": weakref(manager), "used": 0, "contract": 0, "failed": false, "started": false, "has_items": false, "paused_contract": 0, "used_items": []}
	return managers[id]

func track(manager: Node):
	state(manager)
	current = weakref(manager)

func reset_pocket(manager: Node):
	state(manager).used = 0

func shot_strength(manager: Node) -> int:
	# A contract supplies the same strength as a saw, without changing the barrel
	# or persisting into the next charge. Combining both never multiplies again.
	return maxi(2, manager.currentShotgunDamage) if state(manager).contract == Contract.TWO_FOR_ONE else manager.currentShotgunDamage

func player_target(manager: Node, selected: String) -> String:
	if state(manager).contract == Contract.LEAKY_GUN:
		return {"self": "dealer", "dealer": "self"}.get(selected, selected)
	return selected

func select_contract(has_items: bool = true) -> int:
	var selection = mode("contract")
	if selection == 0:
		return 0
	var candidates = []
	for id in CATALOG:
		if id != Contract.NONE and (has_items or not CATALOG[id].requires_items):
			if selection == 1 or id == selection - 1:
				candidates.append(id)
	if candidates.is_empty() or rng.randf() >= activation_chance:
		return 0
	return candidates[rng.randi_range(0, candidates.size() - 1)]

func begin_round(manager: Node):
	track(manager)
	var entry = state(manager)
	entry.used = 0
	entry.used_items.clear()
	entry.started = true
	entry.has_items = manager.roundArray[manager.currentRound].usingItems
	entry.contract = select_contract(entry.has_items)
	var fixed = mode("contract") - 1
	entry.paused_contract = fixed if fixed > 0 and not entry.has_items and CATALOG[fixed].requires_items else 0
	if entry.contract == 0:
		return
	port.contract_effects.announce(manager)
	manager.perm.SetIndicators(false)
	manager.perm.SetInteractionPermissions(false)
	manager.cursor.SetCursor(false, false)
	var dialogue = manager.shellLoader.dialogue
	dialogue.ShowText_ForDuration(port.localization.text("CP_CONTRACT_ANNOUNCE", [port.localization.text(contract_key(entry.contract))]), 3)
	await port.get_tree().create_timer(3, false).timeout

func item_breaks_contract(manager: Node, item: String) -> bool:
	var entry = state(manager)
	if item in CATALOG[entry.contract].items:
		return true
	if entry.contract == Contract.NO_INSURANCE:
		return (item == "handcuffs" and "magnifying glass" in entry.used_items) or (item == "magnifying glass" and "handcuffs" in entry.used_items)
	return false

func allow_pickup(interaction: Node, item: String) -> bool:
	var manager = interaction.roundManager
	var entry = state(manager)
	if entry.failed:
		return false
	if item_breaks_contract(manager, item):
		fail_contract(manager)
		return false
	var limit = mode("pocket")
	# A stolen item's use completes the already-counted adrenaline action.
	if not interaction.stealing and limit > 0 and entry.used >= limit:
		port.notify("CP_POCKET_EXHAUSTED")
		return false
	if not interaction.stealing:
		entry.used += 1
	if item in ["magnifying glass", "handcuffs"] and not item in entry.used_items:
		entry.used_items.append(item)
	return true

func allow_shot(manager: Node, target: String) -> bool:
	if state(manager).failed:
		return false
	if state(manager).contract == Contract.NO_SELF_SHOTS and target == "self":
		fail_contract(manager)
		return false
	return true

func fail_contract(manager: Node):
	var entry = state(manager)
	if entry.failed:
		return
	entry.failed = true
	manager.perm.SetIndicators(false)
	manager.perm.SetInteractionPermissions(false)
	manager.cursor.SetCursor(false, false)
	port.contract_effects.execute(manager, contract_key(entry.contract))

func hide_health(counter: Node):
	if mode("health") == 1 and counter.uiparent != null:
		counter.uiparent.visible = false

func mirror_inventory(manager: Node) -> Array:
	var result = []
	# Snapshot the actual placed inventory, not the random intake draws. This also
	# handles a full table, unaccepted items, and leftovers from the previous load.
	for item in manager.itemSpawnParent.get_children():
		if item.is_queued_for_deletion() or item.get_child_count() < 2:
			continue
		var branch = item.get_child(1)
		if item.get_child(0) is PickupIndicator and branch is InteractionBranch:
			if branch.isPlayerSide:
				result.append(branch.itemName)
			else:
				item.queue_free()
	for amount in manager.amounts.array_amounts:
		amount.amount_dealer = 0
	manager.itemArray_dealer.clear()
	manager.itemArray_instances_dealer.clear()
	manager.numberOfItemsGrabbed_enemy = 0
	manager.numberOfCigs_dealer = 0
	manager.ResetDealerGrid()
	return result

func hud_data() -> Dictionary:
	if current == null or current.get_ref() == null:
		return {}
	var entry = state(current.get_ref())
	if not entry.started or entry.failed:
		return {}
	var limit = mode("pocket") if entry.has_items else 0
	if entry.contract == 0 and entry.paused_contract == 0 and limit == 0:
		return {}
	var id: int = entry.paused_contract if entry.paused_contract != 0 else entry.contract
	return {"contract": entry.contract, "paused": entry.paused_contract, "limit": limit, "remaining": maxi(0, limit - entry.used), "hud_key": hud_key(id, entry.used_items)}

func prune():
	for id in managers.keys():
		if managers[id].ref.get_ref() == null:
			managers.erase(id)
