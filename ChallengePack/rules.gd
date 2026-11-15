extends RefCounted

var last_starter = 1
var dealer_message_shown = false
var rng = RandomNumberGenerator.new()

func _init():
	rng.randomize()

func next_starter(mode: int) -> int:
	var starter = 0
	if mode == 1:
		starter = 1 - last_starter
	elif mode == 2:
		starter = rng.randi_range(0, 1)
	last_starter = starter
	return starter
