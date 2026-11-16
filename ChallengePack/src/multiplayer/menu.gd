extends CanvasLayer

const GREEN = Color(0, 1, 0)
const DIM_GREEN = Color(0, 0.42, 0)

const Labels = preload("../menu.gd").LABELS
var session: Node
var panel: PanelContainer
var editor: PanelContainer
var grid: GridContainer
var status: Label
var hud: Label
var ready_button: Button
var open_button: Button
var edit_button: Button
var first_player: OptionButton
var checks = {}
var choices = {}
var chance: HSlider
var chance_label: Label
var shown = false
var theft_targets: HBoxContainer
var target_ids = []
var bomb: TextureRect
var blocked_raycast: WeakRef
var raycast_state = false
var member_signature = ""
var backdrop: ColorRect
var lobby_button_parent: Control

func text(key: String, args: Array = []) -> String:
	return session.port.localization.text(key, args)

func setup(owner_session: Node):
	session = owner_session
	layer = 112
	open_button = Button.new()
	open_button.position = Vector2(18, 16) if session.in_game else Vector2(127, 345)
	open_button.theme = make_theme()
	open_button.add_theme_font_size_override("font_size", 23 if session.in_game else 39)
	if not session.in_game: open_button.scale = Vector2(0.395638, 0.618437)
	open_button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	open_button.text = "CHALLENGEPACK"
	open_button.pressed.connect(toggle)
	if not session.in_game and is_instance_valid(session.lobby_ui):
		lobby_button_parent = session.lobby_ui.ui_parent_lobby_home
		lobby_button_parent.add_child(open_button)
	else:
		add_child(open_button)
	connect_button_audio(open_button)
	backdrop = ColorRect.new()
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.color = Color(0, 0, 0, 0.98)
	backdrop.hide()
	add_child(backdrop)
	hud = Label.new()
	hud.position = Vector2(18, 54)
	hud.custom_minimum_size.x = 310
	hud.size.x = 310
	hud.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.theme = open_button.theme
	hud.add_theme_font_size_override("font_size", 15)
	add_child(hud)
	bomb = TextureRect.new()
	bomb.texture = ImageTexture.create_from_image(Image.load_from_file(session.port.mod_directory.path_join("assets/contracts/c4.png")))
	bomb.position = Vector2(298, 54)
	bomb.size = Vector2(20, 20)
	bomb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bomb.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bomb.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	add_child(bomb)
	theft_targets = HBoxContainer.new()
	theft_targets.position = Vector2(18, 160)
	theft_targets.theme = open_button.theme
	add_child(theft_targets)
	panel = PanelContainer.new()
	panel.position = Vector2(54, 20)
	panel.custom_minimum_size = Vector2(850, 0)
	panel.theme = open_button.theme
	add_child(panel)
	var column = VBoxContainer.new()
	column.add_theme_constant_override("separation", 2)
	panel.add_child(column)
	var title = Label.new()
	title.text = "CHALLENGEPACK " + session.port.VERSION
	title.add_theme_font_size_override("font_size", 23)
	column.add_child(title)
	var scroll = ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(820, 260)
	scroll.follow_focus = true
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(scroll)
	grid = GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 4)
	scroll.add_child(grid)
	for key in Labels:
		var cell = HBoxContainer.new()
		cell.custom_minimum_size.x = 400
		cell.add_theme_constant_override("separation", 4)
		grid.add_child(cell)
		var button = Button.new()
		button.custom_minimum_size = Vector2(0, 48)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.add_theme_font_size_override("font_size", 16)
		button.pressed.connect(cycle.bind(key))
		cell.add_child(button)
		choices[key] = button
		if key == "contract":
			edit_button = Button.new()
			edit_button.add_theme_font_size_override("font_size", 14)
			edit_button.pressed.connect(open_editor)
			cell.add_child(edit_button)
	first_player = OptionButton.new()
	first_player.custom_minimum_size.x = 400
	first_player.get_popup().theme = panel.theme
	first_player.item_selected.connect(select_player)
	grid.add_child(first_player)
	status = Label.new()
	status.custom_minimum_size = Vector2(800, 0)
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status.add_theme_font_size_override("font_size", 13)
	column.add_child(status)
	ready_button = Button.new()
	ready_button.pressed.connect(session.ready_toggle)
	column.add_child(ready_button)
	var close = Button.new()
	close.text = text("CP_DONE")
	close.pressed.connect(toggle)
	column.add_child(close)
	build_editor()
	connect_button_audio(panel)
	connect_button_audio(editor)
	panel.hide()
	refresh()

func build_editor():
	editor = PanelContainer.new()
	editor.position = panel.position
	editor.custom_minimum_size.x = 850
	editor.theme = panel.theme
	editor.add_theme_stylebox_override("panel", panel.get_theme_stylebox("panel").duplicate())
	add_child(editor)
	var col = VBoxContainer.new()
	editor.add_child(col)
	var title = Label.new()
	title.text = text("CP_ROUND_CONTRACT")
	title.add_theme_font_size_override("font_size", 23)
	col.add_child(title)
	var scroll = ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(820, 280)
	scroll.follow_focus = true
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	col.add_child(scroll)
	var entries = GridContainer.new()
	entries.columns = 2
	entries.add_theme_constant_override("h_separation", 12)
	scroll.add_child(entries)
	for id in session.rules.Catalog.ALL_IDS:
		var check = CheckBox.new()
		check.custom_minimum_size = Vector2(400, 34)
		check.add_theme_font_size_override("font_size", 16)
		check.toggled.connect(select_contract.bind(id))
		entries.add_child(check)
		checks[id] = check
	var actions = HBoxContainer.new()
	col.add_child(actions)
	for all in [true, false]:
		var button = Button.new()
		button.text = text("CP_SELECT_ALL" if all else "CP_SELECT_NONE")
		button.pressed.connect(select_all.bind(all))
		actions.add_child(button)
	chance_label = Label.new()
	col.add_child(chance_label)
	chance = HSlider.new()
	chance.max_value = 100
	chance.step = 1
	chance.value_changed.connect(set_chance)
	col.add_child(chance)
	var close = Button.new()
	close.text = text("CP_DONE")
	close.pressed.connect(func(): editor.hide(); panel.show(); choices.contract.grab_focus())
	col.add_child(close)
	editor.hide()

func contract_text(id: int, detail: bool = false) -> String:
	var C = session.rules.Catalog.Contract
	if id == C.NO_CUFFS: return text("CP_MP_NO_JAMMER_DETAIL" if detail else "CP_MP_NO_JAMMER")
	if id == C.NO_INSURANCE: return text("CP_MP_INSURANCE_DETAIL" if detail else "CP_NO_INSURANCE")
	if id == C.TWO_FOR_ONE and detail: return text("CP_MP_DOUBLE_DETAIL")
	if id == C.LEAKY_GUN and detail: return text("CP_MP_LEAKY_DETAIL")
	return text(session.rules.Catalog.CATALOG[id].detail if detail else session.rules.Catalog.contract_key(id))

func refresh():
	if session == null or not is_instance_valid(status): return
	var values = session.rules.settings
	var editable = session.host() and not session.in_game and not session.loading
	edit_button.text = text("CP_EDIT_CONTRACTS")
	edit_button.visible = values.contract != 0
	for key in choices:
		var options = Labels[key][1]
		if key == "turn": options = ["CP_DEFAULT", "CP_MP_FIXED_FIRST", "CP_ROUND_ROBIN", "CP_RANDOM"]
		var value_key = options[values[key]]
		choices[key].text = text(Labels[key][0]) + ":\n" + (text(value_key) if value_key.begins_with("CP_") else tr(value_key))
		choices[key].tooltip_text = text("CP_MP_TIP_" + key.to_upper())
		choices[key].disabled = not editable
	var signature = str(GlobalSteam.LOBBY_MEMBERS) + TranslationServer.get_locale()
	if member_signature != signature:
		member_signature = signature
		first_player.clear()
		first_player.add_item(text("CP_MP_HOST"))
		first_player.set_item_metadata(0, 0)
		for member in GlobalSteam.LOBBY_MEMBERS:
			first_player.add_item(member.steam_name)
			first_player.set_item_metadata(first_player.item_count - 1, member.steam_id)
	for index in first_player.item_count:
		if first_player.get_item_metadata(index) == values.first_player: first_player.select(index)
	first_player.disabled = not editable or values.turn != 1
	var lines = []
	for member in GlobalSteam.LOBBY_MEMBERS:
		var peer = session.peers.get(member.steam_id, {})
		lines.append(member.steam_name + ": " + text("CP_MP_READY" if peer.get("ready", false) else ("CP_MP_VERIFIED" if peer.get("verified", false) else "CP_MP_CHECKING")))
	status.text = "\n".join(lines)
	if session.in_game: status.text = text("CP_MP_RULES_LOCKED")
	ready_button.text = text("CP_MP_READY_TOGGLE")
	ready_button.disabled = session.in_game or session.loading or session.session.is_empty()
	for id in checks:
		checks[id].text = contract_text(id)
		checks[id].tooltip_text = contract_text(id, true)
		checks[id].set_pressed_no_signal(id in values.contract_pool)
		checks[id].disabled = not editable
	chance.editable = editable
	chance.set_value_no_signal(values.contract_chance)
	chance_label.text = text("CP_CONTRACT_CHANCE", [values.contract_chance])
	var contracts = []
	if session.in_game and is_instance_valid(session.game):
		for p in session.game.instance_handler.instance_property_array:
			var entry = session.rules.state(p.socket_number)
			if entry.contract == 0: continue
			var name = contract_text(entry.contract)
			if entry.contract == session.rules.Catalog.Contract.NO_INSURANCE:
				if 2 in entry.history: name = text("CP_MP_NO_JAMMER")
				if 3 in entry.history: name = text("CP_MP_NO_GLASS")
			if entry.failed: name += " / " + text("CP_MP_FAILED")
			contracts.append(("> " if p.is_active else "") + p.user_name + ": " + name)
	hud.text = "\n".join(contracts) + ("\n" if not contracts.is_empty() else "")
	hud.reset_size()
	bomb.position = Vector2(308, hud.position.y + maxf(0, hud.size.y - 20))
	theft_targets.position.y = hud.position.y + hud.size.y + 12
	bomb.visible = not contracts.is_empty()
	var local = null
	if session.in_game and is_instance_valid(session.game):
		for p in session.game.instance_handler.instance_property_array:
			if p.is_active: local = p
	var candidates = []
	if local != null and local.is_stealing_item and values.items == 1:
		for p in session.game.instance_handler.instance_property_array:
			if p != local: candidates.append(p.socket_number)
	if candidates != target_ids:
		for child in theft_targets.get_children(): child.queue_free()
		target_ids = candidates
		for socket in candidates:
			var button = Button.new()
			button.text = text("CP_MP_REVEAL") + ": " + session.property_for(socket).user_name
			button.pressed.connect(func(): session.theft_target = socket)
			theft_targets.add_child(button)
			connect_button_audio(button)
		if not candidates.is_empty():
			session.theft_target = candidates[0]
			if local.cursor.controller_active: theft_targets.get_children().back().grab_focus()
	theft_targets.visible = not candidates.is_empty() and not shown
	if session.host() and is_instance_valid(session.lobby_ui) and not session.in_game:
		session.lobby_ui.ui_button_start_game.visible = session.can_start()

func cycle(key: String):
	var values = session.rules.settings.duplicate(true)
	values[key] = (values[key] + 1) % session.rules.LIMITS[key]
	session.change_settings(values)
	refresh()

func select_player(index: int):
	var values = session.rules.settings.duplicate(true)
	values.first_player = first_player.get_item_metadata(index)
	session.change_settings(values)

func select_contract(pressed: bool, id: int):
	var values = session.rules.settings.duplicate(true)
	if pressed and not id in values.contract_pool: values.contract_pool.append(id)
	if not pressed: values.contract_pool.erase(id)
	values.contract_pool.sort()
	session.change_settings(values)
	refresh()

func select_all(all: bool):
	if not session.host() or session.in_game: return
	var values = session.rules.settings.duplicate(true)
	values.contract_pool = session.rules.Catalog.ALL_IDS.duplicate() if all else []
	session.change_settings(values)
	refresh()

func set_chance(value: float):
	var values = session.rules.settings.duplicate(true)
	values.contract_chance = roundi(value)
	session.change_settings(values)
	refresh()

func open_editor():
	panel.hide()
	editor.show()
	checks.values()[0].grab_focus()

func toggle():
	shown = not shown
	editor.hide()
	panel.visible = shown
	backdrop.visible = shown
	if shown:
		choices.shells.grab_focus()
		if session.in_game and is_instance_valid(session.game):
			for p in session.game.instance_handler.instance_property_array:
				if p.is_active:
					blocked_raycast = weakref(p.mouse_raycast)
					raycast_state = p.mouse_raycast.getting_selection
					p.mouse_raycast.SetMouseRaycast(false)
	else:
		open_button.grab_focus()
		if blocked_raycast != null and blocked_raycast.get_ref() != null:
			blocked_raycast.get_ref().SetMouseRaycast(raycast_state)
		blocked_raycast = null

func _input(event):
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F8:
		toggle()
		get_viewport().set_input_as_handled()
		return
	if shown and (event.is_action_pressed("ui_cancel") or event.is_action_pressed("exit game")):
		if editor.visible:
			editor.hide()
			panel.show()
			choices.contract.grab_focus()
		else: toggle()
		get_viewport().set_input_as_handled()

# Match the native lobby's receipt font, green phosphor text and square focus.
func make_theme() -> Theme:
	var result = Theme.new()
	result.default_font = load("res://fonts/fake receipt.otf")
	result.default_font_size = 16
	var empty = StyleBoxFlat.new()
	empty.bg_color = Color(0, 0, 0, 0)
	empty.content_margin_left = 8
	empty.content_margin_right = 8
	empty.content_margin_top = 2
	empty.content_margin_bottom = 2
	var hover = empty.duplicate()
	hover.bg_color = Color(0, 0.12, 0)
	var focus = empty.duplicate()
	focus.set_border_width_all(1)
	focus.border_color = GREEN
	var frame = empty.duplicate()
	frame.bg_color = Color.BLACK
	frame.set_border_width_all(1)
	frame.border_color = DIM_GREEN
	frame.set_content_margin_all(14)
	result.set_stylebox("panel", "PanelContainer", frame)
	result.set_stylebox("panel", "PopupMenu", frame)
	result.set_stylebox("panel", "TooltipPanel", frame)
	for kind in ["Button", "OptionButton", "CheckBox", "PopupMenu", "Label", "TooltipLabel"]:
		result.set_color("font_color", kind, GREEN)
		result.set_color("font_hover_color", kind, GREEN)
		result.set_color("font_focus_color", kind, GREEN)
		result.set_color("font_pressed_color", kind, GREEN)
		result.set_color("font_hover_pressed_color", kind, GREEN)
		result.set_color("font_disabled_color", kind, DIM_GREEN)
		result.set_color("font_outline_color", kind, Color.BLACK)
		result.set_color("icon_normal_color", kind, GREEN)
		result.set_color("icon_hover_color", kind, GREEN)
		result.set_color("icon_pressed_color", kind, GREEN)
		result.set_color("icon_disabled_color", kind, DIM_GREEN)
		for state in ["normal", "disabled"]: result.set_stylebox(state, kind, empty)
		for state in ["hover", "pressed", "hover_pressed"]: result.set_stylebox(state, kind, hover)
		result.set_stylebox("focus", kind, focus)
	result.set_stylebox("hover", "PopupMenu", hover)
	var track = StyleBoxFlat.new()
	track.bg_color = Color(0, 0.22, 0)
	track.content_margin_top = 2
	track.content_margin_bottom = 2
	var fill = track.duplicate()
	fill.bg_color = GREEN
	result.set_constant("scrollbar_width", "ScrollContainer", 10)
	for kind in ["HSlider", "VScrollBar", "HScrollBar"]:
		result.set_stylebox("slider", kind, track)
		result.set_stylebox("scroll", kind, track)
		for state in ["grabber_area", "grabber_area_highlight", "grabber", "grabber_highlight", "grabber_pressed"]:
			result.set_stylebox(state, kind, fill)
	var handle = GradientTexture2D.new()
	handle.width = 8
	handle.height = 16
	handle.gradient = Gradient.new()
	handle.gradient.colors = PackedColorArray([GREEN, GREEN])
	for state in ["grabber", "grabber_highlight", "grabber_disabled"]:
		result.set_icon(state, "HSlider", handle)
	for checked in [false, true]:
		var image = Image.create(16, 16, false, Image.FORMAT_RGBA8)
		image.fill(Color.BLACK)
		for edge in [Rect2i(0, 0, 16, 2), Rect2i(0, 14, 16, 2), Rect2i(0, 0, 2, 16), Rect2i(14, 0, 2, 16)]:
			image.fill_rect(edge, GREEN)
		if checked: image.fill_rect(Rect2i(4, 4, 8, 8), GREEN)
		var icon = ImageTexture.create_from_image(image)
		result.set_icon("checked" if checked else "unchecked", "CheckBox", icon)
		result.set_icon("checked_disabled" if checked else "unchecked_disabled", "CheckBox", icon)
	return result

func connect_button_audio(node: Node):
	if node is BaseButton:
		node.mouse_entered.connect(play_menu_sound.bind(false))
		node.focus_entered.connect(play_menu_sound.bind(false))
		node.pressed.connect(play_menu_sound.bind(true))
	for child in node.get_children(): connect_button_audio(child)

func play_menu_sound(pressed: bool):
	if session.in_game or not is_instance_valid(session.lobby_ui): return
	var speaker = session.lobby_ui.speaker_button_press if pressed else session.lobby_ui.speaker_button_hover
	if is_instance_valid(speaker): speaker.play()

func _exit_tree():
	# The lobby entry belongs to the native home screen, so it follows its intro
	# and visibility; release it when this overlay is replaced within the scene.
	if is_instance_valid(lobby_button_parent) and is_instance_valid(open_button):
		open_button.queue_free()
