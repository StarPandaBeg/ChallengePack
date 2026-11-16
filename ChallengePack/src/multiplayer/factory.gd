extends RefCounted

const Extractor = preload("../runtime/patch_builder.gd")
const Effects = preload("../contract_effects.gd")
const PATHS = {
	"packets": "res://multiplayer/scripts/MP_PacketManager.gd",
	"lobby": "res://multiplayer/scripts/MP_LobbyManager.gd",
	"controller": "res://multiplayer/scripts/MP_LobbyController.gd",
	"search": "res://multiplayer/scripts/global scripts/MP_Matchmaking.gd",
	"handler": "res://multiplayer/scripts/global scripts/MP_UserInstanceHandler.gd",
	"round": "res://multiplayer/scripts/global scripts/MP_RoundManager.gd",
	"state": "res://multiplayer/scripts/global scripts/MP_GameStateManager.gd",
	"verify": "res://multiplayer/scripts/global scripts/MP_PacketVerification.gd",
	"shoot": "res://multiplayer/scripts/user scripts/MP_ShotgunInteraction.gd",
	"item": "res://multiplayer/scripts/user scripts/MP_ItemInteraction.gd",
	"shell": "res://multiplayer/scripts/global scripts/MP_ShellBranch.gd",
	"loader": "res://multiplayer/scripts/global scripts/MP_ShellLoader.gd",
	"health": "res://multiplayer/scripts/user scripts/MP_HealthCounter.gd",
	"jammer": "res://multiplayer/scripts/user scripts/MP_Jammer.gd",
	"phone": "res://multiplayer/scripts/user scripts/MP_BurnerPhone.gd",
	"lobby_ui": "res://multiplayer/scripts/global scripts/MP_LobbyUI.gd",
	"item_manager": "res://multiplayer/scripts/user scripts/MP_ItemManager.gd",
	"permissions": "res://multiplayer/scripts/user scripts/MP_UserPermissions.gd",
	"properties": "res://multiplayer/scripts/user scripts/MP_UserInstanceProperties.gd",
	"death": "res://multiplayer/scripts/user scripts/MP_DeathManager.gd",
	"intermediary": "res://multiplayer/scripts/global scripts/MP_InteractionIntermediary.gd"
}
var scripts = {}
var error = ""
var fingerprint = ""
var extract = Extractor.new()

func prepare(directory: String) -> bool:
	scripts.clear()
	error = ""
	extract.error = ""
	var expected = JSON.parse_string(FileAccess.get_file_as_string(directory.path_join("multiplayer/compatibility.json")))
	if not expected is Dictionary: return fail("Missing multiplayer compatibility manifest")
	var globals = FileAccess.get_file_as_string("res://scripts/GlobalVariables.gd").replace("\r\n", "\n")
	if not 'var currentVersion_nr = "v2.2.0"' in globals or not 'var currentVersion_hotfix = 6\n' in globals:
		return fail("Multiplayer requires Buckshot Roulette 2.2.0.6")
	if Image.load_from_file(directory.path_join("assets/contracts/c4.png")) == null:
		return fail("Missing contract HUD image")
	for name in ["armed.wav", "breach.wav"]:
		if Effects.load_pcm(directory.path_join("assets/contracts/" + name)) == null:
			return fail("Missing contract audio: " + name)
	var proof = ""
	for key in PATHS:
		var path = PATHS[key]
		var base = load(path)
		if not base is GDScript: return fail("Missing multiplayer script: " + path)
		var source = base.source_code.replace("\r\n", "\n")
		if source.sha256_text() != expected.get(key): return fail("Unsupported multiplayer script: " + path)
		var body = make_body(key, source)
		if not extract.error.is_empty(): return fail(extract.error)
		body = guard_async(body)
		var script = Extractor.compile_adapter(path, body)
		if script == null: return fail("Cannot compile multiplayer adapter: " + key)
		scripts[path] = script
		proof += source.sha256_text() + body.sha256_text()
	for file in ["rules.gd", "session.gd", "settings.gd", "menu.gd", "contract_hud.gd", "contract_nameplates.gd", "../challenge_hud.gd", "../challenges.gd", "../heal_bullets.gd", "../heal_editor.gd", "../contract_effects.gd", "../challengepack.gd", "../patch_factory.gd", "../online_guard.gd"]:
		proof += FileAccess.get_file_as_string(directory.path_join("multiplayer/" + file)).replace("\r\n", "\n").sha256_text()
	fingerprint = proof.sha256_text()
	return true

func fail(message: String) -> bool:
	error = message
	scripts.clear()
	push_error("[ChallengePack MP] " + message)
	return false

func method(source: String, name: String) -> String:
	return extract.method(source, name)

func replace(source: String, before: String, after: String) -> String:
	return extract.replace_once(source, before, after)

func make_body(key: String, source: String) -> String:
	match key:
		"packets":
			var read = method(source, "read_p2p_packet")
			read = replace(read, "var readable_data: Dictionary =", "var readable_data =")
			read = replace(read, "\t\tif GlobalSteam.STEAM_ID != GlobalSteam.HOST_ID:", "\t\tif not readable_data is Dictionary: return\n\t\tif GlobalSteam.STEAM_ID != GlobalSteam.HOST_ID:")
			read = replace(read, "bytes_to_var(packet_code.decompress_dynamic(-1, FileAccess.COMPRESSION_GZIP))", "bytes_to_var(packet_code.decompress_dynamic(1048576, FileAccess.COMPRESSION_GZIP))")
			read = replace(read, "\t\tPipeData(readable_data)", "\t\tcp_port.mp.receive_native(self, readable_data, packet_sender)")
			var send = method(source, "send_p2p_packet")
			send = replace(send, "\tif GlobalVariables.mp_debugging: return", "\tcp_port.mp.stamp_event(packet_data)\n\tif GlobalVariables.mp_debugging: return")
			var pipe = method(source, "PipeData")
			pipe = replace(pipe, "\tif GlobalVariables.printing_packets:", "\tif not cp_port.mp.before_pipe(self, dict): return\n\tif GlobalVariables.printing_packets:")
			return read + send + pipe + "\nfunc _ready():\n\tprocess_priority = -100\n\tcp_port.mp.register_packets(self)\n\tsuper()\n\nfunc _process(_delta):\n\tcp_port.mp.drain_packets()\n\nfunc send_p2p_packet_directly_to_host(_from: int, data: Dictionary):\n\tcp_port.mp.direct_request(self, data)\n"
		"lobby":
			return "\nfunc join_lobby(id: int):\n\tif not await cp_port.mp.check_lobby(id):\n\t\tcp_port.mp.notice(\"CP_MP_MISMATCH\")\n\t\treturn\n\tsuper(id)\n"
		"controller":
			return "\nfunc StartGame():\n\tif cp_port.mp.can_start():\n\t\tcp_port.mp.loading = true\n\t\tsuper()\n\telse:\n\t\tcp_port.mp.notice(\"CP_MP_NOT_READY\")\n"
		"search":
			return "\nfunc Get():\n\tSteam.addRequestLobbyListStringFilter(\"challengepack\", cp_port.VERSION, 0)\n\tSteam.addRequestLobbyListStringFilter(\"cp_fingerprint\", cp_port.mp.fingerprint, 0)\n\tsuper()\n\nfunc OnLobbyList(found):\n\tvar compatible = []\n\tfor id in found:\n\t\tif cp_port.mp.can_join(id): compatible.append(id)\n\tsuper(compatible)\n"
		"handler":
			return "\nfunc StartMainGame():\n\tif await cp_port.mp.stage(\"scene\"):\n\t\tawait super()\n"
		"round":
			var gen = method(source, "GenerateRandomSequence")
			gen += "\tcp_port.mp.generate_sequence(self)\n"
			var load_routine = method(source, "LoadShotgun")
			load_routine = replace(load_routine, '\tintermed.intermed_properties.cam.BeginLerp("sequence socket_" + str(intermed.intermed_properties.socket_number), true)', '\tif cp_port.mp.rules.settings.shells != 2:\n\t\tintermed.intermed_properties.cam.BeginLerp("sequence socket_" + str(intermed.intermed_properties.socket_number), true)')
			load_routine = replace(load_routine, 'create_timer(game_state.MAIN_sequence_visible_duration, false)', 'create_timer(.25 if cp_port.mp.rules.settings.shells == 2 else game_state.MAIN_sequence_visible_duration, false)')
			load_routine = replace(load_routine, 'create_timer(1.3, false)', 'create_timer(.35 if cp_port.mp.rules.settings.shells == 2 else 1.3, false)')
			load_routine = replace(load_routine, 'create_timer(.4, false)', 'create_timer(.2 if cp_port.mp.rules.settings.shells == 2 else .4, false)')
			load_routine = replace(load_routine, '\tanimator_shell_sequence_machine.play("move up")', '\tif cp_port.mp.rules.settings.shells != 2:\n\t\tanimator_shell_sequence_machine.play("move up")')
			load_routine = replace(load_routine, '\tspeaker_sequence_machine.play()\n\tawait', '\tif cp_port.mp.rules.settings.shells != 2: speaker_sequence_machine.play()\n\tawait')
			load_routine = replace(load_routine, '\tspeaker_sequence_machine.play()\n\tanimator', '\tif cp_port.mp.rules.settings.shells != 2: speaker_sequence_machine.play()\n\tanimator')
			load_routine = replace(load_routine, '\tanimator_shell_sequence_machine.play_backwards("move up")', '\tif cp_port.mp.rules.settings.shells != 2:\n\t\tanimator_shell_sequence_machine.play_backwards("move up")')
			load_routine = replace(load_routine, '\tPassTurn(game_state.MAIN_active_first_turn_socket)', '\tif not await cp_port.mp.stage("load-%s" % cp_port.mp.rules.charge): return\n\tPassTurn(game_state.MAIN_active_first_turn_socket)')
			var begin = method(source, "BeginItemGrabbingForSockets")
			begin = replace(begin, '\tif socket_number_array == []:', '\tif cp_port.mp.rules.settings.mirror == 1:\n\t\tsocket_number_array = cp_port.mp.prepare_mirror(self)\n\tif socket_number_array == []:')
			return gen + load_routine + begin + "\nfunc PassTurn(socket: int):\n\tcp_port.mp.on_turn(socket)\n\tsuper(socket)\n"
		"state":
			return "\nfunc GetItemToGrab(property, incrementing: bool = false):\n\tif cp_port.mp.rules.settings.mirror == 1:\n\t\treturn cp_port.mp.mirror_item(property, incrementing)\n\treturn super(property, incrementing)\n\nfunc CheckIfShooterEndingTurnAfterShot(target: int, shooter: int, shell: String, saw: bool, left: int):\n\tif shell == \"heal\":\n\t\treturn target != shooter or left == 0\n\treturn super(target, shooter, \"live\" if shell == \"lethal\" else shell, saw, left)\n"
		"verify":
			return "\nfunc VerifyPacket(data):\n\treturn cp_port.mp.verify(self, data)\n\nfunc PacketSort(data: Dictionary):\n\tif data.get(\"packet alias\") == \"shoot user request\":\n\t\tcp_port.mp.resolve_shot(self, data)\n\telif data.get(\"packet alias\") == \"interact with item request\":\n\t\tcp_port.mp.resolve_item(self, data)\n\telse:\n\t\tsuper(data)\n"
		"shoot":
			var receive = method(source, "ReceivePacket_Shoot")
			receive = replace(receive, '\tproperties.is_on_secondary_interaction = false', '\tintermediary.game_state.StopTimeoutForSocket("turn", packet_dictionary.shooter_socket_self)\n\tproperties.is_on_secondary_interaction = false')
			receive = replace(receive, '\tvar sent_from =', '\tactive_shooter_shotgun_damage = packet_dictionary.get("cp_strength", active_shooter_shotgun_damage)\n\tcp_port.mp.pending_shots[properties.socket_number] = packet_dictionary.duplicate(true)\n\tvar sent_from =')
			var outcome = method(source, "ShootingOutcome")
			outcome = replace(outcome, '\tawait get_tree().create_timer(.1, false).timeout', '\tif not cp_port.mp.claim_outcome(self): return\n\tawait get_tree().create_timer(.1, false).timeout')
			outcome = outcome.replace('current_shell == "live"', 'current_shell in ["live", "lethal"]')
			outcome = outcome.replace('current_shell == "blank"', 'current_shell in ["blank", "heal"]')
			outcome = replace(outcome, '\t\t\t\tinstance.health_current -= active_shooter_shotgun_damage', '\t\t\t\tinstance.health_current = cp_port.mp.pending_shots[properties.socket_number].cp_health')
			outcome = replace(outcome, '\tRemoveFirstShellFromSequence()', '\tif current_shell == "heal": cp_port.mp.apply_heal(self)\n\tif not cp_port.mp.pending_shots[properties.socket_number].get("cp_penalty", false):\n\t\tRemoveFirstShellFromSequence()')
			var ending = "\nfunc CheckIfEndingTurn(packet_dictionary: Dictionary):\n\tawait cp_port.mp.finish_shot(self, packet_dictionary)\n"
			return receive + outcome + ending
		"item":
			var change = method(source, "ChangeGameStateWithItem")
			change = replace(change, 'if shell_in_chamber == "live": properties.intermediary.game_state.MAIN_active_sequence_dict.sequence_in_shotgun[0] = "blank"\n\t\t\t\telse: properties.intermediary.game_state.MAIN_active_sequence_dict.sequence_in_shotgun[0] = "live"', 'properties.intermediary.game_state.MAIN_active_sequence_dict.sequence_in_shotgun[0] = cp_port.heal_bullets.invert(shell_in_chamber)')
			change = replace(change, "properties.health_current += 1", 'properties.health_current = packet.get("cp_health", properties.health_current)')
			return change + "\nfunc EndItemInteraction(packet: Dictionary):\n\tawait cp_port.mp.finish_item(self, packet)\n"
		"shell":
			return "\nfunc SetState(type: String):\n\tif type in [\"heal\", \"lethal\"]:\n\t\tcp_port.mp.shell_material(self, type, false)\n\telse: super(type)\n\nfunc SetState_Inspecting(type: String):\n\tif type in [\"heal\", \"lethal\"]:\n\t\tcp_port.mp.shell_material(self, type, true)\n\telse: super(type)\n"
		"loader":
			var spawn = method(source, "SpawnShells")
			spawn = replace(spawn, '\tfor i in range(sequence.size()):', '\tif cp_port.mp.rules.settings.shells == 2: return\n\tfor i in range(sequence.size()):')
			spawn = replace(spawn, 'shell_branch.SetState(sequence[i])', 'shell_branch.SetState("unknown" if cp_port.mp.rules.settings.shells == 1 else sequence[i])')
			return spawn
		"phone":
			var phone = method(source, "GetBurnerPhoneString")
			phone = replace(phone, '\t\t\t"blank": final_string_p2', '\t\t\t"heal": final_string_p2 = "... " + cp_port.localization.text("CP_HEAL_ROUND")\n\t\t\t"lethal": final_string_p2 = "... " + cp_port.localization.text("CP_LETHAL_ROUND")\n\t\t\t"blank": final_string_p2')
			return phone
		"lobby_ui":
			return "\nfunc CheckStartButton():\n\tsuper()\n\tui_button_start_game.visible = ui_button_start_game.visible and cp_port.mp.can_start()\n"
		"health":
			return "\nfunc _ready():\n\tsuper()\n\tcp_port.mp.health_visibility(self)\n\nfunc _process(_delta):\n\tcp_port.mp.health_visibility(self)\n\nfunc EnableDisplay():\n\tsuper()\n\tcp_port.mp.health_visibility(self)\n"
		"jammer":
			return "\nfunc ConfirmButton():\n\tif not selected_target_is_valid: return\n\tawait super()\n"
	return ""

func guard_async(body: String) -> String:
	var lines = body.split("\n")
	var result = ""
	for line in lines:
		if line.begins_with("func "):
			result += line + "\n"
			# Async adapters capture their originating scene and charge.
			result += "\tvar cp_epoch = cp_port.mp.epoch\n\tvar cp_charge = cp_port.mp.rules.charge\n"
			continue
		result += line + "\n"
		if line.strip_edges().begins_with("await ") or line.strip_edges().begins_with("await("):
			var indentation = line.substr(0, line.length() - line.lstrip("\t").length())
			result += indentation + "if cp_epoch != cp_port.mp.epoch or cp_charge != cp_port.mp.rules.charge or cp_port.mp.blocked: return\n"
	return result
