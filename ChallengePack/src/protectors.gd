extends Node3D

signal deployment_finished

const RISE_DELAY = 0.45
const RISE_DURATION = 1.1
const RETRACT_DEPTH = 4.0
const SLIDE_SOUND = "res://audio/main compartment show items.ogg"
const HIDDEN_ITEM = "challengepack_hidden_item"
const ITEM_IN_USE = "challengepack_item_in_use"
var item_manager: Node
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
	if item_manager != null and item_manager.itemSpawnParent != null:
		item_manager.itemSpawnParent.child_entered_tree.connect(sync_item)
		sync_inventory()

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
	sync_inventory()

func sync_inventory():
	if item_manager == null or item_manager.itemSpawnParent == null:
		return
	for item in item_manager.itemSpawnParent.get_children():
		sync_item(item)

func sync_item(item: Node):
	if not item is Node3D or item.is_queued_for_deletion() or item.get_child_count() < 2:
		return
	var indicator = item.get_child(0)
	var branch = item.get_child(1)
	# Player intake instances are also not on the player's grid until placed.
	if not indicator is PickupIndicator or not indicator.isDealerItem or not branch is InteractionBranch or branch.isPlayerSide:
		return
	if item.get_meta(ITEM_IN_USE, false):
		return
	if covered:
		if not item.has_meta(HIDDEN_ITEM):
			item.set_meta(HIDDEN_ITEM, item.visible)
		item.hide()
	else:
		restore_item(item)

static func restore_item(item: Node3D):
	if item.has_meta(HIDDEN_ITEM):
		item.visible = item.get_meta(HIDDEN_ITEM)
		item.remove_meta(HIDDEN_ITEM)

static func reveal_item(item: Node3D):
	# Pickup may close the theft UI before its movement animation has finished.
	item.set_meta(ITEM_IN_USE, true)
	restore_item(item)
