extends VBoxContainer

const Card = preload("../challenge_hud.gd")
var resources
var directory: String
var cards = {}
var counter: PanelContainer
var previous = ""

func _init():
	position = Vector2(8, 8)
	custom_minimum_size.x = 264
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_theme_constant_override("separation", 4)
	hide()

func setup(mod_directory: String, cache = null):
	resources = cache
	directory = mod_directory
	counter = Card.new()
	add_child(counter)
	counter.rule.hide()
	counter.bomb.hide()
	counter.hide()

func make_card() -> PanelContainer:
	var card = Card.new()
	card.custom_minimum_size.x = 264
	add_child(card)
	card.setup(directory, resources)
	var column = card.get_child(0)
	var heading = HBoxContainer.new()
	heading.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(heading)
	column.move_child(heading, 0)
	var owner_label = card.label(heading, 11, Card.MUTED)
	owner_label.name = "Owner"
	owner_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	owner_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	card.bomb.reparent(heading)
	card.bomb.custom_minimum_size = Vector2(14, 14)
	card.bomb.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var hint = card.label(column, 11, Card.MUTED)
	hint.name = "Hint"
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.move_child(hint, 2)
	# Pocket usage has its own shared footer; each contract only needs three lines.
	card.pocket.get_parent().hide()
	card.set_meta("owner_label", owner_label)
	card.set_meta("hint_label", hint)
	return card

func refresh_multiplayer(rows: Array, remaining: int, limit: int, localization):
	var signature = str(rows) + str([remaining, limit]) + TranslationServer.get_locale()
	if signature == previous: return
	previous = signature
	var active = []
	for i in rows.size():
		var entry = rows[i]
		active.append(entry.id)
		if not cards.has(entry.id): cards[entry.id] = make_card()
		var card = cards[entry.id]
		move_child(card, i)
		card.show()
		var owner_label = card.get_meta("owner_label")
		owner_label.text = ("> " if entry.own else "") + entry.owner
		owner_label.add_theme_color_override("font_color", Card.INK if entry.own else Card.MUTED)
		card.rule.text = entry.title
		card.rule.add_theme_color_override("font_color", Color("c97b6d") if entry.failed else Card.INK)
		card.get_meta("hint_label").text = entry.hint
		card.bomb.show()
		var background = card.get_theme_stylebox("panel").duplicate()
		background.border_color = Color("c9ad7f") if entry.own else Color("706251")
		card.add_theme_stylebox_override("panel", background)
	for id in cards.keys():
		if id not in active:
			var card = cards[id]
			remove_child(card)
			card.queue_free()
			cards.erase(id)
	move_child(counter, get_child_count() - 1)
	counter.visible = limit > 0
	counter.pocket.visible = limit > 0
	if limit > 0: counter.pocket.text = localization.text("CP_HUD_POCKET_SHORT", [remaining, limit])
	visible = not rows.is_empty() or limit > 0
	size = Vector2(264, 0)
