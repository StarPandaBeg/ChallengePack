extends Node3D

signal deployment_finished

const RISE_DELAY = 0.45
const RISE_DURATION = 1.1
const RETRACT_DEPTH = 4.0
const SLIDE_SOUND = "res://audio/main compartment show items.ogg"
var raised_position: Vector3
var started = false
var deployed = false
var rising = false
var covered = true
var motion: Tween
var speaker: AudioStreamPlayer3D

func _ready():
	raised_position = position
	position.y -= RETRACT_DEPTH
	hide()
	speaker = AudioStreamPlayer3D.new()
	speaker.name = "Protector mechanism"
	speaker.stream = load(SLIDE_SOUND)
	speaker.volume_db = 0
	speaker.unit_size = 12
	speaker.max_distance = 60
	add_child(speaker)

func deploy():
	if started:
		return
	started = true
	motion = create_tween()
	motion.tween_interval(RISE_DELAY)
	motion.tween_callback(begin_motion)
	motion.tween_property(self, "position:y", raised_position.y, RISE_DURATION).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	motion.tween_callback(finish_motion)

func begin_motion():
	rising = true
	visible = covered
	speaker.play()

func finish_motion():
	position = raised_position
	deployed = true
	rising = false
	visible = covered
	speaker.stop()
	deployment_finished.emit()

func wait_until_deployed() -> bool:
	deploy()
	if not deployed:
		await deployment_finished
	return deployed

func _exit_tree():
	if motion != null and motion.is_valid():
		motion.kill()
	if started and not deployed:
		# Release waiting round setup when a scene is removed during the effect.
		deployment_finished.emit()

func set_covered(value: bool):
	covered = value
	# Theft changes only visibility, never the entry animation or its position.
	visible = value and (rising or deployed)
