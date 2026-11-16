extends PanelContainer

const INK = Color("e4d5ba")
const MUTED = Color("a79e8e")
const Contracts = preload("challenges.gd")
var rule: Label
var pocket: Label
var previous = ""
var bomb: TextureRect

func _init():
	position = Vector2(8, 8)
	custom_minimum_size.x = 224
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var background = StyleBoxFlat.new()
	background.bg_color = Color(0.035, 0.03, 0.025, 0.8)
	background.border_color = Color("706251")
	background.border_width_left = 2
	background.content_margin_left = 8
	background.content_margin_right = 8
	background.content_margin_top = 4
	background.content_margin_bottom = 4
	add_theme_stylebox_override("panel", background)
	var column = VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_theme_constant_override("separation", 2)
	add_child(column)
	rule = label(column, 13, INK)
	rule.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var row = HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 6)
	column.add_child(row)
	pocket = label(row, 12, MUTED)
	pocket.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var spacer = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(spacer)
	bomb = TextureRect.new()
	bomb.custom_minimum_size = Vector2(18, 18)
	bomb.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bomb.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	bomb.size_flags_vertical = Control.SIZE_SHRINK_END
	bomb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bomb.modulate = Color("c97b6d")
	row.add_child(bomb)
	bomb.hide()
	hide()

func setup(directory: String):
	var image = Image.load_from_file(directory.path_join("assets/contracts/c4.png"))
	if image != null:
		bomb.texture = ImageTexture.create_from_image(image)

func label(parent: Node, font_size: int, color: Color) -> Label:
	var result = Label.new()
	result.mouse_filter = Control.MOUSE_FILTER_IGNORE
	result.add_theme_font_size_override("font_size", font_size)
	result.add_theme_color_override("font_color", color)
	parent.add_child(result)
	return result

func refresh(data: Dictionary, localization):
	var signature = str(data) + TranslationServer.get_locale()
	if signature == previous:
		return
	previous = signature
	visible = not data.is_empty()
	if not visible:
		bomb.hide()
		return
	var contract: int = data.paused if data.paused != 0 else data.contract
	var paused: bool = data.paused != 0
	bomb.visible = data.contract != 0 and not paused
	rule.visible = contract != 0
	if contract != 0:
		var title = localization.text(data.get("hud_key", Contracts.hud_key(contract)))
		rule.text = localization.text("CP_HUD_RULE_PAUSED" if paused else "CP_HUD_RULE", [title])
		rule.add_theme_color_override("font_color", MUTED if paused else INK)
	pocket.visible = data.limit > 0
	if data.limit > 0:
		pocket.text = localization.text("CP_HUD_POCKET_SHORT", [data.remaining, data.limit])
	size = Vector2(224, 0)

func refresh_multiplayer(rows: Array, remaining: int, limit: int, localization):
	var signature = "mp:" + str(rows) + str([remaining, limit]) + TranslationServer.get_locale()
	if signature == previous: return
	previous = signature
	visible = not rows.is_empty() or limit > 0
	rule.visible = not rows.is_empty()
	rule.text = "\n".join(rows)
	rule.add_theme_color_override("font_color", INK)
	pocket.visible = limit > 0
	if limit > 0: pocket.text = localization.text("CP_HUD_POCKET_SHORT", [remaining, limit])
	bomb.visible = not rows.is_empty()
	size = Vector2(264, 0)
