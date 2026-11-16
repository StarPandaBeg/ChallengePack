extends RefCounted

const Catalog = preload("domain/contracts.gd")
const Contract = Catalog.Contract
const LEGACY_SETTING_COUNT = Catalog.LEGACY_SETTING_COUNT
const ALL_IDS = Catalog.ALL_IDS
const CATALOG = Catalog.CATALOG
var port: Node
var managers = {}
var current: WeakRef
var rng = RandomNumberGenerator.new()

static func contract_key(id: int) -> String:
	return Catalog.contract_key(id)

static func hud_key(id: int, used_items: Array = []) -> String:
	return Catalog.hud_key(id, used_items)

func _init(owner_port: Node):
	port = owner_port
	rng.randomize()

func mode(key: String) -> int:
	return port.active.get(key, 0)

func state(manager: Node) -> Dictionary:
	var id = manager.get_instance_id()
	if not managers.has(id):
		preload("runtime/node_registry.gd").track(manager, managers, {"used": 0, "contract": 0, "failed": false, "started": false, "has_items": false, "paused_contract": 0, "used_items": []})
	return managers[id]

func track(manager: Node):
	state(manager)
	current = weakref(manager)

func reset_pocket(manager: Node):
	state(manager).used = 0

func shot_strength(manager: Node) -> int:
	# A contract supplies the same strength as a saw, without changing the barrel
	# or persisting into the next charge. Combining both never multiplies again.
	return preload("domain/shell_rules.gd").strength(manager.currentShotgunDamage, state(manager).contract == Contract.TWO_FOR_ONE)

func player_target(manager: Node, selected: String) -> String:
	if state(manager).contract == Contract.LEAKY_GUN:
		return {"self": "dealer", "dealer": "self"}.get(selected, selected)
	return selected

func select_contract(has_items: bool = true) -> int:
	if mode("contract") == 0:
		return 0
	var candidates = []
	var pool = port.active.get("contract_pool", ALL_IDS)
	for id in ALL_IDS:
		if id in pool and (has_items or not CATALOG[id].requires_items):
			candidates.append(id)
	return preload("domain/shell_rules.gd").choose_contract(candidates, port.active.get("contract_chance", 30), rng)

func begin_round(manager: Node):
	track(manager)
	var entry = state(manager)
	entry.used = 0
	entry.used_items.clear()
	entry.started = true
	entry.has_items = manager.roundArray[manager.currentRound].usingItems
	entry.contract = select_contract(entry.has_items)
	var pool = port.active.get("contract_pool", ALL_IDS)
	entry.paused_contract = pool[0] if mode("contract") != 0 and pool.size() == 1 and not entry.has_items and CATALOG[pool[0]].requires_items else 0
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
	preload("runtime/node_registry.gd").prune(managers)
