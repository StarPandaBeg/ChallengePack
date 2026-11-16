extends RefCounted

var _values: Dictionary

func _init(values: Dictionary):
	_values = values.duplicate(true)

func to_dictionary() -> Dictionary:
	return _values.duplicate(true)
