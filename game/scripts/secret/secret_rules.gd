class_name SecretRules
extends RefCounted
## secret-cay "One shared secret check": the one question every system that shows something, or
## draws from a list of items or layouts, asks before it shows or draws an entry, and the one
## filter it passes its list through. An item is secret when it carries the SECRET tag, a layout
## when it is marked secret. Works the same for 1 player and for 4. Also the rule that a removed
## player's secret items stay on the island.


## Whether `entry` (an ItemData, an IslandLayoutData, or anything else) is secret.
static func is_secret(entry: Variant) -> bool:
	var item := entry as ItemData if entry is ItemData else null
	if item != null:
		return item.tags.has(DataEnums.ItemTag.SECRET)
	var layout := entry as IslandLayoutData if entry is IslandLayoutData else null
	if layout != null:
		return layout.secret
	return false


## `entries` without its secret ones, in the same order.
static func without_secrets(entries: Array) -> Array:
	var kept: Array = []
	for entry: Variant in entries:
		if not is_secret(entry):
			kept.append(entry)
	return kept


## secret-cay "A leaver's secret items" (design.md decision 9): on the host, as `peer_id`'s player
## `leaving` is removed from the run, lays every secret item it carried on the ground at `at`, so
## the secret never leaves the run with them. A player who already left the island by a route is
## skipped: what they carried left with them. Returns how many piles were laid.
static func lay_down_for_leaver(session: CoopSession, peer_id: int, leaving: PlayerBody, at: Vector2) -> int:
	if session == null or leaving == null or not session.multiplayer.is_server():
		return 0
	if leaving.left_island or session.has_left(peer_id):
		return 0
	var laid: int = 0
	for slot: InventorySlot in leaving.inventory.slots:
		if slot.is_empty() or not is_secret(leaving.inventory.item_for(slot.item_id)):
			continue
		if session.spawn_pickup(slot.item_id, slot.count, at) != null:
			laid += 1
	return laid
