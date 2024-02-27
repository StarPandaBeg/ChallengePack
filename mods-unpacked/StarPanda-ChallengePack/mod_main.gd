extends Node

const STPND_CHALLENGEPACK_DIR := "StarPanda-ChallengePack"
const STPND_CHALLENGEPACK_LOG := "StarPanda-ChallengePack:Main"

var mod_dir_path := ""
var patches_dir_path := ""

var patches := {}
var last_scene := ""

func _init() -> void:
	mod_dir_path = ModLoaderMod.get_unpacked_dir() + STPND_CHALLENGEPACK_DIR
	add_patches()
	
func add_patches() -> void:
	patches_dir_path = mod_dir_path + "/patches"
	
	var dir = DirAccess.open(patches_dir_path)
	for file in dir.get_files():
		if (file == "patch.gd"):
			continue
		var cl = load(patches_dir_path + "/" + file)
		var obj = cl.new()
		ModLoaderLog.info("Found patch for scene '" + obj.getSceneName() + "': " + file, STPND_CHALLENGEPACK_LOG)
		
		if !(patches.has(obj.getSceneName())):
			patches[obj.getSceneName()] = []
		patches[obj.getSceneName()].append(obj)

func _ready() -> void:
	ModLoaderLog.info("Ready!", STPND_CHALLENGEPACK_LOG)
	
func _process(delta):
	var scene := get_scene_root()
	if !(patches.has(scene.name)):
		return
		
	var repeated = (last_scene == scene.name)
	last_scene = scene.name
		
	var patchArr = patches[scene.name]
	for patch in patchArr:
		patch.apply(scene, repeated)
		
func get_scene_root() -> Node:
	return get_tree().get_root().get_child(2)
