extends GutTest
## crafting-inventory "Inventory": 12 slots, weight limit 30, stacking, per-slot tool uses.

var inventory: Inventory


func before_each() -> void:
	inventory = Inventory.new()
	add_child_autofree(inventory)


func test_pick_up_a_coconut_into_an_empty_slot() -> void:
	assert_eq(inventory.add(&"coco", 1), 1)
	assert_eq(inventory.slots[0].item_id, &"coco")
	assert_eq(inventory.slots[0].count, 1)
	assert_almost_eq(inventory.weight(), 0.5, 0.001)


func test_stack_then_next_slot() -> void:
	assert_eq(inventory.add(&"coco", 6), 6)
	assert_eq(inventory.slots[0].count, 5)
	assert_eq(inventory.slots[1].count, 1)


func test_twelve_slots_full_refuses() -> void:
	for i: int in 12:
		assert_eq(inventory.add(&"knife", 1), 1)
	assert_eq(inventory.add(&"knife", 1), 0)


func test_weight_limit_30() -> void:
	assert_eq(inventory.add(&"driftwood", 15), 15)
	assert_almost_eq(inventory.weight(), 30.0, 0.001)
	assert_eq(inventory.add(&"driftwood", 1), 0, "the 16th would pass 30")


func test_tools_do_not_stack_and_keep_uses() -> void:
	inventory.add(&"knife", 2)
	inventory.spend_use(0)
	assert_eq(inventory.slots[0].uses_left, 39)
	assert_eq(inventory.slots[1].uses_left, 40)


func test_spend_last_use_removes_and_adds_remainder() -> void:
	var conch := ItemData.new()
	conch.id = &"conch_fixture"
	conch.durability = 1
	conch.remainder_item_id = &"knife"
	inventory.register(conch)
	inventory.add(&"conch_fixture", 1)
	inventory.spend_use(0)
	assert_eq(inventory.count_id(&"conch_fixture"), 0)
	assert_eq(inventory.slots[0].item_id, &"knife")


func test_remove_and_net_round_trip() -> void:
	inventory.add(&"driftwood", 4)
	assert_true(inventory.remove_id(&"driftwood", 3))
	assert_false(inventory.remove_id(&"driftwood", 3), "only one left")
	var copy := Inventory.new()
	add_child_autofree(copy)
	copy.from_net(inventory.to_net())
	assert_eq(copy.count_id(&"driftwood"), 1)
	assert_eq(copy.to_net(), inventory.to_net())
