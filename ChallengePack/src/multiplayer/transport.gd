extends RefCounted

# Explicit session dependency; native adapters keep their stable facade.
var owner: Node

func _init(session: Node):
	owner = session

func identity() -> Dictionary:
	return {"mod": owner.port.VERSION, "protocol": owner.PROTOCOL, "game": "2.2.0.6", "fingerprint": owner.fingerprint}

func message(alias: String, payload: Dictionary = {}) -> Dictionary:
	owner.custom_counter += 1
	return {"packet category": "ChallengePack", "packet alias": alias, "cp_protocol": owner.PROTOCOL, "session": owner.session, "revision": owner.revision, "charge": owner.rules.charge, "turn": owner.rules.turn, "phase": "game" if owner.in_game else "lobby", "cp_message": owner.custom_counter, "data": payload}

func send(alias: String, payload: Dictionary = {}, target: int = 0):
	if is_instance_valid(owner.packets): owner.packets.send_p2p_packet(target, owner.message(alias, payload))

func drain_packets():
	if owner.draining_packets or not is_instance_valid(owner.packets) or GlobalSteam.LOBBY_ID == 0: return
	if Steam.getAvailableP2PPacketSize(0) == 0: return
	owner.draining_packets = true
	owner.packets.read_all_p2p_packets()
	owner.draining_packets = false

func receive_native(manager: Node, data: Dictionary, remote: int):
	if not remote in owner.ids(): return
	var category = data.get("packet category", "")
	if category == "ChallengePack":
		owner.receive(data, remote)
		return
	if category == "MP_PacketVerification":
		if not owner.host(): return
		if not owner.valid_action(data, remote): return
	elif remote != GlobalSteam.HOST_ID:
		if category == "lobby" and data.get("packet alias") == "member joined list":
			if not owner.accept_scene_arrival(manager, data, remote): return
		else:
			# Only vanilla version negotiation is accepted from an unverified guest.
			if category != "MP_LobbyManager" or data.get("packet alias") != "check version" or data.get("packet_id") != 32 or not data.get("version") is String: return
	# Several original dispatchers depend on Dictionary insertion order. Never
	# let a request route through its unrelated first/second arbitrary fields.
	# The stock member-list update misspells its alias field.
	var canonical = {"packet category": category, "packet alias": data.get("packet alias", data.get("packat alias", "")), "sent_from": "host" if remote == GlobalSteam.HOST_ID else "client", "packet_id": data.get("packet_id", 0)}
	for key in data:
		if not canonical.has(key): canonical[key] = data[key]
	owner.sender = remote
	manager.temp_id = remote
	manager.PipeData(canonical)
	owner.sender = 0

func accept_scene_arrival(manager: Node, data: Dictionary, remote: int) -> bool:
	if not owner.host() or not owner.in_game or owner.blocked or owner.session.is_empty(): return false
	if not owner.peers.get(remote, {}).get("verified", false): return false
	if data.get("packet_id") != 4 or data.get("steam_id") != remote: return false
	if data.get("cp_session") != owner.session or data.get("cp_revision") != owner.revision: return false
	if data.get("cp_charge") != 0 or data.get("cp_turn") != 0: return false
	var checker = manager.memberChecker
	if not is_instance_valid(checker) or not checker.checking or checker.fs: return false
	if remote in checker.membersHere_list: return false
	owner.scene_ready[remote] = true
	print("[ChallengePack MP] accepted scene arrival from ", remote)
	return true

func receive(data: Dictionary, remote: int):
	if data.get("cp_protocol") != owner.PROTOCOL or not data.get("data") is Dictionary: return
	if data.get("phase") != ("game" if owner.in_game else "lobby"): return
	var number = data.get("cp_message", 0)
	if typeof(number) != TYPE_INT or number <= 0: return
	var receipt = "%s:%s:%s" % [data.get("session", ""), remote, number]
	if owner.received_custom.has(receipt): return
	owner.received_custom[receipt] = true
	var alias = data.get("packet alias", "")
	var body: Dictionary = data.data
	if alias == "hello":
		if owner.in_game: return
		if body != owner.identity():
			if owner.host(): owner.reject_peer(remote)
			else: owner.fail(owner.port.localization.text("CP_MP_MISMATCH"))
			return
		if not owner.host() and remote != GlobalSteam.HOST_ID: return
		if not owner.peers.has(remote): owner.peers[remote] = {"verified": false, "ready": false, "deadline": Time.get_ticks_msec() + owner.TIMEOUT}
		owner.peers[remote].verified = true
		if owner.host(): owner.send_settings(remote)
		else: owner.send("hello_ack", owner.identity(), remote)
		return
	if alias == "hello_ack" and owner.host() and body == owner.identity():
		if owner.peers.has(remote): owner.peers[remote].verified = true
		owner.send_settings(remote)
		return
	if alias == "settings" and not owner.host() and remote == GlobalSteam.HOST_ID:
		if body.get("identity") != owner.identity() or not owner.Rules.validate(body.get("rules")): return
		if owner.in_game: return
		owner.session = data.session
		owner.revision = data.revision
		owner.rules.settings = body.rules.duplicate(true)
		owner.expected_stock_digest = body.get("vanilla", "")
		owner.peers[GlobalSteam.STEAM_ID] = {"verified": true, "ready": false, "deadline": 0}
		owner.peers[remote] = {"verified": true, "ready": false, "deadline": Time.get_ticks_msec() + owner.TIMEOUT}
		owner.send("settings_ack", {}, remote)
		return
	if data.get("session") != owner.session or data.get("revision") != owner.revision: return
	if owner.in_game and alias in ["failure", "continue", "digest", "snapshot", "mirror", "contracts"]:
		if data.get("charge", -1) < owner.rules.charge or data.get("turn", -1) < owner.rules.turn: return
	if owner.host():
		if not owner.peers.has(remote) or not owner.peers[remote].verified: return
		match alias:
			"settings_ack": owner.peers[remote].ready = false
			"ready": owner.peers[remote].ready = body.get("ready", false) == true and body.get("vanilla") == owner.vanilla_digest()
			"scene_ready": owner.scene_ready[remote] = true
			"stage_ready":
				if body.get("identity") != owner.identity() or body.get("rules") != owner.rules.settings or body.get("vanilla") != owner.vanilla_digest(): return
				var token = body.get("token", "")
				if not owner.stages.has(token): owner.stages[token] = {}
				owner.stages[token][remote] = true
			"barrier_ack":
				if body.get("token") == owner.barrier: owner.barrier_acks[remote] = true
			"snapshot_request":
				if not remote in owner.resync_requests: owner.resync_requests.append(remote)
				if not owner.busy: owner.flush_snapshots()
		if alias in ["ready", "settings_ack"]: owner.send("peers", {"peers": owner.peers})
	elif remote == GlobalSteam.HOST_ID:
		match alias:
			"peers": owner.peers = body.get("peers", {}).duplicate(true)
			"barrier":
				owner.barrier = body.get("token", "")
				owner.send("barrier_ack", {"token": owner.barrier}, remote)
			"snapshot": owner.apply_snapshot(body)
			"stage_release": owner.released[body.get("token", "")] = true
			"continue": owner.continue_turn(body.get("socket", -1), body.get("shot", false))
			"reject": owner.restore_permissions(body.get("socket", -1))
			"failure": owner.execute_failure(body)
			"contracts": owner.apply_contracts(body)
			"mirror": owner.apply_mirror(body.get("items", []))
			"digest":
				if body.get("digest") != owner.public_digest():
					owner.snapshot_deadline = Time.get_ticks_msec() + owner.TIMEOUT
					for p in owner.game.instance_handler.instance_property_array:
						if p.is_active: p.permissions.SetMainPermission(false)
					owner.send("snapshot_request", {}, remote)

func stamp_request(data: Dictionary) -> Dictionary:
	owner.request_counter += 1
	data["cp_action"] = owner.request_counter
	data["cp_session"] = owner.session
	data["cp_revision"] = owner.revision
	data["cp_charge"] = owner.rules.charge
	data["cp_turn"] = owner.rules.turn
	return data

func direct_request(manager: Node, data: Dictionary):
	owner.stamp_request(data)
	if owner.host(): owner.receive_native(manager, data, GlobalSteam.STEAM_ID)
	else: manager.send_p2p_packet(GlobalSteam.HOST_ID, data)

func valid_action(data: Dictionary, remote: int) -> bool:
	if owner.blocked or owner.snapshot_deadline > 0: return false
	if typeof(data.get("packet_id")) != TYPE_INT or data.get("packet alias") != owner.REQUESTS.get(data.get("packet_id"), ""): return false
	if data.get("cp_session") != owner.session or data.get("cp_revision") != owner.revision or data.get("cp_charge") != owner.rules.charge or data.get("cp_turn") != owner.rules.turn: return false
	var n = data.get("cp_action", 0)
	if typeof(n) != TYPE_INT or n <= owner.received_actions.get(remote, 0): return false
	var socket = data.get("sent_from_socket", -1)
	var property = owner.property_for(socket)
	if property == null or property.user_id != remote or property.health_current <= 0: return false
	owner.received_actions[remote] = n
	return true

func stamp_event(data: Dictionary):
	if owner.in_game and not owner.host() and data.get("packet category") == "lobby" and data.get("packet alias") == "member joined list" and data.get("packet_id") == 4:
		owner.stamp_request(data)
		return
	if data.get("packet category") == "ChallengePack" or not owner.in_game or not owner.host(): return
	if not data.has("cp_event"):
		owner.event_counter += 1
		data["cp_event"] = owner.event_counter
		data["cp_session"] = owner.session
		data["cp_revision"] = owner.revision
		data["cp_charge"] = owner.rules.charge
		data["cp_turn"] = owner.rules.turn

func accept_event(data: Dictionary) -> bool:
	if data.get("cp_session") != owner.session or data.get("cp_revision") != owner.revision: return false
	var n = data.get("cp_event", 0)
	if typeof(n) != TYPE_INT or n <= 0 or owner.received_events.has(n): return false
	if data.get("cp_charge", -1) < owner.rules.charge or data.get("cp_turn", -1) < owner.rules.turn: return false
	owner.received_events[n] = true
	owner.event_counter = maxi(owner.event_counter, n)
	owner.rules.charge = data.cp_charge
	owner.rules.turn = data.cp_turn
	return true

func before_pipe(_manager: Node, data: Dictionary) -> bool:
	if data.get("packet category") == "ChallengePack": return false
	if owner.in_game and data.get("packet category") != "MP_PacketVerification":
		if owner.host(): owner.stamp_event(data)
		if not owner.accept_event(data): return false
	if data.get("packet category") == "MP_PacketVerification" and owner.sender == 0: return false
	if data.get("packet alias") == "timeout exceeded" and data.get("timeout_type") == "jammer":
		owner.finish_jammer_selection(data.get("socket_number", -1), not data.get("ending_turn_after_timeout", false))
	if data.has("cp_players"): owner.rules.players = data.cp_players.duplicate(true)
	return not owner.blocked

