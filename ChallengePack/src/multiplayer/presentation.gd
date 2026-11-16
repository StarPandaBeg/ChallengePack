extends RefCounted

# Explicit session dependency; native adapters keep their stable facade.
var owner: Node

func _init(session: Node):
	owner = session

func presentation():
	if owner.rules.settings.items != 1: return
	var local = null
	for p in owner.game.instance_handler.instance_property_array:
		if p.is_active: local = p
	if local == null: return
	if not local.is_stealing_item: owner.theft_target = -1
	if owner.busy and local.is_stealing_item: owner.busy = false
	for p in owner.game.instance_handler.instance_property_array:
		if p == local:
			for item in p.user_inventory_instance_array:
				if is_instance_valid(item) and owner.hidden.has(item.get_instance_id()):
					item.visible = owner.hidden[item.get_instance_id()]
					owner.hidden.erase(item.get_instance_id())
			continue
		var reveal = local.is_stealing_item and p.socket_number == owner.theft_target
		for item in p.user_inventory_instance_array:
			if is_instance_valid(item):
				if not owner.hidden.has(item.get_instance_id()): owner.hidden[item.get_instance_id()] = item.visible
				item.visible = owner.hidden[item.get_instance_id()] if reveal else false
				if item.get_child_count() > 1 and local.is_stealing_item:
					item.get_child(1).interactionAllowed = reveal and local.has_turn
	for p in owner.game.instance_handler.instance_property_array:
		var held = p.item_interaction.active_item_parent
		if is_instance_valid(held): held.visible = true

func shell_material(branch: Node, type: String, examining: bool):
	var mat = branch.mat_blank_default.duplicate()
	# Multiplying the live shell's red/black texture by green makes its hull
	# almost black, particularly on the ejected shell. Tint the hull directly.
	mat.albedo_texture = null
	mat.albedo_color = Color("299940") if type == "heal" else Color("111117")
	if GlobalVariables.colorblind:
		mat.albedo_color = Color("f4d35e") if type == "heal" else Color("432172")
		mat.emission_enabled = type == "heal"
		mat.emission = Color("715000")
	if examining: mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	branch.shell.set_surface_override_material(1, mat)

func health_visibility(counter: Node):
	var concealed = owner.rules.settings.health == 1
	# Hide stable HP parents, so EnableDisplay and jammer flicker cannot reveal
	# individual charges. The round indicator belongs to a separate branch.
	for charges in [counter.ui_charge_array, counter.ui_charge_array_temp, counter.ui_charge_array_side_left, counter.ui_charge_array_side_right]:
		if charges.is_empty(): continue
		var group = charges[0].get_parent()
		if concealed:
			if not group.has_meta("cp_health_visible"): group.set_meta("cp_health_visible", group.visible)
			group.hide()
		elif group.has_meta("cp_health_visible"):
			group.visible = group.get_meta("cp_health_visible")
			group.remove_meta("cp_health_visible")
	if concealed and counter.properties.health_current > 0 and not counter.ui_parent_winner.visible:
		var round_index = owner.game.MAIN_active_round_index
		if round_index >= 0 and not counter.pos_array_rounds.is_empty():
			counter.ui_round_indicator_selector.position = counter.pos_array_rounds[mini(round_index, counter.pos_array_rounds.size() - 1)].position
			counter.ui_round_indicator_base.show()
			counter.ui_round_indicator_selector.show()

