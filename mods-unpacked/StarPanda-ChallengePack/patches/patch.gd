class_name ScenePatch

var scene_name: String = ""
var applied: bool = false
var repeatable: bool = false
var once: bool = false

func getSceneName() -> String:
	return scene_name
	
func apply(root: Node, repeated: bool = false) -> void:
	if (applied && once):
		return
	if (applied && !repeatable && repeated):
		return
		
	if (applied and !repeated):
		applied = false
	if (applied and repeatable && repeated):
		applied = false
	applied = _apply(root)
	
func _apply(root: Node) -> bool:
	return true
