extends SceneTree

class FixturePlayer extends Node:
	var user_id = 11
	var socket_number = 0
	var health_current = 3
	var health_on_round_start = 4
	var has_turn = true
	var is_holding_shotgun = true
	var is_grabbing_items = false
	var is_holding_item_to_place = false
	var is_stealing_item = false
	var is_viewing_jammer = false
	var is_jammed = false
	var user_inventory = [{}, {}, {}, {}, {}, {}, {}, {}]

class Handler extends Node:
	var instance_property_array = []

class ArrivalChecker extends Node:
	var checking = true
	var fs = false
	var membersHere_list = [11]
	var amountOfPlayers_here = 1
	func MemberJoinedList(id: int):
		membersHere_list.append(id)
		amountOfPlayers_here += 1

class ArrivalPackets extends Node:
	var memberChecker: Node
	var owner_session: Node
	var temp_id = 0
	var received = []
	func PipeData(data: Dictionary):
		if not owner_session.before_pipe(self, data): return
		received.append(data.duplicate(true))
		if data["packet alias"] == "member joined list":
			memberChecker.MemberJoinedList(data.steam_id)

class State extends Node:
	var instance_handler: Node
	var MAIN_active_current_turn_socket = 0
	var MAIN_active_sequence_dict = {"sequence_in_shotgun": ["blank", "live"]}
	var MAIN_inventory_by_socket = [[{}, {}, {}, {}, {}, {}, {}, {}], [{}, {}, {}, {}, {}, {}, {}, {}]]

class MemorySettings extends RefCounted:
	var values = {}
	func save_settings() -> Error: return OK

class Owner extends Node:
	const VERSION = "2.2.0"
	var localization

var failures = 0

func _initialize(): call_deferred("run")

func check(ok: bool, reason: String):
	if not ok:
		failures += 1
		push_error(reason)

func run():
	var installed = root.get_node_or_null("ChallengePack")
	if installed != null:
		root.remove_child(installed)
		installed.free()
	var steam = root.get_node("GlobalSteam")
	var previous_me = steam.STEAM_ID
	var previous_host = steam.HOST_ID
	steam.STEAM_ID = 11
	steam.HOST_ID = 11
	var directory = get_script().resource_path.get_base_dir().get_base_dir().path_join("ChallengePack/src")
	var parent = Owner.new()
	parent.localization = load(directory.path_join("localization.gd")).new()
	parent.localization.setup(directory)
	var host = load(get_script().resource_path.get_base_dir().path_join("mp_transport_fixture.gd")).new()
	var client = host.get_script().new()
	host.settings = MemorySettings.new()
	client.settings = MemorySettings.new()
	client.settings.values = client.rules.settings.duplicate(true)
	host.port = parent
	client.port = parent
	client.local_host = false
	host.fingerprint = "fixture"
	client.fingerprint = "fixture"
	host.session = "session-one"
	host.revision = 3
	host.members = [11, 22]
	host.peers = {11: {"verified": true, "ready": false, "deadline": 0}, 22: {"verified": false, "ready": false, "deadline": 0}}
	host.receive(client.message("hello", client.identity()), 22)
	check(host.peers[22].verified, "Compatible peer verified")
	check(host.outbox.back().packet["packet alias"] == "settings", "Rules sent after handshake")
	steam.STEAM_ID = 22
	client.receive(host.outbox.back().packet, 11)
	check(client.session == host.session and client.revision == host.revision, "Session revision synchronized")
	check(client.rules.settings == host.rules.settings, "Rules synchronized")
	var saved = client.settings.values.duplicate(true)
	var changed = host.rules.settings.duplicate(true)
	changed.contract_chance = 85
	steam.STEAM_ID = 11
	host.change_settings(changed)
	check(host.revision == 4 and not host.peers[22].ready, "Changes invalidate readiness")
	steam.STEAM_ID = 22
	client.receive(host.outbox.back().packet, 11)
	check(client.rules.settings.contract_chance == 85, "Guest sees updated chance")
	check(client.settings.values == saved, "Guest preferences unchanged")
	# Never save fixture settings to the user's real multiplayer preference file.
	client.ready_toggle()
	steam.STEAM_ID = 11
	host.receive(client.outbox.back().packet, 22)
	check(host.peers[22].ready, "Ready acknowledged")
	host.ready_toggle()
	host.compatible = true
	host.stock_digest = host.vanilla_digest()
	check(host.can_start(), "Start requires every participant")
	var stale = client.message("ready", {"ready": true, "vanilla": host.vanilla_digest()})
	stale.revision -= 1
	host.peers[22].ready = false
	host.receive(stale, 22)
	check(not host.peers[22].ready, "Stale ready rejected")
	var ready = client.message("ready", {"ready": true, "vanilla": host.vanilla_digest()})
	host.receive(ready, 22)
	host.peers[22].ready = false
	host.receive(ready, 22)
	check(not host.peers[22].ready, "Duplicate readiness cannot undo invalidation")
	var wrong = client.identity()
	wrong.fingerprint = "different build"
	host.receive(client.message("hello", wrong), 22)
	check(host.rejected == [22], "Different patch fingerprint rejected")
	# Regression: Steam delivers this stock packet after scene loading. It is
	# not an item/shot request, but must reach the native waiting-player counter.
	var checker = ArrivalChecker.new()
	var arrival_packets = ArrivalPackets.new()
	arrival_packets.owner_session = host
	arrival_packets.memberChecker = checker
	host.in_game = true
	client.in_game = true
	var arrival = {"packet category": "lobby", "packet alias": "member joined list", "packet_id": 4, "steam_id": 22}
	client.stamp_event(arrival)
	check(arrival.get("cp_session") == host.session, "Scene arrival carries session context")
	var spoofed_arrival = arrival.duplicate(true)
	spoofed_arrival.steam_id = 11
	host.receive_native(arrival_packets, spoofed_arrival, 22)
	check(checker.amountOfPlayers_here == 1, "Arrival cannot impersonate another Steam sender")
	var stale_arrival = arrival.duplicate(true)
	stale_arrival.cp_revision -= 1
	host.receive_native(arrival_packets, stale_arrival, 22)
	check(checker.amountOfPlayers_here == 1, "Stale scene arrival rejected")
	host.peers[22].verified = false
	host.receive_native(arrival_packets, arrival, 22)
	check(checker.amountOfPlayers_here == 1, "Unverified scene arrival rejected")
	host.peers[22].verified = true
	host.receive_native(arrival_packets, arrival, 22)
	check(checker.amountOfPlayers_here == 2, "Verified arrival advances native Waiting for players")
	host.receive_native(arrival_packets, arrival, 22)
	check(checker.amountOfPlayers_here == 2, "Repeated arrival cannot count a participant twice")
	var update = {"packet category": "lobby", "packat alias": "update member list", "number of players here": 2}
	host.stamp_event(update)
	arrival_packets.owner_session = client
	client.receive_native(arrival_packets, update, 11)
	check(arrival_packets.received.back()["packet alias"] == "update member list", "Stock member-list alias typo normalized")
	host.packets = arrival_packets
	host.startup_deadline = 1
	host._process(0)
	check(host.blocked and not host.stopped.is_empty(), "Waiting for players has a finite startup timeout")
	host.blocked = false
	host.packets = null
	host.in_game = false
	client.in_game = false
	arrival_packets.free()
	checker.free()
	var state = State.new()
	var handler = Handler.new()
	var actor = FixturePlayer.new()
	var rival = FixturePlayer.new()
	rival.socket_number = 1
	rival.user_id = 22
	handler.instance_property_array = [actor, rival]
	state.instance_handler = handler
	host.game = state
	check(host.TIMEOUT == 30000, "Synchronization allows thirty seconds")
	host.queued_stage = "resume"
	check(await host.stage("resume"), "Queued acknowledgments are drained before waiting or timeout")
	check(host.drain_count > 0, "Stage actively processes the receive queue")
	client.game = state
	client.queued_stage = "resume"
	check(await client.stage("resume"), "Client drains queued stage release before waiting or timeout")
	host.rules.charge = 2
	host.rules.turn = 5
	var request = {"packet category": "MP_PacketVerification", "packet alias": "shoot user request", "packet_id": 12, "sent_from_socket": 0, "socket_to_shoot": 1}
	host.stamp_request(request)
	check(not host.valid_action(request, 22), "Actual sender cannot impersonate another seat")
	check(host.valid_action(request, 11), "Owned action accepted")
	check(not host.valid_action(request, 11), "Repeated action rejected")
	var forged_alias = request.duplicate(true)
	forged_alias["packet alias"] = "start game from lobby"
	host.stamp_request(forged_alias)
	check(not host.valid_action(forged_alias, 11), "Packet ID cannot disguise another operation")
	host.sender = 11
	check(not host.verify(null, request).is_empty(), "Valid living target")
	request.socket_to_shoot = 3
	check(host.verify(null, request).is_empty(), "Missing target rejected")
	request.socket_to_shoot = 1
	rival.health_current = 0
	check(host.verify(null, request).is_empty(), "Dead target rejected")
	rival.health_current = 3
	var event = {"packet category": "MP_RoundManager", "packet alias": "pass turn"}
	host.in_game = true
	host.stamp_event(event)
	client.session = host.session
	client.revision = host.revision
	check(client.accept_event(event), "New host event accepted")
	check(not client.accept_event(event), "Host event applied exactly once")
	event.cp_event += 1
	event.cp_charge -= 1
	check(not client.accept_event(event), "Old charge event rejected")
	client.in_game = true
	host.rules.charge = client.rules.charge
	host.rules.turn = client.rules.turn
	var old_failure = host.message("failure", {"socket": 0})
	old_failure.charge -= 1
	client.receive(old_failure, 11)
	check(client.penalties == 0, "Delayed penalty cannot affect next charge")
	var failure = host.message("failure", {"socket": 0})
	client.receive(failure, 11)
	client.receive(failure, 11)
	check(client.penalties == 1, "Penalty notification applies once")
	state.MAIN_inventory_by_socket[0][0] = {"item_id": 2}
	var item = {"packet alias": "interact with item request", "packet_id": 22, "sent_from_socket": 0, "item_socket_number": 0, "local_grid_index": 0, "item_id": 2, "stealing_item": false}
	check(not host.verify(null, item).is_empty(), "Owned grid slot accepted")
	item.item_id = 3
	check(host.verify(null, item).is_empty(), "Forged item ID rejected")
	item.local_grid_index = 8
	check(host.verify(null, item).is_empty(), "Invalid grid slot rejected")
	actor.is_viewing_jammer = true
	var jam = {"packet alias": "secondary item interaction request", "packet_id": 24, "sent_from_socket": 0, "item_id": 3, "item_selected_socket_number": 1}
	# Use the alias registered by the game rather than trusting a client string.
	jam["packet alias"] = host.REQUESTS[24]
	check(not host.verify(null, jam).is_empty(), "Living jammer target accepted")
	rival.is_jammed = true
	check(host.verify(null, jam).is_empty(), "Already jammed target rejected")
	check(host.native_outbox.size() == 1 and host.native_outbox[0].item_selected_socket_number == -1, "Stale jammer target receives synchronized cancellation")
	actor.is_viewing_jammer = false
	host.verify(null, jam)
	check(host.native_outbox.size() == 1, "Duplicate jammer confirmation cannot exit twice")
	steam.STEAM_ID = previous_me
	steam.HOST_ID = previous_host
	host.free()
	client.free()
	parent.free()
	state.free()
	handler.free()
	actor.free()
	rival.free()
	print("CP_MULTIPLAYER_PROTOCOL: failures=", failures)
	quit(1 if failures else 0)
