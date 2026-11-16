extends "challenges.gd"

var failures = 0

func check(condition: bool, message: String = "Check failed"):
	if not condition:
		failures += 1
		push_error(message)

func adapted(name: String, additions: String = "") -> Node:
	var script = GDScript.new()
	var body = factory.scripts["res://scripts/%s.gd" % name].source_code
	if name == "ItemInteraction":
		body = body.replace(factory.method(body, "InteractWith"), "func InteractWith(_itemName: String):\n\tpass\n")
	script.source_code = body + additions
	check(script.reload() == OK)
	var node = script.new()
	node.cp_port = port
	return node

func isolate_indicator(item: Node3D, dealer: bool):
	var replacement = stub("PickupIndicator", {"Revert": "pass", "SnapToMax": "pass"})
	item.get_child(0).set_script(replacement.get_script())
	item.get_child(0).isDealerItem = dealer
	replacement.free()

func item_node(name: String, player: bool) -> Node3D:
	var item = super.item_node(name, player)
	isolate_indicator(item, not player)
	return item

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
	Engine.time_scale = 100
	port.active = port.Settings.DEFAULTS.duplicate()
	port.active.items = 1
	var f = fixture()
	# Already placed leftovers must also be hidden during manager registration.
	var leftover = item_node("beer", false)
	f.items.itemSpawnParent.add_child(leftover)
	root.add_child(f.root)
	f.items.set_process(false)
	check(not leftover.visible, "Existing dealer inventory remained visible")
	var cover = port.room_covers(f.rm)
	var intake = item_node("beer", false)
	intake.get_child(0).isDealerItem = false
	f.items.itemSpawnParent.add_child(intake)
	check(intake.visible, "Player intake was hidden before placement")
	var player = item_node("cigarettes", true)
	f.items.itemSpawnParent.add_child(player)
	check(player.visible)
	# Real meshes, including protruding child meshes, are hidden before rendering.
	var dealer_items = []
	for name in ["beer", "cigarettes", "handcuffs", "handsaw", "magnifying glass", "expired medicine", "burner phone", "adrenaline", "inverter"]:
		var path = "res://instances/item_%s.tscn" % ("beer can" if name == "beer" else name)
		var item = load(path).instantiate()
		isolate_indicator(item, true)
		f.items.itemSpawnParent.add_child(item)
		dealer_items.append(item)
		check(not item.visible, "Dealer spawn leaked: " + name)
		for mesh in item.find_children("*", "GeometryInstance3D", true, false):
			check(not mesh.is_visible_in_tree(), "Child mesh leaked: " + name)
	check(dealer_items.size() == 9, "Real item scene coverage is incomplete")
	await port.await_covers(f.rm)
	await f.items.SetupItemSteal()
	check(not cover.visible and leftover.visible, "Theft did not reveal inventory")
	for item in dealer_items:
		check(item.visible)
	f.items.RevertItemSteal()
	check(cover.visible and not leftover.visible)
	for item in dealer_items:
		check(not item.visible)
	await f.items.SetupItemSteal()
	await f.items.RevertItemSteal_Timeout()
	check(not leftover.visible and player.visible and intake.visible, "Timeout did not restore visibility correctly")
	# Real dealer pickup reveals just its selected table instance before hand motion.
	var hands = adapted("HandManager", '\nvar selected\nvar visible_at_grab = false\nfunc _process(_delta):\n\tpass\nfunc BeginHandLerp(_hand, _grid, _side):\n\tvisible_at_grab = selected.visible\nfunc ReturnHand():\n\tpass\nfunc HandFailsafe():\n\tpass\nfunc PlaySound(_name):\n\tpass\n')
	hands.dealerAI = f.ai
	hands.itemManager = f.items
	hands.lerpDuration = 0.5
	hands.animator_hands = animator(f.root, ["RESET", "dealer use beer"])
	hands.animator_dealerHeadLook = animator(f.root, ["dealer look left", "dealer look forward from left"])
	hands.hand_defaultL = child(f.root, Node3D.new())
	hands.hand_defaultR = child(f.root, Node3D.new())
	hands.hand_beer = child(f.root, Node3D.new())
	hands.hand_beer.hide()
	child(f.root, hands)
	leftover.get_child(0).dealerGridName = child(f.root, Node3D.new())
	f.items.itemArray_instances_dealer.assign([leftover])
	hands.selected = leftover
	await hands.PickupItemFromTable("beer")
	check(hands.visible_at_grab and hands.hand_beer.visible, "Dealer pickup/held item was invisible")
	for item in dealer_items:
		check(not item.visible, "Dealer pickup revealed unrelated items")
	# Closing theft UI must not re-hide the item travelling to the player's hand.
	var interaction = adapted("ItemInteraction", '\nfunc _ready():\n\tpass\nfunc _process(_delta):\n\tpass\nfunc EnablePermissions():\n\tpass\nfunc DisablePermissions():\n\tpass\nfunc DisableShotgun():\n\tpass\n')
	interaction.roundManager = f.rm
	interaction.items = f.items
	interaction.itemManager = f.items
	interaction.hands = hands
	interaction.cursor = f.loader.cursor
	interaction.camera = f.spawner.camera
	interaction.perm = child(f.root, stub("PermissionManager", {"SetIndicators": "pass", "SetInteractionPermissions": "pass", "RevertDescriptionUI": "pass"}))
	interaction.speaker_pickup = child(f.root, AudioStreamPlayer2D.new())
	interaction.amounts = child(f.root, load("res://scripts/ItemAmounts.gd").new())
	interaction.lerpDuration = 0.5
	child(f.root, interaction)
	f.items.interaction = interaction
	f.items.itemArray_instances_dealer.assign(dealer_items)
	await f.items.SetupItemSteal()
	var selected = dealer_items[0]
	selected.get_child(0).dealerGridName = child(f.root, Node3D.new())
	interaction.PickupItemFromTable(selected, selected.get_child(1).itemName)
	check(selected.visible and selected.get_meta(cover.ITEM_IN_USE, false))
	for item in dealer_items.slice(1):
		check(not item.visible)
	check(cover.visible)
	await create_timer(2, false).timeout
	await process_frame
	await process_frame
	f.root.queue_free()
	await process_frame
	await process_frame
	await process_frame
	check(port.covers.is_empty())
	# Mirrored inventories use the same spawn path, with no visibility leaks.
	port.active.mirror = 1
	f = fixture()
	root.add_child(f.root)
	f.items.set_process(false)
	supply_items(f, ["beer", "handcuffs", "cigarettes"])
	f.items.GrabItems_Enemy()
	for item in f.items.itemSpawnParent.get_children():
		if not item.is_queued_for_deletion():
			check(item.visible == item.get_child(1).isPlayerSide, "Mirrored inventory leaked or player items vanished")
	f.root.queue_free()
	await process_frame
	port.active.items = 0
	f = fixture()
	root.add_child(f.root)
	f.items.set_process(false)
	var vanilla = item_node("beer", false)
	f.items.itemSpawnParent.add_child(vanilla)
	check(vanilla.visible, "Default item mode was affected")
	f.root.queue_free()
	await process_frame
	port.queue_free()
	Engine.time_scale = 1
	await process_frame
	print("CP_HIDDEN_ITEMS: %s failures; spawn/leftovers/meshes, player intake, dealer hand, theft/timeout, mirroring and cleanup" % failures)
	quit(1 if failures else 0)
