extends RefCounted

var port: Node
var rng = RandomNumberGenerator.new()

func _init(owner_port: Node):
	port = owner_port
	rng.randomize()

func seed_charge(spawner: Node):
	if port.active.get("heal", 0) == 0 or rng.randf() >= float(port.active.get("heal_chance", 30)) / 100.0:
		return
	var blanks = []
	for i in range(spawner.sequenceArray.size()):
		if spawner.sequenceArray[i] == "blank":
			blanks.append(i)
	if blanks.is_empty():
		return
	var index = blanks[rng.randi_range(0, blanks.size() - 1)]
	spawner.sequenceArray[index] = "heal"
	if port.active.shells == 0:
		var branch = spawner.spawnedShellObjectArray[index].get_child(0)
		branch.mesh.set_surface_override_material(1, material(branch.mat_blank))

func material(base: StandardMaterial3D, shell: String = "heal") -> StandardMaterial3D:
	var result = base.duplicate() as StandardMaterial3D
	result.albedo_color = Color("101010") if shell == "lethal" else Color("37ba59")
	return result

func invert(shell: String) -> String:
	return {"live": "blank", "blank": "live", "heal": "lethal", "lethal": "heal"}.get(shell, shell)

func damage(manager: Node, target: String) -> int:
	if manager.shellSpawner.sequenceArray[0] == "lethal":
		return maxi(1, manager.health_player if target == "player" else manager.health_opponent)
	return port.challenges.shot_strength(manager)

func composition(sequence: Array) -> String:
	return port.localization.text("CP_HEAL_COMPOSITION", [sequence.count("live"), sequence.count("blank"), sequence.count("heal")])

func audio_indicators(spawner: Node):
	await port.get_tree().create_timer(0.37, false).timeout
	if not is_instance_valid(spawner):
		return
	var original_pitch: float = spawner.speaker_audioIndicator.pitch_scale
	for shell in spawner.seq:
		spawner.speaker_audioIndicator.stream = spawner.soundArray_indicators[1 if shell == "live" else 0]
		spawner.speaker_audioIndicator.pitch_scale = original_pitch * (1.35 if shell == "heal" else 1.0)
		spawner.speaker_audioIndicator.play()
		await port.get_tree().create_timer(0.07, false).timeout
		if not is_instance_valid(spawner):
			return
	spawner.speaker_audioIndicator.pitch_scale = original_pitch

func apply(manager: Node, target: String, counter: Node):
	# Match cigarette healing: no revival or restoring a severed defibrillator.
	var player = target == "player"
	var health_key = "health_player" if player else "health_opponent"
	var wire_cut = manager.wireIsCut_player if player else manager.wireIsCut_dealer
	var health: int = manager.get(health_key)
	var maximum: int = manager.roundArray[0].startingHealth
	if health > 0 and not wire_cut and health < maximum:
		manager.set(health_key, mini(maximum, health + port.challenges.shot_strength(manager)))
		counter.UpdateDisplay()
		if counter.speaker_beep != null:
			counter.speaker_beep.play()

func infer_shell(ai: Node) -> bool:
	var sequence = ai.shellSpawner.sequenceArray
	if sequence.is_empty():
		return false
	if ai.sequenceArray_knownShell[0]:
		return true
	# Deduce only from the known composition and genuinely remembered shells.
	var unseen = {"live": sequence.count("live"), "blank": sequence.count("blank"), "heal": sequence.count("heal"), "lethal": sequence.count("lethal")}
	for i in range(sequence.size()):
		if ai.sequenceArray_knownShell[i]:
			unseen[sequence[i]] -= 1
	var types_left = 0
	for count in unseen.values():
		if count > 0:
			types_left += 1
	return types_left == 1
