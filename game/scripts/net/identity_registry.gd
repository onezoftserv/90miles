class_name IdentityRegistry
extends RefCounted
## coop-reconnect "Reclaiming a player": the host's map, for one run, from player id to the peer
## that plays it and a hash of its secret. A join with a player's id and matching secret takes
## that player back: one who dropped, or one whose old connection the host still holds (the
## client crashed and came back before the host noticed). A wrong secret, no valid id, or the
## host's own id joins as a guest: a new player whose identity is not kept. Ids and secrets
## never leave the host.

enum Claim {
	## A new id, now kept for this peer.
	NEW,
	## A dropped player's id with its secret: the peer takes back `old_peer`'s player.
	RECLAIM,
	## A connected player's id with its secret: `old_peer` is a dead connection the host has not
	## noticed yet. The host closes it, and the peer takes back its player.
	TAKEOVER,
	## A new player whose identity is not kept.
	GUEST,
}


## What a join request's identity means for the joining peer.
class Outcome:
	var kind: Claim = Claim.GUEST
	## The peer whose player is taken back (RECLAIM and TAKEOVER), else 0.
	var old_peer: int = 0

	func _init(claim_kind: Claim, reclaimed_from: int = 0) -> void:
		kind = claim_kind
		old_peer = reclaimed_from


## The host's peer: its own player is never claimed by a client (a host and a client from one
## install share the id).
const HOST_PEER: int = MultiplayerPeer.TARGET_PEER_SERVER


class Entry:
	var peer: int = 0
	var secret_hash: PackedByteArray = PackedByteArray()


var _entries: Dictionary[String, Entry] = {}


## `peer` presents `player_id` and `player_secret`. `is_dropped(peer) -> bool` says whether a
## peer dropped and its player still waits in the world.
func claim(player_id: String, player_secret: String, peer: int, is_dropped: Callable) -> Outcome:
	if not PlayerIdentity.from(player_id, player_secret).is_valid():
		return Outcome.new(Claim.GUEST)
	var digest := PlayerIdentity.hash_secret(player_secret)
	var known: Entry = _entries.get(player_id)
	if known == null:
		var entry := Entry.new()
		entry.peer = peer
		entry.secret_hash = digest
		_entries[player_id] = entry
		return Outcome.new(Claim.NEW)
	if known.secret_hash != digest or known.peer == HOST_PEER:
		return Outcome.new(Claim.GUEST)
	var old_peer := known.peer
	known.peer = peer
	return Outcome.new(Claim.RECLAIM if is_dropped.call(old_peer) else Claim.TAKEOVER, old_peer)


## Keeps `player_id` for `peer` whatever was there (the host's own identity at start()).
func reserve(player_id: String, player_secret: String, peer: int) -> void:
	if not PlayerIdentity.from(player_id, player_secret).is_valid():
		return
	var entry := Entry.new()
	entry.peer = peer
	entry.secret_hash = PlayerIdentity.hash_secret(player_secret)
	_entries[player_id] = entry


## The peer playing `player_id`, or 0.
func peer_for(player_id: String) -> int:
	var known: Entry = _entries.get(player_id)
	return known.peer if known != null else 0


## Forgets the identity of `peer`'s player (it was removed, or left the lobby): that id joins
## as a new player next time.
func release_peer(peer: int) -> void:
	for player_id: String in _entries.keys():
		if _entries[player_id].peer == peer:
			_entries.erase(player_id)
