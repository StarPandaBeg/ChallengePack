extends "gameplay.gd"

var failures = 0

func check(ok: bool, reason: String = "Check failed"):
	if not ok:
		failures += 1
		push_error(reason)

func run():
	var installed = root.get_node_or_null("ChallengePack")
	if installed != null: installed.free()
	directory = get_script().resource_path.get_base_dir().get_base_dir().path_join("ChallengePack/src")
	port = load(directory.path_join("challengepack.gd")).new()
	root.add_child(port)
	factory = port.factory
	check(port.compatible, port.compatibility_error)
	var translation = Translation.new()
	translation.locale = "en"
	for key in ["LIVEROUND", "LIVEROUNDS", "BLANKROUND", "BLANKROUNDS"]: translation.add_message(key, "%s shells")
	TranslationServer.add_translation(translation)
	TranslationServer.set_locale("en")
	Engine.time_scale = 100
	for hidden in [0, 1]:
		port.active = port.Settings.DEFAULTS.duplicate(true)
		port.active.health = hidden
		var f = fixture()
		var camera = stub("CameraManager", {"BeginLerp": "visits.append(lerpName)"}, "var visits = []\n")
		child(f.root, camera)
		f.spawner.camera = camera
		var counter = stub("HealthCounter", {"Bootup": "boots += 1"}, "var boots = 0\n")
		child(f.root, counter)
		f.spawner.healthCounter = counter
		f.rm.roundArray[0].bootingUpCounter = true
		root.add_child(f.root)
		f.items.set_process(false)
		await f.spawner.MainShellRoutine()
		check(camera.visits.has("health counter") == (hidden == 0), "Hidden HP skips health-only camera focus")
		check(camera.visits.has("shell compartment"), "Charge reveal camera is preserved")
		check(counter.boots == 1, "Display initialization still runs once")
		check(f.spawner.sequenceArray.size() == 5, "Charge generation is preserved")
		f.root.free()
	Engine.time_scale = 1
	port.free()
	print("CP_HEALTH_CAMERA: failures=", failures)
	quit(1 if failures else 0)
