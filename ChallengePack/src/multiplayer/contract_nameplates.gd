extends Node

var labels = {}
var texture: Texture2D

func setup(directory: String):
	var image = Image.load_from_file(directory.path_join("assets/contracts/c4.png"))
	if image != null: texture = ImageTexture.create_from_image(image)

func refresh(players: Array, rows: Array):
	var active = []
	for row in rows:
		var player = null
		for candidate in players:
			if candidate.socket_number == row.id: player = candidate
		if player == null or player.is_active or player.health_current <= 0: continue
		var source = player.state_manager.nametag
		if not is_instance_valid(source): continue
		active.append(row.id)
		if labels.has(row.id) and (not is_instance_valid(labels[row.id]) or labels[row.id].get_parent() != source):
			remove(row.id)
		if not labels.has(row.id):
			# Inherit the native name's transform, visibility and lifecycle. Copy
			# its font/render settings, but not its transform a second time.
			var label = source.duplicate(0) as Label3D
			for child in label.get_children(): child.free()
			label.name = "ChallengePackContract"
			label.transform = Transform3D.IDENTITY
			label.offset = Vector2.ZERO
			label.position.y = source.pixel_size * (source.font_size + source.outline_size * 2) * 1.25
			source.add_child(label)
			var bomb = Sprite3D.new()
			bomb.name = "Bomb"
			bomb.texture = texture
			bomb.billboard = source.billboard
			bomb.no_depth_test = source.no_depth_test
			bomb.fixed_size = source.fixed_size
			bomb.shaded = source.shaded
			bomb.modulate = Color("c97b6d")
			if texture != null:
				bomb.pixel_size = source.pixel_size * source.font_size * 0.8 / texture.get_width()
			label.add_child(bomb)
			labels[row.id] = label
		var label = labels[row.id]
		label.text = row.title
		label.modulate = Color("c97b6d") if row.failed else source.modulate
		label.show()
		var width = label.font.get_string_size(label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, label.font_size).x
		label.get_node("Bomb").position.x = -(width * 0.5 + label.font_size * 0.65) * label.pixel_size
	for id in labels.keys():
		if id not in active: remove(id)

func remove(id: int):
	if is_instance_valid(labels[id]):
		labels[id].hide()
		labels[id].queue_free()
	labels.erase(id)

func _exit_tree():
	for id in labels.keys(): remove(id)
