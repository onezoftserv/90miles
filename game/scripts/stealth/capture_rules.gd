class_name CaptureRules
extends RefCounted
## guardacostas-capture design.md §2 and §7 (specs "Whole-party capture", "Taken captives", "Captives"):
## who is free, when a capture is a whole-party capture, who is taken, and what a capture, a rescue and
## being taken do to a body. The tests are pure over `Member` snapshots; the host applies the results.
## - A player is free while living, connected, standing (not downed, in a last stand or dead) and not a
##   captive or taken, wherever they are: a rider in a crossing or waiting on the next shore counts.
## - No free player left and at least one captive or taken player is a whole-party capture.
## - A squad that leaves while a free player is left takes its captives: out of play like a rider on
##   the next shore, every item gone but keepsakes, their secret items laid on the landing beach.

## One player as the rules see them.
class Member extends RefCounted:
	var dead: bool = false
	var dropped: bool = false
	var downed: bool = false
	var last_stand: bool = false
	var captive: bool = false
	var taken: bool = false


## The rules' view of `body` (`dropped`: its client is gone and the body waits for it).
static func member_of(body: PlayerBody, dropped: bool) -> Member:
	var member := Member.new()
	member.dead = body.meters.dead
	member.dropped = dropped
	member.downed = body.meters.downed
	member.last_stand = body.meters.last_stand
	member.captive = body.captive
	member.taken = body.taken
	return member


static func is_free(member: Member) -> bool:
	return not (member.dead or member.dropped or member.downed or member.last_stand or member.captive or member.taken)


## How many of `members` are free.
static func free_count(members: Array[Member]) -> int:
	var count: int = 0
	for member: Member in members:
		if is_free(member):
			count += 1
	return count


## No free player left and at least one captive or taken: the whole party is caught.
static func is_whole_party(members: Array[Member]) -> bool:
	var held: bool = false
	for member: Member in members:
		if is_free(member):
			return false
		held = held or ((member.captive or member.taken) and not member.dead)
	return held


## The squad leaves with `captives`: they are taken when a free player is left in the run; otherwise
## none is, because the capture is a whole-party one.
static func taken_on_leaving(captive_count: int, members: Array[Member]) -> int:
	return captive_count if free_count(members) > 0 else 0


## Every member of `session`'s run, in peer order.
static func members_of(session: CoopSession) -> Array[Member]:
	var members: Array[Member] = []
	for peer_id: int in session.peer_ids():
		var body := session.body(peer_id)
		if body != null:
			members.append(member_of(body, session.is_dropped(peer_id)))
	return members


# --- the host's side --------------------------------------------------------------------------------

## Host: `body` is captured by `by` (the soldier that leads them away, or the boat that hauled them
## aboard) with `patrol`'s freeing numbers.
static func capture(body: PlayerBody, by: Node2D, patrol: PatrolData, aboard: bool = false) -> void:
	body.set_captive(true, by, aboard)
	body.free_handle.guard_radius_tiles = patrol.free_guard_radius_tiles
	body.free_handle.hold_time_s = patrol.free_hold_s
	body.spot_meter.clear()


## Host: `body` is free again, standing where it is.
static func release(body: PlayerBody) -> void:
	body.set_captive(false)


## Host: `body` (a captive the squad rows out with while someone is free) is taken: its secret items
## lie on `landing_px` (session coordinates), its other items go except keepsakes, and it waits out of
## play like a rider on the next shore until the party next lands.
static func take(session: CoopSession, body: PlayerBody, landing_px: Vector2) -> void:
	var peer_id: int = session.peer_of(body)
	SecretRules.lay_down_for_leaver(session, peer_id, body, landing_px)
	for slot: InventorySlot in body.inventory.slots:
		if not slot.is_empty() and not _is_keepsake(body.inventory, slot.item_id):
			slot.clear()
	body.inventory.changed.emit()
	body.set_captive(false)
	body.taken = true
	IslandArrival.hold(body)


static func _is_keepsake(inventory: Inventory, id: StringName) -> bool:
	var item := inventory.item_for(id)
	return item != null and item.tags.has(DataEnums.ItemTag.KEEPSAKE)
