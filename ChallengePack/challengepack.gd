extends Node

const Settings = preload("settings.gd")
const Factory = preload("patch_factory.gd")
const Guard = preload("online_guard.gd")
const Options = preload("menu.gd")
const Rules = preload("rules.gd")
const VERSION = "2.0.0"
var settings = Settings.new()
var factory = Factory.new()
var guard = Guard.new()
var active = Settings.DEFAULTS.duplicate()
var compatible = false
var compatibility_error = ""
var options: CanvasLayer
var states = {} # WeakRefs: never retain a dead scene through a manager reference.
var covers = {}
var mod_directory: String
var notice_label: Label
var notice_until = 0
var returning_from_mp = false

func _enter_tree():
	mod_directory = get_script().resource_path.get_base_dir()
	settings.load_settings()
	active = settings.snapshot()
	compatible = factory.prepare(mod_directory)
	compatibility_error = factory.error
	if compatible and not load(mod_directory.path_join("assets/protectors.res")) is PackedScene:
		compatible = false
		compatibility_error = "Cannot load bundled item covers"
	if not guard.prepare():
		compatible = false
		compatibility_error = "Cannot initialize online protection"
	get_tree().node_added.connect(on_node_added)
	clear_invite()
	print("[ChallengePack] %s TEST BUILD; compatibility: %s %s" % [VERSION, compatible, compatibility_error])

func _ready():
	var layer = CanvasLayer.new()
	layer.layer = 120
	add_child(layer)
	notice_label = Label.new()
	notice_label.position = Vector2(30, 25)
	notice_label.size = Vector2(900, 80)
	notice_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	notice_label.add_theme_font_size_override("font_size", 21)
	notice_label.add_theme_color_override("font_shadow_color", Color.BLACK)
	layer.add_child(notice_label)
	if OS.get_cmdline_args().has("+connect_lobby"):
		online_notice()

func on_node_added(node: Node):
	if node.get_parent() == get_tree().root and node.scene_file_path.begins_with("res://multiplayer/"):
		block_mp_scene(node)
	var script = node.get_script()
	if script == null or node.has_meta("challengepack_hooked"):
		return
	var path: String = script.resource_path
	if returning_from_mp and path.begins_with("res://multiplayer/"):
		# Do not permit networking _ready handlers in an unexpected MP scene.
		node.set_script(null)
		return
	var replacement = guard.scripts.get(path)
	if replacement == null and compatible:
		replacement = factory.scripts.get(path)
	if replacement != null:
		Factory.attach(node, replacement, self)
		node.set_meta("challengepack_hooked", true)
		print("[ChallengePack] attached " + path)
	if path == "res://scripts/MenuManager.gd":
		node.ready.connect(menu_ready.bind(node), CONNECT_ONE_SHOT)
	elif path == "res://scripts/ItemManager.gd" and compatible:
		node.ready.connect(items_ready.bind(node), CONNECT_ONE_SHOT)
	elif path == "res://scripts/ShellLoader.gd" and compatible:
		states[node.get_instance_id()] = {"ref": weakref(node), "rules": Rules.new()}

func menu_ready(manager: Node):
	returning_from_mp = false
	options = Options.new()
	manager.add_child(options)
	options.setup(self, manager)
	# Incompatible game builds must also lose the original Start connection.
	if not compatible:
		var button = manager.buttons[0]
		if button.is_connected("is_pressed", manager.Start):
			button.disconnect("is_pressed", manager.Start)
		button.connect("is_pressed", func(): open_options(manager))
		var multiplayer = manager.buttons[22]
		if multiplayer.is_connected("is_pressed", manager.StartMultiplayer):
			multiplayer.disconnect("is_pressed", manager.StartMultiplayer)
		multiplayer.connect("is_pressed", online_notice)

func open_options(_manager: Node):
	if is_instance_valid(options):
		options.open()

func close_options():
	if is_instance_valid(options):
		options.close()

func options_open() -> bool:
	return is_instance_valid(options) and options.shown

func state(loader: Node):
	return states[loader.get_instance_id()].rules

func next_starter(loader: Node) -> int:
	return state(loader).next_starter(active.turn)

func loading_phrase(loader: Node):
	if loader.roundManager.playerData.numberOfDialogueRead >= 3:
		return
	var phrases = ["Some of them are live.", "Now this is a real game."]
	if active.shells == 2:
		phrases[0] = "You won't know their real number."
	loader.dialogue.ShowText_ForDuration(phrases[loader.diaindex % 2], 3)
	loader.diaindex += 1
	await get_tree().create_timer(3, false).timeout
	loader.roundManager.playerData.numberOfDialogueRead += 1

func dealer_turn(loader: Node):
	await get_tree().create_timer(0.6, false).timeout
	var rules = state(loader)
	if not rules.dealer_message_shown:
		loader.dialogue.ShowText_Forever("I'll be the first")
		await get_tree().create_timer(1.9, false).timeout
		loader.dialogue.HideText()
		rules.dealer_message_shown = true
	loader.dealerAI.BeginDealerTurn()

func items_ready(manager: Node):
	if active.items != 1:
		return
	var table = manager.get_tree().current_scene
	# current_scene is not assigned until add_child/ready has completed.
	if table == null or not table.is_ancestor_of(manager):
		table = manager
		while table.get_parent() != get_tree().root:
			table = table.get_parent()
	var parent = table.get_node_or_null("tabletop parent/main tabletop")
	if parent == null:
		abort_challenge("Cannot find the tabletop for item covers")
		return
	var packed = load(mod_directory.path_join("assets/protectors.res"))
	if packed == null:
		abort_challenge("Cannot load item covers")
		return
	var cover = packed.instantiate()
	parent.add_child(cover)
	covers[manager.get_instance_id()] = {"ref": weakref(manager), "cover": weakref(cover)}

func set_covers(manager: Node, visible: bool):
	var entry = covers.get(manager.get_instance_id())
	if entry != null:
		var cover = entry.cover.get_ref()
		if cover != null:
			cover.visible = visible

func abort_challenge(message: String):
	compatible = false
	compatibility_error = message
	push_error("[ChallengePack] " + message)
	get_tree().call_deferred("change_scene_to_file", "res://scenes/menu.tscn")

func clear_invite():
	var globals = get_node_or_null("/root/GlobalVariables")
	if globals != null:
		globals.lobby_id_found_in_command_line = 0
		globals.command_line_checked = true
	var steam = get_node_or_null("/root/GlobalSteam")
	if steam != null:
		steam.LOBBY_INVITE_ARG = false
		if steam.LOBBY_ID != 0 and Engine.has_singleton("Steam"):
			Engine.get_singleton("Steam").leaveLobby(steam.LOBBY_ID)
			steam.LOBBY_ID = 0

func online_notice():
	clear_invite()
	notice_until = Time.get_ticks_msec() + 7000
	print("[ChallengePack] multiplayer blocked")

func block_mp_scene(_scene: Node):
	if returning_from_mp:
		return
	returning_from_mp = true
	online_notice()
	get_tree().call_deferred("change_scene_to_file", "res://scenes/menu.tscn")

func _process(_delta):
	if notice_label != null:
		notice_label.text = "ChallengePack: multiplayer and leaderboard uploads are disabled. Uninstall the mod to play online."
		notice_label.visible = Time.get_ticks_msec() < notice_until
	for id in states.keys():
		if states[id].ref.get_ref() == null:
			states.erase(id)
	for id in covers.keys():
		if covers[id].ref.get_ref() == null:
			covers.erase(id)
