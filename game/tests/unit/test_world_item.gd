extends GutTest
## crafting-inventory "Pick-up": interacting with an item on the ground puts it in the player's
## inventory on the host; what does not fit stays on the ground.

const PLAYER_SCENE: PackedScene = preload("res://scenes/player/player.tscn")
const WORLD_ITEM: PackedScene = preload("res://scenes/items/world_item.tscn")


func _body() -> PlayerBody:
	var body := PLAYER_SCENE.instantiate() as PlayerBody
	add_child_autofree(body)
	return body


func _item(id: StringName, count: int = 1) -> WorldItem:
	var item := WORLD_ITEM.instantiate() as WorldItem
	item.item_id = id
	item.count = count
	add_child_autofree(item)
	return item


func test_solo_interact_picks_up() -> void:
	NetManager.start_solo()
	var body := _body()
	var coco := _item(&"coco")
	coco.interactable.use(body)
	assert_eq(body.inventory.count_id(&"coco"), 1)
	assert_true(coco.is_queued_for_deletion())


func test_a_press_next_to_it_picks_it_up() -> void:
	var body := _body()
	var wood := _item(&"driftwood")
	wood.position = Vector2(8, 0)
	assert_eq(wood.interactable.hold_time_s, 0.0, "instant")
	body.intent = MoveIntent.create(Vector2.ZERO, false, false, true)
	body.advance(1.0 / 60.0)
	assert_eq(body.inventory.count_id(&"driftwood"), 1)


func test_full_inventory_leaves_it_on_the_ground() -> void:
	var body := _body()
	for i: int in 12:
		body.inventory.add(&"knife", 1)
	var coco := _item(&"coco")
	coco.interactable.use(body)
	assert_false(coco.is_queued_for_deletion())
	assert_true(coco.interactable.enabled)
	assert_eq(coco.count, 1)


func test_partial_pick_up_leaves_the_rest() -> void:
	var body := _body()
	body.inventory.add(&"driftwood", 14)
	var pile := _item(&"driftwood", 3)
	pile.interactable.use(body)
	assert_eq(body.inventory.count_id(&"driftwood"), 15, "weight limit 30")
	assert_eq(pile.count, 2)
