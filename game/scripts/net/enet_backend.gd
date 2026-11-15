class_name EnetBackend
extends NetBackend
## The default backend (net-platform "Platform backend"): ENet over UDP through NetPeers, joined
## by IP. It answers inside every call, so hosting and joining are ready before they return.

## Launch argument for a join from outside the game: --connect=<address[:port]>.
const LAUNCH_FLAG: String = "--connect="
## ENet's packet throttle on each client connection (intent-delivery "Unreliable traffic is not
## thinned on a lossless link", owner decision Q2): ENet's default interval and acceleration and
## no deceleration, so the throttle never falls and never drops an intent or a host state.
const THROTTLE_INTERVAL_MS: int = 5000
const THROTTLE_ACCELERATION: int = 2
const THROTTLE_DECELERATION: int = 0


## OK for an address target the join screen would accept (not blank, port 1 to 65535).
func check_target(target: NetJoinTarget) -> Error:
	if target == null or not target.is_address():
		return ERR_INVALID_PARAMETER
	return OK if NetPeers.is_valid_address(target.address, target.port) else ERR_INVALID_PARAMETER


func host(request: NetRequest, port: int) -> void:
	var peer := NetPeers.create_server(port)
	if peer == null:
		request.fail(NetFailure.Reason.PORT_UNAVAILABLE, [port])
		return
	keep_throttle_open(peer)
	var info := NetHostInfo.new()
	info.port = NetPeers.bound_port(peer)
	info.addresses = NetPeers.lan_addresses(IP.get_local_addresses())
	request.succeed(peer, info)


## Keeps ENet's packet throttle open on every client connection the server `peer` accepts from
## now on. It is set the moment each client connects, before the join's reliable traffic:
## deceleration 0 only stops falls, so set any later it would leave a fall from the join in place
## for up to an interval (intent-delivery design.md, "When to open it"). ENet passes the setting
## to the client, so the client's intents to the host stay open too. NetHarness uses it as well.
static func keep_throttle_open(peer: MultiplayerPeer) -> void:
	var enet := peer as ENetMultiplayerPeer
	if enet != null:
		# A weak reference, so the peer's own signal does not keep the peer alive.
		enet.peer_connected.connect(_open_throttle.bind(weakref(enet)))


static func _open_throttle(peer_id: int, server: WeakRef) -> void:
	var enet := server.get_ref() as ENetMultiplayerPeer
	if enet == null:
		return
	var connection: ENetPacketPeer = enet.get_peer(peer_id)
	if connection != null:
		connection.throttle_configure(THROTTLE_INTERVAL_MS, THROTTLE_ACCELERATION, THROTTLE_DECELERATION)


func join(request: NetRequest) -> void:
	if check_target(request.target) != OK:
		request.fail(NetFailure.Reason.INVALID_TARGET)
		return
	var peer := NetPeers.create_client(request.target.address, request.target.port)
	if peer == null:
		request.fail(NetFailure.Reason.UNREACHABLE)
		return
	request.succeed(peer)


## The first --connect= argument, read with the join screen's rules (port 7777 unless given, 1 to
## 65535, address not blank); null when there is none or it is not valid.
func launch_target(args: PackedStringArray) -> NetJoinTarget:
	for arg: String in args:
		if not arg.begins_with(LAUNCH_FLAG):
			continue
		var text := arg.substr(LAUNCH_FLAG.length()).strip_edges()
		var address := text
		var port: int = NetPeers.DEFAULT_PORT
		if text.contains(":"):
			address = text.get_slice(":", 0).strip_edges()
			var port_text := text.get_slice(":", 1).strip_edges()
			if not port_text.is_valid_int():
				return null
			port = port_text.to_int()
		var target := NetJoinTarget.at_address(address, port)
		return target if check_target(target) == OK else null
	return null
