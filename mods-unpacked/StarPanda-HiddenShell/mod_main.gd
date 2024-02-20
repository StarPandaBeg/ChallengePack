extends Node

const STPND_HIDDENSHELL_DIR := "StarPanda-HiddenShell"
const STPND_HIDDENSHELL_LOG := "StarPanda-HiddenShell:Main"

var mod_dir_path := ""
var patches_dir_path := ""

var patches := {}

func _init() -> void:
	mod_dir_path = ModLoaderMod.get_unpacked_dir() + STPND_HIDDENSHELL_DIR
	add_patches()
	
func add_patches() -> void:
	patches_dir_path = mod_dir_path + "/patches"
	
	var dir = DirAccess.open(patches_dir_path)
	for file in dir.get_files():
		if (file == "patch.gd"):
			continue
		var cl = load(patches_dir_path + "/" + file)
		var obj = cl.new()
		ModLoaderLog.info("Found patch for scene '" + obj.getSceneName() + "': " + file, STPND_HIDDENSHELL_LOG)
		
		if !(patches.has(obj.getSceneName())):
			patches[obj.getSceneName()] = []
		patches[obj.getSceneName()].append(obj)

func _ready() -> void:
	ModLoaderLog.info("Ready!", STPND_HIDDENSHELL_LOG)
	
func _process(delta):
	var scene := get_scene_root()
	if !(patches.has(scene.name)):
		return
	
	var patchArr = patches[scene.name]
	for patch in patchArr:
		patch.apply(scene)
		
func get_scene_root() -> Node:
	return get_tree().get_root().get_child(2)
