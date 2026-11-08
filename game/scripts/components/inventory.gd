class_name Inventory
extends Node
## A player's carried items (crafting-inventory "Inventory"): slots holding one item id each,
## stacked up to the item's stack size, under a weight limit. Host state: clients only show
## what `from_net` hands them. Items with more than 1 durability do not stack.

signal changed

var tuning: CraftingTuning = preload("res://resources/crafting_tuning.tres")
var catalog: ContentCatalog = null
var slots: Array[InventorySlot] = []

# Items the catalog does not have (tests, later runtime items); consulted first.
var _extra: Dictionary[StringName, ItemData] = {}


func _init() -> void:
	for i: int in tuning.slot_count:
		slots.append(InventorySlot.new())


## Makes `item` known to this inventory without a file (tests).
func register(item: ItemData) -> void:
	_extra[item.id] = item


## The item data for `id`, or null.
func item_for(id: StringName) -> ItemData:
	if _extra.has(id):
		return _extra[id]
	var source: ContentCatalog = catalog if catalog != null else GameState.content
	return source.get_entry(&"items", id) as ItemData


## Puts up to `count` of `id` in, one unit at a time. Returns how many fit (slots and weight).
## `uses` overrides the uses a new unit starts with (a half-used tool picked back up).
func add(id: StringName, count: int = 1, uses: int = -1) -> int:
	var item := item_for(id)
	if item == null:
		return 0
	var added: int = 0
	for i: int in count:
		if weight() + item.weight > tuning.weight_limit + 0.0001:
			break
		var slot := _slot_for(id, item)
		if slot == null:
			break
		if slot.is_empty():
			slot.item_id = id
			slot.uses_left = uses if uses >= 0 else item.durability
		slot.count += 1
		added += 1
	if added > 0:
		changed.emit()
	return added


func count_id(id: StringName) -> int:
	var total: int = 0
	for slot: InventorySlot in slots:
		if slot.item_id == id:
			total += slot.count
	return total


func count_tag(tag: DataEnums.ItemTag) -> int:
	var total: int = 0
	for slot: InventorySlot in slots:
		if not slot.is_empty() and _has_tag(slot.item_id, tag):
			total += slot.count
	return total


## Removes `count` of `id` (all or nothing). Returns whether it did.
func remove_id(id: StringName, count: int = 1) -> bool:
	if count_id(id) < count:
		return false
	var left: int = count
	for slot: InventorySlot in slots:
		if slot.item_id != id or left <= 0:
			continue
		var taken: int = mini(slot.count, left)
		slot.count -= taken
		left -= taken
		if slot.count <= 0:
			slot.clear()
	changed.emit()
	return true


## Removes up to `count` items with `tag`; returns the ids taken, one entry per unit.
func take_tag(tag: DataEnums.ItemTag, count: int) -> Array[StringName]:
	var taken: Array[StringName] = []
	for slot: InventorySlot in slots:
		while taken.size() < count and not slot.is_empty() and _has_tag(slot.item_id, tag):
			taken.append(slot.item_id)
			slot.count -= 1
			if slot.count <= 0:
				slot.clear()
	if not taken.is_empty():
		changed.emit()
	return taken


## First slot holding an item with `capability`, or -1.
func capability_slot(capability: DataEnums.Capability) -> int:
	for i: int in slots.size():
		var slot := slots[i]
		if slot.is_empty():
			continue
		var item := item_for(slot.item_id)
		if item != null and item.capabilities.has(capability):
			return i
	return -1


## Spends one use of the item in `index`. At 0 uses the unit goes and its remainder item arrives.
func spend_use(index: int) -> void:
	var slot := slots[index]
	if slot.is_empty():
		return
	var item := item_for(slot.item_id)
	slot.uses_left -= 1
	if slot.uses_left > 0 or item == null or item.durability <= 0:
		changed.emit()
		return
	slot.count -= 1
	if slot.count <= 0:
		slot.clear()
	elif item.durability > 0:
		slot.uses_left = item.durability
	if not item.remainder_item_id.is_empty():
		add(item.remainder_item_id, 1)
	changed.emit()


func weight() -> float:
	var total: float = 0.0
	for slot: InventorySlot in slots:
		if slot.is_empty():
			continue
		var item := item_for(slot.item_id)
		if item != null:
			total += item.weight * slot.count
	return total


## The replicated form: one [id, count, uses] per slot.
func to_net() -> Array:
	var out: Array = []
	for slot: InventorySlot in slots:
		out.append([String(slot.item_id), slot.count, slot.uses_left])
	return out


## Replaces the slots with a host state. Malformed entries leave their slot empty.
func from_net(state: Array) -> void:
	for i: int in slots.size():
		var slot := slots[i]
		slot.clear()
		if i >= state.size() or not state[i] is Array or (state[i] as Array).size() != 3:
			continue
		var entry: Array = state[i]
		if typeof(entry[0]) != TYPE_STRING or typeof(entry[1]) != TYPE_INT or typeof(entry[2]) != TYPE_INT:
			continue
		slot.item_id = StringName(entry[0])
		slot.count = maxi(entry[1], 0)
		slot.uses_left = maxi(entry[2], 0)
		if slot.count == 0:
			slot.clear()
	changed.emit()


# A slot that takes one more `id`: a partly filled stack first, else an empty one.
func _slot_for(id: StringName, item: ItemData) -> InventorySlot:
	if item.durability <= 1:
		for slot: InventorySlot in slots:
			if slot.item_id == id and slot.count < maxi(item.stack_size, 1):
				return slot
	for slot: InventorySlot in slots:
		if slot.is_empty():
			return slot
	return null


## The item a player is holding out in the open for a gull: the first FOOD slot, or &"" when the
## inventory has none. Packed items are never "held": callers also skip a swimmer.
func held_food() -> StringName:
	for slot: InventorySlot in slots:
		if not slot.is_empty() and _has_tag(slot.item_id, DataEnums.ItemTag.FOOD):
			return slot.item_id
	return &""


func _has_tag(id: StringName, tag: DataEnums.ItemTag) -> bool:
	var item := item_for(id)
	return item != null and item.tags.has(tag)
