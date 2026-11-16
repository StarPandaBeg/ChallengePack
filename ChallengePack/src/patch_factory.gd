extends RefCounted

# Compile subclasses of the installed game, never ship copies of game methods.
const TARGETS = ["ShellSpawner", "ShellLoader", "ItemManager", "MenuManager", "LeaderboardManager", "HealthCounter", "RoundManager", "ItemInteraction", "ShotgunShooting", "DealerIntelligence", "ShellEjectManager", "ShellExamine", "BurnerPhone", "HandManager"]
var scripts = {}
var error = ""
var error_key = ""
var error_args = []
var directory: String

func prepare(mod_directory: String, check_version: bool = true) -> bool:
	directory = mod_directory
	scripts.clear()
	error = ""
	error_key = ""
	error_args = []
	var expected = JSON.parse_string(FileAccess.get_file_as_string(directory.path_join("compatibility.json")))
	if not expected is Dictionary:
		return fail("Missing compatibility manifest", "CP_ERROR_MANIFEST")
	if check_version:
		var globals = FileAccess.get_file_as_string("res://scripts/GlobalVariables.gd")
		if not 'var currentVersion_nr = "v2.2.0"' in globals or not 'var currentVersion_hotfix = 6\n' in globals.replace("\r\n", "\n"):
			return fail("This mod requires Buckshot Roulette 2.2.0.6", "CP_ERROR_VERSION")
	for name in TARGETS:
		var path = "res://scripts/%s.gd" % name
		var base = load(path)
		if base == null or not base is GDScript or base.source_code.is_empty():
			return fail("Game script source is unavailable: " + name, "CP_ERROR_SOURCE", [name])
		var source = base.source_code.replace("\r\n", "\n")
		if source.sha256_text() != expected.get(name, ""):
			return fail("Unsupported game script: " + name, "CP_ERROR_SCRIPT", [name])
		var body = make_body(name, source)
		if not error.is_empty():
			return false
		var script = GDScript.new()
		script.source_code = 'extends "%s"\nvar cp_port: Node\n' % path + body
		if script.reload() != OK:
			return fail("Cannot compile adapter: " + name, "CP_ERROR_COMPILE", [name])
		scripts[path] = script
	return true

func fail(message: String, key: String = "CP_ERROR_DETAILS", arguments: Array = []) -> bool:
	error = message
	error_key = key
	error_args = [message] if key == "CP_ERROR_DETAILS" else arguments
	scripts.clear()
	push_error("[ChallengePack] " + message)
	return false

func method(source: String, name: String) -> String:
	var start = source.find("func " + name + "(")
	if start < 0:
		fail("Missing method: " + name, "CP_ERROR_METHOD", [name])
		return ""
	var lines = source.substr(start).split("\n")
	var result = lines[0] + "\n"
	for i in range(1, lines.size()):
		var line = lines[i]
		if not line.is_empty() and not line.begins_with("\t") and not line.begins_with("#"):
			break
		result += line + "\n"
	return result

func replace_once(source: String, before: String, after: String) -> String:
	if source.count(before) != 1:
		fail("Adapter anchor mismatch: " + before.strip_edges(), "CP_ERROR_ANCHOR", [before.strip_edges()])
		return ""
	return source.replace(before, after)

func make_body(name: String, source: String) -> String:
	if name == "ShellLoader":
		var body = method(source, "LoadShells")
		var first = body.find("\tif (roundManager.playerData.numberOfDialogueRead < 3):")
		var last = body.find("\tvar numberOfShells =")
		if first < 0 or last <= first:
			fail("Missing loading dialogue anchors", "CP_ERROR_DIALOGUE")
			return ""
		var original_dialogue = body.substr(first, last - first)
		var conditional = "\tif cp_port.active.shells == 0:\n"
		for line in original_dialogue.trim_suffix("\n").split("\n"):
			conditional += "\t" + line + "\n"
		conditional += "\telse:\n\t\tawait cp_port.loading_phrase(self)\n"
		body = body.substr(0, first) + conditional + body.substr(last)
		body = replace_once(body, "\tfor i in range(numberOfShells):", "\tif cp_port.active.shells == 2:\n\t\tnumberOfShells = 8\n\tfor i in range(numberOfShells):")
		var ending = body.find('\tcamera.BeginLerp("home")')
		if ending < 0:
			fail("Missing first-turn anchor", "CP_ERROR_FIRST_TURN")
			return ""
		var player_turn = body.substr(ending)
		body = body.substr(0, ending) + "\tif cp_port.next_starter(self) == 1:\n\t\tawait cp_port.dealer_turn(self)\n\t\treturn\n" + player_turn
		body = replace_once(body, "\troundManager.playerCurrentTurnItemArray = []", "\tcp_port.challenges.reset_pocket(roundManager)\n\troundManager.playerCurrentTurnItemArray = []")
		return body
	if name == "ShellSpawner":
		var routine = method(source, "MainShellRoutine")
		routine = replace_once(routine, '\tfinalstring = text_lives + " " + text_blanks', '\tfinalstring = text_lives + " " + text_blanks\n\tif sequenceArray.has("heal"):\n\t\tfinalstring = cp_port.heal_bullets.composition(sequenceArray)')
		for animation in ["show shells", "hide shells"]:
			routine = replace_once(routine, '\tanim_compartment.play("%s")' % animation, '\tif cp_port.active.shells != 2:\n\t\tanim_compartment.play("%s")' % animation)
		routine = replace_once(routine, "\tif (roundManager.roundArray[roundManager.currentRound].insertingInRandomOrder):", "\tif cp_port.active.shuffle == 0 and roundManager.roundArray[roundManager.currentRound].insertingInRandomOrder:")
		return routine + FileAccess.get_file_as_string(directory.path_join("adapters/spawner.gd.txt"))
	if name == "ItemManager":
		var distribution = method(source, "GrabItems_Enemy")
		distribution = replace_once(distribution, "\tvar selectedResource", "\tvar cp_mirror = cp_port.challenges.mirror_inventory(self) if cp_port.active.get(\"mirror\", 0) == 1 else []\n\tvar selectedResource")
		distribution = replace_once(distribution, "range(roundManager.roundArray[roundManager.currentRound].numberOfItemsToGrab)", "range(cp_mirror.size() if cp_port.active.get(\"mirror\", 0) == 1 else roundManager.roundArray[roundManager.currentRound].numberOfItemsToGrab)")
		distribution = replace_once(distribution, "\t\t\tvar randindex = randi_range(0, availableItemsToGrabArray_dealer.size() - 1)\n\t\t\tvar selectedItem = availableItemsToGrabArray_dealer[randindex]", "\t\t\tvar selectedItem\n\t\t\tif cp_port.active.get(\"mirror\", 0) == 1:\n\t\t\t\tselectedItem = cp_mirror[i]\n\t\t\telse:\n\t\t\t\tvar randindex = randi_range(0, availableItemsToGrabArray_dealer.size() - 1)\n\t\t\t\tselectedItem = availableItemsToGrabArray_dealer[randindex]")
		return distribution + "\nfunc SetupItemSteal():\n\tcp_port.set_covers(self, false)\n\tawait super()\n\nfunc RevertItemSteal():\n\tsuper()\n\tcp_port.set_covers(self, true)\n\nfunc RevertItemSteal_Timeout():\n\tawait super()\n\tcp_port.set_covers(self, true)\n"
	if name == "HealthCounter":
		var routine = method(source, "UpdateDisplayRoutine")
		routine = replace_once(routine, "if (roundManager.health_player == 1 && !dialogueEntered_player && !roundManager.wireIsCut_player && !skipping_careful):", "if cp_port.active.get(\"health\", 0) == 0 and (roundManager.health_player == 1 && !dialogueEntered_player && !roundManager.wireIsCut_player && !skipping_careful):")
		return routine + "\nfunc _ready():\n\tsuper()\n\tcp_port.challenges.hide_health(self)\n\nfunc _process(_delta):\n\tcp_port.challenges.hide_health(self)\n\nfunc UpdateDisplay():\n\tsuper()\n\tcp_port.challenges.hide_health(self)\n\nfunc FlickerLastDigit():\n\tif cp_port.active.get(\"health\", 0) == 0:\n\t\tsuper()\n"
	if name == "RoundManager":
		var start_round = method(source, "StartRound")
		start_round = replace_once(start_round, "\t#USINGITEMS: SETUP ITEM GRIDS IF ROUND CLASS HAS SETUP ITEM GRIDS ENABLED", "\tif not await cp_port.await_covers(self):\n\t\treturn\n\t#USINGITEMS: SETUP ITEM GRIDS IF ROUND CLASS HAS SETUP ITEM GRIDS ENABLED")
		var increment = "\tif (gettingNext && (currentRound +  1) != roundArray.size()): currentRound += 1"
		start_round = replace_once(start_round, increment, increment + "\n\tawait cp_port.challenges.begin_round(self)")
		var player_turn = method(source, "BeginPlayerTurn")
		player_turn = replace_once(player_turn, "\tplayerCurrentTurnItemArray = []", "\tcp_port.challenges.reset_pocket(self)\n\tplayerCurrentTurnItemArray = []")
		return start_round + player_turn + "\nfunc BeginMainGame():\n\tcp_port.deploy_covers(self)\n\tsuper()\n"
	if name == "ItemInteraction":
		var interact = method(source, "InteractWith")
		interact = replace_once(interact, '\t\t\telse: roundManager.shellSpawner.sequenceArray[0] = "live"', '\t\t\telif roundManager.shellSpawner.sequenceArray[0] == "blank": roundManager.shellSpawner.sequenceArray[0] = "live"')
		return interact + "\nfunc PickupItemFromTable(itemParent: Node3D, passedItemName: String):\n\tif not cp_port.challenges.allow_pickup(self, passedItemName):\n\t\treturn\n\tcp_port.reveal_item(itemParent)\n\tawait super(itemParent, passedItemName)\n"
	if name == "HandManager":
		var pickup = method(source, "PickupItemFromTable")
		return replace_once(pickup, "\tactiveIndex = activeInstance.get_child(0).dealerGridIndex", "\tcp_port.reveal_item(activeInstance)\n\tactiveIndex = activeInstance.get_child(0).dealerGridIndex")
	if name == "ShotgunShooting":
		var shoot = method(source, "Shoot")
		shoot = replace_once(shoot, "\tdealerShotTrue = false", "\tif not cp_port.challenges.allow_shot(roundManager, who):\n\t\treturn\n\tdealerShotTrue = false")
		shoot = replace_once(shoot, "\tPlayShootingSound()", '\tPlayShootingSound()\n\tif currentRoundInChamber == "heal":\n\t\tcp_port.heal_bullets.apply(roundManager, "player" if who == "self" else "dealer", healthCounter)\n\t\tplayerCanGoAgain = who == "self"')
		shoot = replace_once(shoot, '\tif (currentRoundInChamber == "blank" && who == "self"):\n\t\tanimator_shotgun.play', '\tif (currentRoundInChamber in ["blank", "heal"] && who == "self"):\n\t\tanimator_shotgun.play')
		shoot = replace_once(shoot, '\tif (currentRoundInChamber == "blank" && who == "dealer"): disablingDelayShit = true', '\tif (currentRoundInChamber in ["blank", "heal"] && who == "dealer"): disablingDelayShit = true')
		var eject = method(source, "ShootingDealerEjection")
		eject = replace_once(eject, '(currentRoundInChamberCopy == "blank" or currentRoundInChamberCopy == "live")', '(currentRoundInChamberCopy in ["blank", "live", "heal"])')
		return shoot + eject
	if name == "ShellExamine":
		return '\nfunc SetupShell():\n\tsuper()\n\tif shellSpawner.sequenceArray[0] == "heal":\n\t\tmesh.set_surface_override_material(1, cp_port.heal_bullets.material(mat_blank))\n'
	if name == "ShellEjectManager":
		var body = ""
		for action in ["EjectShell", "BeerEjection_player", "BeerEjection_dealer", "DeathEjection"]:
			var eject = method(source, action)
			eject = replace_once(eject, '\telse: mesh.set_surface_override_material(1, mat_blank)', '\telif shellSpawner.sequenceArray[0] == "heal": mesh.set_surface_override_material(1, cp_port.heal_bullets.material(mat_blank))\n\telse: mesh.set_surface_override_material(1, mat_blank)')
			body += eject
		return body
	if name == "BurnerPhone":
		var phone = method(source, "SendDialogue")
		return replace_once(phone, '\t\telse: secondpart = tr("LIVEROUND") % ""', '\t\telif sequence[randindex] == "heal": secondpart = cp_port.localization.text("CP_HEAL_ROUND")\n\t\telse: secondpart = tr("LIVEROUND") % ""')
	if name == "DealerIntelligence":
		var choice = method(source, "DealerChoice")
		choice = replace_once(choice, '\t\t\tif (roundManager.shellSpawner.sequenceArray[0] == "blank"): \n\t\t\t\tknownShell = "blank"\n\t\t\t\tdealerTarget = "self"\n\t\t\telse: \n\t\t\t\tknownShell = "live"\n\t\t\t\tdealerTarget = "player"', '\t\t\tknownShell = shellSpawner.sequenceArray[0]\n\t\t\tdealerTarget = "player" if knownShell == "live" else "self"')
		# Both the last-shell deduction and magnifier must remember all three types.
		var classify = 'if (shellSpawner.sequenceArray[0] == "live"): knownShell = "live" \n'
		for indent in ["\t\t", "\t\t\t"]:
			choice = replace_once(choice, indent + classify + indent + 'else: knownShell = "blank"', indent + 'knownShell = shellSpawner.sequenceArray[0]')
		choice = replace_once(choice, 'knownShell != "live" && shellSpawner.sequenceArray.size() != 1', 'knownShell not in ["live", "heal"] && shellSpawner.sequenceArray.size() != 1')
		choice = replace_once(choice, '&& knownShell != "blank"):', '&& knownShell not in ["blank", "heal"]):')
		var shoot = method(source, "Shoot")
		shoot = replace_once(shoot, "\t#SUBTRACT HEALTH. ASSIGN DEALER CAN GO AGAIN. RETURN IF DEAD", '\tif currentRoundInChamber == "heal":\n\t\tcp_port.heal_bullets.apply(roundManager, "dealer" if who == "self" else "player", healthCounter)\n\t\tdealerCanGoAgain = who == "self"\n\t#SUBTRACT HEALTH. ASSIGN DEALER CAN GO AGAIN. RETURN IF DEAD')
		var coin = method(source, "CoinFlip")
		coin = replace_once(coin, 'var c_blank = shellSpawner.sequenceArray.count("blank")', 'var c_blank = shellSpawner.sequenceArray.count("blank") + shellSpawner.sequenceArray.count("heal")')
		return choice + shoot + coin + '\nfunc FigureOutShell():\n\treturn cp_port.heal_bullets.infer_shell(self)\n'
	if name == "MenuManager":
		return "\nfunc Start():\n\tcp_port.open_options(self)\n\nfunc cp_start_game():\n\tawait super.Start()\n\nfunc StartMultiplayer():\n\tcp_port.online_notice()\n\nfunc _input(event):\n\tif cp_port.options_open():\n\t\tif event.is_action_pressed(\"ui_cancel\") or event.is_action_pressed(\"exit game\"):\n\t\t\tcp_port.close_options()\n\t\t\tget_viewport().set_input_as_handled()\n\t\treturn\n\tsuper(event)\n"
	if name == "LeaderboardManager":
		return "\nfunc UploadScore(_rounds, _visible, _initial):\n\tprint(\"[ChallengePack] leaderboard upload blocked\")\n\nfunc UploadScore_Deprecated(_rounds, _visible, _initial):\n\tprint(\"[ChallengePack] leaderboard upload blocked\")\n"
	return ""

static func attach(node: Node, script: GDScript, port: Node) -> void:
	# Scene exports are already assigned when node_added fires. Preserve all script
	# state, including typed arrays and references, before set_script resets it.
	var state = {}
	for property in node.get_property_list():
		if property.usage & PROPERTY_USAGE_SCRIPT_VARIABLE:
			state[property.name] = node.get(property.name)
	node.set_script(script)
	for key in state:
		node.set(key, state[key])
	node.set("cp_port", port)
