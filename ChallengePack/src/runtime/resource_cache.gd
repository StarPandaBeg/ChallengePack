extends RefCounted

var _textures: Dictionary = {}
var _sounds: Dictionary = {}

func texture(path: String) -> Texture2D:
	if not _textures.has(path):
		var image = Image.load_from_file(path)
		_textures[path] = ImageTexture.create_from_image(image) if image != null else null
	return _textures[path]

func sound(path: String) -> AudioStreamWAV:
	if not _sounds.has(path): _sounds[path] = decode_pcm(path)
	return _sounds[path]

static func decode_pcm(path: String) -> AudioStreamWAV:
	# Godot 4.1 has no runtime OGG/WAV loader. Read our prepared 16-bit PCM
	# directly so release assets need neither .import files nor the editor.
	var file = FileAccess.open(path, FileAccess.READ)
	if file == null or file.get_buffer(4).get_string_from_ascii() != "RIFF":
		return null
	file.get_32()
	if file.get_buffer(4).get_string_from_ascii() != "WAVE":
		return null
	var sound = AudioStreamWAV.new()
	var valid_format = false
	while file.get_position() + 8 <= file.get_length():
		var chunk = file.get_buffer(4).get_string_from_ascii()
		var length = file.get_32()
		var start = file.get_position()
		if start + length > file.get_length():
			return null
		if chunk == "fmt " and length >= 16:
			var format = file.get_16()
			var channels = file.get_16()
			sound.mix_rate = file.get_32()
			file.get_32()
			file.get_16()
			valid_format = format == 1 and channels in [1, 2] and file.get_16() == 16
			sound.stereo = channels == 2
			sound.format = AudioStreamWAV.FORMAT_16_BITS
		elif chunk == "data":
			sound.data = file.get_buffer(length)
		file.seek(start + length + length % 2)
	return sound if valid_format and not sound.data.is_empty() else null
