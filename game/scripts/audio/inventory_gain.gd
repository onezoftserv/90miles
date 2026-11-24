class_name InventoryGain
extends RefCounted
## sound-pass audio "Pick-up cue" (design D5): a bag gained an item when any item's count rose,
## whether picked up or crafted. Taking items out, moving them, and spending a use (which leaves the
## counts) gain nothing. The first bag seen only seeds, so a joiner's bag is silent.

var _last: Dictionary[StringName, int] = {}
var _seen: bool = false


## Each item id's total count over the bag's slots.
static func counts(inventory: Inventory) -> Dictionary[StringName, int]:
	var totals: Dictionary[StringName, int] = {}
	for slot: InventorySlot in inventory.slots:
		if slot.is_empty():
			continue
		totals[slot.item_id] = totals.get(slot.item_id, 0) + slot.count
	return totals


## True when some id has more in `after` than in `before`.
static func gained(before: Dictionary, after: Dictionary) -> bool:
	for id: Variant in after:
		if int(after[id]) > int(before.get(id, 0)):
			return true
	return false


## True when `now` gained on the last bag seen; the first call only seeds.
func observe(now: Dictionary) -> bool:
	var copy: Dictionary[StringName, int] = {}
	for id: Variant in now:
		copy[StringName(id)] = int(now[id])
	if not _seen:
		_seen = true
		_last = copy
		return false
	var more: bool = gained(_last, copy)
	_last = copy
	return more


## The next bag seeds again (a new body).
func reset() -> void:
	_seen = false
	_last.clear()
