class_name NetHarness
extends RefCounted
## Test helper (coop-networking): a host and clients in one process. Each peer gets its own
## branch node with its own SceneMultiplayer (relay off) and a CoopSession named "Session", so
## RPC, spawner and synchronizer paths match across branches. ENet runs on a free localhost
## port. Call teardown() from after_each: sessions are freed before their peers are closed,
## because closing a peer under live synchronizers logs engine errors.

const SESSION_SCENE: PackedScene = preload("res://scenes/net/coop_session.tscn")
const TIMEOUT_S: float = 5.0

var port: int = 0
var branches: Array[Node] = []
var apis: Array[SceneMultiplayer] = []
var sessions: Array[CoopSession] = []
var _test: GutTest


func _init(test: GutTest) -> void:
	_test = test


## Adds the host branch and (unless `started` is false) starts its session, in the lobby phase
## when `lobby` is true. `setup` gets the session before start().
func add_host(setup: Callable = Callable(), started: bool = true, lobby: bool = false) -> CoopSession:
	var session := _add_branch("Host", setup)
	var peer := NetPeers.create_server(0)
	port = NetPeers.bound_port(peer)
	apis[0].multiplayer_peer = peer
	if started:
		session.start(lobby)
	return session


## Adds a client named `player_name` and waits until the host has it in its roster (in the
## lobby nothing spawns, so there is no body to wait for). Returns null on timeout.
func join_lobby(player_name: String) -> CoopSession:
	var named := func(session: CoopSession) -> void: session.local_name = player_name
	var session := add_client(named)
	var host: CoopSession = sessions[0]
	var listed := func() -> bool:
		return _connected(session) and host.roster.has(session.multiplayer.get_unique_id())
	var ok: bool = await _test.wait_until(listed, TIMEOUT_S)
	return session if ok else null


## Waits until `session`'s peer is connected.
func wait_connected(session: CoopSession) -> bool:
	return await _test.wait_until(func() -> bool: return _connected(session), TIMEOUT_S)


## Adds a client branch pointed at the host and starts its session, without waiting.
func add_client(setup: Callable = Callable()) -> CoopSession:
	var session := _add_branch("Client%d" % branches.size(), setup)
	apis[apis.size() - 1].multiplayer_peer = NetPeers.create_client("127.0.0.1", port)
	session.start()
	return session


## Adds a client and waits until it is connected and its own player has spawned on it and
## on the host. Returns null on timeout.
func join(setup: Callable = Callable()) -> CoopSession:
	var session := add_client(setup)
	var host: CoopSession = sessions[0]
	var spawned := func() -> bool:
		if not _connected(session):
			return false
		var id: int = session.multiplayer.get_unique_id()
		return session.body(id) != null and host.body(id) != null
	var ok: bool = await _test.wait_until(spawned, TIMEOUT_S)
	if not ok:
		return null
	silence_input()
	return session


## Waits until every connected session shows a player for every peer the host has.
func settle() -> bool:
	var settled := func() -> bool:
		var expected: int = sessions[0].peer_ids().size()
		for session: CoopSession in sessions:
			if is_instance_valid(session) and _connected(session) and session.peer_ids().size() != expected:
				return false
		return true
	return await _test.wait_until(settled, TIMEOUT_S)


## Turns off keyboard input on every body, so tests set intents directly.
func silence_input() -> void:
	for session: CoopSession in sessions:
		if not is_instance_valid(session):
			continue
		for id: int in session.peer_ids():
			session.body(id).player_input.enabled = false


func peer_id(session: CoopSession) -> int:
	return session.multiplayer.get_unique_id()


## The player this session's own peer controls.
func own_body(session: CoopSession) -> PlayerBody:
	return session.body(peer_id(session))


## Frees a session, then closes its peer: what a peer quitting looks like to the others.
func drop(session: CoopSession) -> void:
	var index: int = sessions.find(session)
	if index < 0:
		return
	session.free()
	_close(apis[index])


func teardown() -> void:
	for i: int in range(sessions.size() - 1, -1, -1):
		if is_instance_valid(sessions[i]):
			sessions[i].free()
	for api: SceneMultiplayer in apis:
		_close(api)
	for branch: Node in branches:
		if is_instance_valid(branch):
			_test.get_tree().set_multiplayer(null, branch.get_path())
			branch.free()
	sessions.clear()
	apis.clear()
	branches.clear()


func _add_branch(branch_name: String, setup: Callable) -> CoopSession:
	var branch := Node.new()
	branch.name = branch_name
	_test.add_child(branch)
	var api := SceneMultiplayer.new()
	api.server_relay = false
	_test.get_tree().set_multiplayer(api, branch.get_path())
	var session := SESSION_SCENE.instantiate() as CoopSession
	branch.add_child(session)
	# After _ready (the spawners exist) and before start() and the connection.
	if setup.is_valid():
		setup.call(session)
	branches.append(branch)
	apis.append(api)
	sessions.append(session)
	return session


func _connected(session: CoopSession) -> bool:
	var peer := session.multiplayer.multiplayer_peer
	return peer != null and peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED


func _close(api: SceneMultiplayer) -> void:
	if api.multiplayer_peer != null and not api.multiplayer_peer is OfflineMultiplayerPeer:
		api.multiplayer_peer.close()
	api.multiplayer_peer = null
