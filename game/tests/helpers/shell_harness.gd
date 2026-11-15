class_name ShellHarness
extends RefCounted
## Test helper (coop-rematch): real game shells for a host and clients in one process, each in its
## own branch with its own SceneMultiplayer (relay off), over ENet on a free localhost port. Unlike
## NetHarness, the whole run is real: the shell, the island, the HUD and the session. Every shell is
## named "Shell", so the session's and the rematch node's paths match across branches.
##
## Peers are installed on the branch, not through NetManager (one per process), and the shell's
## _on_hosting() and _on_joining() are called as _continue() would. Leaving and dropping close the
## branch's peer as NetManager.leave() closes the game's.
##
## All shells share the one WeatherManager.sky: a client applying the host's clock fires the sky's
## `changed`, which the host's session answers with another clock message, so clock messages loop
## while both runs exist, and a client's run end stops the shared weather. Tests here assert nothing
## about a client's weather (coop-rematch design.md, Risks). teardown() ends every run before closing
## its peer, because closing a peer under live synchronizers logs engine errors.

const SHELL_SCENE: PackedScene = preload("res://scenes/shell/game_shell.tscn")
const TIMEOUT_S: float = 5.0
## The same ENet throttle settings as NetHarness, so a loaded machine does not read as congestion.
const THROTTLE_INTERVAL_MS: int = 5000
const THROTTLE_ACCELERATION: int = 2
const THROTTLE_DECELERATION: int = 0

var port: int = 0
var shells: Array[GameShell] = []
var apis: Array[SceneMultiplayer] = []
var branches: Array[Node] = []
var _settings_paths: Array[String] = []
var _test: GutTest


func _init(test: GutTest) -> void:
	_test = test


## The host's shell, hosting as `player_name` and showing its lobby. `seeds` rolls its run seeds.
func add_host(player_name: String, seeds: Callable) -> GameShell:
	var shell := _add_shell("Host", player_name, seeds)
	var peer := NetPeers.create_server(0)
	port = NetPeers.bound_port(peer)
	apis[0].multiplayer_peer = peer
	apis[0].peer_connected.connect(_unthrottle)
	shell._on_hosting()
	return shell


## A client shell joining the host as `player_name`. It does not wait.
func add_client(player_name: String) -> GameShell:
	var shell := _add_shell("Client%d" % branches.size(), player_name, Callable())
	apis[apis.size() - 1].multiplayer_peer = NetPeers.create_client("127.0.0.1", port)
	shell._on_joining()
	return shell


## A client that is in the host's lobby, both sides listing it. Null on timeout.
func join_lobby(player_name: String) -> GameShell:
	var shell := add_client(player_name)
	var host: GameShell = shells[0]
	var listed := func() -> bool:
		return shell.flow == GameShell.Flow.LOBBY and host.session != null and host.session.roster.has(peer_id(shell))
	return shell if await wait(listed) else null


## Starts the host's run and waits until every client shell is in it with every body. False on
## timeout. Keyboard input is then off on every body.
func begin_run() -> bool:
	var host: GameShell = shells[0]
	if not host.session.begin_run():
		return false
	var in_run := func() -> bool:
		var expected: int = host.session.peer_ids().size()
		for shell: GameShell in shells:
			if not _connected(shell):
				continue
			if shell.flow != GameShell.Flow.RUN or shell.session == null or shell.session.peer_ids().size() != expected:
				return false
		return true
	var ok: bool = await wait(in_run)
	silence_input()
	return ok


## Kills every player on the host and waits until every connected shell shows its summary.
func end_run() -> bool:
	var host: GameShell = shells[0]
	for id: int in host.session.peer_ids():
		host.session.body(id).meters.dead = true
	var shown := func() -> bool:
		for shell: GameShell in shells:
			if _connected(shell) and shell.flow != GameShell.Flow.SUMMARY:
				return false
		return true
	return await wait(shown)


func wait(condition: Callable, timeout_s: float = TIMEOUT_S) -> bool:
	return await _test.wait_until(condition, timeout_s)


## Turns off keyboard input on every body of every shell.
func silence_input() -> void:
	for shell: GameShell in shells:
		if shell.session == null:
			continue
		for id: int in shell.session.peer_ids():
			shell.session.body(id).player_input.enabled = false


func peer_id(shell: GameShell) -> int:
	return apis[shells.find(shell)].get_unique_id()


func peer_of(shell: GameShell) -> MultiplayerPeer:
	return apis[shells.find(shell)].multiplayer_peer


## The shell picks "Volver al inicio" or leaves the lobby: back to its title, and its connection
## closes, as NetManager.leave() does in the game.
func go_home(shell: GameShell) -> void:
	shell.back_to_title()
	_close(apis[shells.find(shell)])


## The shell's player drops: its run is freed and its connection closes, with no title.
func drop(shell: GameShell) -> void:
	shell._end_run()
	_close(apis[shells.find(shell)])


func teardown() -> void:
	for shell: GameShell in shells:
		if is_instance_valid(shell):
			shell._end_run()
	for api: SceneMultiplayer in apis:
		_close(api)
	for branch: Node in branches:
		if is_instance_valid(branch):
			_test.get_tree().set_multiplayer(null, branch.get_path())
			branch.free()
	for path: String in _settings_paths:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	shells.clear()
	apis.clear()
	branches.clear()
	_settings_paths.clear()


func _add_shell(branch_name: String, player_name: String, seeds: Callable) -> GameShell:
	var branch := Node.new()
	branch.name = branch_name
	_test.add_child(branch)
	var api := SceneMultiplayer.new()
	api.server_relay = false
	_test.get_tree().set_multiplayer(api, branch.get_path())
	# Each peer has its own settings, so its own name and player id.
	var path: String = "user://test_shell_harness_%s.cfg" % branch_name.to_lower()
	var config := ConfigFile.new()
	config.set_value("player", "name", player_name)
	config.save(path)
	var shell := SHELL_SCENE.instantiate() as GameShell
	shell.name = "Shell"
	shell.settings_path = path
	shell.port = 0
	if seeds.is_valid():
		shell.seed_source = seeds
	branch.add_child(shell)
	branches.append(branch)
	apis.append(api)
	shells.append(shell)
	_settings_paths.append(path)
	return shell


func _connected(shell: GameShell) -> bool:
	var peer := peer_of(shell)
	return peer != null and peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED


func _close(api: SceneMultiplayer) -> void:
	if api.multiplayer_peer != null and not api.multiplayer_peer is OfflineMultiplayerPeer:
		api.multiplayer_peer.close()
	api.multiplayer_peer = null


func _unthrottle(peer: int) -> void:
	if apis.is_empty():
		return
	var enet := apis[0].multiplayer_peer as ENetMultiplayerPeer
	if enet == null:
		return
	var connection: ENetPacketPeer = enet.get_peer(peer)
	if connection != null:
		connection.throttle_configure(THROTTLE_INTERVAL_MS, THROTTLE_ACCELERATION, THROTTLE_DECELERATION)
