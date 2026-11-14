class_name FakeNetBackend
extends NetBackend
## Test helper (net-platform, design.md D6): fakes the platform layer, not the transport. The
## peers it hands back are real ENet-on-localhost peers from NetPeers; what it scripts is the
## platform around them: answers that come some frames later, refusals with a reason, a start-up
## failure, a lobby directory of token to ENet port, invites, and peers delivered after leave().
##
## Deferral counts SceneTree.process_frame, which fires every frame, also while the tree is
## paused, so the fake works with or without NetManager. It never touches `multiplayer`.
## Servers open on the port the request asks for, so tests pass 0 (a free one) or a port they just
## probed, because other GUT runs may share the machine.
##
## Suites that use it call reset() from after_each, after NetManager.use_backend(null).

## Answer after this many process frames; 0 answers inside the host() or join() call.
var defer_frames: int = 0
## A reason to refuse hosting with (NONE hosts).
var refuse_host: NetFailure.Reason = NetFailure.Reason.NONE
## A reason to refuse joining with (NONE joins).
var refuse_join: NetFailure.Reason = NetFailure.Reason.NONE
## False: host() and join() never answer.
var answer: bool = true
## True: answers already scheduled still arrive after leave() (the late-peer tests).
var deliver_after_leave: bool = false
## What start() returns.
var start_failure: NetFailure.Reason = NetFailure.Reason.NONE
## What launch_target() returns.
var launch: NetJoinTarget
## "start", "host", "join" and "leave", in order. poll() is counted in poll_count instead.
var calls: PackedStringArray = PackedStringArray()
var poll_count: int = 0
## The lobby token this fake's last successful host registered.
var last_token: String = ""
## Every peer this fake created, in order: the tests check whether each was closed.
var offered: Array[MultiplayerPeer] = []

# Token -> ENet port of every open fake lobby, shared by every fake (the platform's directory).
static var _lobbies: Dictionary[String, int] = {}
# Every peer any fake created, closed by reset().
static var _all_offered: Array[MultiplayerPeer] = []

var _scheduled: Array[Scheduled] = []
var _tokens: PackedStringArray = PackedStringArray()


## One answer waiting for its frame.
class Scheduled:
	var request: NetRequest
	var frames_left: int = 0


## A fake with an in-code profile: id &"fake", the given join timeout and a test lobby note.
static func make(timeout_s: float = 0.0) -> FakeNetBackend:
	var fake: FakeNetBackend = new()
	var row := NetBackendProfile.new()
	row.id = &"fake"
	row.backend_script = (fake.get_script() as Script).resource_path
	row.join_timeout_s = timeout_s
	row.lobby_note = PackedStringArray(["Sala de prueba en el puerto %d.", "Test lobby on port %d."])
	fake.profile = row
	return fake


## Closes every peer any fake opened and empties the lobby directory.
static func reset() -> void:
	for peer: MultiplayerPeer in _all_offered:
		if peer != null and peer.get_connection_status() != MultiplayerPeer.CONNECTION_DISCONNECTED:
			peer.close()
	_all_offered.clear()
	_lobbies.clear()


## Lists an ENet server on `port` in the lobby directory, as if a host had opened a platform
## lobby, and returns its token.
static func open_lobby(port: int) -> String:
	var token := "sala-%d" % port
	_lobbies[token] = port
	return token


## Whether `token` names an open lobby.
static func has_lobby(token: String) -> bool:
	return _lobbies.has(token)


## An accepted invite or a platform "join game".
func accept_invite(target: NetJoinTarget) -> void:
	join_requested.emit(target)


## The last peer this fake created, or null.
func last_offered() -> MultiplayerPeer:
	return offered.back() if not offered.is_empty() else null


func start(_args: PackedStringArray) -> NetFailure.Reason:
	calls.append("start")
	return start_failure


## OK for an address the join screen would accept, or for any token: an unknown token fails
## inside join() as NOT_FOUND, like a lobby that closed.
func check_target(target: NetJoinTarget) -> Error:
	if target == null:
		return ERR_INVALID_PARAMETER
	if target.is_address():
		return OK if NetPeers.is_valid_address(target.address, target.port) else ERR_INVALID_PARAMETER
	return OK if not target.token.strip_edges().is_empty() else ERR_INVALID_PARAMETER


func host(request: NetRequest, _port: int) -> void:
	calls.append("host")
	_reply(request)


func join(request: NetRequest) -> void:
	calls.append("join")
	_reply(request)


## Leaves the fake platform session: drops answers not yet given (unless deliver_after_leave)
## and closes the lobbies this fake opened. Never closes a peer.
func leave() -> void:
	calls.append("leave")
	if not deliver_after_leave:
		_scheduled.clear()
		_stop_ticking()
	for token: String in _tokens:
		_lobbies.erase(token)
	_tokens.clear()


func launch_target(_args: PackedStringArray) -> NetJoinTarget:
	return launch


func poll(_delta: float) -> void:
	poll_count += 1


func _reply(request: NetRequest) -> void:
	if not answer:
		return
	if defer_frames <= 0:
		_answer(request)
		return
	var entry := Scheduled.new()
	entry.request = request
	entry.frames_left = defer_frames
	_scheduled.append(entry)
	var tree := Engine.get_main_loop() as SceneTree
	if tree != null and not tree.process_frame.is_connected(_on_process_frame):
		tree.process_frame.connect(_on_process_frame)


func _on_process_frame() -> void:
	var due: Array[NetRequest] = []
	var waiting: Array[Scheduled] = []
	for entry: Scheduled in _scheduled:
		entry.frames_left -= 1
		if entry.frames_left <= 0:
			due.append(entry.request)
		else:
			waiting.append(entry)
	_scheduled = waiting
	if _scheduled.is_empty():
		_stop_ticking()
	for request: NetRequest in due:
		_answer(request)


func _stop_ticking() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	if tree != null and tree.process_frame.is_connected(_on_process_frame):
		tree.process_frame.disconnect(_on_process_frame)


# Answers like a platform would. A request no longer pending still gets its peer: NetRequest
# closes a peer delivered late, which is what the late-peer tests check.
func _answer(request: NetRequest) -> void:
	if request.kind == NetRequest.Kind.HOST:
		_answer_host(request)
	else:
		_answer_join(request)


func _answer_host(request: NetRequest) -> void:
	if refuse_host != NetFailure.Reason.NONE:
		request.fail(refuse_host)
		return
	var peer := NetPeers.create_server(request.port)
	if peer == null:
		request.fail(NetFailure.Reason.PORT_UNAVAILABLE, [request.port])
		return
	_keep(peer)
	var info := NetHostInfo.new()
	info.port = NetPeers.bound_port(peer)
	var was_pending: bool = request.is_pending()
	request.succeed(peer, info)
	if was_pending and request.peer == peer:
		var token := open_lobby(info.port)
		_tokens.append(token)
		last_token = token


func _answer_join(request: NetRequest) -> void:
	if refuse_join != NetFailure.Reason.NONE:
		request.fail(refuse_join)
		return
	var target := request.target
	if target == null or check_target(target) != OK:
		request.fail(NetFailure.Reason.INVALID_TARGET)
		return
	var address: String = target.address
	var port: int = target.port
	if not target.is_address():
		if not _lobbies.has(target.token):
			request.fail(NetFailure.Reason.NOT_FOUND)
			return
		address = "127.0.0.1"
		port = _lobbies[target.token]
	var peer := NetPeers.create_client(address, port)
	if peer == null:
		request.fail(NetFailure.Reason.UNREACHABLE)
		return
	_keep(peer)
	request.succeed(peer)


func _keep(peer: MultiplayerPeer) -> void:
	offered.append(peer)
	_all_offered.append(peer)
