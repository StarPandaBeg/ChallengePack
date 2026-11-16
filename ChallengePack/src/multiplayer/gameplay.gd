extends RefCounted

# Game interactions and their local presentation; networking stays in Session.
var owner: Node
var busy = false
var mirror: Array = []
var mirror_offsets: Dictionary = {}
var pending_shots: Dictionary = {}
var applied_outcomes: Dictionary = {}
var completed_actions: Dictionary = {}
var theft_target: int = -1
var hidden: Dictionary = {}

func _init(session: Node):
	owner = session

func apply_contracts(data: Dictionary):
	owner.rules.players = data.players.duplicate(true)
	owner.rules.charge = data.charge
	owner.rules.last_actor = -1
	announce_contracts()

func apply_mirror(items: Array):
	if not is_instance_valid(owner.game): return
	mirror = items.duplicate()
	mirror_offsets.clear()
	for socket in owner.alive():
		var p = owner.property_for(socket)
		for item in p.user_inventory_instance_array:
			if is_instance_valid(item): item.queue_free()
		p.item_manager.ClearInventory_Dictionaries()
		owner.game.Global_ClearInventoryDictionaries(socket)
	for socket in owner.alive():
		var p = owner.property_for(socket)
		for i in range(mirror.size()):
			p.item_manager.Debug_SpawnItemSeparately(mirror[i], i)
			p.user_inventory[i] = {"item_id": mirror[i], "item_local_grid_index": i}
	recount_items()

func recount_items():
	owner.game.SetupEmptyGlobalItemCount()
	for p in owner.game.instance_handler.instance_property_array:
		p.CLearInventory_Count()
		for entry in p.user_inventory:
			if entry.is_empty(): continue
			p.user_inventory_count_by_item_id[entry.item_id] += 1
			owner.game.global_item_count_on_table_by_id[entry.item_id] += 1

func execute_failure(data: Dictionary):
	var socket = data.get("socket", -1)
	var p = owner.property_for(socket)
	if p == null or owner.rules.state(socket).failed: return
	owner.rules.state(socket).failed = true
	owner.game.StopAllTimeouts()
	for user in owner.game.instance_handler.instance_property_array:
		user.permissions.SetMainPermission(false)
		user.has_turn = false
	var cue = AudioStreamPlayer.new()
	cue.stream = owner.port.resources.sound(owner.port.mod_directory.path_join("assets/contracts/breach.wav"))
	owner.add_child(cue)
	var generation = owner.epoch
	var charge = owner.rules.charge
	cue.play()
	await owner.get_tree().create_timer(1.0, false).timeout
	if not is_instance_valid(owner):
		if is_instance_valid(cue): cue.queue_free()
		return
	if not is_instance_valid(p) or owner.blocked or not owner.current(generation, charge):
		cue.queue_free()
		return
	p.shotgun.SetShotgunVisible_Global(false)
	p.shotgun.SetShotgunVisible_Local(p.is_active)
	var packet = {"shooter_socket_self": socket, "shooter_socket_target": socket, "shooter_shell": "lethal", "shooter_sequence_length_after_eject": data.get("left", 1), "shooter_socket_target_direction": "self", "barrel_sawed_off": false, "sent_from_socket": socket, "ending_turn_after_shot": true, "cp_strength": p.health_current, "cp_health": 0, "cp_penalty": true, "cp_event": -data.get("event", 1)}
	p.shotgun.ReceivePacket_Shoot(packet)
	cue.queue_free()

func generate_sequence(_round_manager: Node):
	if not owner.host(): return
	var sequence = owner.rules.sequences(owner.game.MAIN_active_sequence_dict.sequence)
	owner.game.MAIN_active_sequence_dict.sequence_visible = sequence.visible
	owner.game.MAIN_active_sequence_dict.sequence_in_shotgun = sequence.loaded
	owner.game.MAIN_active_sequence_dict_send = owner.game.MAIN_active_sequence_dict.duplicate(true)
	owner.game.MAIN_active_sequence_dict_send.erase("sequence_in_shotgun")
	if owner.rules.settings.shells == 2:
		owner.game.MAIN_active_sequence_dict_send.sequence = []
		owner.game.MAIN_active_sequence_dict_send.sequence_visible = []
	elif owner.rules.settings.shells == 1:
		owner.game.MAIN_active_sequence_dict_send.sequence = []
		owner.game.MAIN_active_sequence_dict_send.sequence_visible = []
		for _i in sequence.visible.size(): owner.game.MAIN_active_sequence_dict_send.sequence_visible.append("unknown")
	var has_items = false
	for p in owner.game.instance_handler.instance_property_array:
		for item in p.user_inventory:
			if not item.is_empty(): has_items = true
	owner.rules.begin_charge(owner.alive(), has_items)
	var fixed_socket = -1
	var host_socket = -1
	for p in owner.game.instance_handler.instance_property_array:
		if p.user_id == GlobalSteam.HOST_ID: host_socket = p.socket_number
		if p.user_id == owner.rules.settings.first_player: fixed_socket = p.socket_number
	if fixed_socket == -1: fixed_socket = host_socket
	owner.game.MAIN_active_first_turn_socket = owner.rules.starter(owner.alive(), host_socket, owner.game.MAIN_active_turn_order, owner.game.MAIN_active_first_turn_socket, fixed_socket)
	owner.send("contracts", {"players": owner.rules.players, "charge": owner.rules.charge})
	announce_contracts()

func announce_contracts():
	var any = false
	for s in owner.rules.players:
		if owner.rules.players[s].contract != 0: any = true
	if any:
		var sound = AudioStreamPlayer.new()
		sound.stream = owner.port.resources.sound(owner.port.mod_directory.path_join("assets/contracts/armed.wav"))
		owner.add_child(sound)
		sound.finished.connect(sound.queue_free)
		sound.play()

func on_turn(socket: int):
	owner.rules.begin_turn(socket)
	busy = false

func prepare_mirror(_round_manager: Node) -> Array:
	if owner.host():
		var resources = []
		var retained = {}
		for p in owner.game.instance_handler.instance_property_array:
			if p.health_current != 0: continue
			for item in p.user_inventory:
				if not item.is_empty(): retained[item.item_id] = retained.get(item.item_id, 0) + 1
		for r in owner.game.MAIN_item_resource_array:
			resources.append({"id": r.id, "enabled": r.distribution_enabled, "per_player": r.max_amount_on_table, "global_max": r.max_amount_on_table_global - retained.get(r.id, 0)})
		var items = owner.rules.mirror_pool(resources, owner.alive().size(), owner.game.MAIN_active_num_of_items_to_grab)
		owner.send("mirror", {"items": items})
		apply_mirror(items)
	return []

func verify(_verifier: Node, data: Dictionary) -> Dictionary:
	if owner.blocked or not data.has("packet_id") or not data.has("sent_from_socket"): return {}
	if data.get("packet alias") != owner.REQUESTS.get(data.packet_id, ""): return {}
	var p = owner.property_for(data.sent_from_socket)
	if p == null or p.user_id != owner.sender or p.health_current <= 0: return {}
	var active = owner.game.MAIN_active_current_turn_socket == p.socket_number and p.has_turn
	match data.packet_id:
		10:
			if not active or busy or p.is_holding_shotgun: return {}
		12:
			var target = owner.property_for(data.get("socket_to_shoot", -1))
			if not active or busy or not p.is_holding_shotgun or target == null or target.health_current <= 0: return {}
			if owner.game.MAIN_active_sequence_dict.get("sequence_in_shotgun", []).is_empty(): return {}
			if owner.rules.state(p.socket_number).contract == owner.Rules.Catalog.Contract.NO_SELF_SHOTS and target == p:
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
			if typeof(grid) != TYPE_INT or grid < 0 or grid > 7 or owner.property_for(socket) == null: return {}
			var entry = owner.game.MAIN_inventory_by_socket[socket][grid]
			if entry.is_empty() or entry.item_id != data.get("item_id"): return {}
			var stolen = data.get("stealing_item", false)
			if typeof(stolen) != TYPE_BOOL: return {}
			if stolen:
				if not p.is_stealing_item or socket == p.socket_number: return {}
			elif socket != p.socket_number: return {}
			var result = owner.rules.item_result(p.socket_number, entry.item_id, stolen)
			if result == "contract":
				punish(p.socket_number)
				return {}
			if result != "ok":
				owner.send("reject", {"socket": p.socket_number}, p.user_id)
				restore_permissions(p.socket_number)
				return {}
		24:
			var target = owner.property_for(data.get("item_selected_socket_number", -1))
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
	var p = owner.property_for(socket)
	if p != null and p.is_active:
		p.permissions.SetMainPermission(true)
		p.SetTurnControllerPrompts(true)
	owner.notice("CP_POCKET_EXHAUSTED")

func broadcast_native(data: Dictionary):
	owner.packets.send_p2p_packet(0, data)
	owner.packets.PipeData(data)

func resolve_shot(_verifier: Node, data: Dictionary):
	var socket = data.sent_from_socket
	owner.game.StopTimeoutForSocket("turn", socket)
	var actual = owner.rules.target(socket, data.socket_to_shoot, owner.alive())
	var p = owner.property_for(actual)
	var shell = owner.game.MAIN_active_sequence_dict.sequence_in_shotgun[0]
	var effect = owner.rules.shot_effect(socket, actual, shell, owner.game.MAIN_barrel_sawed_off, p.health_current, p.health_on_round_start)
	var strength = effect.strength
	var hp = effect.health
	var left = owner.game.MAIN_active_sequence_dict.sequence_in_shotgun.size() - 1
	var ending = not effect.keep_turn or left == 0 or owner.property_for(socket).user_id in owner.game.MAIN_active_user_id_exceeded_secondary_timeout_array
	busy = true
	broadcast_native({"packet category": "MP_UserInstanceProperties", "packet alias": "shoot user", "sent_from": "host", "packet_id": 13, "shooter_socket_self": socket, "shooter_socket_target": actual, "shooter_shell": shell, "shooter_sequence_length_after_eject": left, "shooter_socket_target_direction": owner.game.round_manager.GetDirection(socket, actual), "barrel_sawed_off": owner.game.MAIN_barrel_sawed_off, "sent_from_socket": socket, "ending_turn_after_shot": ending, "cp_selected_target": data.socket_to_shoot, "cp_strength": strength, "cp_health": hp})

func resolve_item(_verifier: Node, data: Dictionary):
	var socket = data.sent_from_socket
	var p = owner.property_for(socket)
	owner.rules.accept_item(socket, data.item_id, data.stealing_item)
	busy = true
	var packet = {"packet category": "MP_UserInstanceProperties", "packet alias": "interact with item", "sent_from": "host", "packet_id": 23, "item_socket_number": data.item_socket_number, "local_grid_index": data.local_grid_index, "item_id": data.item_id, "socket_number": socket, "stealing_item": data.stealing_item, "ending_turn_after_item_use": owner.game.CheckIfEndingTurnAfterItemUse(data.item_id, socket), "cp_health": mini(p.health_current + 1, p.health_on_round_start) if data.item_id == 4 else p.health_current, "current_shell_in_chamber": "unknown", "phone_verbal_shell": "", "phone_verbal_index": "", "cp_players": owner.rules.players.duplicate(true)}
	var private_packet = packet.duplicate(true)
	if data.item_id in [2, 5, 9]: private_packet.current_shell_in_chamber = owner.game.MAIN_active_sequence_dict.sequence_in_shotgun[0]
	if data.item_id == 5: packet.current_shell_in_chamber = private_packet.current_shell_in_chamber
	if data.item_id == 6:
		private_packet.phone_verbal_index = owner.game.GetBurnerPhone_VerbalIndex()
		private_packet.phone_verbal_shell = owner.game._GetBurnerPhone_Shell(private_packet.phone_verbal_index)
	owner.stamp_event(packet)
	for key in ["cp_event", "cp_session", "cp_revision", "cp_charge", "cp_turn"]: private_packet[key] = packet[key]
	for id in owner.ids():
		if id != GlobalSteam.STEAM_ID: owner.packets.send_p2p_packet(id, private_packet if id == p.user_id else packet)
	owner.packets.PipeData(private_packet)

func apply_heal(shoot: Node):
	var packet = pending_shots[shoot.properties.socket_number]
	var target = owner.property_for(packet.shooter_socket_target)
	if target == null: return
	target.health_counter.healing_health = packet.cp_health > target.health_current
	target.health_current = packet.cp_health
	target.health_counter.UpdateDisplay()

func claim_outcome(shoot: Node) -> bool:
	var socket = shoot.properties.socket_number
	var packet = pending_shots.get(socket, {})
	if packet.get("shooter_socket_self", -1) != socket: return false
	var token = "%s:%s:%s" % [owner.rules.charge, socket, packet.get("cp_event", 0)]
	if applied_outcomes.has(token): return false
	applied_outcomes[token] = true
	return true



func punish(socket: int):
	if owner.rules.state(socket).failed or busy: return
	busy = true
	var data = {"socket": socket, "left": owner.game.MAIN_active_sequence_dict.sequence_in_shotgun.size(), "event": owner.event_counter + 1}
	owner.send("failure", data)
	execute_failure(data)

func advance_interaction():
	if not is_instance_valid(owner.game) or owner.rules.settings.items != 1: return
	var local = null
	for player in owner.game.instance_handler.instance_property_array:
		if player.is_active: local = player
	if local == null: return
	if not local.is_stealing_item: theft_target = -1
	# Adrenaline's selection is a continuation, not a second locked action.
	if busy and local.is_stealing_item: busy = false
	for player in owner.game.instance_handler.instance_property_array:
		if player == local: continue
		for item in player.user_inventory_instance_array:
			if is_instance_valid(item) and item.get_child_count() > 1 and local.is_stealing_item:
				item.get_child(1).interactionAllowed = player.socket_number == theft_target and local.has_turn

func continue_turn(socket: int, after_shot: bool = false):
	var p = owner.property_for(socket)
	if p == null or p.health_current <= 0: return
	p.has_turn = true
	p.is_interacting_with_item = false
	p.is_on_secondary_interaction = false
	if after_shot: owner.game.BeginTimeoutForSocket("turn", owner.game.MAIN_timeout_duration_turn, socket)
	if p.is_active:
		p.FreeLookCameraForUser_Enable()
		p.permissions.SetMainPermission(true)
		p.SetTurnControllerPrompts(true)
		GlobalVariables.cursor_state_after_toggle = true
		p.cursor.SetCursor(true, true)

func finish_jammer_selection(socket: int, resume: bool):
	var p = owner.property_for(socket)
	if p == null: return
	p.is_viewing_jammer = false
	p.is_on_jammer_selection = false
	p.is_on_secondary_interaction = false
	p.is_interacting_with_item = false
	p.jammer_manager.looping = false
	if p.is_active: p.jammer_manager.SetJammerControllerPrompts(false)
	if resume and owner.game.MAIN_active_current_turn_socket == socket and p.health_current > 0:
		p.has_turn = true
	busy = false
	print("[ChallengePack MP] jammer selection finished; socket=", socket, "; resume=", resume)

func finish_shot(shoot: Node, packet: Dictionary):
	var token = "shot-%s" % packet.get("cp_event", 0)
	if completed_actions.has(token): return
	completed_actions[token] = true
	var generation = owner.epoch
	var charge = owner.rules.charge
	if not await owner.stage(token): return
	if not is_instance_valid(owner): return
	if not owner.current(generation, charge) or not is_instance_valid(shoot): return
	if packet.get("cp_penalty", false): owner.notice("CP_MP_CONTRACT_FAILED", [shoot.properties.user_name])
	busy = false
	if not owner.host(): return
	var socket = packet.shooter_socket_self
	var winner = shoot.CheckIfUserHasWon()
	owner.flush_snapshots()
	owner.send("digest", {"digest": owner.public_digest()})
	if winner != -1 or packet.ending_turn_after_shot:
		var hand_over = not (packet.shooter_socket_target == socket and packet.shooter_shell in ["blank", "heal"])
		var empty = not packet.get("cp_penalty", false) and packet.shooter_sequence_length_after_eject == 0
		owner.game.round_manager.UserEndTurn_Packet(socket, hand_over, empty, winner)
	else:
		owner.send("continue", {"socket": socket, "shot": true})
		continue_turn(socket, true)

func finish_item(interaction: Node, packet: Dictionary):
	var token = "item-%s" % packet.get("cp_event", 0)
	if completed_actions.has(token): return
	completed_actions[token] = true
	var generation = owner.epoch
	var charge = owner.rules.charge
	if not await owner.stage(token): return
	if not is_instance_valid(owner): return
	if not owner.current(generation, charge) or not is_instance_valid(interaction): return
	var p = interaction.properties
	p.is_interacting_with_item = false
	if packet.item_id == 3: finish_jammer_selection(p.socket_number, not packet.ending_turn_after_item_use)
	busy = false
	if not owner.host(): return
	owner.flush_snapshots()
	owner.send("digest", {"digest": owner.public_digest()})
	if packet.ending_turn_after_item_use:
		owner.game.round_manager.UserEndTurn_Packet(p.socket_number, true, owner.game.MAIN_active_sequence_dict.sequence_in_shotgun.is_empty(), -1)
	else:
		owner.send("continue", {"socket": p.socket_number})
		continue_turn(p.socket_number)

func presentation():
	if owner.rules.settings.items != 1: return
	var local = null
	for p in owner.game.instance_handler.instance_property_array:
		if p.is_active: local = p
	if local == null: return
	for p in owner.game.instance_handler.instance_property_array:
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
	for p in owner.game.instance_handler.instance_property_array:
		var held = p.item_interaction.active_item_parent
		if is_instance_valid(held): held.visible = true

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

func health_visibility(counter: Node):
	var concealed = owner.rules.settings.health == 1
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
		var round_index = owner.game.MAIN_active_round_index
		if round_index >= 0 and not counter.pos_array_rounds.is_empty():
			counter.ui_round_indicator_selector.position = counter.pos_array_rounds[mini(round_index, counter.pos_array_rounds.size() - 1)].position
			counter.ui_round_indicator_base.show()
			counter.ui_round_indicator_selector.show()

