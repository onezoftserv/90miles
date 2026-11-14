class_name EnetBackend
extends NetBackend
## The default backend (net-platform "Platform backend"): ENet over UDP through NetPeers, joined
## by IP. It answers inside every call, so hosting and joining are ready before they return.

## Launch argument for a join from outside the game: --connect=<address[:port]>.
const LAUNCH_FLAG: String = "--connect="


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
	var info := NetHostInfo.new()
	info.port = NetPeers.bound_port(peer)
	info.addresses = NetPeers.lan_addresses(IP.get_local_addresses())
	request.succeed(peer, info)


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
