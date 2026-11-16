extends Node

const Rules = preload("rules.gd")
const Settings = preload("settings.gd")
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
var last_tick = 0
var snapshot_deadline = 0
var in_game = false
var epoch = 0
var resync_requests = []
var stages = {}
var released = {}
var stock_digest = ""
var expected_stock_digest = ""
var startup_deadline = 0
var draining_packets = false

var gameplay = preload("gameplay.gd").new(self)
var receipt_charge = -1

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
	if in_game and is_instance_valid(game):
		gameplay.advance_interaction()
		gameplay.presentation()
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
			"snapshot_request":
				if not remote in resync_requests: resync_requests.append(remote)
				if not gameplay.busy: flush_snapshots()
		if alias in ["ready", "settings_ack"]: send("peers", {"peers": peers})
	elif remote == GlobalSteam.HOST_ID:
		match alias:
			"peers": peers = body.get("peers", {}).duplicate(true)
			"snapshot": apply_snapshot(body)
			"stage_release": released[body.get("token", "")] = true
			"continue": gameplay.continue_turn(body.get("socket", -1), body.get("shot", false))
			"reject": gameplay.restore_permissions(body.get("socket", -1))
			"failure": gameplay.execute_failure(body)
			"contracts": gameplay.apply_contracts(body)
			"mirror": gameplay.apply_mirror(body.get("items", []))
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
	if typeof(n) != TYPE_INT or n <= 0: return false
	if data.get("cp_charge", -1) < rules.charge or data.get("cp_turn", -1) < rules.turn: return false
	if receipt_charge != data.cp_charge:
		receipt_charge = data.cp_charge
		received_events.clear()
		gameplay.completed_actions.clear()
		gameplay.applied_outcomes.clear()
	if received_events.has(n): return false
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
	if not is_instance_valid(game) or not Rules.snapshot_shape(data): return
	var roster = {}
	for player in game.instance_handler.instance_property_array:
		roster[player.socket_number] = player.health_on_round_start
	if not Rules.valid_snapshot(data, roster): return
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
	gameplay.recount_items()
	snapshot_deadline = 0

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
	gameplay.busy = false
	stages.clear()
	released.clear()
	received_events.clear()
	received_custom.clear()
	received_actions.clear()
	gameplay.pending_shots.clear()
	gameplay.applied_outcomes.clear()
	gameplay.completed_actions.clear()
	gameplay.hidden.clear()
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
	gameplay.busy = false
	if is_instance_valid(ui): ui.queue_free()
	ui = null
	stages.clear()
	released.clear()
	gameplay.hidden.clear()
	gameplay.pending_shots.clear()

func before_pipe(_manager: Node, data: Dictionary) -> bool:
	if data.get("packet category") == "ChallengePack": return false
	if in_game and data.get("packet category") != "MP_PacketVerification":
		if host(): stamp_event(data)
		if not accept_event(data): return false
	if data.get("packet category") == "MP_PacketVerification" and sender == 0: return false
	if data.get("packet alias") == "timeout exceeded" and data.get("timeout_type") == "jammer":
		gameplay.finish_jammer_selection(data.get("socket_number", -1), not data.get("ending_turn_after_timeout", false))
	if data.has("cp_players"): rules.players = data.cp_players.duplicate(true)
	return not blocked

func stage(token: String) -> bool:
	var generation = epoch
	var charge = rules.charge
	print("[ChallengePack MP] waiting for stage ", token, "; host=", host())
	var deadline = Time.get_ticks_msec() + TIMEOUT
	if host():
		if not stages.has(token): stages[token] = {}
		stages[token][GlobalSteam.STEAM_ID] = true
		while is_instance_valid(game) and not blocked and current(generation, charge):
			# process_frame resumes before node processing after focus returns.
			# Consume queued acknowledgments before expiring a wall-clock deadline.
			drain_packets()
			if blocked or not current(generation, charge) or not stages.has(token): return false
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
		while not released.has(token) and not blocked and current(generation, charge):
			drain_packets()
			if released.has(token): break
			if blocked or not current(generation, charge): return false
			if Time.get_ticks_msec() >= retry_at:
				send("stage_ready", {"token": token, "identity": identity(), "rules": rules.settings, "vanilla": vanilla_digest()}, GlobalSteam.HOST_ID)
				retry_at = Time.get_ticks_msec() + 500
			if Time.get_ticks_msec() > deadline:
				push_warning("[ChallengePack MP] stage release timed out: " + token)
				fail(port.localization.text("CP_MP_TIMEOUT", [TIMEOUT_SECONDS]))
				return false
			await get_tree().process_frame
	var complete = not blocked and is_instance_valid(game) and current(generation, charge)
	if complete:
		if token == "scene": startup_deadline = 0
		print("[ChallengePack MP] completed stage ", token)
	return complete

func flush_snapshots():
	for id in resync_requests:
		if id in ids(): send("snapshot", snapshot(), id)
	resync_requests.clear()

func current(generation: int, charge: int) -> bool:
	return epoch == generation and rules.charge == charge and not blocked

func preferences() -> Dictionary:
	return rules.settings.duplicate(true)

func commit_preferences(values: Dictionary) -> Error:
	if GlobalSteam.LOBBY_ID <= 0 or not GlobalSteam.STEAM_ID in ids() or not host() or in_game or loading or not Rules.validate(values): return ERR_UNAUTHORIZED
	change_settings(values)
	return OK

