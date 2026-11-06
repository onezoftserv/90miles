class_name InventorySlot
extends RefCounted
## One inventory slot: an item id, how many, and for tools the uses left.

var item_id: StringName = &""
var count: int = 0
## Uses left on a tool or serving; 0 for items without a counter.
var uses_left: int = 0


func is_empty() -> bool:
	return item_id.is_empty()


func clear() -> void:
	item_id = &""
	count = 0
	uses_left = 0
