extends RefCounted

const CONTRACT_KEYS = ["CP_OFF", "CP_NO_HEALING", "CP_NO_SELF_SHOTS", "CP_NO_CUFFS"]
const CONTRACT_CHANCE = 0.30
var port: Node
var managers = {}
var current: WeakRef
var rng = RandomNumberGenerator.new()

func _init(owner_port: Node):
	port = owner_port
	rng.randomize()

func mode(key: String) -> int:
	return port.active.get(key, 0)

func state(manager: Node) -> Dictionary:
	var id = manager.get_instance_id()
	if not managers.has(id):
		managers[id] = {"ref": weakref(manager), "used": 0, "contract": 0, "failed": false, "started": false, "has_items": false, "paused_contract": 0}
	return managers[id]

func track(manager: Node):
	state(manager)
	current = weakref(manager)

func reset_pocket(manager: Node):
	state(manager).used = 0

func select_contract(has_items: bool = true) -> int:
	var selection = mode("contract")
	if selection == 0 or (not has_items and selection in [2, 4]):
		return 0
	if rng.randf() >= CONTRACT_CHANCE:
		return 0
	if not has_items:
		return 2 if selection in [1, 3] else 0
	return rng.randi_range(1, 3) if selection == 1 else maxi(0, selection - 1)

func begin_round(manager: Node):
	track(manager)
	var entry = state(manager)
	entry.used = 0
	entry.started = true
	entry.has_items = manager.roundArray[manager.currentRound].usingItems
	entry.contract = select_contract(entry.has_items)
	entry.paused_contract = mode("contract") - 1 if not entry.has_items and mode("contract") in [2, 4] else 0
	if entry.contract == 0:
		return
	manager.perm.SetIndicators(false)
	manager.perm.SetInteractionPermissions(false)
	manager.cursor.SetCursor(false, false)
	var dialogue = manager.shellLoader.dialogue
	dialogue.ShowText_ForDuration(port.localization.text("CP_CONTRACT_ANNOUNCE", [port.localization.text(CONTRACT_KEYS[entry.contract])]), 3)
	await port.get_tree().create_timer(3, false).timeout

func item_breaks_contract(manager: Node, item: String) -> bool:
	var contract = state(manager).contract
	return (contract == 1 and item in ["cigarettes", "expired medicine"]) or (contract == 3 and item == "handcuffs")

func allow_pickup(interaction: Node, item: String) -> bool:
	var manager = interaction.roundManager
	var entry = state(manager)
	if entry.failed:
		return false
	if item_breaks_contract(manager, item):
		fail_contract(manager)
		return false
	# A stolen item's use completes the already-counted adrenaline action.
	if interaction.stealing:
		return true
	var limit = mode("pocket")
	if limit > 0 and entry.used >= limit:
		port.notify("CP_POCKET_EXHAUSTED")
		return false
	entry.used += 1
	return true

func allow_shot(manager: Node, target: String) -> bool:
	if state(manager).failed:
		return false
	if state(manager).contract == 2 and target == "self":
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
	port.failure_screen.open(CONTRACT_KEYS[entry.contract])

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
	return {"contract": entry.contract, "paused": entry.paused_contract, "limit": limit, "remaining": maxi(0, limit - entry.used)}

func prune():
	for id in managers.keys():
		if managers[id].ref.get_ref() == null:
			managers.erase(id)
