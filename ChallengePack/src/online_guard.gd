extends RefCounted

# Independent implementation using the game's own typed managers. No shared
# metadata lock: installing another mod cannot silently disable our protection.
const LOBBY = "res://multiplayer/scripts/MP_LobbyManager.gd"
const COMMAND = "res://multiplayer/scripts/global scripts/MP_CommandLineChecker.gd"
const BOARD = "res://scripts/LeaderboardManager.gd"
var scripts = {}

func prepare(allow_multiplayer: bool = false) -> bool:
	scripts.clear()
	var bodies = {
		LOBBY: "func _ready():\n\tif connecting_join_requested and not Steam.join_requested.is_connected(_on_Lobby_Join_Requested):\n\t\tSteam.join_requested.connect(_on_Lobby_Join_Requested)\n\nfunc Pipe(_alias: String = \"\", _sub_alias: String = \"\"):\n\tcp_port.online_notice()\n\nfunc CreateLobby():\n\tcp_port.online_notice()\n\nfunc join_lobby(_id: int) -> void:\n\tcp_port.online_notice()\n\nfunc CheckCommandLine():\n\tpass\n",
		COMMAND: "func check_command_line() -> void:\n\tcp_port.clear_invite()\n\nfunc JoinGameOutsideLobby(_id):\n\tcp_port.online_notice()\n",
		BOARD: "func UploadScore(_rounds, _visible, _initial):\n\tprint(\"[ChallengePack] leaderboard upload blocked\")\n\nfunc UploadScore_Deprecated(_rounds, _visible, _initial):\n\tprint(\"[ChallengePack] leaderboard upload blocked\")\n"
	}
	if allow_multiplayer:
		bodies.erase(LOBBY)
		bodies.erase(COMMAND)
	for path in bodies:
		var script = GDScript.new()
		script.source_code = 'extends "%s"\nvar cp_port: Node\n' % path + bodies[path]
		if script.reload() != OK:
			return false
		scripts[path] = script
	return true
