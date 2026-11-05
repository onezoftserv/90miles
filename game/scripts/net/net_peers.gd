class_name NetPeers
extends RefCounted
## Creates the multiplayer transport (coop-networking "Host and join", review item 40). ENet
## now, joined by IP; the host forwards UDP DEFAULT_PORT by hand (no UPnP). Steam relay or
## WebRTC would replace only create_server() and create_client(). Used by NetManager and by
## the tests; autoloads hold no constants (core-services), so the numbers live here.

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
