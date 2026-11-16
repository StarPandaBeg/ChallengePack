extends "gameplay.gd"

var failures = 0

func check(condition: bool, message: String = "Check failed"):
	if not condition:
		failures += 1
		push_error(message)

func entry_manager(f: Dictionary) -> Node:
	# Keep the real adapted BeginMainGame; replace only its unrelated batch setup.
	var script = GDScript.new()
	script.source_code = factory.scripts["res://scripts/RoundManager.gd"].source_code + "\nvar batch_calls = 0\nfunc _ready():\n\tpass\nfunc _process(_delta):\n\tpass\nfunc MainBatchSetup(_enter):\n\tbatch_calls += 1\n"
	check(script.reload() == OK)
	var manager = script.new()
	manager.cp_port = port
	child(f.root, manager)
	f.items.roundManager = manager
	return manager

func record_deployment(manager: Node, result: Dictionary):
	result.completed = await port.await_covers(manager)

func run():
	var installed = root.get_node_or_null("ChallengePack")
	if installed != null:
		root.remove_child(installed)
		installed.free()
	directory = get_script().resource_path.get_base_dir().get_base_dir().path_join("ChallengePack/src")
	port = load(directory.path_join("challengepack.gd")).new()
	root.add_child(port)
	check(port.compatible, port.compatibility_error)
	factory = port.factory
	port.active = port.Settings.DEFAULTS.duplicate()
	port.active.items = 1
	Engine.time_scale = 1
	var f = fixture()
	root.add_child(f.root)
	f.items.set_process(false)
	var cover = port.room_covers(f.rm)
	check(cover != null and not cover.visible and not cover.started, "Covers appeared while still outside the room")
	check(cover.position.y == cover.raised_position.y - cover.RETRACT_DEPTH)
	check(cover.speaker.stream is AudioStream, "Installed mechanical sound is unavailable")
	var packed = load(port.mod_directory.path_join("assets/protectors.res")).instantiate()
	for i in range(2):
		check(cover.get_child(i).transform == packed.get_child(i).transform, "Cover placement/orientation changed")
	packed.free()
	port.items_ready(f.items)
	check(f.table.get_child_count() == 1, "Repeated ready duplicated covers")
	var manager = entry_manager(f)
	manager.BeginMainGame()
	check(manager.batch_calls == 1 and cover.started, "Entry did not deploy covers and call super")
	var first_motion = cover.motion
	manager.BeginMainGame()
	check(cover.motion == first_motion, "Entry restarted the mechanism")
	await create_timer(0.7, false).timeout
	check(cover.rising and cover.visible and not cover.deployed, "Entry did not reach its rising phase")
	check(cover.position.y > cover.raised_position.y - cover.RETRACT_DEPTH and cover.position.y < cover.raised_position.y, "Covers did not rise through the tabletop")
	check(cover.speaker.playing, "Mechanism sound did not play while rising")
	# Theft during the entry animation must not be undone by its completion.
	port.set_covers(f.items, false)
	check(not cover.visible)
	await port.await_covers(manager)
	check(cover.deployed and not cover.rising and not cover.visible, "Completion undid theft visibility")
	check(cover.position == cover.raised_position and not cover.speaker.playing, "Mechanism did not settle/stop its sound")
	port.set_covers(f.items, true)
	check(cover.visible and cover.position == cover.raised_position)
	check(cover.motion == first_motion and not cover.speaker.playing, "Theft replayed the entry effect")
	f.root.queue_free()
	await process_frame
	await process_frame
	await process_frame
	check(port.covers.is_empty(), "Covers retained a dead scene")
	# A fresh scene gets its own effect; direct-at-table starts also deploy safely.
	f = fixture()
	root.add_child(f.root)
	f.items.set_process(false)
	cover = port.room_covers(f.rm)
	check(not cover.started and not cover.visible)
	await port.await_covers(f.rm)
	check(cover.deployed and cover.visible, "Direct entry did not finish deployment")
	f.root.queue_free()
	await process_frame
	# Bound tweens/audio must die with a scene removed halfway through entry.
	f = fixture()
	root.add_child(f.root)
	f.items.set_process(false)
	cover = port.room_covers(f.rm)
	var dead_cover = weakref(cover)
	var interrupted = {}
	record_deployment(f.rm, interrupted)
	await create_timer(0.6, false).timeout
	f.root.queue_free()
	await process_frame
	await process_frame
	await process_frame
	check(dead_cover.get_ref() == null and port.covers.is_empty(), "Interrupted entry retained a cover or manager")
	check(interrupted.get("completed", true) == false, "Interrupted entry did not cancel waiting round setup")
	port.active.items = 0
	f = fixture()
	root.add_child(f.root)
	f.items.set_process(false)
	check(port.room_covers(f.rm) == null and f.table.get_child_count() == 0, "Default items spawned a mechanism")
	f.root.queue_free()
	await process_frame
	port.queue_free()
	first_motion = null
	await process_frame
	print("CP_PROTECTORS: %s failures; retraction, entry/super, rise/sound, theft, scene recreation, direct entry and cleanup" % failures)
	quit(1 if failures else 0)
