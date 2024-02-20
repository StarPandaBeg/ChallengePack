extends "res://mods-unpacked/StarPanda-HiddenShell/patches/patch.gd"

const STPND_HIDDENSHELL_LOG := "StarPanda-HiddenShell:MenuPatch"

enum Mode {
	DEFAULT,
	QUANTITY,
	HIDDEN
}
var modesTotal = len(Mode.keys())

var mode_button: ButtonClass
var mode_label: Node

func _init():
	scene_name = "menu"

func apply(root: Node) -> void:
	if (applied):
		return
	
	_move_exit_button(root)
	var label = _create_options_button_label(root)
	var logic = _create_options_button_real(root, label)
	_register_options_button_real(root, logic)
	_hide_mode_switch()
	
	ModLoaderLog.info("Applied menu patch!", STPND_HIDDENSHELL_LOG)
	
	applied = true
	
func _move_exit_button(root: Node):
	var optionsExitLabel = root.get_node("Camera/dialogue UI/menu ui/button_exit options")
	var optionsExitButton = root.get_node("Camera/dialogue UI/menu ui/true button_return options")
	optionsExitLabel.position.y += 50
	optionsExitButton.position.y += 50
	ModLoaderLog.debug("Original 'return' button moved", STPND_HIDDENSHELL_LOG)
	
func _create_options_button_label(root: Node) -> CanvasItem:
	var optionsModeLabel = Label.new()
	var parent = root.get_node("Camera/dialogue UI/menu ui")
	var font = load("res://fonts/fake receipt.otf")
	
	optionsModeLabel.size = Vector2(960, 35)
	optionsModeLabel.position = Vector2(7.802, 424)
	optionsModeLabel.scale = Vector2(0.76, 1)
	optionsModeLabel.pivot_offset = Vector2(480, 0)
	optionsModeLabel.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	
	optionsModeLabel.set("theme_override_colors/font_shadow_color", Color.BLACK)
	optionsModeLabel.set("theme_override_fonts/font", font)
	optionsModeLabel.set("theme_override_font_sizes/font_size", 26)
	
	parent.add_child(optionsModeLabel)
	mode_label = optionsModeLabel
	ModLoaderLog.debug("'Mode' label created", STPND_HIDDENSHELL_LOG)
	return optionsModeLabel
	
func _create_options_button_real(root: Node, label: CanvasItem) -> ButtonClass:
	var optionsModeButton = Button.new()
	var optionsModeButtonLogic = ButtonClass.new()
	var parent = root.get_node("Camera/dialogue UI/menu ui")
	var cursorManager = root.get_node("standalone managers/cursor manager")
	
	optionsModeButton.size = Vector2(8, 8)
	optionsModeButton.position = Vector2(300, 428)
	optionsModeButton.scale = Vector2(48, 3)
	optionsModeButton.modulate = Color.TRANSPARENT
	optionsModeButton.self_modulate = Color.TRANSPARENT
	
	optionsModeButtonLogic.cursor = cursorManager
	optionsModeButtonLogic.isDynamic = true
	optionsModeButtonLogic.playing = true
	optionsModeButtonLogic.ui = label
	optionsModeButtonLogic.speaker_press = root.get_node("speaker_press")
	optionsModeButtonLogic.speaker_hover = root.get_node("speaker_hover")
	optionsModeButtonLogic.name = "button class_hiddenshell_mode"
	
	optionsModeButton.add_child(optionsModeButtonLogic)
	parent.add_child(optionsModeButton)
	
	ModLoaderLog.debug("'Mode' real button created", STPND_HIDDENSHELL_LOG)
	
	mode_button = optionsModeButtonLogic	
	return optionsModeButtonLogic
	
func _register_options_button_real(root: Node, button: ButtonClass):
	var optionsMenuButton = root.get_node("Camera/dialogue UI/menu ui/true button_options/button class_options")
	var optionsExitButton = root.get_node("Camera/dialogue UI/menu ui/true button_return options/button class_return options")
	
	button.connect("is_pressed", _change_mode)
	optionsMenuButton.connect("is_pressed", _show_mode_switch)
	optionsExitButton.connect("is_pressed", _hide_mode_switch)
	ModLoaderLog.debug("'Mode' real button registered", STPND_HIDDENSHELL_LOG)
	
func _change_mode():
	var current_mode_s = ProjectSettings.get_setting("hiddenshell_mode", "DEFAULT")
	var current_mode = Mode.get(current_mode_s)	
	var new_mode = current_mode + 1 if (current_mode + 1 < modesTotal) else 0
	var new_mode_s = Mode.keys()[new_mode]
	
	ProjectSettings.set_setting("hiddenshell_mode", new_mode_s)
	mode_label.text = "shell visibility: " + new_mode_s
	ModLoaderLog.info("New mode: " + new_mode_s, STPND_HIDDENSHELL_LOG)
	
func _show_mode_switch():
	var current_mode_s = ProjectSettings.get_setting("hiddenshell_mode", "DEFAULT")	
	mode_label.text = "shell visibility: " + current_mode_s
	mode_button.ui.visible = true
	mode_button.isActive = true
	mode_button.SetFilter("stop")
	
func _hide_mode_switch():
	mode_button.ui.visible = false
	mode_button.isActive = false
	mode_button.SetFilter("ignore")

