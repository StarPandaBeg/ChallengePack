extends SceneTree

func _initialize(): call_deferred("run")

func run():
	var installed = root.get_node_or_null("ChallengePack")
	if installed != null:
		root.remove_child(installed)
		installed.free()
	var args = OS.get_cmdline_user_args()
	if args.size() != 1:
		push_error("Pass the extracted release root after --")
		quit(1)
		return
	var script = load(args[0].path_join("ChallengePack/src/challengepack.gd"))
	if script == null or not script.can_instantiate(): quit(1); return
	var port = script.new()
	port.name = "ChallengePack"
	root.add_child(port)
	if not port.compatible or not port.mp.compatible:
		push_error(port.compatibility_error + " " + port.mp.error)
		quit(1)
		return
	if port.guard.scripts.has(port.guard.LOBBY) or not port.guard.scripts.has(port.guard.BOARD):
		push_error("Release must enable compatible multiplayer and block solo score uploads")
		quit(1)
		return
	print("CP_RELEASE_OK: ", port.VERSION, "; import-free archive and every solo/network adapter compiled")
	port.queue_free()
	await process_frame
	quit()
