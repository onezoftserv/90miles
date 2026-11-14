extends GutTest
## net-platform "Hosting and joining may finish later", "Cancelling a pending request", "Join
## timeout", "Failure reasons" and "Join requests from outside the game": NetManager drives the
## active backend through NetRequests. Most cases swap in FakeNetBackend (design.md D6); the
## first three are solo, offline and need no second peer.

const NOBODY_PORT: int = 7999

# What the NetManager and request handlers saw, in order (an Array, so the handlers can append).
var _seen: Array[String] = []
var _servers: Array[MultiplayerPeer] = []


func before_all() -> void:
	assert_true(NetManager.backend is EnetBackend, "every suite starts on ENet")


func after_all() -> void:
	assert_true(NetManager.backend is EnetBackend, "every suite leaves ENet behind")


func before_each() -> void:
	_seen.clear()
	NetManager.start_solo()


func after_each() -> void:
	get_tree().paused = false
	for handler: Callable in [_on_hosted, _on_host_failed, _on_join_failed]:
		for sig: Signal in [NetManager.hosted, NetManager.host_failed, NetManager.join_failed]:
			if sig.is_connected(handler):
				sig.disconnect(handler)
	NetManager.leave()
	NetManager.use_backend(null)
	FakeNetBackend.reset()
	for server: MultiplayerPeer in _servers:
		server.close()
	_servers.clear()


func _fake(timeout_s: float = 0.0) -> FakeNetBackend:
	var fake := FakeNetBackend.make(timeout_s)
	NetManager.use_backend(fake)
	return fake


func _offline() -> bool:
	return NetManager.multiplayer.multiplayer_peer is OfflineMultiplayerPeer and not NetManager.is_online()


func _on_hosted(port: int) -> void:
	_seen.append("hosted %d" % port)


func _on_settled(request: NetRequest) -> void:
	var installed: bool = request.peer != null and NetManager.multiplayer.multiplayer_peer == request.peer
	_seen.append("settled %s%s" % [NetRequest.State.keys()[request.state], " installed" if installed else ""])


func _on_host_failed() -> void:
	_seen.append("host_failed %s %s" % [NetFailure.Reason.keys()[NetManager.last_failure], "offline" if _offline() else "online"])


func _on_join_failed() -> void:
	_seen.append("join_failed %s %s" % [NetFailure.Reason.keys()[NetManager.last_failure], "offline" if _offline() else "online"])


func _settles(request: NetRequest, max_s: float = 2.0) -> bool:
	return await wait_until(func() -> bool: return not request.is_pending(), max_s)


# --- Solo: exactly 1 player, offline -------------------------------------------------------------

func test_solo_never_touches_the_backend() -> void:
	var fake := FakeNetBackend.make()
	fake.start_failure = NetFailure.Reason.PLATFORM_UNAVAILABLE
	fake.refuse_host = NetFailure.Reason.PLATFORM_UNAVAILABLE
	fake.refuse_join = NetFailure.Reason.PLATFORM_UNAVAILABLE
	NetManager.use_backend(fake)
	assert_eq(NetManager.startup_failure, NetFailure.Reason.PLATFORM_UNAVAILABLE)
	NetManager.start_solo()
	assert_true(NetManager.multiplayer.multiplayer_peer is OfflineMultiplayerPeer)
	assert_eq(NetManager.multiplayer.get_unique_id(), 1)
	assert_true(NetManager.multiplayer.is_server())
	assert_false(NetManager.is_online())
	NetManager.leave()
	NetManager.start_solo()
	assert_eq(fake.calls, PackedStringArray(["start"]), "no host, join or leave call")
	assert_true(fake.offered.is_empty(), "no port opened")


func test_a_late_peer_after_going_solo_is_closed() -> void:
	var fake := _fake()
	fake.defer_frames = 3
	fake.deliver_after_leave = true
	var request := NetManager.request_host(0)
	assert_eq(request.state, NetRequest.State.PENDING)
	NetManager.start_solo()
	assert_eq(request.state, NetRequest.State.CANCELLED)
	assert_eq(request.reason, NetFailure.Reason.CANCELLED)
	assert_has(fake.calls, "leave", "going solo leaves the platform session")
	await wait_process_frames(5)
	assert_eq(fake.offered.size(), 1, "the backend still delivered a peer")
	var late := fake.last_offered()
	if late != null:
		assert_eq(late.get_connection_status(), MultiplayerPeer.CONNECTION_DISCONNECTED, "closed, never installed")
	assert_true(_offline(), "solo stays on the offline peer")
	assert_eq(NetManager.multiplayer.get_unique_id(), 1)
	assert_null(NetManager.pending_request())


func test_startup_failure_refuses_host_and_join_but_not_solo() -> void:
	var fake := FakeNetBackend.make()
	fake.start_failure = NetFailure.Reason.NOT_SIGNED_IN
	NetManager.use_backend(fake)
	watch_signals(NetManager)
	var hosting := NetManager.request_host(0)
	assert_eq(hosting.state, NetRequest.State.FAILED)
	assert_eq(hosting.reason, NetFailure.Reason.NOT_SIGNED_IN)
	assert_eq(NetManager.last_failure, NetFailure.Reason.NOT_SIGNED_IN)
	var joining := NetManager.request_join(NetJoinTarget.with_token("sala-1", "Yuni"))
	assert_eq(joining.state, NetRequest.State.FAILED)
	assert_eq(joining.reason, NetFailure.Reason.NOT_SIGNED_IN)
	assert_eq(NetManager.host(0), ERR_CANT_CREATE)
	assert_eq(NetManager.join("127.0.0.1", NOBODY_PORT), ERR_CANT_CONNECT)
	assert_eq(NetManager.join("", NOBODY_PORT), ERR_INVALID_PARAMETER, "a bad address is still refused first")
	assert_eq(fake.calls, PackedStringArray(["start"]), "the backend was never asked")
	assert_signal_not_emitted(NetManager, "hosted")
	assert_signal_not_emitted(NetManager, "host_failed")
	assert_signal_not_emitted(NetManager, "join_failed")
	assert_true(_offline())
	NetManager.start_solo()
	assert_true(NetManager.multiplayer.multiplayer_peer is OfflineMultiplayerPeer)
	assert_true(NetManager.multiplayer.is_server(), "solo still works")
	assert_eq(NetManager.last_failure, NetFailure.Reason.NONE, "going solo clears the last failure")


# --- Requests through the backend ----------------------------------------------------------------

func test_enet_requests_are_ready_before_they_return() -> void:
	watch_signals(NetManager)
	var hosting := NetManager.request_host(0)
	assert_eq(hosting.state, NetRequest.State.READY)
	assert_true(NetManager.multiplayer.multiplayer_peer is ENetMultiplayerPeer)
	assert_eq(NetManager.multiplayer.multiplayer_peer, hosting.peer)
	assert_true(NetManager.multiplayer.is_server())
	assert_not_null(NetManager.host_info())
	if NetManager.host_info() != null:
		assert_eq(NetManager.host_info().port, NetPeers.bound_port(hosting.peer))
		assert_signal_emitted_with_parameters(NetManager, "hosted", [NetManager.host_info().port])
		assert_eq(NetManager.lobby_note(),
				"Los demás se unen por IP en el puerto UDP %d. Por internet, abre ese puerto en tu router." % NetManager.host_info().port)
	assert_null(NetManager.pending_request())
	var joining := NetManager.request_join(NetJoinTarget.at_address("127.0.0.1", NOBODY_PORT))
	assert_eq(joining.state, NetRequest.State.READY)
	assert_eq(hosting.peer.get_connection_status(), MultiplayerPeer.CONNECTION_DISCONNECTED, "the old host peer closed")
	assert_eq(NetManager.multiplayer.multiplayer_peer, joining.peer)
	assert_eq(joining.peer.get_connection_status(), MultiplayerPeer.CONNECTION_CONNECTING)
	assert_false((NetManager.multiplayer as SceneMultiplayer).server_relay)
	assert_null(NetManager.host_info(), "a client has no host info")
	assert_eq(NetManager.lobby_note(), "")


func test_a_pending_host_installs_nothing_until_answered() -> void:
	var fake := _fake()
	fake.defer_frames = 3
	watch_signals(NetManager)
	NetManager.hosted.connect(_on_hosted)
	var request := NetManager.request_host(0)
	request.settled.connect(_on_settled)
	assert_eq(request.state, NetRequest.State.PENDING)
	assert_eq(NetManager.pending_request(), request)
	assert_true(_offline(), "nothing installed while pending")
	assert_null(NetManager.host_info())
	await wait_process_frames(1)
	assert_true(request.is_pending())
	assert_true(_offline())
	assert_signal_not_emitted(NetManager, "hosted")
	assert_true(await _settles(request), "the backend answered")
	assert_eq(request.state, NetRequest.State.READY)
	var peer := NetManager.multiplayer.multiplayer_peer
	assert_true(peer is ENetMultiplayerPeer)
	assert_eq(peer, request.peer)
	assert_true(NetManager.multiplayer.is_server())
	assert_eq(NetManager.multiplayer.get_unique_id(), 1)
	assert_false((NetManager.multiplayer as SceneMultiplayer).server_relay, "the relay stays off")
	var port: int = NetPeers.bound_port(peer)
	assert_eq(_seen, ["hosted %d" % port, "settled READY installed"] as Array[String], "hosted fires before settled")
	assert_eq(NetManager.host_info().port, port)
	assert_null(NetManager.pending_request())
	assert_eq(NetManager.lobby_note(), "Sala de prueba en el puerto %d." % port, "the note comes from the active profile")
	assert_eq(fake.calls, PackedStringArray(["start", "host"]))


func test_asking_again_cancels_the_pending_request() -> void:
	var fake := _fake()
	fake.defer_frames = 3
	fake.deliver_after_leave = true
	watch_signals(NetManager)
	var first := NetManager.request_host(0)
	var second := NetManager.request_host(0)
	assert_eq(first.state, NetRequest.State.CANCELLED)
	assert_eq(second.state, NetRequest.State.PENDING)
	assert_eq(NetManager.pending_request(), second)
	assert_eq(fake.calls, PackedStringArray(["start", "host", "leave", "host"]))
	assert_true(await _settles(second))
	assert_eq(second.state, NetRequest.State.READY)
	assert_eq(fake.offered.size(), 2, "both requests were answered")
	if fake.offered.size() == 2:
		assert_eq(fake.offered[0].get_connection_status(), MultiplayerPeer.CONNECTION_DISCONNECTED, "the first peer is closed")
		assert_eq(NetManager.multiplayer.multiplayer_peer, fake.offered[1], "only the second is installed")
	assert_eq(first.state, NetRequest.State.CANCELLED)
	assert_signal_emit_count(NetManager, "hosted", 1)


func test_leaving_cancels_and_leaves_the_platform_session() -> void:
	var fake := _fake()
	fake.defer_frames = 3
	watch_signals(NetManager)
	var request := NetManager.request_join(NetJoinTarget.with_token("sala-1", "Yuni"))
	assert_eq(request.state, NetRequest.State.PENDING)
	NetManager.leave()
	assert_eq(request.state, NetRequest.State.CANCELLED)
	assert_eq(fake.calls, PackedStringArray(["start", "join", "leave"]))
	assert_true(_offline())
	assert_null(NetManager.pending_request())
	await wait_process_frames(5)
	assert_true(_offline(), "the dropped answer never arrives")
	assert_true(fake.offered.is_empty())
	assert_signal_not_emitted(NetManager, "join_failed")
	assert_signal_not_emitted(NetManager, "joined")
	NetManager.leave()
	assert_eq(fake.calls.count("leave"), 1, "nothing open, so nothing to leave again")


func test_a_join_by_token_connects_to_the_lobby() -> void:
	var server := NetPeers.create_server(0)
	_servers.append(server)
	var token := FakeNetBackend.open_lobby(NetPeers.bound_port(server))
	var fake := _fake()
	fake.defer_frames = 2
	var request := NetManager.request_join(NetJoinTarget.with_token(token, "Yuni"))
	assert_true(request.is_pending())
	assert_true(await _settles(request))
	assert_eq(request.state, NetRequest.State.READY)
	assert_eq(NetManager.multiplayer.multiplayer_peer, request.peer)
	assert_false(NetManager.multiplayer.is_server(), "a client")
	assert_ne(request.peer.get_connection_status(), MultiplayerPeer.CONNECTION_DISCONNECTED)


func test_a_join_nobody_answers_times_out() -> void:
	var fake := _fake(0.3)
	fake.answer = false
	watch_signals(NetManager)
	NetManager.join_failed.connect(_on_join_failed)
	var request := NetManager.request_join(NetJoinTarget.with_token("sala-1", "Yuni"))
	assert_eq(request.state, NetRequest.State.PENDING)
	assert_true(await wait_for_signal(NetManager.join_failed, 3.0), "the watchdog fired")
	assert_signal_emit_count(NetManager, "join_failed", 1)
	assert_eq(_seen, ["join_failed TIMED_OUT offline"] as Array[String], "offline with the reason before the signal")
	assert_eq(request.state, NetRequest.State.FAILED)
	assert_eq(request.reason, NetFailure.Reason.TIMED_OUT)
	assert_eq(NetManager.last_failure, NetFailure.Reason.TIMED_OUT)
	assert_eq(NetManager.failure_text(NetManager.last_failure), "El anfitrión no respondió.")
	assert_true(_offline())
	assert_has(fake.calls, "leave")


func test_a_join_still_connecting_times_out() -> void:
	# Answered at once, but nobody is there: the watchdog counts until the host is reached, so a
	# client peer still connecting times out too.
	var fake := _fake(0.3)
	watch_signals(NetManager)
	var request := NetManager.request_join(NetJoinTarget.at_address("127.0.0.1", NOBODY_PORT))
	assert_eq(request.state, NetRequest.State.READY)
	assert_true(await wait_for_signal(NetManager.join_failed, 3.0), "timed out while still connecting")
	assert_eq(NetManager.last_failure, NetFailure.Reason.TIMED_OUT)
	assert_true(_offline())
	assert_has(fake.calls, "leave")
	assert_eq(fake.last_offered().get_connection_status(), MultiplayerPeer.CONNECTION_DISCONNECTED)


func test_the_watchdog_stops_once_the_host_is_reached() -> void:
	var server := NetPeers.create_server(0)
	_servers.append(server)
	var server_port: int = NetPeers.bound_port(server)
	_fake(1.5)
	watch_signals(NetManager)
	var request := NetManager.request_join(NetJoinTarget.at_address("127.0.0.1", server_port))
	assert_eq(request.state, NetRequest.State.READY)
	var reached: bool = await wait_until(func() -> bool:
		server.poll()
		return NetManager.multiplayer.multiplayer_peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED, 1.5)
	assert_true(reached, "the client reached the host")
	await wait_until(func() -> bool:
		server.poll()
		return false, 2.0)
	assert_signal_emitted(NetManager, "joined")
	assert_signal_not_emitted(NetManager, "join_failed")
	assert_true(NetManager.is_online(), "still connected after the timeout would have run out")


func test_late_refusals_carry_a_reason() -> void:
	var fake := _fake()
	fake.defer_frames = 2
	fake.refuse_host = NetFailure.Reason.NOT_SIGNED_IN
	fake.refuse_join = NetFailure.Reason.FULL
	watch_signals(NetManager)
	NetManager.host_failed.connect(_on_host_failed)
	NetManager.join_failed.connect(_on_join_failed)
	var hosting := NetManager.request_host(0)
	hosting.settled.connect(_on_settled)
	assert_eq(hosting.state, NetRequest.State.PENDING)
	assert_true(await _settles(hosting))
	assert_eq(hosting.state, NetRequest.State.FAILED)
	assert_eq(hosting.reason, NetFailure.Reason.NOT_SIGNED_IN)
	assert_eq(_seen, ["settled FAILED", "host_failed NOT_SIGNED_IN offline"] as Array[String])
	assert_signal_emit_count(NetManager, "host_failed", 1)
	assert_signal_not_emitted(NetManager, "hosted")
	assert_eq(NetManager.failure_text(NetManager.last_failure), "Inicia sesión en la plataforma para jugar en línea.")
	assert_eq(fake.calls, PackedStringArray(["start", "host", "leave"]))
	assert_true(_offline())
	_seen.clear()
	var joining := NetManager.request_join(NetJoinTarget.with_token("sala-1", "Yuni"))
	assert_eq(joining.state, NetRequest.State.PENDING)
	assert_true(await _settles(joining))
	assert_eq(joining.reason, NetFailure.Reason.FULL)
	assert_eq(_seen, ["join_failed FULL offline"] as Array[String])
	assert_signal_emit_count(NetManager, "join_failed", 1)
	assert_eq(NetManager.failure_text(NetManager.last_failure), "La partida está llena.")
	assert_eq(fake.calls, PackedStringArray(["start", "host", "leave", "join", "leave"]))
	assert_true(_offline())


func test_refusals_inside_the_call_emit_nothing() -> void:
	var fake := _fake()
	fake.refuse_host = NetFailure.Reason.NO_PRIVILEGE
	fake.refuse_join = NetFailure.Reason.FULL
	watch_signals(NetManager)
	var hosting := NetManager.request_host(0)
	assert_eq(hosting.state, NetRequest.State.FAILED)
	assert_eq(hosting.reason, NetFailure.Reason.NO_PRIVILEGE)
	assert_eq(NetManager.last_failure, NetFailure.Reason.NO_PRIVILEGE)
	assert_eq(NetManager.host(0), ERR_CANT_CREATE)
	var joining := NetManager.request_join(NetJoinTarget.with_token("sala-1", "Yuni"))
	assert_eq(joining.state, NetRequest.State.FAILED)
	assert_eq(joining.reason, NetFailure.Reason.FULL)
	assert_eq(NetManager.join("127.0.0.1", NOBODY_PORT), ERR_CANT_CONNECT)
	fake.refuse_join = NetFailure.Reason.NONE
	var gone := NetManager.request_join(NetJoinTarget.with_token("sala-que-no-existe", "Pepe"))
	assert_eq(gone.state, NetRequest.State.FAILED)
	assert_eq(gone.reason, NetFailure.Reason.NOT_FOUND)
	assert_eq(NetManager.failure_text(NetManager.last_failure), "Esa partida ya no existe.")
	var asked: int = fake.calls.size()
	var blank := NetManager.request_join(NetJoinTarget.with_token("  ", "Nadie"))
	assert_eq(blank.state, NetRequest.State.FAILED)
	assert_eq(blank.reason, NetFailure.Reason.INVALID_TARGET)
	assert_eq(NetManager.join("", NOBODY_PORT), ERR_INVALID_PARAMETER)
	assert_eq(fake.calls.size(), asked, "a refused target never reaches the backend")
	assert_signal_not_emitted(NetManager, "hosted")
	assert_signal_not_emitted(NetManager, "host_failed")
	assert_signal_not_emitted(NetManager, "join_failed")
	assert_signal_not_emitted(NetManager, "joined")
	assert_true(_offline())
	assert_true(fake.offered.is_empty())


func test_transport_failures_carry_a_reason() -> void:
	var fake := _fake()
	watch_signals(NetManager)
	assert_eq(NetManager.request_join(NetJoinTarget.at_address("127.0.0.1", NOBODY_PORT)).state, NetRequest.State.READY)
	NetManager._on_connection_failed()
	assert_signal_emitted(NetManager, "join_failed")
	assert_eq(NetManager.last_failure, NetFailure.Reason.UNREACHABLE)
	assert_eq(NetManager.failure_text(NetManager.last_failure), "No se pudo conectar.")
	assert_true(_offline())
	assert_eq(fake.calls, PackedStringArray(["start", "join", "leave"]))
	assert_eq(NetManager.request_host(0).state, NetRequest.State.READY)
	NetManager._on_server_disconnected()
	assert_signal_emitted(NetManager, "host_lost")
	assert_eq(NetManager.last_failure, NetFailure.Reason.HOST_LEFT)
	assert_eq(NetManager.failure_text(NetManager.last_failure), "Se perdió la conexión con el anfitrión.")
	assert_true(_offline())
	assert_eq(fake.calls, PackedStringArray(["start", "join", "leave", "host", "leave"]))


func test_failure_lines_and_the_lobby_note_come_from_the_table() -> void:
	assert_eq(NetManager.failure_text(NetFailure.Reason.PORT_UNAVAILABLE, [7777]), "No se pudo abrir el puerto 7777.")
	assert_eq(NetManager.failure_text(NetFailure.Reason.PORT_UNAVAILABLE, [7777], "en"), "Could not open port 7777.")
	assert_eq(NetManager.failure_text(NetFailure.Reason.NONE), "")
	assert_eq(NetManager.failure_text(NetFailure.Reason.CANCELLED), "")
	assert_eq(NetManager.lobby_note(), "", "no note while not hosting")
	NetManager.host(0)
	var port: int = NetManager.host_info().port
	assert_eq(NetManager.lobby_note("en"), "Others join by IP on UDP port %d. Over the internet, forward that port on your router." % port)


func test_an_outside_join_is_kept_until_taken() -> void:
	var fake := _fake()
	watch_signals(NetManager)
	var invite := NetJoinTarget.with_token("sala-1", "Yuni")
	fake.accept_invite(invite)
	assert_signal_emitted_with_parameters(NetManager, "outside_join_requested", [invite])
	var later := NetJoinTarget.with_token("sala-2", "Pepe")
	fake.accept_invite(later)
	assert_eq(NetManager.take_outside_join(), later, "the latest request is kept")
	assert_null(NetManager.take_outside_join(), "taken once")
	assert_eq(fake.calls, PackedStringArray(["start"]), "keeping a request never joins by itself")
	assert_true(_offline())
	var launched := FakeNetBackend.make()
	launched.launch = NetJoinTarget.with_token("sala-3", "Lazaro")
	NetManager.use_backend(launched, PackedStringArray(["--connect=lo-que-sea"]))
	assert_eq(NetManager.take_outside_join(), launched.launch, "a launch target is kept too")
	launched.accept_invite(invite)
	NetManager.use_backend(null)
	assert_null(NetManager.take_outside_join(), "restoring the backend clears it")
	fake.accept_invite(invite)
	assert_null(NetManager.take_outside_join(), "a backend swapped out is no longer heard")


func test_poll_runs_while_paused() -> void:
	var fake := _fake()
	assert_eq(NetManager.process_mode, Node.PROCESS_MODE_ALWAYS)
	await wait_process_frames(2)
	var before: int = fake.poll_count
	assert_gt(before, 0, "polled every frame")
	get_tree().paused = true
	await wait_process_frames(3)
	var during: int = fake.poll_count
	get_tree().paused = false
	assert_gte(during - before, 2, "still polled while paused")


func test_restoring_the_backend_returns_to_enet() -> void:
	var fake := FakeNetBackend.make(0.3)
	fake.start_failure = NetFailure.Reason.PLATFORM_UNAVAILABLE
	NetManager.use_backend(fake)
	assert_eq(NetManager.backend, fake)
	assert_eq(NetManager.backend_profile().id, &"fake")
	assert_eq(NetManager.startup_failure, NetFailure.Reason.PLATFORM_UNAVAILABLE)
	NetManager.use_backend(null)
	assert_true(NetManager.backend is EnetBackend)
	assert_eq(NetManager.startup_failure, NetFailure.Reason.NONE)
	assert_eq(NetManager.backend_profile().id, &"enet")
	assert_eq(NetManager.backend_profile().join_timeout_s, 0.0, "ENet keeps its own timeout")
	assert_true(_offline())
	assert_eq(NetManager.host(0), OK, "hosting works again")
	assert_true(NetManager.multiplayer.multiplayer_peer is ENetMultiplayerPeer)
