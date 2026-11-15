extends GutTest
## net-platform "Platform backend" and "Hosting and joining may finish later": EnetBackend wraps
## NetPeers and answers inside every call. It hands back a peer and never sets one; here the
## test stands in for NetManager and settles each answer without touching `multiplayer`.

const NOBODY_PORT: int = 7999

var _peers: Array[MultiplayerPeer] = []


func before_each() -> void:
	NetManager.start_solo()


func after_each() -> void:
	for peer: MultiplayerPeer in _peers:
		if peer != null and peer.get_connection_status() != MultiplayerPeer.CONNECTION_DISCONNECTED:
			peer.close()
	_peers.clear()
	NetManager.leave()


# A request the test settles the way NetManager will: READY with a peer, FAILED without.
func _request(kind: NetRequest.Kind, port: int = 0, target: NetJoinTarget = null) -> NetRequest:
	var request := NetRequest.new(kind, port, target)
	request.answered.connect(_settle)
	return request


func _settle(request: NetRequest) -> void:
	if request.peer != null:
		_peers.append(request.peer)
	request.settle(NetRequest.State.READY if request.peer != null else NetRequest.State.FAILED)


func test_host_answers_before_returning() -> void:
	var request := _request(NetRequest.Kind.HOST)
	EnetBackend.new().host(request, 0)
	assert_eq(request.state, NetRequest.State.READY, "answered inside the call")
	assert_true(request.peer is ENetMultiplayerPeer)
	assert_eq(request.peer.get_unique_id(), 1, "a server peer: the host is peer 1")
	assert_eq(request.reason, NetFailure.Reason.NONE)
	assert_not_null(request.info)
	assert_gt(request.info.port, 0)
	assert_eq(request.info.port, NetPeers.bound_port(request.peer))
	assert_eq(request.info.addresses, NetPeers.lan_addresses(IP.get_local_addresses()))
	for address: String in request.info.addresses:
		assert_true(address.is_valid_ip_address() and not address.contains(":"), "%s is IPv4" % address)
		assert_false(address.begins_with("127."), "%s is not loopback" % address)
		assert_false(address.begins_with("169.254."), "%s is not link-local" % address)


func test_a_taken_port_fails_with_its_number() -> void:
	var holder := NetPeers.create_server(0)
	assert_not_null(holder)
	_peers.append(holder)
	var port: int = NetPeers.bound_port(holder)
	var request := _request(NetRequest.Kind.HOST)
	EnetBackend.new().host(request, port)
	assert_engine_error("Couldn't create an ENet host")
	assert_eq(request.state, NetRequest.State.FAILED)
	assert_eq(request.reason, NetFailure.Reason.PORT_UNAVAILABLE)
	assert_eq(request.reason_args, [port])
	assert_null(request.peer, "no peer")
	assert_null(request.info)


func test_join_answers_connecting() -> void:
	var request := _request(NetRequest.Kind.JOIN, 0, NetJoinTarget.at_address("127.0.0.1", NOBODY_PORT))
	EnetBackend.new().join(request)
	assert_eq(request.state, NetRequest.State.READY, "answered inside the call, even with nobody there")
	assert_true(request.peer is ENetMultiplayerPeer)
	assert_eq(request.peer.get_connection_status(), MultiplayerPeer.CONNECTION_CONNECTING)


func test_check_target_refuses_blank_and_bad_ports() -> void:
	var backend := EnetBackend.new()
	assert_eq(backend.check_target(NetJoinTarget.at_address("127.0.0.1", NetPeers.DEFAULT_PORT)), OK)
	assert_eq(backend.check_target(NetJoinTarget.at_address("192.168.1.20", 1)), OK)
	assert_eq(backend.check_target(NetJoinTarget.at_address("192.168.1.20", 65535)), OK)
	assert_eq(backend.check_target(NetJoinTarget.at_address("", NetPeers.DEFAULT_PORT)), ERR_INVALID_PARAMETER)
	assert_eq(backend.check_target(NetJoinTarget.at_address("   ", NetPeers.DEFAULT_PORT)), ERR_INVALID_PARAMETER)
	assert_eq(backend.check_target(NetJoinTarget.at_address("127.0.0.1", 0)), ERR_INVALID_PARAMETER)
	assert_eq(backend.check_target(NetJoinTarget.at_address("127.0.0.1", 65536)), ERR_INVALID_PARAMETER)
	assert_eq(backend.check_target(NetJoinTarget.with_token("109775241234567", "Yuni")), ERR_INVALID_PARAMETER,
			"ENet cannot join a platform token")
	assert_eq(backend.check_target(null), ERR_INVALID_PARAMETER)


func test_a_refused_target_fails_without_a_peer() -> void:
	var request := _request(NetRequest.Kind.JOIN, 0, NetJoinTarget.with_token("109775241234567", "Yuni"))
	EnetBackend.new().join(request)
	assert_eq(request.state, NetRequest.State.FAILED)
	assert_eq(request.reason, NetFailure.Reason.INVALID_TARGET)
	assert_null(request.peer)


func test_launch_argument() -> void:
	var backend := EnetBackend.new()
	var written := backend.launch_target(PackedStringArray(["--verbose", "--connect=10.0.0.5:7780"]))
	assert_not_null(written)
	if written != null:
		assert_true(written.is_address())
		assert_eq(written.address, "10.0.0.5")
		assert_eq(written.port, 7780)
		assert_eq(written.label, "10.0.0.5:7780")
	var default_port := backend.launch_target(PackedStringArray(["--connect=10.0.0.5"]))
	assert_not_null(default_port)
	if default_port != null:
		assert_eq(default_port.address, "10.0.0.5")
		assert_eq(default_port.port, NetPeers.DEFAULT_PORT)
		assert_eq(default_port.label, "10.0.0.5:7777")
	assert_null(backend.launch_target(PackedStringArray(["--connect="])), "blank address")
	assert_null(backend.launch_target(PackedStringArray(["--connect=h:0"])), "port 0")
	assert_null(backend.launch_target(PackedStringArray(["--connect=h:65536"])), "port past 65535")
	assert_null(backend.launch_target(PackedStringArray(["--connect=h:abc"])), "port not a number")
	assert_null(backend.launch_target(PackedStringArray(["--host", "--join=10.0.0.5"])), "no flag")
	assert_null(backend.launch_target(PackedStringArray()), "no arguments")


func test_a_backend_never_sets_the_peer() -> void:
	var request := _request(NetRequest.Kind.HOST)
	EnetBackend.new().host(request, 0)
	assert_true(request.peer is ENetMultiplayerPeer)
	assert_true(NetManager.multiplayer.multiplayer_peer is OfflineMultiplayerPeer, "NetManager's peer untouched")
	assert_true(get_tree().root.multiplayer.multiplayer_peer is OfflineMultiplayerPeer, "the root's peer untouched")


func test_an_answer_is_given_once() -> void:
	var request := NetRequest.new(NetRequest.Kind.HOST)
	watch_signals(request)
	var first := NetPeers.create_server(0)
	var second := NetPeers.create_server(0)
	_peers.append(first)
	_peers.append(second)
	request.succeed(first, NetHostInfo.new())
	request.succeed(second)
	request.fail(NetFailure.Reason.FULL)
	assert_signal_emit_count(request, "answered", 1)
	assert_eq(request.peer, first, "the first answer stands")
	assert_eq(request.reason, NetFailure.Reason.NONE)
	assert_eq(second.get_connection_status(), MultiplayerPeer.CONNECTION_DISCONNECTED, "a second peer is closed")
	assert_true(request.is_pending(), "still pending until NetManager settles it")
	request.settle(NetRequest.State.READY)
	request.settle(NetRequest.State.FAILED)
	assert_signal_emit_count(request, "settled", 1)
	assert_eq(request.state, NetRequest.State.READY)


func test_a_peer_for_a_cancelled_request_is_closed() -> void:
	var request := NetRequest.new(NetRequest.Kind.JOIN, 0, NetJoinTarget.at_address("127.0.0.1", NOBODY_PORT))
	watch_signals(request)
	request.cancel()
	assert_eq(request.state, NetRequest.State.CANCELLED)
	assert_eq(request.reason, NetFailure.Reason.CANCELLED)
	assert_signal_emit_count(request, "settled", 1)
	var late := NetPeers.create_client("127.0.0.1", NOBODY_PORT)
	_peers.append(late)
	request.succeed(late)
	assert_signal_not_emitted(request, "answered")
	assert_null(request.peer, "never kept")
	assert_eq(late.get_connection_status(), MultiplayerPeer.CONNECTION_DISCONNECTED, "closed, never installed")


func test_a_failure_without_a_reason_is_unsupported() -> void:
	var request := NetRequest.new(NetRequest.Kind.JOIN)
	request.fail(NetFailure.Reason.NONE)
	assert_eq(request.reason, NetFailure.Reason.UNSUPPORTED)
	var no_peer := NetRequest.new(NetRequest.Kind.HOST)
	no_peer.succeed(null)
	assert_eq(no_peer.reason, NetFailure.Reason.UNSUPPORTED, "a null peer is a failure")
	assert_null(no_peer.peer)


func test_the_base_backend_refuses_everything_safely() -> void:
	var backend := NetBackend.new()
	assert_eq(backend.start(PackedStringArray()), NetFailure.Reason.NONE)
	assert_eq(backend.check_target(NetJoinTarget.at_address("127.0.0.1", 7777)), ERR_INVALID_PARAMETER)
	var host := _request(NetRequest.Kind.HOST)
	backend.host(host, 0)
	assert_eq(host.state, NetRequest.State.FAILED)
	assert_eq(host.reason, NetFailure.Reason.UNSUPPORTED)
	var join := _request(NetRequest.Kind.JOIN, 0, NetJoinTarget.with_token("abc", "Yuni"))
	backend.join(join)
	assert_eq(join.reason, NetFailure.Reason.UNSUPPORTED)
	assert_null(backend.launch_target(PackedStringArray(["--connect=10.0.0.5"])))
	backend.leave()
	backend.poll(0.016)
	assert_true(NetManager.multiplayer.multiplayer_peer is OfflineMultiplayerPeer)


func test_join_targets() -> void:
	var address := NetJoinTarget.at_address(" 192.168.1.20 ", 7780)
	assert_true(address.is_address())
	assert_eq(address.address, "192.168.1.20")
	assert_eq(address.label, "192.168.1.20:7780")
	var token := NetJoinTarget.with_token("109775241234567", "Yuni")
	assert_false(token.is_address())
	assert_eq(token.token, "109775241234567")
	assert_eq(token.label, "Yuni")
	assert_eq(token.port, 0)


# intent-delivery "Unreliable traffic is not thinned on a lossless link" (owner decision Q2): the
# host keeps ENet's packet throttle open on each client connection from the moment it connects,
# before the join's reliable traffic, and ENet passes the setting to the client.
func test_a_hosted_peer_keeps_the_throttle_open_on_every_client_connection() -> void:
	var request := _request(NetRequest.Kind.HOST)
	EnetBackend.new().host(request, 0)
	var server := request.peer as ENetMultiplayerPeer
	assert_not_null(server)
	if server == null:
		return
	var client := NetPeers.create_client("127.0.0.1", request.info.port) as ENetMultiplayerPeer
	_peers.append(client)
	var ids: Array[int] = []
	server.peer_connected.connect(func(id: int) -> void: ids.append(id))
	var connected := func() -> bool:
		server.poll()
		client.poll()
		return not ids.is_empty() and client.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED
	assert_true(await wait_until(connected, 5.0), "the client connected")
	if ids.is_empty():
		return
	var to_client: ENetPacketPeer = server.get_peer(ids[0])
	assert_eq(to_client.get_statistic(ENetPacketPeer.PEER_PACKET_THROTTLE_DECELERATION), EnetBackend.THROTTLE_DECELERATION)
	assert_eq(to_client.get_statistic(ENetPacketPeer.PEER_PACKET_THROTTLE_ACCELERATION), EnetBackend.THROTTLE_ACCELERATION)
	assert_eq(to_client.get_statistic(ENetPacketPeer.PEER_PACKET_THROTTLE_INTERVAL), EnetBackend.THROTTLE_INTERVAL_MS)
	var to_host: ENetPacketPeer = client.get_peer(1)
	var told := func() -> bool:
		server.poll()
		client.poll()
		return to_host.get_statistic(ENetPacketPeer.PEER_PACKET_THROTTLE_DECELERATION) == 0
	assert_true(await wait_until(told, 5.0), "ENet passed the setting to the client")


func test_the_throttle_numbers() -> void:
	assert_eq(EnetBackend.THROTTLE_INTERVAL_MS, 5000, "ENet's default interval")
	assert_eq(EnetBackend.THROTTLE_ACCELERATION, 2, "ENet's default acceleration")
	assert_eq(EnetBackend.THROTTLE_DECELERATION, 0, "never thinned")


func test_solo_has_no_connection_to_throttle() -> void:
	NetManager.start_solo()
	assert_true(NetManager.multiplayer.multiplayer_peer is OfflineMultiplayerPeer, "solo is offline: no ENet peer at all")
