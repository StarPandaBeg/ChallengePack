extends RefCounted

# Compile subclasses of the installed game, never ship copies of game methods.
const TARGETS = ["ShellSpawner", "ShellLoader", "ItemManager", "MenuManager", "LeaderboardManager"]
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
		return body
	if name == "ShellSpawner":
		var routine = method(source, "MainShellRoutine")
		for animation in ["show shells", "hide shells"]:
			routine = replace_once(routine, '\tanim_compartment.play("%s")' % animation, '\tif cp_port.active.shells != 2:\n\t\tanim_compartment.play("%s")' % animation)
		routine = replace_once(routine, "\tif (roundManager.roundArray[roundManager.currentRound].insertingInRandomOrder):", "\tif cp_port.active.shuffle == 0 and roundManager.roundArray[roundManager.currentRound].insertingInRandomOrder:")
		return routine + FileAccess.get_file_as_string(directory.path_join("adapters/spawner.gd.txt"))
	if name == "ItemManager":
		return "\nfunc SetupItemSteal():\n\tcp_port.set_covers(self, false)\n\tawait super()\n\nfunc RevertItemSteal():\n\tsuper()\n\tcp_port.set_covers(self, true)\n\nfunc RevertItemSteal_Timeout():\n\tawait super()\n\tcp_port.set_covers(self, true)\n"
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
