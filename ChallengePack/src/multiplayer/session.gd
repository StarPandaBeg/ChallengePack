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
var _transport = preload("transport.gd").new(self)
var _lobby = preload("lobby.gd").new(self)
var _synchronization = preload("synchronization.gd").new(self)
var _actions = preload("actions.gd").new(self)
var _presentation = preload("presentation.gd").new(self)

func setup(parent_port: Node):
	port = parent_port
	process_priority = 100 # Apply concealment after the game's ordinary updates.
	settings.load_settings()
	rules.settings = settings.values.duplicate(true)

func host() -> bool:
	return _lobby.host()

func ids() -> Array:
	return _lobby.ids()

func identity() -> Dictionary:
	return _transport.identity()

func message(alias: String, payload: Dictionary = {}) -> Dictionary:
	return _transport.message(alias, payload)

func send(alias: String, payload: Dictionary = {}, target: int = 0):
	return _transport.send(alias, payload, target)

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
	return _lobby._process(_delta)

func drain_packets():
	return _transport.drain_packets()

func receive_native(manager: Node, data: Dictionary, remote: int):
	return _transport.receive_native(manager, data, remote)

func accept_scene_arrival(manager: Node, data: Dictionary, remote: int) -> bool:
	return _transport.accept_scene_arrival(manager, data, remote)

func receive(data: Dictionary, remote: int):
	return _transport.receive(data, remote)

func change_settings(values: Dictionary):
	return _lobby.change_settings(values)

func ready_toggle():
	return _lobby.ready_toggle()

func vanilla_digest() -> String:
	return _lobby.vanilla_digest()

func send_settings(target: int = 0):
	return _lobby.send_settings(target)

func can_start() -> bool:
	return _lobby.can_start()

func reject_peer(id: int):
	return _lobby.reject_peer(id)

func can_join(id: int) -> bool:
	return _lobby.can_join(id)

func check_lobby(id: int) -> bool:
	return await _lobby.check_lobby(id)

func stamp_request(data: Dictionary) -> Dictionary:
	return _transport.stamp_request(data)

func direct_request(manager: Node, data: Dictionary):
	return _transport.direct_request(manager, data)

func valid_action(data: Dictionary, remote: int) -> bool:
	return _transport.valid_action(data, remote)

func stamp_event(data: Dictionary):
	return _transport.stamp_event(data)

func accept_event(data: Dictionary) -> bool:
	return _transport.accept_event(data)

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
	return _synchronization.snapshot()

func public_digest() -> String:
	return _synchronization.public_digest()

func apply_snapshot(data: Dictionary):
	return _synchronization.apply_snapshot(data)

func apply_contracts(data: Dictionary):
	return _actions.apply_contracts(data)

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
	return _transport.before_pipe(_manager, data)

func stage(token: String) -> bool:
	return await _synchronization.stage(token)

func apply_mirror(items: Array):
	return _actions.apply_mirror(items)

func recount_items():
	return _actions.recount_items()

func execute_failure(data: Dictionary):
	return await _actions.execute_failure(data)

func presentation():
	return _presentation.presentation()

func generate_sequence(_round_manager: Node):
	return _actions.generate_sequence(_round_manager)

func announce_contracts():
	return _actions.announce_contracts()

func on_turn(socket: int):
	return _actions.on_turn(socket)

func prepare_mirror(_round_manager: Node) -> Array:
	return _actions.prepare_mirror(_round_manager)

func mirror_item(_property: Node, _incrementing: bool):
	return _actions.mirror_item(_property, _incrementing)

func verify(_verifier: Node, data: Dictionary) -> Dictionary:
	return _actions.verify(_verifier, data)

func restore_permissions(socket: int):
	return _actions.restore_permissions(socket)

func broadcast_native(data: Dictionary):
	return _actions.broadcast_native(data)

func resolve_shot(_verifier: Node, data: Dictionary):
	return _actions.resolve_shot(_verifier, data)

func resolve_item(_verifier: Node, data: Dictionary):
	return _actions.resolve_item(_verifier, data)

func apply_heal(shoot: Node):
	return _actions.apply_heal(shoot)

func claim_outcome(shoot: Node) -> bool:
	return _actions.claim_outcome(shoot)

func punish(socket: int):
	return _actions.punish(socket)

func shell_material(branch: Node, type: String, examining: bool):
	return _presentation.shell_material(branch, type, examining)

func continue_turn(socket: int, after_shot: bool = false):
	return _actions.continue_turn(socket, after_shot)

func finish_jammer_selection(socket: int, resume: bool):
	return _actions.finish_jammer_selection(socket, resume)

func health_visibility(counter: Node):
	return _presentation.health_visibility(counter)

func finish_shot(shoot: Node, packet: Dictionary):
	return await _actions.finish_shot(shoot, packet)

func finish_item(interaction: Node, packet: Dictionary):
	return await _actions.finish_item(interaction, packet)

func flush_snapshots():
	return _synchronization.flush_snapshots()

