extends SceneTree

func _initialize():
	call_deferred("run")

func run():
	var directory = get_script().resource_path.get_base_dir().get_base_dir().path_join("ChallengePack")
	print("CP_SOURCE: ", "extracted project" if FileAccess.file_exists("res://gdre_export.log") else "embedded game pack")
	for file in ["challengepack.gd", "menu.gd", "settings.gd", "online_guard.gd", "rules.gd"]:
		var loaded = load(directory.path_join(file))
		check(loaded != null and loaded.can_instantiate(), "Cannot compile " + file)
	var guard = load(directory.path_join("online_guard.gd")).new()
	check(guard.prepare(), "Cannot compile online guard")
	var factory = load(directory.path_join("patch_factory.gd")).new()
	if not factory.prepare(directory):
		push_error(factory.error)
		quit(1)
		return
	var port = Node.new()
	root.add_child(port)
	for name in ["ShellSpawner", "ShellLoader"]:
		var path = "res://scripts/%s.gd" % name
		var node = load(path).new()
		var rm = load("res://scripts/RoundManager.gd").new()
		node.roundManager = rm
		var camera = load("res://scripts/CameraManager.gd").new()
		node.camera = camera
		var before = {}
		for prop in node.get_property_list():
			if prop.usage & PROPERTY_USAGE_SCRIPT_VARIABLE:
				before[prop.name] = node.get(prop.name)
		factory.attach(node, factory.scripts[path], port)
		check(node.roundManager == rm and node.camera == camera)
		check(node.cp_port == port)
		for key in before:
			check(node.get(key) == before[key], name + ": lost " + key)
		# The replacement must remain assignable to the game's typed exports.
		if name == "ShellSpawner":
			rm.shellSpawner = node
		else:
			rm.shellLoader = node
		node.free()
		rm.free()
		camera.free()
	port.free()
	print("CP_PROBE_OK: all adapters compiled; exports and typed references retained")
	quit()

func check(condition: bool, message: String = "Check failed"):
	if not condition:
		push_error(message)
		quit(1)
