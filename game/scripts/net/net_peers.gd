class_name NetPeers
extends RefCounted
## The ENet peer factory behind EnetBackend and the tests (coop-networking "Host and join",
## net-platform "Platform backend", review item 40): joined by IP; the host forwards UDP
## DEFAULT_PORT by hand (no UPnP). A platform backend (Steam, EOS, a console) is a NetBackend of
## its own and leaves this file alone. Autoloads hold no constants (core-services), so the
## numbers live here.

const DEFAULT_PORT: int = 7777
const MAX_PLAYERS: int = 4
const MAX_PORT: int = 65535


## A server peer on `port` (0 picks a free one) for up to MAX_PLAYERS - 1 clients, or null.
static func create_server(port: int) -> MultiplayerPeer:
	if port < 0 or port > MAX_PORT:
		return null
	var peer := ENetMultiplayerPeer.new()
	if peer.create_server(port, MAX_PLAYERS - 1) != OK:
		return null
	return peer


## A client peer connecting to `address`:`port`, or null for a blank address or a bad port.
static func create_client(address: String, port: int) -> MultiplayerPeer:
	if not is_valid_address(address, port):
		return null
	var peer := ENetMultiplayerPeer.new()
	if peer.create_client(address.strip_edges(), port) != OK:
		return null
	return peer


## Whether `address`:`port` can be joined at all (not blank, port 1 to 65535).
static func is_valid_address(address: String, port: int) -> bool:
	return not address.strip_edges().is_empty() and port >= 1 and port <= MAX_PORT


## The local port a server peer is bound to (0 if unknown).
static func bound_port(peer: MultiplayerPeer) -> int:
	var enet := peer as ENetMultiplayerPeer
	if enet == null or enet.host == null:
		return 0
	return enet.host.get_local_port()


## The LAN IPv4 addresses worth showing in the host's lobby (no loopback, no link-local), sorted.
## `all` is IP.get_local_addresses(). Moved here from LobbyScreen.
static func lan_addresses(all: PackedStringArray) -> PackedStringArray:
	var shown: PackedStringArray = []
	for address: String in all:
		if address.is_valid_ip_address() and not address.contains(":") \
				and not address.begins_with("127.") and not address.begins_with("169.254."):
			shown.append(address)
	shown.sort()
	return shown
