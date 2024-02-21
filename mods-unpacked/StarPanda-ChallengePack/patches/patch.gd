class_name ScenePatch

var scene_name: String = ""
var applied: bool = false

func getSceneName() -> String:
	return scene_name
	
func apply(root: Node) -> void:
	if (applied):
		return
	applied = _apply(root)
	
func _apply(root: Node) -> bool:
	return true