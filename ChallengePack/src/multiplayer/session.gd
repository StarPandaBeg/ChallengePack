extends Node

const Rules = preload("rules.gd")
const Settings = preload("settings.gd")
const Effects = preload("../contract_effects.gd")
const PROTOCOL = 1
const TIMEOUT_SECONDS = 30
const TIMEOUT = TIMEOUT_SECONDS * 1000
const REQUESTS = {10: "pickup shotgun request", 12: "shoot user request", 15: "look at user request", 17: "grab item request", 19: "place item request", 22: "interact with item request", 24: "secondary item interaction request"}
var port: Node
var settings = Settings.new()
var rules = Rules.new()
var compatible = false
var error = ""
var fingerprint = ""
var packets: Node
var game: Node
var lobby_ui: Node
var ui: CanvasLayer
var session = ""
var revision = 0
var peers = {}
var members = []
var lobby_owner = 0
var lobby_id = 0
var loading = false
var scene_ready = {}
var request_counter = 0
var event_counter = 0
var custom_counter = 0
var received_custom = {}
var received_events = {}
var received_actions = {}
var sender = 0
var blocked = false
var barrier = ""
var barrier_acks = {}
var barrier_deadline = 0
var mirror = []
var mirror_offsets = {}
var pending_shots = {}
var applied_outcomes = {}
var completed_actions = {}
var last_tick = 0
var snapshot_deadline = 0
var last_digest = ""
var in_game = false
var epoch = 0
var resync_requests = []
var theft_target = -1
var busy = false
var stages = {}
var released = {}
var hidden = {}
var stock_digest = ""
var expected_stock_digest = ""
var startup_deadline = 0
var draining_packets = false

func setup(parent_port: Node):
	port = parent_port
	process_priority = 100 # Apply concealment after the game's ordinary updates.
	settings.load_settings()
	rules.settings = settings.values.duplicate(true)

func host() -> bool:
	return GlobalSteam.STEAM_ID == GlobalSteam.HOST_ID

func ids() -> Array:
	var result = []
	for member in GlobalSteam.LOBBY_MEMBERS: result.append(member.steam_id)
	result.sort()
	return result

func identity() -> Dictionary:
	return {"mod": port.VERSION, "protocol": PROTOCOL, "game": "2.2.0.6", "fingerprint": fingerprint}

func message(alias: String, payload: Dictionary = {}) -> Dictionary:
	custom_counter += 1
	return {"packet category": "ChallengePack", "packet alias": alias, "cp_protocol": PROTOCOL, "session": session, "revision": revision, "charge": rules.charge, "turn": rules.turn, "phase": "game" if in_game else "lobby", "cp_message": custom_counter, "data": payload}

func send(alias: String, payload: Dictionary = {}, target: int = 0):
	if is_instance_valid(packets): packets.send_p2p_packet(target, message(alias, payload))

func notice(key: String, args: Array = []):
	port.notice_key = key
	port.notice_args = args
	port.notice_until = Time.get_ticks_msec() + 8000

func fail(reason: String):
	if blocked: return
	blocked = true
	notice("CP_MP_STOPPED", [reason])
	push_warning("[ChallengePack MP] " + reason)
	if is_instance_valid(game):
		game.StopAllTimeouts()
		game.round_manager.intermed.ExitGame(reason)
	elif is_instance_valid(packets) and is_instance_valid(packets.lobby):
		packets.lobby.leave_lobby()

func _process(_delta):
	if not compatible or not is_instance_valid(packets): return
	drain_packets()
	if not is_instance_valid(packets): return
	if in_game and is_instance_valid(game): presentation()
	var now = Time.get_ticks_msec()
	if in_game and startup_deadline > 0 and now > startup_deadline:
		startup_deadline = 0
		push_warning("[ChallengePack MP] scene startup timed out; arrived=%s; expected=%s; stages=%s" % [scene_ready.keys(), ids(), stages])
		fail(port.localization.text("CP_MP_TIMEOUT", [TIMEOUT_SECONDS]))
		return
	if now - last_tick < 200: return
	last_tick = now
	if GlobalSteam.LOBBY_ID == 0:
		lobby_id = 0
		if is_instance_valid(ui): ui.refresh()
		return
	var current = ids()
	var changed = current != members or lobby_owner != GlobalSteam.HOST_ID or lobby_id != GlobalSteam.LOBBY_ID
	if changed and in_game:
		if lobby_owner != 0 and lobby_owner != GlobalSteam.HOST_ID:
			fail(port.localization.text("CP_MP_HOST_LEFT"))
			return
		for id in current:
			if not id in members and host(): packets.lobby.KickPlayerInLobby(id)
		members = current
		changed = false
		if current.size() < 2:
			fail(port.localization.text("CP_MP_NOT_ENOUGH"))
			return
	if changed:
		if in_game and lobby_owner != 0 and lobby_owner != GlobalSteam.HOST_ID:
			fail(port.localization.text("CP_MP_HOST_LEFT"))
			return
		members = current
		lobby_owner = GlobalSteam.HOST_ID
		lobby_id = GlobalSteam.LOBBY_ID
		blocked = false
		peers.clear()
		if host():
			session = "%s-%s" % [GlobalSteam.STEAM_ID, Time.get_ticks_usec()]
			revision += 1
			Steam.setLobbyData(lobby_id, "challengepack", port.VERSION)
			Steam.setLobbyData(lobby_id, "cp_protocol", str(PROTOCOL))
			Steam.setLobbyData(lobby_id, "cp_fingerprint", fingerprint)
			peers[GlobalSteam.STEAM_ID] = {"verified": true, "ready": false, "deadline": now + TIMEOUT}
		for id in members:
			if id != GlobalSteam.STEAM_ID: peers[id] = {"verified": false, "ready": false, "deadline": now + TIMEOUT}
		if not host(): send("hello", identity(), GlobalSteam.HOST_ID)
	if host():
		if not in_game and stock_digest != vanilla_digest():
			stock_digest = vanilla_digest()
			change_settings(rules.settings)
		for id in peers.keys():
			if id != GlobalSteam.STEAM_ID and not peers[id].verified:
				if now > peers[id].deadline:
					packets.lobby.KickPlayerInLobby(id)
					peers[id].deadline = now + TIMEOUT
				else: send("hello", identity(), id)
		if not barrier.is_empty() and now > barrier_deadline:
			fail(port.localization.text("CP_MP_TIMEOUT", [TIMEOUT_SECONDS]))
	elif snapshot_deadline > 0 and now > snapshot_deadline:
		fail(port.localization.text("CP_MP_TIMEOUT", [TIMEOUT_SECONDS]))
	if not host() and peers.has(GlobalSteam.HOST_ID) and not peers[GlobalSteam.HOST_ID].verified and now > peers[GlobalSteam.HOST_ID].deadline:
		fail(port.localization.text("CP_MP_MISMATCH"))
	if is_instance_valid(ui): ui.refresh()

func drain_packets():
	if draining_packets or not is_instance_valid(packets) or GlobalSteam.LOBBY_ID == 0: return
	if Steam.getAvailableP2PPacketSize(0) == 0: return
	draining_packets = true
	packets.read_all_p2p_packets()
	draining_packets = false

func receive_native(manager: Node, data: Dictionary, remote: int):
	if not remote in ids(): return
	var category = data.get("packet category", "")
	if category == "ChallengePack":
		receive(data, remote)
		return
	if category == "MP_PacketVerification":
		if not host(): return
		if not valid_action(data, remote): return
	elif remote != GlobalSteam.HOST_ID:
		if category == "lobby" and data.get("packet alias") == "member joined list":
			if not accept_scene_arrival(manager, data, remote): return
		else:
			# Only vanilla version negotiation is accepted from an unverified guest.
			if category != "MP_LobbyManager" or data.get("packet alias") != "check version" or data.get("packet_id") != 32 or not data.get("version") is String: return
	# Several original dispatchers depend on Dictionary insertion order. Never
	# let a request route through its unrelated first/second arbitrary fields.
	# The stock member-list update misspells its alias field.
	var canonical = {"packet category": category, "packet alias": data.get("packet alias", data.get("packat alias", "")), "sent_from": "host" if remote == GlobalSteam.HOST_ID else "client", "packet_id": data.get("packet_id", 0)}
	for key in data:
		if not canonical.has(key): canonical[key] = data[key]
	sender = remote
	manager.temp_id = remote
	manager.PipeData(canonical)
	sender = 0

func accept_scene_arrival(manager: Node, data: Dictionary, remote: int) -> bool:
	if not host() or not in_game or blocked or session.is_empty(): return false
	if not peers.get(remote, {}).get("verified", false): return false
	if data.get("packet_id") != 4 or data.get("steam_id") != remote: return false
	if data.get("cp_session") != session or data.get("cp_revision") != revision: return false
	if data.get("cp_charge") != 0 or data.get("cp_turn") != 0: return false
	var checker = manager.memberChecker
	if not is_instance_valid(checker) or not checker.checking or checker.fs: return false
	if remote in checker.membersHere_list: return false
	scene_ready[remote] = true
	print("[ChallengePack MP] accepted scene arrival from ", remote)
	return true

func receive(data: Dictionary, remote: int):
	if data.get("cp_protocol") != PROTOCOL or not data.get("data") is Dictionary: return
	if data.get("phase") != ("game" if in_game else "lobby"): return
	var number = data.get("cp_message", 0)
	if typeof(number) != TYPE_INT or number <= 0: return
	var receipt = "%s:%s:%s" % [data.get("session", ""), remote, number]
	if received_custom.has(receipt): return
	received_custom[receipt] = true
	var alias = data.get("packet alias", "")
	var body: Dictionary = data.data
	if alias == "hello":
		if in_game: return
		if body != identity():
			if host(): reject_peer(remote)
			else: fail(port.localization.text("CP_MP_MISMATCH"))
			return
		if not host() and remote != GlobalSteam.HOST_ID: return
		if not peers.has(remote): peers[remote] = {"verified": false, "ready": false, "deadline": Time.get_ticks_msec() + TIMEOUT}
		peers[remote].verified = true
		if host(): send_settings(remote)
		else: send("hello_ack", identity(), remote)
		return
	if alias == "hello_ack" and host() and body == identity():
		if peers.has(remote): peers[remote].verified = true
		send_settings(remote)
		return
	if alias == "settings" and not host() and remote == GlobalSteam.HOST_ID:
		if body.get("identity") != identity() or not Rules.validate(body.get("rules")): return
		if in_game: return
		session = data.session
		revision = data.revision
		rules.settings = body.rules.duplicate(true)
		expected_stock_digest = body.get("vanilla", "")
		peers[GlobalSteam.STEAM_ID] = {"verified": true, "ready": false, "deadline": 0}
		peers[remote] = {"verified": true, "ready": false, "deadline": Time.get_ticks_msec() + TIMEOUT}
		send("settings_ack", {}, remote)
		return
	if data.get("session") != session or data.get("revision") != revision: return
	if in_game and alias in ["failure", "continue", "digest", "snapshot", "mirror", "contracts"]:
		if data.get("charge", -1) < rules.charge or data.get("turn", -1) < rules.turn: return
	if host():
		if not peers.has(remote) or not peers[remote].verified: return
		match alias:
			"settings_ack": peers[remote].ready = false
			"ready": peers[remote].ready = body.get("ready", false) == true and body.get("vanilla") == vanilla_digest()
			"scene_ready": scene_ready[remote] = true
			"stage_ready":
				if body.get("identity") != identity() or body.get("rules") != rules.settings or body.get("vanilla") != vanilla_digest(): return
				var token = body.get("token", "")
				if not stages.has(token): stages[token] = {}
				stages[token][remote] = true
			"barrier_ack":
				if body.get("token") == barrier: barrier_acks[remote] = true
			"snapshot_request":
				if not remote in resync_requests: resync_requests.append(remote)
				if not busy: flush_snapshots()
		if alias in ["ready", "settings_ack"]: send("peers", {"peers": peers})
	elif remote == GlobalSteam.HOST_ID:
		match alias:
			"peers": peers = body.get("peers", {}).duplicate(true)
			"barrier":
				barrier = body.get("token", "")
				send("barrier_ack", {"token": barrier}, remote)
			"snapshot": apply_snapshot(body)
			"stage_release": released[body.get("token", "")] = true
			"continue": continue_turn(body.get("socket", -1), body.get("shot", false))
			"reject": restore_permissions(body.get("socket", -1))
			"failure": execute_failure(body)
			"contracts": apply_contracts(body)
			"mirror": apply_mirror(body.get("items", []))
			"digest":
				if body.get("digest") != public_digest():
					snapshot_deadline = Time.get_ticks_msec() + TIMEOUT
					for p in game.instance_handler.instance_property_array:
						if p.is_active: p.permissions.SetMainPermission(false)
					send("snapshot_request", {}, remote)

func change_settings(values: Dictionary):
	if not host() or in_game or not Rules.validate(values): return
	rules.settings = values.duplicate(true)
	settings.values = values.duplicate(true)
	settings.save_settings()
	revision += 1
	for id in peers: peers[id].ready = false
	send_settings()

func ready_toggle():
	if not host() and expected_stock_digest != vanilla_digest():
		notice("CP_MP_NOT_READY")
		return
	var me = GlobalSteam.STEAM_ID
	if not peers.has(me): peers[me] = {"verified": true, "ready": false, "deadline": 0}
	peers[me].ready = not peers[me].ready
	if host(): send("peers", {"peers": peers})
	else: send("ready", {"ready": peers[me].ready, "vanilla": vanilla_digest()}, GlobalSteam.HOST_ID)

func vanilla_digest() -> String:
	return var_to_bytes(GlobalVariables.active_match_customization_dictionary).hex_encode().sha256_text()

func send_settings(target: int = 0):
	send("settings", {"identity": identity(), "rules": rules.settings, "members": members, "vanilla": vanilla_digest()}, target)

func can_start() -> bool:
	if not compatible or blocked or in_game or loading or not host() or members.size() < 2: return false
	if stock_digest != vanilla_digest(): return false
	for id in members:
		if not peers.has(id) or not peers[id].verified or not peers[id].ready: return false
	return true

func reject_peer(id: int):
	if peers.has(id):
		peers[id].verified = false
		peers[id].ready = false
	if is_instance_valid(packets) and is_instance_valid(packets.lobby): packets.lobby.KickPlayerInLobby(id)

func can_join(id: int) -> bool:
	return Steam.getLobbyData(id, "challengepack") == port.VERSION and Steam.getLobbyData(id, "cp_protocol") == str(PROTOCOL) and Steam.getLobbyData(id, "cp_fingerprint") == fingerprint

func check_lobby(id: int) -> bool:
	Steam.requestLobbyData(id)
	var deadline = Time.get_ticks_msec() + TIMEOUT
	while is_inside_tree() and Time.get_ticks_msec() < deadline:
		if not Steam.getLobbyData(id, "challengepack").is_empty(): return can_join(id)
		await get_tree().process_frame
	return false

func stamp_request(data: Dictionary) -> Dictionary:
	request_counter += 1
	data["cp_action"] = request_counter
	data["cp_session"] = session
	data["cp_revision"] = revision
	data["cp_charge"] = rules.charge
	data["cp_turn"] = rules.turn
	return data

func direct_request(manager: Node, data: Dictionary):
	stamp_request(data)
	if host(): receive_native(manager, data, GlobalSteam.STEAM_ID)
	else: manager.send_p2p_packet(GlobalSteam.HOST_ID, data)

func valid_action(data: Dictionary, remote: int) -> bool:
	if blocked or snapshot_deadline > 0: return false
	if typeof(data.get("packet_id")) != TYPE_INT or data.get("packet alias") != REQUESTS.get(data.get("packet_id"), ""): return false
	if data.get("cp_session") != session or data.get("cp_revision") != revision or data.get("cp_charge") != rules.charge or data.get("cp_turn") != rules.turn: return false
	var n = data.get("cp_action", 0)
	if typeof(n) != TYPE_INT or n <= received_actions.get(remote, 0): return false
	var socket = data.get("sent_from_socket", -1)
	var property = property_for(socket)
	if property == null or property.user_id != remote or property.health_current <= 0: return false
	received_actions[remote] = n
	return true

func stamp_event(data: Dictionary):
	if in_game and not host() and data.get("packet category") == "lobby" and data.get("packet alias") == "member joined list" and data.get("packet_id") == 4:
		stamp_request(data)
		return
	if data.get("packet category") == "ChallengePack" or not in_game or not host(): return
	if not data.has("cp_event"):
		event_counter += 1
		data["cp_event"] = event_counter
		data["cp_session"] = session
		data["cp_revision"] = revision
		data["cp_charge"] = rules.charge
		data["cp_turn"] = rules.turn

func accept_event(data: Dictionary) -> bool:
	if data.get("cp_session") != session or data.get("cp_revision") != revision: return false
	var n = data.get("cp_event", 0)
	if typeof(n) != TYPE_INT or n <= 0 or received_events.has(n): return false
	if data.get("cp_charge", -1) < rules.charge or data.get("cp_turn", -1) < rules.turn: return false
	received_events[n] = true
	event_counter = maxi(event_counter, n)
	rules.charge = data.cp_charge
	rules.turn = data.cp_turn
	return true

func property_for(socket: int):
	if not is_instance_valid(game): return null
	for property in game.instance_handler.instance_property_array:
		if property.socket_number == socket: return property
	return null

func alive() -> Array:
	var result = []
	if is_instance_valid(game):
		for property in game.instance_handler.instance_property_array:
			if property.health_current > 0: result.append(property.socket_number)
	return result

func start_barrier(token: String):
	barrier = token
	barrier_deadline = Time.get_ticks_msec() + TIMEOUT
	barrier_acks = {GlobalSteam.STEAM_ID: true}
	send("barrier", {"token": token})
	while is_inside_tree() and not blocked:
		var complete = true
		for id in ids():
			if not barrier_acks.has(id): complete = false
		if complete: break
		await get_tree().process_frame
	barrier = ""

func snapshot() -> Dictionary:
	var health = {}
	var inventories = {}
	if is_instance_valid(game):
		for p in game.instance_handler.instance_property_array:
			health[p.socket_number] = p.health_current
			inventories[p.socket_number] = []
			for item in p.user_inventory: inventories[p.socket_number].append(item.get("item_id", 0))
	return {"charge": rules.charge, "turn": rules.turn, "players": rules.players.duplicate(true), "health": health, "inventories": inventories, "last_actor": rules.last_actor, "current": game.MAIN_active_current_turn_socket if is_instance_valid(game) else -1, "direction": game.MAIN_active_turn_order if is_instance_valid(game) else "CW", "sawed": game.MAIN_barrel_sawed_off if is_instance_valid(game) else false}

func public_digest() -> String:
	return var_to_bytes(snapshot()).hex_encode().sha256_text()

func apply_snapshot(data: Dictionary):
	if not is_instance_valid(game) or not data.get("players") is Dictionary or not data.get("health") is Dictionary: return
	rules.charge = data.charge
	rules.turn = data.turn
	rules.players = data.players.duplicate(true)
	rules.last_actor = data.last_actor
	for socket in data.health:
		var p = property_for(socket)
		if p != null:
			p.health_current = data.health[socket]
			p.health_counter.UpdateDisplay()
	game.MAIN_active_current_turn_socket = data.get("current", -1)
	game.MAIN_active_turn_order = data.get("direction", "CW")
	game.MAIN_barrel_sawed_off = data.get("sawed", false)
	for socket in data.get("inventories", {}):
		var p = property_for(socket)
		if p == null: continue
		var wanted = data.inventories[socket]
		for i in range(8):
			var existing = p.user_inventory[i].get("item_id", 0)
			if existing == wanted[i]: continue
			if is_instance_valid(p.user_inventory_instance_array[i]): p.user_inventory_instance_array[i].queue_free()
			p.user_inventory_instance_array[i] = null
			p.user_inventory[i] = {}
			game.MAIN_inventory_by_socket[socket][i] = {}
			if wanted[i] != 0:
				p.item_manager.Debug_SpawnItemSeparately(wanted[i], i)
				p.user_inventory[i] = {"item_id": wanted[i], "item_local_grid_index": i}
	recount_items()
	snapshot_deadline = 0

func apply_contracts(data: Dictionary):
	rules.players = data.players.duplicate(true)
	rules.charge = data.charge
	rules.last_actor = -1
	announce_contracts()

func register_packets(manager: Node):
	epoch += 1
	packets = manager
	manager.tree_exiting.connect(scene_exiting.bind(weakref(manager)), CONNECT_ONE_SHOT)
	game = manager.game_state
	lobby_ui = manager.lobby_ui
	in_game = is_instance_valid(game)
	loading = false
	startup_deadline = Time.get_ticks_msec() + TIMEOUT if in_game else 0
	scene_ready.clear()
	if in_game: scene_ready[GlobalSteam.STEAM_ID] = true
	if not in_game: lobby_id = 0
	blocked = false
	busy = false
	stages.clear()
	released.clear()
	received_events.clear()
	received_custom.clear()
	received_actions.clear()
	pending_shots.clear()
	applied_outcomes.clear()
	completed_actions.clear()
	hidden.clear()
	rules.reset()
	if is_instance_valid(ui): ui.queue_free()
	ui = load(port.mod_directory.path_join("multiplayer/menu.gd")).new()
	add_child(ui)
	ui.setup(self)
	print("[ChallengePack MP] packet manager connected; gameplay=", in_game)

func scene_exiting(reference: WeakRef):
	if reference.get_ref() != packets: return
	epoch += 1
	game = null
	packets = null
	lobby_ui = null
	in_game = false
	startup_deadline = 0
	loading = false
	busy = false
	if is_instance_valid(ui): ui.queue_free()
	ui = null
	stages.clear()
	released.clear()
	hidden.clear()
	pending_shots.clear()

func before_pipe(_manager: Node, data: Dictionary) -> bool:
	if data.get("packet category") == "ChallengePack": return false
	if in_game and data.get("packet category") != "MP_PacketVerification":
		if host(): stamp_event(data)
		if not accept_event(data): return false
	if data.get("packet category") == "MP_PacketVerification" and sender == 0: return false
	if data.get("packet alias") == "timeout exceeded" and data.get("timeout_type") == "jammer":
		finish_jammer_selection(data.get("socket_number", -1), not data.get("ending_turn_after_timeout", false))
	if data.has("cp_players"): rules.players = data.cp_players.duplicate(true)
	return not blocked

func stage(token: String) -> bool:
	var captured_epoch = epoch
	print("[ChallengePack MP] waiting for stage ", token, "; host=", host())
	var deadline = Time.get_ticks_msec() + TIMEOUT
	if host():
		if not stages.has(token): stages[token] = {}
		stages[token][GlobalSteam.STEAM_ID] = true
		while is_instance_valid(game) and not blocked and captured_epoch == epoch:
			# process_frame resumes before node processing after focus returns.
			# Consume queued acknowledgments before expiring a wall-clock deadline.
			drain_packets()
			if blocked or captured_epoch != epoch or not stages.has(token): return false
			var complete = true
			for id in ids():
				if not stages[token].has(id): complete = false
			if complete: break
			if Time.get_ticks_msec() > deadline:
				push_warning("[ChallengePack MP] stage timeout: %s; ready=%s; expected=%s" % [token, stages[token].keys(), ids()])
				fail(port.localization.text("CP_MP_TIMEOUT", [TIMEOUT_SECONDS]))
				return false
			await get_tree().process_frame
		send("stage_release", {"token": token})
	else:
		send("stage_ready", {"token": token, "identity": identity(), "rules": rules.settings, "vanilla": vanilla_digest()}, GlobalSteam.HOST_ID)
		var retry_at = Time.get_ticks_msec() + 500
		while not released.has(token) and not blocked and captured_epoch == epoch:
			drain_packets()
			if released.has(token): break
			if blocked or captured_epoch != epoch: return false
			if Time.get_ticks_msec() >= retry_at:
				send("stage_ready", {"token": token, "identity": identity(), "rules": rules.settings, "vanilla": vanilla_digest()}, GlobalSteam.HOST_ID)
				retry_at = Time.get_ticks_msec() + 500
			if Time.get_ticks_msec() > deadline:
				push_warning("[ChallengePack MP] stage release timed out: " + token)
				fail(port.localization.text("CP_MP_TIMEOUT", [TIMEOUT_SECONDS]))
				return false
			await get_tree().process_frame
	var complete = not blocked and is_instance_valid(game) and captured_epoch == epoch
	if complete:
		if token == "scene": startup_deadline = 0
		print("[ChallengePack MP] completed stage ", token)
	return complete

func apply_mirror(items: Array):
	if not is_instance_valid(game): return
	mirror = items.duplicate()
	mirror_offsets.clear()
	for socket in alive():
		var p = property_for(socket)
		for item in p.user_inventory_instance_array:
			if is_instance_valid(item): item.queue_free()
		p.item_manager.ClearInventory_Dictionaries()
		game.Global_ClearInventoryDictionaries(socket)
	for socket in alive():
		var p = property_for(socket)
		for i in range(mirror.size()):
			p.item_manager.Debug_SpawnItemSeparately(mirror[i], i)
			p.user_inventory[i] = {"item_id": mirror[i], "item_local_grid_index": i}
	recount_items()

func recount_items():
	game.SetupEmptyGlobalItemCount()
	for p in game.instance_handler.instance_property_array:
		p.CLearInventory_Count()
		for entry in p.user_inventory:
			if entry.is_empty(): continue
			p.user_inventory_count_by_item_id[entry.item_id] += 1
			game.global_item_count_on_table_by_id[entry.item_id] += 1

func execute_failure(data: Dictionary):
	var socket = data.get("socket", -1)
	var p = property_for(socket)
	if p == null or rules.state(socket).failed: return
	rules.state(socket).failed = true
	game.StopAllTimeouts()
	for user in game.instance_handler.instance_property_array:
		user.permissions.SetMainPermission(false)
		user.has_turn = false
	var cue = AudioStreamPlayer.new()
	cue.stream = Effects.load_pcm(port.mod_directory.path_join("assets/contracts/breach.wav"))
	add_child(cue)
	cue.play()
	await get_tree().create_timer(1.0, false).timeout
	if not is_instance_valid(p) or blocked:
		cue.queue_free()
		return
	p.shotgun.SetShotgunVisible_Global(false)
	p.shotgun.SetShotgunVisible_Local(p.is_active)
	var packet = {"shooter_socket_self": socket, "shooter_socket_target": socket, "shooter_shell": "lethal", "shooter_sequence_length_after_eject": data.get("left", 1), "shooter_socket_target_direction": "self", "barrel_sawed_off": false, "sent_from_socket": socket, "ending_turn_after_shot": true, "cp_strength": p.health_current, "cp_health": 0, "cp_penalty": true, "cp_event": -data.get("event", 1)}
	p.shotgun.ReceivePacket_Shoot(packet)
	cue.queue_free()

func presentation():
	if rules.settings.items != 1: return
	var local = null
	for p in game.instance_handler.instance_property_array:
		if p.is_active: local = p
	if local == null: return
	if not local.is_stealing_item: theft_target = -1
	if busy and local.is_stealing_item: busy = false
	for p in game.instance_handler.instance_property_array:
		if p == local:
			for item in p.user_inventory_instance_array:
				if is_instance_valid(item) and hidden.has(item.get_instance_id()):
					item.visible = hidden[item.get_instance_id()]
					hidden.erase(item.get_instance_id())
			continue
		var reveal = local.is_stealing_item and p.socket_number == theft_target
		for item in p.user_inventory_instance_array:
			if is_instance_valid(item):
				if not hidden.has(item.get_instance_id()): hidden[item.get_instance_id()] = item.visible
				item.visible = hidden[item.get_instance_id()] if reveal else false
				if item.get_child_count() > 1 and local.is_stealing_item:
					item.get_child(1).interactionAllowed = reveal and local.has_turn
	for p in game.instance_handler.instance_property_array:
		var held = p.item_interaction.active_item_parent
		if is_instance_valid(held): held.visible = true

func generate_sequence(_round_manager: Node):
	if not host(): return
	var sequence = rules.sequences(game.MAIN_active_sequence_dict.sequence)
	game.MAIN_active_sequence_dict.sequence_visible = sequence.visible
	game.MAIN_active_sequence_dict.sequence_in_shotgun = sequence.loaded
	game.MAIN_active_sequence_dict_send = game.MAIN_active_sequence_dict.duplicate(true)
	game.MAIN_active_sequence_dict_send.erase("sequence_in_shotgun")
	if rules.settings.shells == 2:
		game.MAIN_active_sequence_dict_send.sequence = []
		game.MAIN_active_sequence_dict_send.sequence_visible = []
	elif rules.settings.shells == 1:
		game.MAIN_active_sequence_dict_send.sequence = []
		game.MAIN_active_sequence_dict_send.sequence_visible = []
		for _i in sequence.visible.size(): game.MAIN_active_sequence_dict_send.sequence_visible.append("unknown")
	var has_items = false
	for p in game.instance_handler.instance_property_array:
		for item in p.user_inventory:
			if not item.is_empty(): has_items = true
	rules.begin_charge(alive(), has_items)
	var fixed_socket = -1
	var host_socket = -1
	for p in game.instance_handler.instance_property_array:
		if p.user_id == GlobalSteam.HOST_ID: host_socket = p.socket_number
		if p.user_id == rules.settings.first_player: fixed_socket = p.socket_number
	if fixed_socket == -1: fixed_socket = host_socket
	game.MAIN_active_first_turn_socket = rules.starter(alive(), host_socket, game.MAIN_active_turn_order, game.MAIN_active_first_turn_socket, fixed_socket)
	send("contracts", {"players": rules.players, "charge": rules.charge})
	announce_contracts()

func announce_contracts():
	var any = false
	for s in rules.players:
		if rules.players[s].contract != 0: any = true
	if any:
		var sound = AudioStreamPlayer.new()
		sound.stream = Effects.load_pcm(port.mod_directory.path_join("assets/contracts/armed.wav"))
		add_child(sound)
		sound.finished.connect(sound.queue_free)
		sound.play()

func on_turn(socket: int):
	rules.begin_turn(socket)
	busy = false

func prepare_mirror(_round_manager: Node) -> Array:
	if host():
		var resources = []
		var retained = {}
		for p in game.instance_handler.instance_property_array:
			if p.health_current != 0: continue
			for item in p.user_inventory:
				if not item.is_empty(): retained[item.item_id] = retained.get(item.item_id, 0) + 1
		for r in game.MAIN_item_resource_array:
			resources.append({"id": r.id, "enabled": r.distribution_enabled, "per_player": r.max_amount_on_table, "global_max": r.max_amount_on_table_global - retained.get(r.id, 0)})
		var items = rules.mirror_pool(resources, alive().size(), game.MAIN_active_num_of_items_to_grab)
		send("mirror", {"items": items})
		apply_mirror(items)
	return []

func mirror_item(_property: Node, _incrementing: bool):
	return null

func verify(_verifier: Node, data: Dictionary) -> Dictionary:
	if blocked or not data.has("packet_id") or not data.has("sent_from_socket"): return {}
	if data.get("packet alias") != REQUESTS.get(data.packet_id, ""): return {}
	var p = property_for(data.sent_from_socket)
	if p == null or p.user_id != sender or p.health_current <= 0: return {}
	var active = game.MAIN_active_current_turn_socket == p.socket_number and p.has_turn
	match data.packet_id:
		10:
			if not active or busy or p.is_holding_shotgun: return {}
		12:
			var target = property_for(data.get("socket_to_shoot", -1))
			if not active or busy or not p.is_holding_shotgun or target == null or target.health_current <= 0: return {}
			if game.MAIN_active_sequence_dict.get("sequence_in_shotgun", []).is_empty(): return {}
			if rules.state(p.socket_number).contract == Rules.Catalog.Contract.NO_SELF_SHOTS and target == p:
				punish(p.socket_number)
				return {}
		15:
			if not active or not p.is_holding_shotgun: return {}
			if not data.get("direction_to_look") in ["self", "forward", "left", "right"]: return {}
		17:
			if busy or not p.is_grabbing_items or p.is_holding_item_to_place: return {}
		19:
			var grid = data.get("local_grid_index", -1)
			if not p.is_grabbing_items or not p.is_holding_item_to_place or typeof(grid) != TYPE_INT or grid < 0 or grid > 7 or not p.user_inventory[grid].is_empty(): return {}
		22:
			if not active or (busy and not p.is_stealing_item): return {}
			var socket = data.get("item_socket_number", -1)
			var grid = data.get("local_grid_index", -1)
			if typeof(grid) != TYPE_INT or grid < 0 or grid > 7 or property_for(socket) == null: return {}
			var entry = game.MAIN_inventory_by_socket[socket][grid]
			if entry.is_empty() or entry.item_id != data.get("item_id"): return {}
			var stolen = data.get("stealing_item", false)
			if typeof(stolen) != TYPE_BOOL: return {}
			if stolen:
				if not p.is_stealing_item or socket == p.socket_number: return {}
			elif socket != p.socket_number: return {}
			var result = rules.item_result(p.socket_number, entry.item_id, stolen)
			if result == "contract":
				punish(p.socket_number)
				return {}
			if result != "ok":
				send("reject", {"socket": p.socket_number}, p.user_id)
				restore_permissions(p.socket_number)
				return {}
		24:
			var target = property_for(data.get("item_selected_socket_number", -1))
			if not active or not p.is_viewing_jammer or data.get("item_id") != 3: return {}
			if target == null or target == p or target.health_current <= 0 or target.is_jammed:
				# The UI locks while confirmation travels to the host. Return the
				# consumed jammer through the regular synchronized exit animation.
				broadcast_native({"packet category": "MP_UserInstanceProperties", "packet alias": "secondary item interaction", "sent_from": "host", "packet_id": 25, "socket_number": p.socket_number, "item_id": 3, "has_exit_animation": true, "item_selected_socket_number": -1, "item_selected_local_grid_index": 0, "ending_turn_after_item_use": false})
				return {}
			data["has_exit_animation"] = true
			data["item_selected_local_grid_index"] = 0
		_:
			return {}
	return data.duplicate(true)

func restore_permissions(socket: int):
	var p = property_for(socket)
	if p != null and p.is_active:
		p.permissions.SetMainPermission(true)
		p.SetTurnControllerPrompts(true)
	notice("CP_POCKET_EXHAUSTED")

func broadcast_native(data: Dictionary):
	packets.send_p2p_packet(0, data)
	packets.PipeData(data)

func resolve_shot(_verifier: Node, data: Dictionary):
	var socket = data.sent_from_socket
	game.StopTimeoutForSocket("turn", socket)
	var actual = rules.target(socket, data.socket_to_shoot, alive())
	var p = property_for(actual)
	var shell = game.MAIN_active_sequence_dict.sequence_in_shotgun[0]
	var effect = rules.shot_effect(socket, actual, shell, game.MAIN_barrel_sawed_off, p.health_current, p.health_on_round_start)
	var strength = effect.strength
	var hp = effect.health
	var left = game.MAIN_active_sequence_dict.sequence_in_shotgun.size() - 1
	var ending = not effect.keep_turn or left == 0 or property_for(socket).user_id in game.MAIN_active_user_id_exceeded_secondary_timeout_array
	busy = true
	broadcast_native({"packet category": "MP_UserInstanceProperties", "packet alias": "shoot user", "sent_from": "host", "packet_id": 13, "shooter_socket_self": socket, "shooter_socket_target": actual, "shooter_shell": shell, "shooter_sequence_length_after_eject": left, "shooter_socket_target_direction": game.round_manager.GetDirection(socket, actual), "barrel_sawed_off": game.MAIN_barrel_sawed_off, "sent_from_socket": socket, "ending_turn_after_shot": ending, "cp_selected_target": data.socket_to_shoot, "cp_strength": strength, "cp_health": hp})

func resolve_item(_verifier: Node, data: Dictionary):
	var socket = data.sent_from_socket
	var p = property_for(socket)
	rules.accept_item(socket, data.item_id, data.stealing_item)
	busy = true
	var packet = {"packet category": "MP_UserInstanceProperties", "packet alias": "interact with item", "sent_from": "host", "packet_id": 23, "item_socket_number": data.item_socket_number, "local_grid_index": data.local_grid_index, "item_id": data.item_id, "socket_number": socket, "stealing_item": data.stealing_item, "ending_turn_after_item_use": game.CheckIfEndingTurnAfterItemUse(data.item_id, socket), "cp_health": mini(p.health_current + 1, p.health_on_round_start) if data.item_id == 4 else p.health_current, "current_shell_in_chamber": "unknown", "phone_verbal_shell": "", "phone_verbal_index": "", "cp_players": rules.players.duplicate(true)}
	var private_packet = packet.duplicate(true)
	if data.item_id in [2, 5, 9]: private_packet.current_shell_in_chamber = game.MAIN_active_sequence_dict.sequence_in_shotgun[0]
	if data.item_id == 5: packet.current_shell_in_chamber = private_packet.current_shell_in_chamber
	if data.item_id == 6:
		private_packet.phone_verbal_index = game.GetBurnerPhone_VerbalIndex()
		private_packet.phone_verbal_shell = game._GetBurnerPhone_Shell(private_packet.phone_verbal_index)
	stamp_event(packet)
	for key in ["cp_event", "cp_session", "cp_revision", "cp_charge", "cp_turn"]: private_packet[key] = packet[key]
	for id in ids():
		if id != GlobalSteam.STEAM_ID: packets.send_p2p_packet(id, private_packet if id == p.user_id else packet)
	packets.PipeData(private_packet)

func apply_heal(shoot: Node):
	var packet = pending_shots[shoot.properties.socket_number]
	var target = property_for(packet.shooter_socket_target)
	if target == null: return
	target.health_counter.healing_health = packet.cp_health > target.health_current
	target.health_current = packet.cp_health
	target.health_counter.UpdateDisplay()

func claim_outcome(shoot: Node) -> bool:
	var socket = shoot.properties.socket_number
	var packet = pending_shots.get(socket, {})
	if packet.get("shooter_socket_self", -1) != socket: return false
	var token = "%s:%s:%s" % [rules.charge, socket, packet.get("cp_event", 0)]
	if applied_outcomes.has(token): return false
	applied_outcomes[token] = true
	return true



func punish(socket: int):
	if rules.state(socket).failed or busy: return
	busy = true
	var data = {"socket": socket, "left": game.MAIN_active_sequence_dict.sequence_in_shotgun.size(), "event": event_counter + 1}
	send("failure", data)
	execute_failure(data)

func shell_material(branch: Node, type: String, examining: bool):
	var mat = branch.mat_blank_default.duplicate()
	# Multiplying the live shell's red/black texture by green makes its hull
	# almost black, particularly on the ejected shell. Tint the hull directly.
	mat.albedo_texture = null
	mat.albedo_color = Color("299940") if type == "heal" else Color("111117")
	if GlobalVariables.colorblind:
		mat.albedo_color = Color("f4d35e") if type == "heal" else Color("432172")
		mat.emission_enabled = type == "heal"
		mat.emission = Color("715000")
	if examining: mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	branch.shell.set_surface_override_material(1, mat)

func continue_turn(socket: int, after_shot: bool = false):
	var p = property_for(socket)
	if p == null or p.health_current <= 0: return
	p.has_turn = true
	p.is_interacting_with_item = false
	p.is_on_secondary_interaction = false
	if after_shot: game.BeginTimeoutForSocket("turn", game.MAIN_timeout_duration_turn, socket)
	if p.is_active:
		p.FreeLookCameraForUser_Enable()
		p.permissions.SetMainPermission(true)
		p.SetTurnControllerPrompts(true)
		GlobalVariables.cursor_state_after_toggle = true
		p.cursor.SetCursor(true, true)

func finish_jammer_selection(socket: int, resume: bool):
	var p = property_for(socket)
	if p == null: return
	p.is_viewing_jammer = false
	p.is_on_jammer_selection = false
	p.is_on_secondary_interaction = false
	p.is_interacting_with_item = false
	p.jammer_manager.looping = false
	if p.is_active: p.jammer_manager.SetJammerControllerPrompts(false)
	if resume and game.MAIN_active_current_turn_socket == socket and p.health_current > 0:
		p.has_turn = true
	busy = false
	print("[ChallengePack MP] jammer selection finished; socket=", socket, "; resume=", resume)

func health_visibility(counter: Node):
	var concealed = rules.settings.health == 1
	# Hide stable HP parents, so EnableDisplay and jammer flicker cannot reveal
	# individual charges. The round indicator belongs to a separate branch.
	for charges in [counter.ui_charge_array, counter.ui_charge_array_temp, counter.ui_charge_array_side_left, counter.ui_charge_array_side_right]:
		if charges.is_empty(): continue
		var group = charges[0].get_parent()
		if concealed:
			if not group.has_meta("cp_health_visible"): group.set_meta("cp_health_visible", group.visible)
			group.hide()
		elif group.has_meta("cp_health_visible"):
			group.visible = group.get_meta("cp_health_visible")
			group.remove_meta("cp_health_visible")
	if concealed and counter.properties.health_current > 0 and not counter.ui_parent_winner.visible:
		var round_index = game.MAIN_active_round_index
		if round_index >= 0 and not counter.pos_array_rounds.is_empty():
			counter.ui_round_indicator_selector.position = counter.pos_array_rounds[mini(round_index, counter.pos_array_rounds.size() - 1)].position
			counter.ui_round_indicator_base.show()
			counter.ui_round_indicator_selector.show()

func finish_shot(shoot: Node, packet: Dictionary):
	var token = "shot-%s" % packet.get("cp_event", 0)
	if completed_actions.has(token): return
	completed_actions[token] = true
	var captured_epoch = epoch
	if not await stage(token): return
	if captured_epoch != epoch or not is_instance_valid(shoot): return
	if packet.get("cp_penalty", false): notice("CP_MP_CONTRACT_FAILED", [shoot.properties.user_name])
	busy = false
	if not host(): return
	var socket = packet.shooter_socket_self
	var winner = shoot.CheckIfUserHasWon()
	flush_snapshots()
	send("digest", {"digest": public_digest()})
	if winner != -1 or packet.ending_turn_after_shot:
		var hand_over = not (packet.shooter_socket_target == socket and packet.shooter_shell in ["blank", "heal"])
		var empty = not packet.get("cp_penalty", false) and packet.shooter_sequence_length_after_eject == 0
		game.round_manager.UserEndTurn_Packet(socket, hand_over, empty, winner)
	else:
		send("continue", {"socket": socket, "shot": true})
		continue_turn(socket, true)

func finish_item(interaction: Node, packet: Dictionary):
	var token = "item-%s" % packet.get("cp_event", 0)
	if completed_actions.has(token): return
	completed_actions[token] = true
	var captured_epoch = epoch
	if not await stage(token): return
	if captured_epoch != epoch or not is_instance_valid(interaction): return
	var p = interaction.properties
	p.is_interacting_with_item = false
	if packet.item_id == 3: finish_jammer_selection(p.socket_number, not packet.ending_turn_after_item_use)
	busy = false
	if not host(): return
	flush_snapshots()
	send("digest", {"digest": public_digest()})
	if packet.ending_turn_after_item_use:
		game.round_manager.UserEndTurn_Packet(p.socket_number, true, game.MAIN_active_sequence_dict.sequence_in_shotgun.is_empty(), -1)
	else:
		send("continue", {"socket": p.socket_number})
		continue_turn(p.socket_number)

func flush_snapshots():
	for id in resync_requests:
		if id in ids(): send("snapshot", snapshot(), id)
	resync_requests.clear()

