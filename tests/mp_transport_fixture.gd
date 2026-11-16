extends "../ChallengePack/src/multiplayer/session.gd"

# In-memory transport: no Steam packets or lobby changes in protocol tests.
var local_host = true
var test_members = [11, 22]
var outbox = []
var stopped = ""
var rejected = []
var penalties = 0

func host() -> bool: return local_host
func ids() -> Array: return test_members

func send(alias: String, payload: Dictionary = {}, target: int = 0):
	outbox.append({"target": target, "packet": message(alias, payload).duplicate(true)})

func fail(reason: String):
	blocked = true
	stopped = reason

func reject_peer(id: int): rejected.append(id)
func execute_failure(_data: Dictionary): penalties += 1
