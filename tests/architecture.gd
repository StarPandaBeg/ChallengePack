extends SceneTree

var failures = 0

func _initialize(): call_deferred("run")

func check(ok: bool, reason: String):
	if not ok:
		failures += 1
		push_error(reason)

func run():
	var directory = get_script().resource_path.get_base_dir().get_base_dir().path_join("ChallengePack/src")
	var session = load(directory.path_join("multiplayer/session.gd")).new()
	var game = Node.new()
	session.game = game
	# A malformed network snapshot must be rejected before any field is read
	# or game state is written. The previous implementation indexes charge here.
	session.apply_snapshot({"players": {}, "health": {}})
	check(session.rules.charge == 0, "Malformed snapshot cannot change the charge")
	check(session.current(session.epoch, session.rules.charge), "Current operation may continue")
	check(not session.current(session.epoch - 1, session.rules.charge), "Previous scene operation is cancelled")
	check(not session.current(session.epoch, session.rules.charge + 1), "Different charge operation is cancelled")
	session.blocked = true
	check(not session.current(session.epoch, session.rules.charge), "Blocked session cannot resume an operation")
	session.blocked = false
	var Model = load(directory.path_join("multiplayer/rules.gd"))
	var snapshot = {"charge": 1, "turn": 1, "players": {0: {"contract": 0, "used": 0, "history": [], "failed": false}}, "health": {0: 3}, "inventories": {0: [0, 0, 0, 0, 0, 0, 0, 0]}, "last_actor": 0, "current": 0, "direction": "CW", "sawed": false}
	check(Model.valid_snapshot(snapshot, {0: 4}), "Valid snapshot accepted")
	for invalid in ["short", "health", "contract", "history", "direction"]:
		var bad = snapshot.duplicate(true)
		match invalid:
			"short": bad.inventories[0] = [1]
			"health": bad.health[0] = 5
			"contract": bad.players[0].contract = 999
			"history": bad.players[0].history = ["beer"]
			"direction": bad.direction = "invalid"
		check(not Model.valid_snapshot(bad, {0: 4}), "Reject malformed snapshot: " + invalid)
	session.free()
	game.free()
	print("CP_ARCHITECTURE: failures=", failures)
	quit(1 if failures else 0)
