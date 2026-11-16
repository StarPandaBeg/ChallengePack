extends RefCounted

const Contracts = preload("../domain/contracts.gd")
var read: Callable
var write: Callable
var limits: Dictionary

func _init(reader: Callable, writer: Callable, option_limits: Dictionary):
	read = reader
	write = writer
	limits = option_limits.duplicate()

func values() -> Dictionary: return read.call().duplicate(true)

func set_value(key: String, value) -> Error:
	var next = values()
	if not next.has(key): return ERR_INVALID_PARAMETER
	next[key] = value
	var result = write.call(next)
	return OK if result == null else result

func cycle(key: String) -> Error:
	if not limits.has(key): return ERR_INVALID_PARAMETER
	return set_value(key, (values()[key] + 1) % limits[key])

func toggle_contract(pressed: bool, id: int) -> Error:
	var pool = values().contract_pool
	if pressed and not id in pool: pool.append(id)
	if not pressed: pool.erase(id)
	pool.sort()
	return set_value("contract_pool", pool)

func select_all(selected: bool) -> Error:
	return set_value("contract_pool", Contracts.ALL_IDS if selected else [])
