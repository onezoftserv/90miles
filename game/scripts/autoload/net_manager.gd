extends Node
## NetManager autoload (core-services spec): hosting, joining and peers for the game's
## multiplayer API. Gameplay networking lives in CoopSession, which uses whatever peer is set
## here. The transport comes from the active platform backend (net-platform), chosen once at
## startup from res://resources/net_backends.tres; ENet is the default. This autoload alone
## installs peers and reports connection events; the backend only hands peers over.
##
## Hosting and joining go through NetRequests that come back READY (peer installed), PENDING or
## FAILED. A request refused before the backend is asked (a startup failure, or a target the
## backend refuses) changes nothing; any other request first goes offline, so a backend failure
## leaves the game offline. Leaving, going solo or asking again cancels a pending request, and a
## peer delivered for a cancelled request is closed. Solo is the offline peer and asks the
## backend for nothing. Like every core service, it declares no constants, enums or exports: the
## enums live in NetFailure and NetRequest, the data in the table.

## Hosting started; `port` is the port opened (0 when the backend has none).
signal hosted(port: int)
## The client reached the host.
signal joined
## The client could not reach the host; the game is back on the offline peer. The reason is in
## last_failure.
signal join_failed
## The host went away; the game is back on the offline peer.
signal host_lost
## Hosting failed after request_host() returned; the game is back on the offline peer. The
## reason is in last_failure.
signal host_failed
## An invite, a platform "join game" or a launch argument. Kept until take_outside_join().
signal outside_join_requested(target: NetJoinTarget)

## The active platform backend.
var backend: NetBackend
## Every backend's profile and the failure lines.
var table: NetBackendTable
## Why the last host or join failed (NONE after a new request or going solo).
var last_failure: NetFailure.Reason = NetFailure.Reason.NONE
## Format arguments for last_failure's line.
var last_failure_args: Array = []
## What the backend's start() said. Anything but NONE refuses host and join, never solo.
var startup_failure: NetFailure.Reason = NetFailure.Reason.NONE

# The current host or join request: pending, or ready with its peer installed.
var _request: NetRequest
# The request whose backend call is on the stack: an answer for it came inside the call.
var _calling: NetRequest
# A host or join was asked since the game last went offline, so the backend has a session to leave.
var _session_open: bool = false
var _host_info: NetHostInfo
var _outside_join: NetJoinTarget
# Seconds left before a join that has not reached the host fails as timed out; 0 = not watching.
var _watch_left_s: float = 0.0


func _ready() -> void:
	# Polls the backend and runs the join watchdog also while the game is paused.
	process_mode = Node.PROCESS_MODE_ALWAYS
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)
	# The one place the backend is chosen. No peer changes at boot.
	table = NetBackendTable.load_shipped()
	use_backend(_startup_backend(), OS.get_cmdline_args() + OS.get_cmdline_user_args())


func _process(delta: float) -> void:
	if backend != null:
		backend.poll(delta)
	if _watch_left_s > 0.0:
		_watch_left_s -= delta
		if _watch_left_s <= 0.0:
			_on_join_timed_out()


## Hosts on `port` (NetPeers.DEFAULT_PORT unless given; 0 picks a free one) and answers at once,
## for callers that start their session on the return value. Returns OK only when the server peer
## is installed; ERR_CANT_CREATE if hosting failed (with ENet: the port cannot be bound), and the
## game is then offline; ERR_BUSY if the backend would answer later: that request is cancelled
## and the game is offline, so no peer is installed under the caller afterwards. A caller that can
## wait uses request_host().
func host(port: int = NetPeers.DEFAULT_PORT) -> Error:
	return _answer_now(request_host(port), ERR_CANT_CREATE)


## Starts connecting to a host and answers at once; `joined` or `join_failed` follows an OK.
## Returns ERR_INVALID_PARAMETER, with nothing changed, for an address the backend cannot join;
## ERR_CANT_CONNECT if the join failed, and the game is then offline; ERR_BUSY if the backend
## would answer later: that request is cancelled and the game is offline. OK only when the client
## peer is installed and connecting. A caller that can wait uses request_join().
func join(address: String, port: int = NetPeers.DEFAULT_PORT) -> Error:
	var target := NetJoinTarget.at_address(address, port)
	if backend == null or backend.check_target(target) != OK:
		return ERR_INVALID_PARAMETER
	return _answer_now(request_join(target), ERR_CANT_CONNECT)


## Solo: the offline peer, so the host code path runs and no port is opened. Cancels a pending
## request and leaves the backend's session if a host or join was asked; otherwise the backend
## hears nothing.
func start_solo() -> void:
	last_failure = NetFailure.Reason.NONE
	last_failure_args = []
	_go_offline()


## Closes the current connection and returns to the offline peer.
func leave() -> void:
	start_solo()


func is_online() -> bool:
	return not multiplayer.multiplayer_peer is OfflineMultiplayerPeer


## Asks the backend to host on `port`. Unless it is refused first (a startup failure: FAILED with
## its reason and nothing changed), the game goes offline before the backend is asked: a pending
## request is cancelled and the current peer closed. The request comes back READY (the server peer
## installed and `hosted` emitted), PENDING (`hosted` then `settled` follow, or `host_failed`), or
## FAILED with its reason and the game offline. A FAILED answer emits no signal.
func request_host(port: int = NetPeers.DEFAULT_PORT) -> NetRequest:
	var request := NetRequest.new(NetRequest.Kind.HOST, port)
	if startup_failure != NetFailure.Reason.NONE:
		_refuse(request, startup_failure)
		return request
	_open(request)
	backend.host(request, port)
	_calling = null
	return request


## Asks the backend to join `target`. Same answers as request_host(): READY (the client peer
## installed and connecting; `joined` or `join_failed` follows), PENDING (`settled` follows, or
## `join_failed`), or FAILED. A target the backend refuses, or a startup failure, gives FAILED
## with nothing changed; a failure from the backend gives FAILED with the game offline.
func request_join(target: NetJoinTarget) -> NetRequest:
	var request := NetRequest.new(NetRequest.Kind.JOIN, 0, target)
	if startup_failure != NetFailure.Reason.NONE:
		_refuse(request, startup_failure)
		return request
	if target == null or backend.check_target(target) != OK:
		_refuse(request, NetFailure.Reason.INVALID_TARGET)
		return request
	_open(request)
	backend.join(request)
	_calling = null
	# The watchdog counts from the request until connected_to_server (design.md D8).
	var timeout_s: float = backend.profile.join_timeout_s if backend.profile != null else 0.0
	if timeout_s > 0.0 and request == _request \
			and (request.is_pending() or request.state == NetRequest.State.READY):
		_watch_left_s = timeout_s
	return request


## The request still waiting on the backend, or null.
func pending_request() -> NetRequest:
	return _request if _request != null and _request.is_pending() else null


## What the host's lobby shows about how others join; null unless hosting.
func host_info() -> NetHostInfo:
	return _host_info


## The active backend's profile.
func backend_profile() -> NetBackendProfile:
	return backend.profile if backend != null else null


## `reason`'s line from the table, Spanish unless `locale` says otherwise; "" for NONE,
## CANCELLED or a missing line.
func failure_text(reason: NetFailure.Reason, args: Array = [], locale: String = "es") -> String:
	return table.failure_text(reason, args, locale) if table != null else ""


## The active profile's lobby note with the port opened; "" when not hosting or when the profile
## has none, which keeps the lobby scene's own note.
func lobby_note(locale: String = "es") -> String:
	if _host_info == null or table == null:
		return ""
	return table.lobby_note(backend_profile(), _host_info.port, locale)


## The join request kept from outside the game, once; then null.
func take_outside_join() -> NetJoinTarget:
	var target := _outside_join
	_outside_join = null
	return target


## Tests: swaps the active backend. Goes offline first (leaving the old backend's session if a
## host or join was asked), then runs the new backend's start(args) and keeps its launch target.
## null restores the startup choice with no launch target. Every swap forgets a kept outside join.
func use_backend(next: NetBackend, args: PackedStringArray = PackedStringArray()) -> void:
	if backend != null:
		start_solo()
		if backend.join_requested.is_connected(_on_backend_join_requested):
			backend.join_requested.disconnect(_on_backend_join_requested)
	var restoring: bool = next == null
	backend = _startup_backend() if restoring else next
	_outside_join = null
	last_failure = NetFailure.Reason.NONE
	last_failure_args = []
	backend.join_requested.connect(_on_backend_join_requested)
	startup_failure = backend.start(PackedStringArray() if restoring else args)
	if not restoring:
		_on_backend_join_requested(backend.launch_target(args))


func _use(peer: MultiplayerPeer) -> void:
	var current := multiplayer.multiplayer_peer
	if current != null and current != peer and not current is OfflineMultiplayerPeer:
		current.close()
	var scene_api := multiplayer as SceneMultiplayer
	if scene_api != null:
		# Clients never talk to each other directly: everything goes through the host.
		scene_api.server_relay = false
	multiplayer.multiplayer_peer = peer


func _startup_backend() -> NetBackend:
	return table.create(table.pick(Callable(OS, &"has_feature")))


# host() and join() answer at once: OK only for READY, `failed` for FAILED. A request still pending
# is cancelled (offline again, the backend's session left), so a caller that took the error never
# meets a peer installed later.
func _answer_now(request: NetRequest, failed: Error) -> Error:
	match request.state:
		NetRequest.State.READY:
			return OK
		NetRequest.State.PENDING:
			_go_offline()
			return ERR_BUSY
		_:
			return failed


# Steps 2 to 4 of a request (design.md "Fixed ordering"): offline, no failure, then the request.
func _open(request: NetRequest) -> void:
	_go_offline()
	last_failure = NetFailure.Reason.NONE
	last_failure_args = []
	_request = request
	_session_open = true
	_calling = request
	request.answered.connect(_on_answered)


# Step 1: refused before anything changed. FAILED with its reason, no backend call, no signal.
func _refuse(request: NetRequest, why: NetFailure.Reason) -> void:
	request.fail(why)
	last_failure = request.reason
	last_failure_args = request.reason_args.duplicate()
	request.settle(NetRequest.State.FAILED)


# Cancels a pending request, leaves the backend's session if a host or join was asked, and
# installs a fresh offline peer. Keeps last_failure.
func _go_offline() -> void:
	_watch_left_s = 0.0
	_host_info = null
	var current := _request
	_request = null
	if current != null:
		current.cancel()
	if _session_open:
		_session_open = false
		if backend != null:
			backend.leave()
	_use(OfflineMultiplayerPeer.new())


func _on_answered(request: NetRequest) -> void:
	if request != _request or not request.is_pending():
		# Cancelled or stale: its peer is closed, never installed.
		request.cancel()
		return
	if request.peer == null:
		if request == _calling:
			# Inside the call: the caller reads the result, so no signal.
			_request = null
			last_failure = request.reason
			last_failure_args = request.reason_args.duplicate()
			request.settle(NetRequest.State.FAILED)
		else:
			_fail_late(request)
		return
	_use(request.peer)
	if request.kind == NetRequest.Kind.HOST:
		_host_info = request.info if request.info != null else NetHostInfo.new()
		hosted.emit(_host_info.port)
	request.settle(NetRequest.State.READY)


# A failure after the call returned: settled first, then offline, then the reason and the signal.
func _fail_late(request: NetRequest) -> void:
	_request = null
	request.settle(NetRequest.State.FAILED)
	_go_offline()
	last_failure = request.reason
	last_failure_args = request.reason_args.duplicate()
	if request.kind == NetRequest.Kind.HOST:
		host_failed.emit()
	else:
		join_failed.emit()


# The profile's join timeout ran out before the client reached the host.
func _on_join_timed_out() -> void:
	_watch_left_s = 0.0
	var request := _request
	if request == null:
		return
	if request.is_pending():
		# Answers in the backend's place; the late-failure path takes it from there.
		request.fail(NetFailure.Reason.TIMED_OUT)
		return
	_go_offline()
	last_failure = NetFailure.Reason.TIMED_OUT
	last_failure_args = []
	join_failed.emit()


func _on_backend_join_requested(target: NetJoinTarget) -> void:
	if target == null:
		return
	_outside_join = target
	outside_join_requested.emit(target)


func _on_connected_to_server() -> void:
	_watch_left_s = 0.0
	joined.emit()


func _on_connection_failed() -> void:
	_go_offline()
	last_failure = NetFailure.Reason.UNREACHABLE
	last_failure_args = []
	join_failed.emit()


func _on_server_disconnected() -> void:
	_go_offline()
	last_failure = NetFailure.Reason.HOST_LEFT
	last_failure_args = []
	host_lost.emit()
