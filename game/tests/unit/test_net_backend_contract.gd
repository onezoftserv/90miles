extends GutTest
## net-platform "Every backend keeps the session contract": the multiplayer contract CoopSession
## relies on, checked for EnetBackend and for FakeNetBackend (design.md D6). Every case runs once
## per backend, as two tests that share one helper, so each gets its own before and after.
##
## Two branches stand for two machines. Each has its own SceneMultiplayer and its own backend, and
## does NetManager's part: it installs the peer a backend answers with, then settles the request.
## The fake answers some frames later and joins by lobby token, as a platform does. The same steps
## are the two-machine checklist for the Steam change, since a Steam peer cannot connect to itself.
##
## The relay is not part of what this suite checks: a backend never touches the SceneMultiplayer,
## and NetManager._use() turns the relay off (design.md D11). Each branch sets it off only to match
## the game; test_net_requests.gd checks it through NetManager on ENet and on a slower backend.

const ENET: StringName = &"enet"
const FAKE: StringName = &"fake"
## The fake answers this many frames after the call, like a platform lobby.
const FAKE_DEFER: int = 3
const TIMEOUT_S: float = 5.0

var _host: Machine
var _client: Machine


## One machine: a branch with its own SceneMultiplayer and its own backend. It stands in for
## NetManager: on `answered` it installs the peer and settles READY, or settles FAILED when there
## is no peer; an answer for a request it no longer waits on is closed. leave() cancels a pending
## request, leaves the platform session and closes the installed peer.
class Machine:
	extends RefCounted

	var branch: Node
	var api: SceneMultiplayer
	var backend: NetBackend
	## Every peer this machine installed, in order.
	var installed: Array[MultiplayerPeer] = []
	## The request this machine waits on (the latest one).
	var request: NetRequest

	## Makes `next` the request this machine waits on, without handing it to the backend. Asking
	## again cancels the request before it, as NetManager does.
	func track(next: NetRequest) -> NetRequest:
		if request != null:
			request.cancel()
		request = next
		next.answered.connect(_on_answered)
		return next

	## Hands `asked` to the backend.
	func send(asked: NetRequest) -> void:
		if asked.kind == NetRequest.Kind.HOST:
			backend.host(asked, asked.port)
		else:
			backend.join(asked)

	func ask_host(port: int) -> NetRequest:
		var asked := track(NetRequest.new(NetRequest.Kind.HOST, port))
		send(asked)
		return asked

	func ask_join(target: NetJoinTarget) -> NetRequest:
		var asked := track(NetRequest.new(NetRequest.Kind.JOIN, 0, target))
		send(asked)
		return asked

	func leave() -> void:
		if request != null:
			request.cancel()
		backend.leave()
		var peer := api.multiplayer_peer
		if peer != null and not peer is OfflineMultiplayerPeer:
			peer.close()
		api.multiplayer_peer = OfflineMultiplayerPeer.new()

	func is_offline() -> bool:
		return api.multiplayer_peer == null or api.multiplayer_peer is OfflineMultiplayerPeer

	func is_connected_to_host() -> bool:
		var peer := api.multiplayer_peer
		return peer != null and not peer is OfflineMultiplayerPeer \
				and peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED

	func _on_answered(answered: NetRequest) -> void:
		if answered != request or not answered.is_pending():
			if answered.peer != null:
				answered.peer.close()
			return
		if answered.peer == null:
			answered.settle(NetRequest.State.FAILED)
			return
		api.multiplayer_peer = answered.peer
		installed.append(answered.peer)
		answered.settle(NetRequest.State.READY)


## A request that keeps every peer the backend offered it. Holding them means only
## NetRequest.succeed() can close a late one: EnetBackend keeps no reference, so otherwise reference
## counting would free and close a late ENet peer whatever the request did.
class WatchedRequest:
	extends NetRequest

	var offers: Array[MultiplayerPeer] = []

	func _init(request_kind: NetRequest.Kind = NetRequest.Kind.HOST, host_port: int = 0,
			join_target: NetJoinTarget = null) -> void:
		super(request_kind, host_port, join_target)

	func succeed(offered: MultiplayerPeer, host_info: NetHostInfo = null) -> void:
		if offered != null:
			offers.append(offered)
		super(offered, host_info)


func before_all() -> void:
	assert_true(NetManager.backend is EnetBackend, "every suite starts on ENet")


func after_all() -> void:
	assert_true(NetManager.backend is EnetBackend, "every suite leaves ENet behind")


func after_each() -> void:
	for machine: Machine in [_host, _client]:
		if machine != null:
			_drop(machine)
	_host = null
	_client = null
	NetManager.leave()
	NetManager.use_backend(null)
	FakeNetBackend.reset()


# --- Two machines ----------------------------------------------------------------------------------

func _machines(kind: StringName) -> void:
	_host = _machine("Host", kind)
	_client = _machine("Client", kind)


func _machine(machine_name: String, kind: StringName) -> Machine:
	var machine := Machine.new()
	machine.branch = Node.new()
	machine.branch.name = machine_name
	add_child(machine.branch)
	machine.api = SceneMultiplayer.new()
	# As NetManager._use() sets it; no backend reads or writes it.
	machine.api.server_relay = false
	get_tree().set_multiplayer(machine.api, machine.branch.get_path())
	machine.backend = _backend(kind)
	return machine


func _backend(kind: StringName) -> NetBackend:
	if kind == ENET:
		return EnetBackend.new()
	var fake := FakeNetBackend.make()
	fake.defer_frames = FAKE_DEFER
	# The worst platform: answers already on their way still arrive after leave().
	fake.deliver_after_leave = true
	return fake


func _drop(machine: Machine) -> void:
	if machine.request != null:
		machine.request.cancel()
	machine.backend.leave()
	var peer := machine.api.multiplayer_peer
	if peer != null and not peer is OfflineMultiplayerPeer:
		peer.close()
	machine.api.multiplayer_peer = null
	if is_instance_valid(machine.branch):
		get_tree().set_multiplayer(null, machine.branch.get_path())
		machine.branch.free()


func _settled(request: NetRequest) -> bool:
	return await wait_until(func() -> bool: return not request.is_pending(), TIMEOUT_S)


## Hosts on a free port and waits for the answer. Returns how a client joins it: the lobby token
## on the fake, the address on ENet. Null if the host never came up.
func _open_host() -> NetJoinTarget:
	var request := _host.ask_host(0)
	await _settled(request)
	assert_eq(request.state, NetRequest.State.READY, "the host is up")
	if request.state != NetRequest.State.READY:
		return null
	if _host.backend is FakeNetBackend:
		return NetJoinTarget.with_token((_host.backend as FakeNetBackend).last_token, "Sala de prueba")
	return NetJoinTarget.at_address("127.0.0.1", request.info.port)


## Joins `target` and waits until the client is connected and the host has admitted it. Returns
## the client's peer id, or 0 if it never got there.
func _connect_client(target: NetJoinTarget) -> int:
	var request := _client.ask_join(target)
	await _settled(request)
	if request.state != NetRequest.State.READY:
		return 0
	var id: int = _client.api.get_unique_id()
	var admitted := func() -> bool: return _client.is_connected_to_host() and _host.api.get_peers().has(id)
	var ok: bool = await wait_until(admitted, TIMEOUT_S)
	return id if ok else 0


func _host_lost() -> bool:
	var lost := func() -> bool: return get_signal_emit_count(_client.api, "server_disconnected") > 0
	return await wait_until(lost, TIMEOUT_S)


## A free UDP port right now: a server is opened on port 0 and closed again.
func _free_port() -> int:
	var probe := NetPeers.create_server(0)
	assert_not_null(probe, "a probe server opens")
	if probe == null:
		return 0
	var port: int = NetPeers.bound_port(probe)
	probe.close()
	return port


## The player leaves while `request` is in flight, then the backend's answer arrives. A platform
## answers later on its own. ENet answers only inside its call, so for ENet the call comes after
## leaving: the earliest an ENet answer can come after leave().
func _answer_after_leaving(machine: Machine, request: NetRequest) -> void:
	var answers_later: bool = machine.backend is FakeNetBackend
	machine.track(request)
	if answers_later:
		machine.send(request)
	machine.leave()
	if not answers_later:
		machine.send(request)
	await wait_process_frames(FAKE_DEFER + 3)


# --- The host is peer 1 and a client 2 or more ---------------------------------------------------

func test_host_is_peer_one_and_the_client_two_or_more_enet() -> void:
	await _host_is_peer_one_and_the_client_two_or_more(ENET)


func test_host_is_peer_one_and_the_client_two_or_more_fake() -> void:
	await _host_is_peer_one_and_the_client_two_or_more(FAKE)


func _host_is_peer_one_and_the_client_two_or_more(kind: StringName) -> void:
	_machines(kind)
	var target: NetJoinTarget = await _open_host()
	assert_eq(_host.api.get_unique_id(), 1, "the host is peer 1")
	assert_true(_host.api.is_server())
	var id: int = await _connect_client(target)
	assert_gte(id, 2, "a client is 2 or more")
	assert_false(_client.api.is_server(), "a client is not the server")
	assert_eq(_host.api.get_peers(), PackedInt32Array([id]), "the host sees the client")
	assert_eq(_client.api.get_peers(), PackedInt32Array([1]), "the client sees only the host")
	# The relay is NetManager's (design.md D11): test_net_requests.gd checks it after NetManager
	# installs an ENet peer and a slower backend's. Here it would only read back _machine()'s value.


# --- A reconnect is a new peer --------------------------------------------------------------------

func test_a_reconnect_is_a_new_peer_enet() -> void:
	await _a_reconnect_is_a_new_peer(ENET)


func test_a_reconnect_is_a_new_peer_fake() -> void:
	await _a_reconnect_is_a_new_peer(FAKE)


func _a_reconnect_is_a_new_peer(kind: StringName) -> void:
	_machines(kind)
	var target: NetJoinTarget = await _open_host()
	var first: int = await _connect_client(target)
	assert_gte(first, 2, "the first connection")
	_client.leave()
	var gone := func() -> bool: return not _host.api.get_peers().has(first)
	assert_true(await wait_until(gone, TIMEOUT_S), "the host saw the client go")
	var second: int = await _connect_client(target)
	assert_gte(second, 2, "the second connection")
	assert_ne(second, first, "a reconnect is a new peer")
	assert_eq(_host.api.get_peers(), PackedInt32Array([second]), "only the new peer is on the host")


# --- disconnect_peer closes the client ------------------------------------------------------------

func test_disconnect_peer_closes_the_client_enet() -> void:
	await _disconnect_peer_closes_the_client(ENET)


func test_disconnect_peer_closes_the_client_fake() -> void:
	await _disconnect_peer_closes_the_client(FAKE)


func _disconnect_peer_closes_the_client(kind: StringName) -> void:
	_machines(kind)
	var id: int = await _connect_client(await _open_host())
	assert_gte(id, 2, "connected")
	watch_signals(_client.api)
	_host.api.multiplayer_peer.disconnect_peer(id)
	assert_true(await _host_lost(), "the client hears it was dropped")
	assert_signal_emit_count(_client.api, "server_disconnected", 1)
	assert_eq(_client.api.multiplayer_peer.get_connection_status(), MultiplayerPeer.CONNECTION_DISCONNECTED,
			"the client's peer is closed")
	var gone := func() -> bool: return not _host.api.get_peers().has(id)
	assert_true(await wait_until(gone, TIMEOUT_S), "and the host no longer lists it")


# --- The host closing reaches the client ----------------------------------------------------------

func test_host_closing_reaches_the_client_enet() -> void:
	await _host_closing_reaches_the_client(ENET)


func test_host_closing_reaches_the_client_fake() -> void:
	await _host_closing_reaches_the_client(FAKE)


func _host_closing_reaches_the_client(kind: StringName) -> void:
	_machines(kind)
	var id: int = await _connect_client(await _open_host())
	assert_gte(id, 2, "connected")
	watch_signals(_client.api)
	_host.leave()
	assert_true(await _host_lost(), "the client reports the host as lost")
	assert_signal_emit_count(_client.api, "server_disconnected", 1)
	assert_eq(_client.api.multiplayer_peer.get_connection_status(), MultiplayerPeer.CONNECTION_DISCONNECTED)


# --- A bad target fails with no peer --------------------------------------------------------------

func test_a_bad_target_fails_without_a_peer_enet() -> void:
	await _a_bad_target_fails_without_a_peer(ENET)


func test_a_bad_target_fails_without_a_peer_fake() -> void:
	await _a_bad_target_fails_without_a_peer(FAKE)


func _a_bad_target_fails_without_a_peer(kind: StringName) -> void:
	_machines(kind)
	var targets: Array[NetJoinTarget] = [
		NetJoinTarget.at_address("", NetPeers.DEFAULT_PORT),
		NetJoinTarget.at_address("127.0.0.1", 0),
		NetJoinTarget.with_token("sala-que-no-existe", "Nadie"),
	]
	var allowed: Array[NetFailure.Reason] = [NetFailure.Reason.INVALID_TARGET, NetFailure.Reason.NOT_FOUND]
	for target: NetJoinTarget in targets:
		var request := _client.ask_join(target)
		await _settled(request)
		var shown := "\"%s\"" % target.label
		assert_true(request.is_answered(), "%s: the backend answered" % shown)
		assert_eq(request.state, NetRequest.State.FAILED, "%s: failed" % shown)
		assert_has(allowed, request.reason, "%s: INVALID_TARGET or NOT_FOUND, got %s"
				% [shown, NetFailure.Reason.keys()[request.reason]])
		assert_null(request.peer, "%s: no peer" % shown)
	assert_true(_client.installed.is_empty(), "nothing was installed")
	assert_true(_client.is_offline(), "the machine stays offline")
	if _client.backend is FakeNetBackend:
		assert_true((_client.backend as FakeNetBackend).offered.is_empty(), "no peer was opened")


# --- A peer after leave is closed -----------------------------------------------------------------

func test_a_peer_after_leave_is_closed_enet() -> void:
	await _a_peer_after_leave_is_closed(ENET)


func test_a_peer_after_leave_is_closed_fake() -> void:
	await _a_peer_after_leave_is_closed(FAKE)


func _a_peer_after_leave_is_closed(kind: StringName) -> void:
	_machines(kind)
	var target: NetJoinTarget = await _open_host()
	watch_signals(_host.api)

	# A late host: its server is closed, so the port is free again.
	var port: int = _free_port()
	var hosting := WatchedRequest.new(NetRequest.Kind.HOST, port)
	await _answer_after_leaving(_client, hosting)
	assert_eq(hosting.state, NetRequest.State.CANCELLED, "host: cancelled by leaving")
	_assert_late_peer_closed(hosting, "host")
	assert_null(hosting.info, "host: no lobby shown")
	var again := NetPeers.create_server(port)
	assert_not_null(again, "host: the late server was closed, so port %d is free" % port)
	if again != null:
		again.close()

	# A late join: its client is closed, so the host never admits it.
	var joining := WatchedRequest.new(NetRequest.Kind.JOIN, 0, target)
	await _answer_after_leaving(_client, joining)
	assert_eq(joining.state, NetRequest.State.CANCELLED, "join: cancelled by leaving")
	_assert_late_peer_closed(joining, "join")
	await wait_seconds(0.3)
	assert_signal_not_emitted(_host.api, "peer_connected", "join: the host never admitted the late client")
	assert_eq(_host.api.get_peers(), PackedInt32Array(), "join: no peer on the host")

	assert_true(_client.installed.is_empty(), "nothing was installed after leave")
	assert_true(_client.is_offline(), "the machine stays offline")
	if _client.backend is FakeNetBackend:
		assert_eq((_client.backend as FakeNetBackend).last_token, "", "no lobby was listed for the late host")


func _assert_late_peer_closed(request: WatchedRequest, what: String) -> void:
	assert_eq(request.offers.size(), 1, "%s: the backend still answered with a peer" % what)
	for peer: MultiplayerPeer in request.offers:
		assert_eq(peer.get_connection_status(), MultiplayerPeer.CONNECTION_DISCONNECTED,
				"%s: the late peer is closed" % what)
	assert_null(request.peer, "%s: never kept" % what)
