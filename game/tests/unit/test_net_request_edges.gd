extends GutTest
## net-platform "What a request changes": what a request leaves behind when it is not READY.
## host() and join() answer at once, so on a slower backend they report ERR_BUSY and cancel the
## request instead of OK on the offline peer standing in for it (a caller that took OK would start
## its session as host). A request refused before the backend is asked changes nothing; a failure
## from the backend leaves the game offline. Every case is 1 player, with no second peer.

const NOBODY_PORT: int = 7999

var _servers: Array[MultiplayerPeer] = []


func before_all() -> void:
	assert_true(NetManager.backend is EnetBackend, "every suite starts on ENet")


func after_all() -> void:
	assert_true(NetManager.backend is EnetBackend, "every suite leaves ENet behind")


func before_each() -> void:
	NetManager.start_solo()


func after_each() -> void:
	NetManager.leave()
	NetManager.use_backend(null)
	FakeNetBackend.reset()
	for server: MultiplayerPeer in _servers:
		server.close()
	_servers.clear()


func _fake() -> FakeNetBackend:
	var fake := FakeNetBackend.make()
	NetManager.use_backend(fake)
	return fake


func _offline() -> bool:
	return NetManager.multiplayer.multiplayer_peer is OfflineMultiplayerPeer and not NetManager.is_online()


# A fake that answers 3 frames late, and still answers after leave() (the worst platform).
func _slow_fake() -> FakeNetBackend:
	var fake := _fake()
	fake.defer_frames = 3
	fake.deliver_after_leave = true
	return fake


# --- host() and join() on a slower backend -----------------------------------------------------

func test_host_is_never_ok_while_the_backend_has_not_answered() -> void:
	var fake := _slow_fake()
	watch_signals(NetManager)
	var answer: Error = NetManager.host(0)
	assert_ne(answer, OK, "no OK on the offline peer standing in for a pending host")
	assert_eq(answer, ERR_BUSY)
	assert_null(NetManager.pending_request(), "the request was cancelled for the caller")
	assert_true(_offline())
	assert_eq(fake.calls, PackedStringArray(["start", "host", "leave"]), "the backend left its session")
	await wait_process_frames(6)
	assert_eq(fake.offered.size(), 1, "the backend still answered")
	var late := fake.last_offered()
	if late != null:
		assert_eq(late.get_connection_status(), MultiplayerPeer.CONNECTION_DISCONNECTED, "closed, never installed")
	assert_true(_offline(), "nothing is installed under the caller later")
	assert_null(NetManager.host_info())
	assert_signal_not_emitted(NetManager, "hosted")
	assert_signal_not_emitted(NetManager, "host_failed")


func test_join_is_never_ok_while_the_backend_has_not_answered() -> void:
	var fake := _slow_fake()
	watch_signals(NetManager)
	var answer: Error = NetManager.join("127.0.0.1", NOBODY_PORT)
	assert_ne(answer, OK, "no OK on the offline peer standing in for a pending join")
	assert_eq(answer, ERR_BUSY)
	assert_null(NetManager.pending_request(), "the request was cancelled for the caller")
	assert_true(_offline())
	assert_eq(fake.calls, PackedStringArray(["start", "join", "leave"]))
	await wait_process_frames(6)
	assert_eq(fake.offered.size(), 1, "the backend still answered")
	var late := fake.last_offered()
	if late != null:
		assert_eq(late.get_connection_status(), MultiplayerPeer.CONNECTION_DISCONNECTED, "closed, never installed")
	assert_true(_offline())
	assert_signal_not_emitted(NetManager, "joined")
	assert_signal_not_emitted(NetManager, "join_failed")


func test_the_wrappers_still_answer_at_once_when_the_backend_does() -> void:
	var fake := _fake()
	assert_eq(NetManager.host(0), OK, "a READY host")
	assert_true(NetManager.multiplayer.is_server())
	assert_true(NetManager.is_online())
	assert_eq(NetManager.join("127.0.0.1", NOBODY_PORT), OK, "a READY join, still connecting")
	assert_false(NetManager.multiplayer.is_server())
	assert_eq(NetManager.join("", NOBODY_PORT), ERR_INVALID_PARAMETER, "a bad address is refused first")
	fake.refuse_host = NetFailure.Reason.NO_PRIVILEGE
	assert_eq(NetManager.host(0), ERR_CANT_CREATE, "a failure inside the call")
	assert_true(_offline())


# --- What a FAILED request leaves --------------------------------------------------------------

func test_a_refused_target_changes_nothing() -> void:
	watch_signals(NetManager)
	var hosting := NetManager.request_host(0)
	assert_eq(hosting.state, NetRequest.State.READY)
	var info := NetManager.host_info()
	var refused := NetManager.request_join(NetJoinTarget.at_address("", NetPeers.DEFAULT_PORT))
	assert_eq(refused.state, NetRequest.State.FAILED)
	assert_eq(refused.reason, NetFailure.Reason.INVALID_TARGET)
	assert_eq(NetManager.multiplayer.multiplayer_peer, hosting.peer, "the host's server stays installed")
	assert_ne(hosting.peer.get_connection_status(), MultiplayerPeer.CONNECTION_DISCONNECTED, "and open")
	assert_true(NetManager.multiplayer.is_server())
	assert_eq(NetManager.host_info(), info, "the lobby's info is kept")
	assert_eq(NetManager.join("   ", NetPeers.DEFAULT_PORT), ERR_INVALID_PARAMETER)
	assert_eq(NetManager.multiplayer.multiplayer_peer, hosting.peer, "the wrapper's refusal changes nothing either")
	assert_signal_emit_count(NetManager, "hosted", 1)
	assert_signal_not_emitted(NetManager, "join_failed")


func test_a_backend_failure_inside_the_call_leaves_the_game_offline() -> void:
	var holder := NetPeers.create_server(0)
	assert_not_null(holder)
	if holder == null:
		return
	_servers.append(holder)
	var taken: int = NetPeers.bound_port(holder)
	var hosting := NetManager.request_host(0)
	assert_eq(hosting.state, NetRequest.State.READY)
	watch_signals(NetManager)
	var again := NetManager.request_host(taken)
	assert_engine_error("Couldn't create an ENet host")
	assert_eq(again.state, NetRequest.State.FAILED)
	assert_eq(again.reason, NetFailure.Reason.PORT_UNAVAILABLE)
	assert_eq(again.reason_args, [taken])
	assert_eq(hosting.peer.get_connection_status(), MultiplayerPeer.CONNECTION_DISCONNECTED, "the first server closed before the backend was asked")
	assert_true(_offline(), "the game is offline")
	assert_null(NetManager.host_info())
	assert_eq(NetManager.last_failure, NetFailure.Reason.PORT_UNAVAILABLE)
	assert_eq(NetManager.failure_text(NetManager.last_failure, NetManager.last_failure_args), "No se pudo abrir el puerto %d." % taken)
	assert_signal_not_emitted(NetManager, "host_failed", "a failure inside the call emits nothing")


func test_a_backend_failure_leaves_the_platform_session() -> void:
	var fake := _fake()
	var hosting := NetManager.request_host(0)
	assert_eq(hosting.state, NetRequest.State.READY)
	fake.refuse_host = NetFailure.Reason.NO_PRIVILEGE
	assert_eq(NetManager.host(0), ERR_CANT_CREATE)
	assert_eq(fake.calls, PackedStringArray(["start", "host", "leave", "host"]), "left before asking again")
	assert_eq(hosting.peer.get_connection_status(), MultiplayerPeer.CONNECTION_DISCONNECTED)
	assert_true(_offline())
	assert_eq(NetManager.last_failure, NetFailure.Reason.NO_PRIVILEGE)
	var startup_refused := FakeNetBackend.make()
	startup_refused.start_failure = NetFailure.Reason.PLATFORM_UNAVAILABLE
	NetManager.use_backend(startup_refused)
	var refused := NetManager.request_host(0)
	assert_eq(refused.reason, NetFailure.Reason.PLATFORM_UNAVAILABLE)
	assert_eq(startup_refused.calls, PackedStringArray(["start"]), "a startup refusal asks the backend nothing")
	assert_true(_offline())
