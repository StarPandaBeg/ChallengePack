class_name CPModConfig

const ROOT_DIR_NAME := "StarPanda-ChallengePack"

static var loaded := false
static var manifest : Dictionary

static func get_version() -> String:
	_load()
	if (!loaded):
		return "-"
	return manifest["version_number"]
	
static func get_root_path() -> String:
	return ModLoaderMod.get_unpacked_dir() + ROOT_DIR_NAME

static func _load() -> void:
	if (loaded):
		return
	var manifest_path = get_root_path() + "/manifest.json"
	var manifest_text = FileAccess.get_file_as_string(manifest_path)
	manifest = JSON.parse_string(manifest_text)
	loaded = true
