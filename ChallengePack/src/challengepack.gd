extends Node

const Settings = preload("settings.gd")
const Factory = preload("patch_factory.gd")
const Guard = preload("online_guard.gd")
const Options = preload("menu.gd")
const Rules = preload("rules.gd")
const Localization = preload("localization.gd")
const Challenges = preload("challenges.gd")
const ChallengeHUD = preload("challenge_hud.gd")
const HealBullets = preload("heal_bullets.gd")
const FailureScreen = preload("failure_screen.gd")
const Protectors = preload("protectors.gd")
const WhatsNew = preload("whats_new.gd")
const ContractEffects = preload("contract_effects.gd")
const MultiplayerSession = preload("multiplayer/session.gd")
const MultiplayerFactory = preload("multiplayer/factory.gd")
var mp
var mp_factory = MultiplayerFactory.new()
const VERSION = "2.1.0"
var settings = Settings.new()
var factory = Factory.new()
var guard = Guard.new()
var localization = Localization.new()
var challenges
var heal_bullets
var active = Settings.DEFAULTS.duplicate()
var compatible = false
var compatibility_error = ""
var compatibility_key = ""
var compatibility_args = []
var options: CanvasLayer
var news: CanvasLayer
var news_checked = false # Once per application launch, including forced previews.
var states = {} # WeakRefs: never retain a dead scene through a manager reference.
var covers = {}
var mod_directory: String
var notice_label: Label
var notice_until = 0
var notice_key = "CP_ONLINE_DISABLED"
var notice_args = []
var challenge_hud: PanelContainer
var failure_screen: CanvasLayer
var contract_effects: CanvasLayer
var returning_from_mp = false

func _enter_tree():
	mod_directory = get_script().resource_path.get_base_dir()
	localization.setup(mod_directory)
	challenges = Challenges.new(self)
	heal_bullets = HealBullets.new(self)
	settings.load_settings()
	active = settings.snapshot()
	compatible = factory.prepare(mod_directory)
	compatibility_error = factory.error
	compatibility_key = factory.error_key
	compatibility_args = factory.error_args.duplicate()
	if compatible and not load(mod_directory.path_join("assets/protectors.res")) is PackedScene:
		compatible = false
		set_compatibility_error("CP_ERROR_COVERS")
	mp = MultiplayerSession.new()
	mp.setup(self)
	mp.compatible = mp_factory.prepare(mod_directory)
	mp.error = mp_factory.error
	mp.fingerprint = mp_factory.fingerprint
	add_child(mp)
	print("[ChallengePack] multiplayer compatibility: ", mp.compatible, " ", mp.error)
	if not guard.prepare(mp.compatible):
		compatible = false
		set_compatibility_error("CP_ERROR_ONLINE")
	get_tree().node_added.connect(on_node_added)
	if not mp.compatible: clear_invite()
	print("[ChallengePack] %s; compatibility: %s %s" % [VERSION, compatible, compatibility_error])

func set_compatibility_error(key: String, arguments: Array = []):
	compatibility_key = key
	compatibility_args = arguments.duplicate()
	compatibility_error = localization.text(key, arguments)

func compatibility_message() -> String:
	if compatibility_key.is_empty():
		return compatibility_error
	return localization.text(compatibility_key, compatibility_args)

func _ready():
	var layer = CanvasLayer.new()
	layer.layer = 120
	add_child(layer)
	notice_label = Label.new()
	notice_label.position = Vector2(18, 82)
	notice_label.size = Vector2(900, 80)
	notice_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	notice_label.add_theme_font_size_override("font_size", 21)
	notice_label.add_theme_color_override("font_shadow_color", Color.BLACK)
	layer.add_child(notice_label)
	challenge_hud = ChallengeHUD.new()
	layer.add_child(challenge_hud)
	challenge_hud.setup(mod_directory)
	failure_screen = FailureScreen.new()
	add_child(failure_screen)
	failure_screen.setup(self)
	contract_effects = ContractEffects.new()
	add_child(contract_effects)
	contract_effects.setup(self)
	if not mp.compatible and OS.get_cmdline_args().has("+connect_lobby"):
		online_notice()

func on_node_added(node: Node):
	if not mp.compatible and node.get_parent() == get_tree().root and node.scene_file_path.begins_with("res://multiplayer/"):
		block_mp_scene(node)
	var script = node.get_script()
	if script == null or node.has_meta("challengepack_hooked"):
		return
	var path: String = script.resource_path
	if not mp.compatible and returning_from_mp and path.begins_with("res://multiplayer/"):
		# Do not permit networking _ready handlers in an unexpected MP scene.
		node.set_script(null)
		return
	var replacement = mp_factory.scripts.get(path) if mp.compatible else null
	if replacement == null: replacement = guard.scripts.get(path)
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
	elif path == "res://scripts/RoundManager.gd" and compatible:
		challenges.track(node)

func menu_ready(manager: Node):
	returning_from_mp = false
	options = Options.new()
	manager.add_child(options)
	options.setup(self, manager)
	news = WhatsNew.new()
	manager.add_child(news)
	news.setup(self, manager)
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
	if is_instance_valid(news) and news.shown:
		return
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
	var phrases = ["CP_SOME_LIVE", "CP_REAL_GAME"]
	if active.shells == 2:
		phrases[0] = "CP_HIDDEN_COUNT"
	loader.dialogue.ShowText_ForDuration(localization.text(phrases[loader.diaindex % 2]), 3)
	loader.diaindex += 1
	await get_tree().create_timer(3, false).timeout
	loader.roundManager.playerData.numberOfDialogueRead += 1

func dealer_turn(loader: Node):
	await get_tree().create_timer(0.6, false).timeout
	var rules = state(loader)
	if not rules.dealer_message_shown:
		loader.dialogue.ShowText_Forever(localization.text("CP_DEALER_FIRST"))
		await get_tree().create_timer(1.9, false).timeout
		loader.dialogue.HideText()
		rules.dealer_message_shown = true
	loader.dealerAI.BeginDealerTurn()

func items_ready(manager: Node):
	if active.items != 1:
		return
	if covers.has(manager.get_instance_id()):
		return
	var table = manager.get_tree().current_scene
	# current_scene is not assigned until add_child/ready has completed.
	if table == null or not table.is_ancestor_of(manager):
		table = manager
		while table.get_parent() != get_tree().root:
			table = table.get_parent()
	var parent = table.get_node_or_null("tabletop parent/main tabletop")
	if parent == null:
		abort_challenge("CP_ERROR_TABLE")
		return
	var packed = load(mod_directory.path_join("assets/protectors.res"))
	if packed == null:
		abort_challenge("CP_ERROR_COVERS")
		return
	var cover = packed.instantiate()
	cover.set_script(Protectors)
	cover.item_manager = manager
	parent.add_child(cover)
	covers[manager.get_instance_id()] = {"ref": weakref(manager), "cover": weakref(cover)}

func set_covers(manager: Node, visible: bool):
	var entry = covers.get(manager.get_instance_id())
	if entry != null:
		var cover = entry.cover.get_ref()
		if cover != null:
			cover.set_covered(visible)

func reveal_item(item: Node3D):
	if active.items == 1:
		Protectors.reveal_item(item)

func room_covers(manager: Node):
	for entry in covers.values():
		var items = entry.ref.get_ref()
		if items != null and items.roundManager == manager:
			return entry.cover.get_ref()
	return null

func deploy_covers(manager: Node):
	var cover = room_covers(manager)
	if cover != null:
		cover.deploy()

func await_covers(manager: Node) -> bool:
	var cover = room_covers(manager)
	if cover != null:
		# Also cover a scene that starts directly at the table, without the intro.
		return await cover.wait_until_deployed()
	return true

func abort_challenge(key: String):
	compatible = false
	set_compatibility_error(key)
	push_error("[ChallengePack] " + compatibility_error)
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
	notify("CP_ONLINE_DISABLED")
	print("[ChallengePack] multiplayer blocked")

func notify(key: String, arguments: Array = [], seconds: float = 7):
	notice_key = key
	notice_args = arguments.duplicate()
	notice_until = Time.get_ticks_msec() + int(seconds * 1000)

func block_mp_scene(_scene: Node):
	if returning_from_mp:
		return
	returning_from_mp = true
	online_notice()
	get_tree().call_deferred("change_scene_to_file", "res://scenes/menu.tscn")

func _process(_delta):
	if notice_label != null:
		notice_label.text = localization.text(notice_key, notice_args)
		notice_label.visible = Time.get_ticks_msec() < notice_until
	if challenge_hud != null:
		challenge_hud.refresh(challenges.hud_data(), localization)
	challenges.prune()
	for id in states.keys():
		if states[id].ref.get_ref() == null:
			states.erase(id)
	for id in covers.keys():
		if covers[id].ref.get_ref() == null:
			covers.erase(id)
