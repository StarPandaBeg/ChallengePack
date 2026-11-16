extends SceneTree

var failures = 0

func _initialize(): call_deferred("run")

func check(ok: bool, reason: String):
	if not ok:
		failures += 1
		push_error(reason)

func run():
	var directory = get_script().resource_path.get_base_dir().get_base_dir().path_join("ChallengePack/src")
	var port = load(directory.path_join("challengepack.gd")).new()
	root.add_child(port)
	check(port.compatible, port.compatibility_error)
	var scene = load("res://scenes/main.tscn").instantiate()
	var counter = scene.get_node("standalone managers/health counter")
	port.factory.attach(counter, port.factory.scripts["res://scripts/HealthCounter.gd"], port)
	var rounds = counter.roundManager.roundIndicatorParent
	for endless in [false, true]:
		counter.roundManager.endless = endless
		for concealed in [false, true]:
			port.active.health = int(concealed)
			counter.uiparent.show()
			rounds.show()
			for group in counter.uiArray: group.show()
			counter.UpdateDisplay()
			check(counter.uiparent.visible and rounds.visible, "Round indicator parent remains visible")
			for group in counter.uiArray:
				check(group.visible == not concealed, "Only health display groups are concealed")
			# Bootup and flicker can enable individual symbols or health groups.
			for symbol in counter.symbolArray_player + counter.symbolArray_enemy: symbol.show()
			for group in counter.uiArray: group.show()
			port.challenges.hide_health(counter)
			for group in counter.uiArray:
				check(group.visible == not concealed, "Health cannot leak after display animation")
			rounds.hide()
			port.challenges.hide_health(counter)
			check(not rounds.visible, "Native round indicator visibility is preserved")
	await round_animation(port, scene, counter)
	scene.free()
	port.free()
	print("CP_HIDDEN_HEALTH: failures=", failures)
	quit(1 if failures else 0)

# Run the complete game routine, including its shutdown and RESET animation.
func round_animation(port: Node, scene: Node, counter: Node):
	var manager = counter.roundManager
	var adapter = GDScript.new()
	adapter.source_code = port.factory.scripts["res://scripts/RoundManager.gd"].source_code + "\nfunc _ready():\n\tpass\n\nfunc _process(_delta):\n\tpass\n"
	check(adapter.reload() == OK, "Round adapter compiles")
	port.factory.attach(manager, adapter, port)
	var camera = GDScript.new()
	camera.source_code = 'extends "res://scripts/CameraManager.gd"\nfunc BeginLerp(_name: String):\n\tpass\n'
	check(camera.reload() == OK, "Controlled camera compiles")
	manager.camera.set_script(camera)
	var statue = GDScript.new()
	statue.source_code = 'extends "res://scripts/StatueManager.gd"\nfunc CheckStatus():\n\tpass\n'
	check(statue.reload() == OK, "Controlled statue compiles")
	manager.statue.set_script(statue)
	var screen = scene.get_node("tabletop parent/main tabletop/health counter")
	screen.get_parent().remove_child(screen)
	root.add_child(screen)
	manager.get_parent().remove_child(manager)
	root.add_child(manager)
	var data = load("res://scripts/RoundClass.gd").new()
	manager.roundArray.assign([data])
	var original_material = manager.roundIndicator.material_override
	Engine.time_scale = 50
	for endless in [false, true]:
		manager.endless = endless
		for concealed in [false, true]:
			port.active.health = int(concealed)
			for number in [1, 2, 3]:
				data.indicatorNumber = number
				await manager.RoundIndicator()
				await process_frame
				check(manager.roundIndicatorParent.visible == concealed, "Round stays visible after complete introduction only with hidden HP")
				if concealed:
					check(manager.roundIndicator.visible and manager.roundIndicator.material_override.albedo_color.a == 1.0, "Round marker remains opaque after RESET")
					check(manager.roundIndicator.material_override != original_material and original_material.albedo_color.a == 0.0, "Persistent mark uses a local material")
					check(manager.roundIndicator.position == manager.roundIndicatorPositions[number], "Correct round position")
					check(not manager.animator_roundIndicator.is_playing(), "Persistent marker does not blink or repeat audio")
				counter.DisableCounter()
				check(not manager.roundIndicatorParent.visible, "Round indicator hides at batch end")
	Engine.time_scale = 1
	manager.free()
	screen.free()
