extends PanelContainer

const INK = Color("e4d5ba")
const MUTED = Color("a79e8e")
const TITLES = ["CP_OFF", "CP_HUD_NO_HEALING", "CP_HUD_NO_SELF_SHOTS", "CP_HUD_NO_CUFFS"]
var rule: Label
var pocket: Label
var previous = ""

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
	background.content_margin_top = 5
	background.content_margin_bottom = 5
	add_theme_stylebox_override("panel", background)
	var column = VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_theme_constant_override("separation", 2)
	add_child(column)
	rule = label(column, 14, INK)
	rule.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	pocket = label(column, 12, MUTED)
	hide()

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
		return
	var contract: int = data.paused if data.paused != 0 else data.contract
	var paused: bool = data.paused != 0
	rule.visible = contract != 0
	if contract != 0:
		var title = localization.text(TITLES[contract])
		rule.text = localization.text("CP_HUD_RULE_PAUSED" if paused else "CP_HUD_RULE", [title])
		rule.add_theme_color_override("font_color", MUTED if paused else INK)
	pocket.visible = data.limit > 0
	if data.limit > 0:
		pocket.text = localization.text("CP_HUD_POCKET_SHORT", [data.remaining, data.limit])
	size = Vector2(224, 0)
