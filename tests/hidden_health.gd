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
	scene.free()
	port.free()
	print("CP_HIDDEN_HEALTH: failures=", failures)
	quit(1 if failures else 0)
