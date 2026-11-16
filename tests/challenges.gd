extends "gameplay.gd"

func item_node(name: String, player: bool) -> Node3D:
	var item = Node3D.new()
	var indicator = stub("PickupIndicator", {})
	indicator.isDealerItem = not player
	item.add_child(indicator)
	indicator.owner = item
	var branch = load("res://scripts/InteractionBranch.gd").new()
	branch.itemName = name
	branch.isPlayerSide = player
	item.add_child(branch)
	branch.owner = item
	return item

func supply_items(f: Dictionary, names: Array):
	var amounts = child(f.root, load("res://scripts/ItemAmounts.gd").new())
	f.items.amounts = amounts
	for name in ["beer", "cigarettes", "handcuffs"]:
		var amount = load("res://scripts/AmountResource.gd").new()
		amount.itemName = name
		amount.amount_active = 8
		amount.amount_player = names.count(name)
		amount.amount_dealer = 1 if name == "beer" else 0
		amounts.array_amounts.append(amount)
		var definition = load("res://scripts/ItemResource.gd").new()
		definition.itemName = name
		var template = item_node(name, false)
		var scene = PackedScene.new()
		check(scene.pack(template) == OK)
		template.free()
		definition.instance = scene
		f.items.instanceArray_dealer.append(definition)
	for i in range(8):
		var grid = child(f.root, Node3D.new())
		grid.position.z = i + 1
		var grid_branch = load("res://scripts/gridBranch.gd").new()
		grid_branch.activeIndex = i
		grid.add_child(grid_branch)
		f.items.gridParentArray_enemy.append(grid)
	f.items.ResetDealerGrid()
	for name in names:
		f.items.itemSpawnParent.add_child(item_node(name, true))
	f.items.itemSpawnParent.add_child(item_node("beer", false))
	f.items.numberOfItemsGrabbed_enemy = 1
	f.items.itemArray_dealer.assign(["beer"])
	f.rm.roundArray[0].startingHealth = 4
	f.rm.roundArray[0].numberOfItemsToGrab = 3

func health_counter(f: Dictionary) -> Node:
	var counter = load("res://scripts/HealthCounter.gd").new()
	counter.roundManager = f.rm
	counter.uiparent = child(f.root, Node3D.new())
	for i in range(7):
		counter.symbolArray_player.append(child(counter.uiparent, MeshInstance3D.new()))
		counter.symbolArray_enemy.append(child(counter.uiparent, MeshInstance3D.new()))
	counter.animator_flickerPlayer = animator(f.root, ["RESET", "flicker digit"])
	counter.animator_flickerEnemy = animator(f.root, ["RESET", "flicker digit"])
	f.rm.health_player = 2
	f.rm.health_opponent = 3
	f.root.add_child(counter)
	return counter

func run():
	var installed = root.get_node_or_null("ChallengePack")
	if installed != null:
		root.remove_child(installed)
		installed.free()
	directory = get_script().resource_path.get_base_dir().get_base_dir().path_join("ChallengePack/src")
	port = load(directory.path_join("challengepack.gd")).new()
	port.name = "ChallengePack"
	root.add_child(port)
	check(port.compatible, port.compatibility_error)
	factory = port.factory
	Engine.time_scale = 100
	var checked = 0
	for hidden in range(2):
		for mirror in range(2):
			for pocket in range(3):
				for contract in range(5):
					port.active = port.Settings.DEFAULTS.duplicate()
					port.active.merge({"health": hidden, "mirror": mirror, "pocket": pocket, "contract": contract}, true)
					var f = fixture()
					root.add_child(f.root)
					f.items.set_process(false)
					f.rm.roundArray[0].usingItems = true
					arm_contract()
					await port.challenges.begin_round(f.rm)
					var entry = port.challenges.state(f.rm)
					if contract == 1:
						check(entry.contract in [1, 2, 3])
					else:
						check(entry.contract == maxi(0, contract - 1))
					check(port.challenges.item_breaks_contract(f.rm, "cigarettes") == (entry.contract == 1))
					check(port.challenges.item_breaks_contract(f.rm, "expired medicine") == (entry.contract == 1))
					check(port.challenges.item_breaks_contract(f.rm, "handcuffs") == (entry.contract == 3))
					check(not port.challenges.item_breaks_contract(f.rm, "beer"))
					var interaction = f.items.interaction
					interaction.roundManager = f.rm
					for i in range(3):
						check(port.challenges.allow_pickup(interaction, "magnifying glass") == (pocket == 0 or i < pocket))
					var used = entry.used
					interaction.stealing = true
					check(port.challenges.allow_pickup(interaction, "magnifying glass"))
					check(entry.used == used, "Stolen item consumed another pocket slot")
					interaction.stealing = false
					port.challenges.reset_pocket(f.rm)
					check(entry.used == 0)
					var counter = health_counter(f)
					counter.UpdateDisplay()
					check(counter.uiparent.visible == (hidden == 0))
					check(f.rm.health_player == 2 and f.rm.health_opponent == 3)
					var names = ["beer", "cigarettes", "cigarettes", "handcuffs"]
					supply_items(f, names)
					f.items.GrabItems_Enemy()
					if mirror == 1:
						var dealer = f.items.itemArray_dealer.duplicate()
						dealer.sort()
						var expected = names.duplicate()
						expected.sort()
						check(dealer == expected, "Mirrored inventory differs from player's leftovers + new items")
						check(f.items.numberOfItemsGrabbed_enemy == names.size())
						check(f.items.gridParentArray_enemy_available.size() == 8 - names.size())
						for amount in f.items.amounts.array_amounts:
							check(amount.amount_dealer == amount.amount_player)
					else:
						check(f.items.numberOfItemsGrabbed_enemy == 4, "Vanilla distribution changed")
					f.root.queue_free()
					await process_frame
					checked += 1
	# Full inventories and consecutive mirrored distributions must neither grow
	# beyond eight slots nor retain queued dealer items from the previous copy.
	port.active = port.Settings.DEFAULTS.duplicate()
	port.active.merge({"health": 1, "mirror": 1, "pocket": 2, "items": 1, "contract": 4}, true)
	var full = fixture()
	root.add_child(full.root)
	full.items.set_process(false)
	await port.await_covers(full.rm)
	supply_items(full, ["beer", "beer", "beer", "beer", "beer", "beer", "beer", "beer"])
	full.items.GrabItems_Enemy()
	full.items.GrabItems_Enemy()
	check(full.items.numberOfItemsGrabbed_enemy == 8)
	check(full.items.gridParentArray_enemy_available.is_empty())
	# Finish queued removals from the mirrored redistribution before the vanilla
	# theft routine snapshots the inventory and scans it after its camera delay.
	await process_frame
	await process_frame
	await full.items.SetupItemSteal()
	check(not full.table.get_node("Protectors").visible)
	full.items.RevertItemSteal()
	check(full.table.get_node("Protectors").visible)
	await process_frame
	await process_frame
	check(full.items.itemSpawnParent.get_child_count() == 16)
	# Exercise the actual patched StartRound and BeginPlayerTurn on an already
	# ready node, bypassing only the unrelated scene initialization routine.
	var manager = child(full.root, Node.new())
	manager.set_script(load("res://scripts/RoundManager.gd"))
	manager.set_process(false)
	manager.playerData = full.rm.playerData
	manager.roundArray.assign([full.rm.roundArray[0], load("res://scripts/RoundClass.gd").new()])
	manager.shellLoader = full.loader
	manager.shellSpawner = child(full.root, stub("ShellSpawner", {"MainShellRoutine": "calls += 1"}, "var calls = 0\n"))
	manager.perm = full.perm
	manager.cursor = full.loader.cursor
	manager.controller = full.items.controller
	manager.deskUI_parent = child(full.root, Control.new())
	manager.deskUI_shotgun = child(full.root, Control.new())
	manager.handcuffs = child(full.root, load("res://scripts/HandcuffManager.gd").new())
	manager.handcuffs.roundManager = manager
	factory.attach(manager, factory.scripts["res://scripts/RoundManager.gd"], port)
	manager.set_process(false)
	port.challenges.state(manager).used = 2
	await manager.StartRound(true)
	check(manager.currentRound == 1)
	check(manager.shellSpawner.calls == 1)
	check(port.challenges.state(manager).contract == 0)
	check(port.challenges.state(manager).paused_contract == 3)
	check(port.challenges.state(manager).used == 0)
	port.challenges.state(manager).used = 2
	await manager.BeginPlayerTurn()
	check(port.challenges.state(manager).used == 0)
	full.root.queue_free()
	await process_frame
	# Forbidden actions are intercepted by the actual shooting adapter before
	# ejection, damage, animation, or any of its unassigned exports are touched.
	port.active = port.Settings.DEFAULTS.duplicate()
	port.active.contract = 3
	var f = fixture()
	root.add_child(f.root)
	f.items.set_process(false)
	arm_contract()
	await port.challenges.begin_round(f.rm)
	var shooting = load("res://scripts/ShotgunShooting.gd").new()
	shooting.roundManager = f.rm
	root.add_child(shooting)
	shooting.Shoot("self")
	check(port.challenges.state(f.rm).failed)
	check(port.failure_screen.shown and paused)
	check(port.failure_screen.contract_key == "CP_NO_SELF_SHOTS")
	check(current_scene == null, "Contract failure skipped its result screen")
	await create_timer(0.45, true, false, true).timeout
	port.failure_screen.request_return()
	await process_frame
	await process_frame
	check(not paused and not port.failure_screen.shown)
	shooting.queue_free()
	f.root.queue_free()
	await process_frame
	await process_frame
	check(current_scene != null and current_scene.scene_file_path == "res://scenes/menu.tscn")
	current_scene.queue_free()
	Engine.time_scale = 1
	await process_frame
	await process_frame
	check(port.challenges.managers.is_empty(), "Challenge state retained a dead manager")
	port.queue_free()
	await process_frame
	print("CP_CHALLENGES_OK: %s combinations, hidden health, mirrored inventories, pocket/adrenaline, contracts and loss" % checked)
	quit()
