extends RefCounted

# Explicit session dependency; native adapters keep their stable facade.
var owner: Node

func _init(session: Node):
	owner = session

func host() -> bool:
	return GlobalSteam.STEAM_ID == GlobalSteam.HOST_ID

func ids() -> Array:
	var result = []
	for member in GlobalSteam.LOBBY_MEMBERS: result.append(member.steam_id)
	result.sort()
	return result

func _process(_delta):
	if not owner.compatible or not is_instance_valid(owner.packets): return
	owner.drain_packets()
	if not is_instance_valid(owner.packets): return
	if owner.in_game and is_instance_valid(owner.game): owner.presentation()
	var now = Time.get_ticks_msec()
	if owner.in_game and owner.startup_deadline > 0 and now > owner.startup_deadline:
		owner.startup_deadline = 0
		push_warning("[ChallengePack MP] scene startup timed out; arrived=%s; expected=%s; stages=%s" % [owner.scene_ready.keys(), owner.ids(), owner.stages])
		owner.fail(owner.port.localization.text("CP_MP_TIMEOUT", [owner.TIMEOUT_SECONDS]))
		return
	if now - owner.last_tick < 200: return
	owner.last_tick = now
	if GlobalSteam.LOBBY_ID == 0:
		owner.lobby_id = 0
		if is_instance_valid(owner.ui): owner.ui.refresh()
		return
	var current = owner.ids()
	var changed = current != owner.members or owner.lobby_owner != GlobalSteam.HOST_ID or owner.lobby_id != GlobalSteam.LOBBY_ID
	if changed and owner.in_game:
		if owner.lobby_owner != 0 and owner.lobby_owner != GlobalSteam.HOST_ID:
			owner.fail(owner.port.localization.text("CP_MP_HOST_LEFT"))
			return
		for id in current:
			if not id in owner.members and owner.host(): owner.packets.lobby.KickPlayerInLobby(id)
		owner.members = current
		changed = false
		if current.size() < 2:
			owner.fail(owner.port.localization.text("CP_MP_NOT_ENOUGH"))
			return
	if changed:
		if owner.in_game and owner.lobby_owner != 0 and owner.lobby_owner != GlobalSteam.HOST_ID:
			owner.fail(owner.port.localization.text("CP_MP_HOST_LEFT"))
			return
		owner.members = current
		owner.lobby_owner = GlobalSteam.HOST_ID
		owner.lobby_id = GlobalSteam.LOBBY_ID
		owner.blocked = false
		owner.peers.clear()
		if owner.host():
			owner.session = "%s-%s" % [GlobalSteam.STEAM_ID, Time.get_ticks_usec()]
			owner.revision += 1
			Steam.setLobbyData(owner.lobby_id, "challengepack", owner.port.VERSION)
			Steam.setLobbyData(owner.lobby_id, "cp_protocol", str(owner.PROTOCOL))
			Steam.setLobbyData(owner.lobby_id, "cp_fingerprint", owner.fingerprint)
			owner.peers[GlobalSteam.STEAM_ID] = {"verified": true, "ready": false, "deadline": now + owner.TIMEOUT}
		for id in owner.members:
			if id != GlobalSteam.STEAM_ID: owner.peers[id] = {"verified": false, "ready": false, "deadline": now + owner.TIMEOUT}
		if not owner.host(): owner.send("hello", owner.identity(), GlobalSteam.HOST_ID)
	if owner.host():
		if not owner.in_game and owner.stock_digest != owner.vanilla_digest():
			owner.stock_digest = owner.vanilla_digest()
			owner.change_settings(owner.rules.settings)
		for id in owner.peers.keys():
			if id != GlobalSteam.STEAM_ID and not owner.peers[id].verified:
				if now > owner.peers[id].deadline:
					owner.packets.lobby.KickPlayerInLobby(id)
					owner.peers[id].deadline = now + owner.TIMEOUT
				else: owner.send("hello", owner.identity(), id)
		if not owner.barrier.is_empty() and now > owner.barrier_deadline:
			owner.fail(owner.port.localization.text("CP_MP_TIMEOUT", [owner.TIMEOUT_SECONDS]))
	elif owner.snapshot_deadline > 0 and now > owner.snapshot_deadline:
		owner.fail(owner.port.localization.text("CP_MP_TIMEOUT", [owner.TIMEOUT_SECONDS]))
	if not owner.host() and owner.peers.has(GlobalSteam.HOST_ID) and not owner.peers[GlobalSteam.HOST_ID].verified and now > owner.peers[GlobalSteam.HOST_ID].deadline:
		owner.fail(owner.port.localization.text("CP_MP_MISMATCH"))
	if is_instance_valid(owner.ui): owner.ui.refresh()

func change_settings(values: Dictionary):
	if not owner.host() or owner.in_game or not owner.Rules.validate(values): return
	owner.rules.settings = values.duplicate(true)
	owner.settings.values = values.duplicate(true)
	owner.settings.save_settings()
	owner.revision += 1
	for id in owner.peers: owner.peers[id].ready = false
	owner.send_settings()

func ready_toggle():
	if not owner.host() and owner.expected_stock_digest != owner.vanilla_digest():
		owner.notice("CP_MP_NOT_READY")
		return
	var me = GlobalSteam.STEAM_ID
	if not owner.peers.has(me): owner.peers[me] = {"verified": true, "ready": false, "deadline": 0}
	owner.peers[me].ready = not owner.peers[me].ready
	if owner.host(): owner.send("peers", {"peers": owner.peers})
	else: owner.send("ready", {"ready": owner.peers[me].ready, "vanilla": owner.vanilla_digest()}, GlobalSteam.HOST_ID)

func vanilla_digest() -> String:
	return var_to_bytes(GlobalVariables.active_match_customization_dictionary).hex_encode().sha256_text()

func send_settings(target: int = 0):
	owner.send("settings", {"identity": owner.identity(), "rules": owner.rules.settings, "members": owner.members, "vanilla": owner.vanilla_digest()}, target)

func can_start() -> bool:
	if not owner.compatible or owner.blocked or owner.in_game or owner.loading or not owner.host() or owner.members.size() < 2: return false
	if owner.stock_digest != owner.vanilla_digest(): return false
	for id in owner.members:
		if not owner.peers.has(id) or not owner.peers[id].verified or not owner.peers[id].ready: return false
	return true

func reject_peer(id: int):
	if owner.peers.has(id):
		owner.peers[id].verified = false
		owner.peers[id].ready = false
	if is_instance_valid(owner.packets) and is_instance_valid(owner.packets.lobby): owner.packets.lobby.KickPlayerInLobby(id)

func can_join(id: int) -> bool:
	return Steam.getLobbyData(id, "challengepack") == owner.port.VERSION and Steam.getLobbyData(id, "cp_protocol") == str(owner.PROTOCOL) and Steam.getLobbyData(id, "cp_fingerprint") == owner.fingerprint

func check_lobby(id: int) -> bool:
	Steam.requestLobbyData(id)
	var deadline = Time.get_ticks_msec() + owner.TIMEOUT
	while owner.is_inside_tree() and Time.get_ticks_msec() < deadline:
		if not Steam.getLobbyData(id, "challengepack").is_empty(): return owner.can_join(id)
		await owner.get_tree().process_frame
	return false

