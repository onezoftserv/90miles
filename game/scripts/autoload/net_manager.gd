extends Node
## NetManager autoload (core-services spec): hosting, joining and peers for the game's
## multiplayer API. Gameplay networking lives in CoopSession, which uses whatever peer is set
## here; the transport comes from NetPeers. This autoload only sets the peer and reports
## connection events.

## Hosting started; `port` is the bound port.
signal hosted(port: int)
## The client reached the host.
signal joined
## The client could not reach the host; the game is back on the offline peer.
signal join_failed
## The host went away; the game is back on the offline peer.
signal host_lost


func _ready() -> void:
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)


## Hosts on `port` (NetPeers.DEFAULT_PORT unless given; 0 picks a free one). Returns
## ERR_CANT_CREATE if the port cannot be bound.
func host(port: int = NetPeers.DEFAULT_PORT) -> Error:
	var peer := NetPeers.create_server(port)
	if peer == null:
		return ERR_CANT_CREATE
	_use(peer)
	hosted.emit(NetPeers.bound_port(peer))
	return OK


## Starts connecting to a host; `joined` or `join_failed` follows.
func join(address: String, port: int = NetPeers.DEFAULT_PORT) -> Error:
	if not NetPeers.is_valid_address(address, port):
		return ERR_INVALID_PARAMETER
	var peer := NetPeers.create_client(address, port)
	if peer == null:
		return ERR_CANT_CONNECT
	_use(peer)
	return OK


## Solo: the offline peer, so the host code path runs and no port is opened.
func start_solo() -> void:
	_use(OfflineMultiplayerPeer.new())


## Closes the current connection and returns to the offline peer.
func leave() -> void:
	start_solo()


func is_online() -> bool:
	return not multiplayer.multiplayer_peer is OfflineMultiplayerPeer


func _use(peer: MultiplayerPeer) -> void:
	var current := multiplayer.multiplayer_peer
	if current != null and current != peer and not current is OfflineMultiplayerPeer:
		current.close()
	var scene_api := multiplayer as SceneMultiplayer
	if scene_api != null:
		# Clients never talk to each other directly: everything goes through the host.
		scene_api.server_relay = false
	multiplayer.multiplayer_peer = peer


func _on_connected_to_server() -> void:
	joined.emit()


func _on_connection_failed() -> void:
	start_solo()
	join_failed.emit()


func _on_server_disconnected() -> void:
	start_solo()
	host_lost.emit()
