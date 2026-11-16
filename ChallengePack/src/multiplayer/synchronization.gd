extends RefCounted

# Explicit session dependency; native adapters keep their stable facade.
var owner: Node

func _init(session: Node):
	owner = session

func snapshot() -> Dictionary:
	var health = {}
	var inventories = {}
	if is_instance_valid(owner.game):
		for p in owner.game.instance_handler.instance_property_array:
			health[p.socket_number] = p.health_current
			inventories[p.socket_number] = []
			for item in p.user_inventory: inventories[p.socket_number].append(item.get("item_id", 0))
	return {"charge": owner.rules.charge, "turn": owner.rules.turn, "players": owner.rules.players.duplicate(true), "health": health, "inventories": inventories, "last_actor": owner.rules.last_actor, "current": owner.game.MAIN_active_current_turn_socket if is_instance_valid(owner.game) else -1, "direction": owner.game.MAIN_active_turn_order if is_instance_valid(owner.game) else "CW", "sawed": owner.game.MAIN_barrel_sawed_off if is_instance_valid(owner.game) else false}

func public_digest() -> String:
	return var_to_bytes(owner.snapshot()).hex_encode().sha256_text()

func apply_snapshot(data: Dictionary):
	if not is_instance_valid(owner.game) or not data.get("players") is Dictionary or not data.get("health") is Dictionary: return
	owner.rules.charge = data.charge
	owner.rules.turn = data.turn
	owner.rules.players = data.players.duplicate(true)
	owner.rules.last_actor = data.last_actor
	for socket in data.health:
		var p = owner.property_for(socket)
		if p != null:
			p.health_current = data.health[socket]
			p.health_counter.UpdateDisplay()
	owner.game.MAIN_active_current_turn_socket = data.get("current", -1)
	owner.game.MAIN_active_turn_order = data.get("direction", "CW")
	owner.game.MAIN_barrel_sawed_off = data.get("sawed", false)
	for socket in data.get("inventories", {}):
		var p = owner.property_for(socket)
		if p == null: continue
		var wanted = data.inventories[socket]
		for i in range(8):
			var existing = p.user_inventory[i].get("item_id", 0)
			if existing == wanted[i]: continue
			if is_instance_valid(p.user_inventory_instance_array[i]): p.user_inventory_instance_array[i].queue_free()
			p.user_inventory_instance_array[i] = null
			p.user_inventory[i] = {}
			owner.game.MAIN_inventory_by_socket[socket][i] = {}
			if wanted[i] != 0:
				p.item_manager.Debug_SpawnItemSeparately(wanted[i], i)
				p.user_inventory[i] = {"item_id": wanted[i], "item_local_grid_index": i}
	owner.recount_items()
	owner.snapshot_deadline = 0

func stage(token: String) -> bool:
	var captured_epoch = owner.epoch
	print("[ChallengePack MP] waiting for stage ", token, "; host=", owner.host())
	var deadline = Time.get_ticks_msec() + owner.TIMEOUT
	if owner.host():
		if not owner.stages.has(token): owner.stages[token] = {}
		owner.stages[token][GlobalSteam.STEAM_ID] = true
		while is_instance_valid(owner.game) and not owner.blocked and captured_epoch == owner.epoch:
			# process_frame resumes before node processing after focus returns.
			# Consume queued acknowledgments before expiring a wall-clock deadline.
			owner.drain_packets()
			if owner.blocked or captured_epoch != owner.epoch or not owner.stages.has(token): return false
			var complete = true
			for id in owner.ids():
				if not owner.stages[token].has(id): complete = false
			if complete: break
			if Time.get_ticks_msec() > deadline:
				push_warning("[ChallengePack MP] stage timeout: %s; ready=%s; expected=%s" % [token, owner.stages[token].keys(), owner.ids()])
				owner.fail(owner.port.localization.text("CP_MP_TIMEOUT", [owner.TIMEOUT_SECONDS]))
				return false
			await owner.get_tree().process_frame
		owner.send("stage_release", {"token": token})
	else:
		owner.send("stage_ready", {"token": token, "identity": owner.identity(), "rules": owner.rules.settings, "vanilla": owner.vanilla_digest()}, GlobalSteam.HOST_ID)
		var retry_at = Time.get_ticks_msec() + 500
		while not owner.released.has(token) and not owner.blocked and captured_epoch == owner.epoch:
			owner.drain_packets()
			if owner.released.has(token): break
			if owner.blocked or captured_epoch != owner.epoch: return false
			if Time.get_ticks_msec() >= retry_at:
				owner.send("stage_ready", {"token": token, "identity": owner.identity(), "rules": owner.rules.settings, "vanilla": owner.vanilla_digest()}, GlobalSteam.HOST_ID)
				retry_at = Time.get_ticks_msec() + 500
			if Time.get_ticks_msec() > deadline:
				push_warning("[ChallengePack MP] stage release timed out: " + token)
				owner.fail(owner.port.localization.text("CP_MP_TIMEOUT", [owner.TIMEOUT_SECONDS]))
				return false
			await owner.get_tree().process_frame
	var complete = not owner.blocked and is_instance_valid(owner.game) and captured_epoch == owner.epoch
	if complete:
		if token == "scene": owner.startup_deadline = 0
		print("[ChallengePack MP] completed stage ", token)
	return complete

func flush_snapshots():
	for id in owner.resync_requests:
		if id in owner.ids(): owner.send("snapshot", owner.snapshot(), id)
	owner.resync_requests.clear()

