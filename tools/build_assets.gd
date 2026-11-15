extends SceneTree

func _initialize():
	var repo = ProjectSettings.globalize_path("res://").trim_suffix("/").get_base_dir()
	var source = repo.path_join("assets/protectors")
	var output = repo.path_join("ChallengePack/src/assets")
	DirAccess.make_dir_recursive_absolute(output)
	var vertices = []
	var normals = []
	var uvs = []
	var surface = SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for line in FileAccess.get_file_as_string(source.path_join("protector.obj")).split("\n"):
		var parts = line.strip_edges().split(" ", false)
		if parts.is_empty():
			continue
		match parts[0]:
			"v": vertices.append(Vector3(float(parts[1]), float(parts[2]), float(parts[3])))
			"vn": normals.append(Vector3(float(parts[1]), float(parts[2]), float(parts[3])))
			"vt": uvs.append(Vector2(float(parts[1]), 1.0 - float(parts[2])))
			"f":
				for i in range(2, parts.size() - 1):
					# OBJ is counterclockwise; Godot uses clockwise front faces.
					for index in [1, i + 1, i]:
						var face = parts[index].split("/")
						surface.set_normal(normals[int(face[2]) - 1])
						surface.set_uv(uvs[int(face[1]) - 1])
						surface.add_vertex(vertices[int(face[0]) - 1])
	var mesh = surface.commit()
	assert(mesh != null and mesh.get_surface_count() == 1)
	var parent = Node3D.new()
	parent.name = "Protectors"
	parent.scale = Vector3(1.2, 1.3, 1)
	for i in range(2):
		var cover = MeshInstance3D.new()
		cover.name = "Protector " + ("A" if i == 0 else "B")
		cover.mesh = mesh
		var image = Image.load_from_file(source.path_join("protector_base_%s.png" % ("a" if i == 0 else "b")))
		assert(image != null)
		var material = StandardMaterial3D.new()
		material.albedo_texture = ImageTexture.create_from_image(image)
		cover.material_override = material
		cover.transform = Transform3D(Vector3(0, 0, 3), Vector3(0, 2, 0), Vector3(-2.8, 0, 0), Vector3(-4.198, 0.1, 5.254 if i == 0 else -5.254))
		# Turn each cover in place so its opening faces the dealer.
		cover.basis = Basis(Vector3.UP, PI) * cover.basis
		parent.add_child(cover)
		cover.owner = parent
	var scene = PackedScene.new()
	assert(scene.pack(parent) == OK)
	assert(ResourceSaver.save(scene, output.path_join("protectors.res"), ResourceSaver.FLAG_COMPRESS | ResourceSaver.FLAG_BUNDLE_RESOURCES) == OK)
	parent.free()
	print("CP_ASSETS_OK: standalone mesh and textures bundled")
	quit()
