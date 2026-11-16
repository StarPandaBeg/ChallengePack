extends "gameplay.gd"

var failures = 0
const FORBIDDEN = {
	1: ["cigarettes", "expired medicine"], 2: [], 3: ["handcuffs"],
	4: ["magnifying glass", "burner phone"], 5: ["beer", "inverter"],
	6: ["handsaw"], 7: ["adrenaline"], 8: ["beer"], 9: ["inverter"], 10: [], 11: [], 12: []
}
const ITEMS = ["beer", "cigarettes", "expired medicine", "handcuffs", "magnifying glass", "burner phone", "handsaw", "inverter", "adrenaline"]

func check(condition: bool, message: String = "Check failed"):
	if not condition:
		failures += 1
		push_error(message)

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
	# Count execution requests without pausing the rule matrix. The companion
	# contract_effects fixture exercises real animations/results for every type.
	var recording = GDScript.new()
	recording.source_code = 'extends CanvasLayer\nvar calls = []\nfunc execute(_manager, key):\n\tcalls.append(key)\nfunc announce(_manager):\n\tpass\n'
	check(recording.reload() == OK)
	var effects = recording.new()
	root.add_child(effects)
	port.contract_effects = effects
	port.active = port.Settings.DEFAULTS.duplicate()
	check(port.challenges.menu_keys().slice(0, 5) == ["CP_OFF", "CP_RANDOM", "CP_NO_HEALING", "CP_NO_SELF_SHOTS", "CP_NO_CUFFS"], "Legacy contract IDs/settings changed")
	var f = fixture()
	root.add_child(f.root)
	f.items.set_process(false)
	f.rm.roundArray[0].usingItems = true
	var interaction = f.items.interaction
	interaction.roundManager = f.rm
	port.challenges.track(f.rm)
	var entry = port.challenges.state(f.rm)
	entry.started = true
	entry.has_items = true
	for contract in FORBIDDEN:
		for stealing in [false, true]:
			interaction.stealing = stealing
			for item in ITEMS:
				entry.contract = contract
				entry.failed = false
				entry.used = 0
				entry.used_items.clear()
				var before = effects.calls.size()
				var forbidden = item in FORBIDDEN[contract]
				check(port.challenges.allow_pickup(interaction, item) == not forbidden, "Wrong item rule: %s / %s / stealing %s" % [contract, item, stealing])
				check(effects.calls.size() == before + (1 if forbidden else 0), "Wrong penalty count")
				check(entry.used == (0 if forbidden or stealing else 1), "Wrong pocket accounting")
				if forbidden:
					check(effects.calls.back() == port.challenges.contract_key(contract), "Wrong failure reason")
					check(not port.challenges.allow_pickup(interaction, item), "Failed contract accepts another item")
					check(effects.calls.size() == before + 1, "Repeated action repeats execution")
		# Existing self-shot restriction keeps its ID and affects only the player.
		entry.failed = false
		check(port.challenges.allow_shot(f.rm, "dealer"), "Contract unexpectedly forbids shooting the dealer")
		check(port.challenges.allow_shot(f.rm, "self") == (contract != 2), "Self-shot rule changed")
	# No Safety Net: either order, repeats, and stolen items share one history.
	for first in ["magnifying glass", "handcuffs"]:
		var second = "handcuffs" if first == "magnifying glass" else "magnifying glass"
		for stolen_first in [false, true]:
			entry.contract = 10
			entry.failed = false
			entry.used = 0
			entry.used_items.clear()
			interaction.stealing = stolen_first
			check(port.challenges.hud_data().hud_key == "CP_HUD_NO_INSURANCE")
			check(port.challenges.allow_pickup(interaction, first))
			check(port.challenges.allow_pickup(interaction, first), "Same item type must remain allowed")
			check(entry.used_items.size() == 1, "History accumulates duplicate items")
			check(port.challenges.hud_data().hud_key == ("CP_HUD_INSURANCE_NO_CUFFS" if first == "magnifying glass" else "CP_HUD_INSURANCE_NO_GLASS"))
			port.challenges.reset_pocket(f.rm)
			check(entry.used == 0 and entry.used_items == [first], "New turn erased charge history")
			check(port.challenges.allow_shot(f.rm, "self"), "No Safety Net forbids a self-shot")
			interaction.stealing = not stolen_first
			check(not port.challenges.allow_pickup(interaction, second), "Opposite item did not break No Safety Net")
	# A pocket rejection must not record an item that was never used.
	entry.contract = 10
	entry.failed = false
	entry.used_items.clear()
	port.active.pocket = 1
	entry.used = 1
	interaction.stealing = false
	check(not port.challenges.allow_pickup(interaction, "magnifying glass"))
	check(not entry.failed and entry.used_items.is_empty(), "Pocket rejection poisoned history")
	port.challenges.reset_pocket(f.rm)
	check(port.challenges.allow_pickup(interaction, "handcuffs"), "Rejected glass unexpectedly forbids cuffs")
	# Adrenaline counts once even when the stolen item is tracked by the contract.
	entry.used = 0
	entry.used_items.clear()
	check(port.challenges.allow_pickup(interaction, "adrenaline"))
	interaction.stealing = true
	check(port.challenges.allow_pickup(interaction, "magnifying glass"))
	check(entry.used == 1 and entry.used_items == ["magnifying glass"])
	check(not port.challenges.allow_pickup(interaction, "handcuffs"))
	# The real charge-start handler clears history, including a silent/off charge.
	Engine.time_scale = 100
	port.active.pocket = 0
	port.active.contract = 11
	entry.failed = false
	arm_contract()
	await port.challenges.begin_round(f.rm)
	check(entry.used_items.is_empty(), "Next charge retained item history")
	entry.used_items.append("handcuffs")
	port.active.contract = 0
	await port.challenges.begin_round(f.rm)
	check(entry.contract == 0 and entry.used_items.is_empty(), "Silent charge retained history")
	var new_manager = Node.new()
	root.add_child(new_manager)
	check(port.challenges.state(new_manager).used_items.is_empty(), "New scene inherited history")
	new_manager.free()
	f.root.queue_free()
	await process_frame
	await process_frame
	port.challenges.prune()
	check(port.challenges.managers.is_empty(), "Contract retained a dead manager")
	port.queue_free()
	effects.queue_free()
	Engine.time_scale = 1
	await process_frame
	print("CP_CONTRACT_RULES: %s failures; twelve contracts, 216 item/theft cases, both insurance orders, turns, pocket/adrenaline, expiry, cleanup" % failures)
	quit(1 if failures else 0)
