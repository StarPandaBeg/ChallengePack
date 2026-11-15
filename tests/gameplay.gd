extends SceneTree

var port: Node
var factory
var directory: String
var checks = 0

func _initialize():
	call_deferred("run")

func stub(name: String, methods: Dictionary, fields: String = "") -> Node:
	var path = "res://scripts/%s.gd" % name
	var source = load(path).source_code.replace("\r\n", "\n")
	var script = GDScript.new()
	var body = 'extends "%s"\n' % path + fields + "\nfunc _ready():\n\tpass\n\nfunc _process(_delta):\n\tpass\n"
	for method in methods:
		body += "\n" + factory.method(source, method).get_slice("\n", 0) + "\n"
		for line in methods[method].split("\n"):
			body += "\t" + line + "\n"
	script.source_code = body
	check(script.reload() == OK)
	return script.new()

func child(parent: Node, node: Node) -> Node:
	parent.add_child(node)
	return node

func animator(parent: Node, names: Array) -> AnimationPlayer:
	var player = AnimationPlayer.new()
	var library = AnimationLibrary.new()
	for name in names:
		var animation = Animation.new()
		animation.length = 0.01
		library.add_animation(name, animation)
	player.add_animation_library("", library)
	return child(parent, player)

func fixture() -> Dictionary:
	var group = Node3D.new()
	group.name = "Fixture"
	var table_parent = child(group, Node3D.new())
	table_parent.name = "tabletop parent"
	var table = child(table_parent, Node3D.new())
	table.name = "main tabletop"
	var rm = stub("RoundManager", {"SetupDeskUI": "player_calls += 1", "LoadShells": "pass", "ClearDeskUI": "pass"}, "var player_calls = 0\n")
	child(group, rm)
	rm.playerData = load("res://scripts/PlayerData.gd").new()
	rm.playerData.numberOfDialogueRead = 3
	rm.shellLoadingSpedUp = true
	var round_data = load("res://scripts/RoundClass.gd").new()
	round_data.amountLive = 2
	round_data.amountBlank = 3
	round_data.shufflingArray = true
	round_data.insertingInRandomOrder = true
	rm.roundArray.assign([round_data])
	var camera = child(group, stub("CameraManager", {"BeginLerp": "pass"}))
	var dialogue = child(group, stub("DialogueManager", {"ShowText_ForDuration": "texts.append(activeText)", "ShowText_Forever": "texts.append(activeText)", "HideText": "pass"}, "var texts = []\n"))
	var ai = child(group, stub("DealerIntelligence", {"BeginDealerTurn": "dealer_calls += 1", "Speaker_HandCrack": "pass"}, "var dealer_calls = 0\n"))
	var perm = child(group, stub("PermissionManager", {"SetStackInvalidIndicators": "pass", "SetIndicators": "pass", "SetInteractionPermissions": "interaction_enabled = state"}, "var interaction_enabled = false\n"))
	var cursor = child(group, stub("CursorManager", {"SetCursor": "pass"}))
	var spawner = load("res://scripts/ShellSpawner.gd").new()
	spawner.roundManager = rm
	spawner.camera = camera
	spawner.dialogue = dialogue
	spawner.ai = ai
	spawner.shellInstance = load("res://instances/shell.tscn")
	spawner.spawnParent = child(group, Node3D.new())
	spawner.shellLocationArray.assign([Vector3.ZERO, Vector3.ONE, Vector3.UP, Vector3.LEFT, Vector3.RIGHT])
	spawner.anim_compartment = animator(group, ["show shells", "hide shells"])
	spawner.speaker_latchOpen = child(group, AudioStreamPlayer2D.new())
	spawner.speaker_audioIndicator = child(group, AudioStreamPlayer2D.new())
	var sound = AudioStreamWAV.new()
	spawner.soundArray_latchOpen.assign([sound, sound])
	spawner.soundArray_indicators.assign([sound, sound])
	child(group, spawner)
	var loader = load("res://scripts/ShellLoader.gd").new()
	loader.roundManager = rm
	loader.camera = camera
	loader.dialogue = dialogue
	loader.dealerAI = ai
	loader.perm = perm
	loader.cursor = cursor
	loader.animator_shotgun = animator(group, ["grab shotgun_pointing enemy", "enemy rack shotgun start", "enemy put down shotgun"])
	loader.animator_dealerHands = animator(group, ["dealer grab shotgun", "RESET"])
	loader.animator_dealerHandRight = animator(group, ["load single shell", "RESET"])
	loader.speaker_loadShell = child(group, AudioStreamPlayer2D.new())
	loader.shotgunHand_L = child(group, Node3D.new())
	loader.shotgunHand_R = child(group, Node3D.new())
	child(group, loader)
	var recording = {"motions": 0}
	loader.animator_dealerHandRight.animation_started.connect(func(name):
		if name == "load single shell":
			recording.motions += 1)
	rm.shellSpawner = spawner
	rm.shellLoader = loader
	var items = load("res://scripts/ItemManager.gd").new()
	items.roundManager = rm
	items.camera = camera
	items.cursor = cursor
	items.itemSpawnParent = child(group, Node3D.new())
	items.btnParent_stealing = child(group, Control.new())
	items.btnparent_ff_stealing = child(group, Control.new())
	items.controller = child(group, stub("ControllerManager", {}))
	items.interaction = child(group, stub("ItemInteraction", {"EnablePermissions": "pass", "DisableShotgun": "pass", "DisablePermissions": "pass"}))
	child(group, items)
	return {"root": group, "rm": rm, "spawner": spawner, "loader": loader, "ai": ai, "perm": perm, "items": items, "table": table, "dialogue": dialogue, "recording": recording}

func run():
	directory = get_script().resource_path.get_base_dir().get_base_dir().path_join("ChallengePack")
	port = load(directory.path_join("challengepack.gd")).new()
	root.add_child(port)
	check(port.compatible)
	factory = port.factory
	var translation = Translation.new()
	translation.locale = "en"
	for key in ["LIVEROUND", "LIVEROUNDS", "BLANKROUND", "BLANKROUNDS"]:
		translation.add_message(key, "%s shells")
	TranslationServer.add_translation(translation)
	TranslationServer.set_locale("en")
	Engine.time_scale = 100
	for shells in range(3):
		for items in range(2):
			for shuffle in range(2):
				for turn in range(3):
					port.active = {"shells": shells, "items": items, "shuffle": shuffle, "turn": turn}
					var f = fixture()
					root.add_child(f.root)
					f.items.set_process(false)
					# Cover both normal and accelerated loading, and main/endless state.
					f.rm.shellLoadingSpedUp = shuffle == 0
					f.rm.endless = items == 1
					await f.spawner.MainShellRoutine()
					check(f.spawner.sequenceArray.count("live") == 2)
					check(f.spawner.sequenceArray.count("blank") == 3)
					var displayed = []
					for shell in f.spawner.spawnedShellObjectArray:
						var branch = shell.get_child(0)
						displayed.append("live" if branch.isLive else "blank")
						if shells == 1:
							check(branch.mesh.get_surface_override_material(1).albedo_color == branch.mat_blank.albedo_color)
					if shuffle == 1:
						check(displayed == f.spawner.sequenceArray, "Reload shuffled the displayed order")
					if shells != 0:
						check(f.rm.playerData.skippingShellDescription)
						check(not f.spawner.speaker_audioIndicator.playing)
					if shells == 2:
						check(f.spawner.anim_compartment.current_animation == "")
						check(not f.spawner.speaker_audioIndicator.playing)
					var sequence = f.spawner.sequenceArray.duplicate()
					var chosen = 0 if turn != 2 else -1
					await f.loader.LoadShells()
					check(f.recording.motions == (8 if shells == 2 else 5), "Incorrect number of loading gestures")
					check(f.ai.dealer_calls + f.rm.player_calls == 1, "Must start exactly one turn")
					if chosen == 0:
						check(f.rm.player_calls == 1)
					check(f.spawner.sequenceArray == sequence, "Presentation changed live shell data")
					if turn == 1:
						await f.loader.LoadShells()
						check(f.ai.dealer_calls == 1 and f.rm.player_calls == 1)
					# The original information items must still read actual chamber data.
					var examine = load("res://scripts/ShellExamine.gd").new()
					examine.shellSpawner = f.spawner
					examine.shellParent = Node3D.new()
					examine.mesh = f.spawner.spawnedShellObjectArray[0].get_child(0).mesh
					examine.mat_live = StandardMaterial3D.new()
					examine.mat_blank = StandardMaterial3D.new()
					examine.SetupShell()
					check(examine.mesh.get_surface_override_material(1) == (examine.mat_live if sequence[0] == "live" else examine.mat_blank))
					examine.shellParent.free()
					examine.free()
					if items == 1:
						var cover = f.table.get_node("Protectors")
						check(cover.get_child_count() == 2 and cover.visible)
						await f.items.SetupItemSteal()
						check(not cover.visible)
						f.items.RevertItemSteal()
						check(cover.visible)
						await f.items.SetupItemSteal()
						await f.items.RevertItemSteal_Timeout()
						check(cover.visible)
					else:
						check(f.table.get_child_count() == 0)
					f.root.queue_free()
					await process_frame
					checks += 1
					print("CP_MATRIX_STEP ", checks)
	Engine.time_scale = 1
	await process_frame
	await process_frame
	print("CP_CLEANUP states=", port.states.size(), " covers=", port.covers.size())
	for id in port.states:
		print("CP_RETAINED_STATE ", port.states[id].ref.get_ref())
	check(port.states.is_empty() and port.covers.is_empty(), "Dead scene retained")
	port.queue_free()
	await process_frame
	print("CP_GAMEPLAY_OK: %s combinations, real spawn/load methods, turn selection, theft/timeout, cleanup" % checks)
	quit()

func check(condition: bool, message: String = "Check failed"):
	if not condition:
		push_error(message)
		quit(1)
