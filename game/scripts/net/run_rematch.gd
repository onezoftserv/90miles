class_name RunRematch
extends Node
## coop-networking "Rematch with the same party" (design D2): the host's call to start again with
## every client still connected. It travels on this node, the shell's child named "Rematch", and
## not on CoopSession, because the session is what a rematch replaces: the node exists at the same
## path on every peer before and after. Only the host sends the call and only a client acts on it.
## Offline (solo) nothing is sent: solo's "Otra vez" starts a solo run instead.
##
## The host frees its run before it calls and opens its new lobby after (design D3), so on ENet's
## one reliable channel the old run's despawns reach each client first and the new run's spawns
## last. A client rebuilds inside `called` (design D4).

## Client: the host called a rematch.
signal called

const HOST_ID: int = 1


## Host: tells every connected client to start again. False offline or on a client, and then
## nothing is sent.
func call_party() -> bool:
	if multiplayer.multiplayer_peer is OfflineMultiplayerPeer or not multiplayer.is_server():
		return false
	begin.rpc()
	return true


# Client: the host's call. Anything else (a local call, the host itself) is ignored.
@rpc("authority", "call_remote", "reliable")
func begin() -> void:
	if multiplayer.is_server() or multiplayer.get_remote_sender_id() != HOST_ID:
		return
	called.emit()
