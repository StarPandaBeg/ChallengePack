extends RefCounted

var scripts = {}
var error = ""
var error_key = ""
var error_args = []
var directory: String

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

func replace_count(source: String, before: String, after: String, count: int) -> String:
	if source.count(before) != count:
		fail("Adapter anchor mismatch: " + before.strip_edges(), "CP_ERROR_ANCHOR", [before.strip_edges()])
		return ""
	return source.replace(before, after)

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

static func compile_adapter(path: String, body: String) -> GDScript:
	var script = GDScript.new()
	script.source_code = 'extends "%s"\nvar cp_port: Node\n' % path + body
	return script if script.reload() == OK else null
