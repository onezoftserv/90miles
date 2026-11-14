class_name PalmSync
extends Node
## The island's palms on every peer (coop-networking "Structure state on every peer" and "Structure
## state for joiners"; structure-state-sync design D5). The island adds it to the session in
## `furnish`, so it goes with the island's other furniture when the party travels and the next island
## adds its own at the same path. The host sends a palm's coconuts to every client in the run when
## they change, and every palm's count to a joiner or a rejoined player once its island has loaded
## (`CoopSession.join_state_sent`). A client applies only what the host sends, by the palm's place in
## the layout (the same on every peer; palm node names are not), held to 0 up to the layout's count.
## Solo has no client, so nothing is sent.

const HOST_ID: int = CoopSession.HOST_ID

## Host: the messages it sent (the solo test reads it).
var sent_count: int = 0

var _session: CoopSession
var _palms: Array[Palm] = []
## Each palm's layout count: the most it can hold.
var _most: Array[int] = []


## Every peer: follows `palms`, in layout order, whose layout counts are `most`. Call once, with this
## node in `session`.
func setup(session: CoopSession, palms: Array[Palm], most: Array[int]) -> void:
	_session = session
	_palms = palms.duplicate()
	_most = most.duplicate()
	for index: int in _palms.size():
		_palms[index].coconuts_changed.connect(_on_coconuts_changed.bind(index))
	session.join_state_sent.connect(_send_all)


## Every palm's count, in layout order.
func counts() -> PackedInt32Array:
	var all := PackedInt32Array()
	for palm: Palm in _palms:
		all.append(palm.coconuts)
	return all


## Client: palm `index` holds `count`, held to 0 up to its layout count. An index out of range is
## dropped.
func apply_count(index: int, count: int) -> void:
	if index < 0 or index >= _palms.size() or index >= _most.size():
		return
	_palms[index].coconuts = clampi(count, 0, _most[index])


## Client: every palm's count, in layout order. A list of another size is for another island and is
## dropped.
func apply_counts(all: PackedInt32Array) -> void:
	if all.size() != _palms.size():
		return
	for index: int in all.size():
		apply_count(index, all[index])


@rpc("authority", "call_remote", "reliable")
func receive_count(index: int, count: int) -> void:
	if multiplayer.get_remote_sender_id() == HOST_ID:
		apply_count(index, count)


@rpc("authority", "call_remote", "reliable")
func receive_counts(all: PackedInt32Array) -> void:
	if multiplayer.get_remote_sender_id() == HOST_ID:
		apply_counts(all)


# Host: palm `index` changed, so every client in the run hears it.
func _on_coconuts_changed(count: int, index: int) -> void:
	if not multiplayer.is_server():
		return
	for peer: int in _peers_in_run():
		receive_count.rpc_id(peer, index, count)
		sent_count += 1


# Host: a joiner or a rejoined player gets every count, after the world state that loads its island.
func _send_all(peer: int) -> void:
	if multiplayer.is_server() and multiplayer.get_peers().has(peer):
		receive_counts.rpc_id(peer, counts())
		sent_count += 1


# Connected clients with a player in the session. A peer in the lobby or still joining has no island
# to keep; it gets every count when it is admitted.
func _peers_in_run() -> Array[int]:
	var peers: Array[int] = []
	for peer: int in multiplayer.get_peers():
		if _session.body(peer) != null:
			peers.append(peer)
	return peers
