class_name IdentityRegistry
extends RefCounted
## coop-reconnect "Reclaiming a player": the host's map, for one run, from player id to the peer
## that plays it and a hash of its secret. A join with a dropped player's id and matching
## secret reclaims that player. An id in use, a wrong secret, or no valid id joins as a guest:
## a new player whose identity is not kept. Ids and secrets never leave the host.

enum Claim {
	## A new id, now kept for this peer.
	NEW,
	## A dropped player's id with its secret: the peer takes back `old_peer`'s player.
	RECLAIM,
	## A new player whose identity is not kept.
	GUEST,
}


## What a join request's identity means for the joining peer.
class Outcome:
	var kind: Claim = Claim.GUEST
	## The dropped peer whose player is reclaimed (RECLAIM only), else 0.
	var old_peer: int = 0

	func _init(claim_kind: Claim, reclaimed_from: int = 0) -> void:
		kind = claim_kind
		old_peer = reclaimed_from


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
	if known.secret_hash != digest or not is_dropped.call(known.peer):
		return Outcome.new(Claim.GUEST)
	var old_peer := known.peer
	known.peer = peer
	return Outcome.new(Claim.RECLAIM, old_peer)


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
