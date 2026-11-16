extends CanvasLayer

# Presentation only: never call Shoot/Kill, consume a shell or enter revival.
var port: Node
var armed: AudioStreamPlayer
var breach: AudioStreamPlayer
var gunshot: AudioStreamPlayer
var blackout: ColorRect
var executing = false
var previous_paused = false
var sequence = 0
var participants = []
var owner_ref: WeakRef
var owner_exit: Callable
var fade: Tween

func setup(owner_port: Node):
	port = owner_port
	layer = 128
	process_mode = Node.PROCESS_MODE_ALWAYS
	armed = speaker("armed.wav", -9)
	breach = speaker("breach.wav", -6)
	gunshot = speaker("", 0)
	blackout = ColorRect.new()
	blackout.color = Color(0, 0, 0, 0)
	blackout.mouse_filter = Control.MOUSE_FILTER_IGNORE
	blackout.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(blackout)

func speaker(filename: String, volume: float) -> AudioStreamPlayer:
	var result = AudioStreamPlayer.new()
	if not filename.is_empty():
		result.stream = load_pcm(port.mod_directory.path_join("assets/contracts/" + filename))
	result.volume_db = volume
	add_child(result)
	return result

static func load_pcm(path: String) -> AudioStreamWAV:
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

func announce(manager: Node):
	if executing:
		return
	armed.bus = manager.shellLoader.speaker_loadShell.bus
	armed.play()

func allow_during_pause(node: Node):
	if node == null:
		return
	for entry in participants:
		if entry.ref.get_ref() == node:
			return
	participants.append({"ref": weakref(node), "mode": node.process_mode})
	node.process_mode = Node.PROCESS_MODE_ALWAYS

func valid_sequence(ticket: int) -> bool:
	return executing and ticket == sequence and owner_ref != null and owner_ref.get_ref() != null

func execute(manager: Node, key: String):
	if executing or port.failure_screen.shown:
		return
	var shooting = manager.dealerAI.shotgunShooting if manager.dealerAI != null else null
	# Incomplete fixtures or missing scene references still get a usable result.
	if shooting == null or shooting.animator_shotgun == null:
		port.failure_screen.open(key)
		return
	executing = true
	sequence += 1
	var ticket = sequence
	owner_ref = weakref(manager)
	owner_exit = owner_exiting
	manager.tree_exiting.connect(owner_exit, CONNECT_ONE_SHOT)
	previous_paused = get_tree().paused
	get_tree().paused = true
	port.challenge_hud.hide()
	port.notice_until = 0
	port.notice_label.hide()
	armed.stop()
	breach.bus = shooting.speaker_live.bus
	breach.play()
	if shooting.btnParent_shootingChoice != null:
		shooting.btnParent_shootingChoice.hide()
	if shooting.decisionText != null:
		shooting.decisionText.SetUI(false)
	if shooting.shotgunshaker != null and shooting.shotgunshaker.shaking:
		shooting.shotgunshaker.StopShaking()
	var animator: AnimationPlayer = shooting.animator_shotgun
	allow_during_pause(animator)
	allow_during_pause(shooting.camera)
	allow_during_pause(shooting.cameraShaker)
	allow_during_pause(shooting.animator_muzzleFlash)
	allow_during_pause(shooting.animator_muzzleFlash_model)
	# Animation audio tracks need their original speakers to process while paused.
	for name in ["player grab shotgun", "player shoot self"]:
		var animation = animator.get_animation(name)
		if animation == null:
			continue
		for track in animation.get_track_count():
			if animation.track_get_type(track) == Animation.TYPE_AUDIO:
				var root = animator.get_node(animator.root_node)
				allow_during_pause(root.get_node_or_null(animation.track_get_path(track)))
	shooting.camera.BeginLerp("enemy")
	animator.play("player grab shotgun")
	await get_tree().create_timer(0.65, true).timeout
	if not valid_sequence(ticket):
		return
	animator.play("player shoot self")
	await get_tree().create_timer(2.5, true).timeout
	if not valid_sequence(ticket):
		return
	# Use the game's live-shot sound regardless of the real chamber contents.
	gunshot.stream = shooting.speaker_live.stream
	gunshot.bus = shooting.speaker_live.bus
	gunshot.volume_db = shooting.speaker_live.volume_db
	gunshot.play()
	shooting.animator_muzzleFlash.play("muzzle flash fire")
	shooting.animator_muzzleFlash_model.play("fire")
	shooting.cameraShaker.Shake()
	blackout.color = Color(0.5, 0.03, 0.02, 0.4)
	fade = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	fade.tween_property(blackout, "color", Color.BLACK, 0.35)
	await get_tree().create_timer(0.7, true).timeout
	if not valid_sequence(ticket):
		return
	finish()
	port.failure_screen.open(key)

func restore_participants():
	for entry in participants:
		var node = entry.ref.get_ref()
		if node != null:
			node.process_mode = entry.mode
	participants.clear()

func finish():
	if owner_ref != null:
		var manager = owner_ref.get_ref()
		if manager != null and manager.tree_exiting.is_connected(owner_exit):
			manager.tree_exiting.disconnect(owner_exit)
	owner_ref = null
	if fade != null:
		fade.kill()
	blackout.color = Color(0, 0, 0, 0)
	restore_participants()
	executing = false
	get_tree().paused = previous_paused

func cancel():
	sequence += 1
	armed.stop()
	breach.stop()
	gunshot.stop()
	if executing:
		finish()

func owner_exiting():
	# CONNECT_ONE_SHOT removes itself after emission; do not disconnect it twice.
	owner_ref = null
	cancel()

func _input(event):
	if executing and (event.is_action_pressed("ui_cancel") or event.is_action_pressed("exit game") or event.is_action_pressed("ui_accept")):
		get_viewport().set_input_as_handled()

func _exit_tree():
	cancel()
