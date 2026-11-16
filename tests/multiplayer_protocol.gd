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
	var state = State.new()
	var handler = Handler.new()
	var actor = FixturePlayer.new()
	var rival = FixturePlayer.new()
	rival.socket_number = 1
	rival.user_id = 22
	handler.instance_property_array = [actor, rival]
	state.instance_handler = handler
	host.game = state
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
