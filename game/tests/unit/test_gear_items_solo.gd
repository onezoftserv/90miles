extends GutTest
## content-batch-4 with exactly 1 player, offline (crafting-inventory "Pliers open cans", "The
## machete opens coconuts", "Flint and steel light a fire" and "The conch leaves its horn"): a solo
## player uses the batch's tools through the host's use and craft paths, with no knife and no
## lighter, so each number comes from the new tool alone.

const SESSION_SCENE: PackedScene = preload("res://scenes/net/coop_session.tscn")
const M := DataEnums.Meter

var session: CoopSession
var me: PlayerBody
# Build sites and the fire they become go here, so each test starts without leftovers.
var arena: Node2D


func before_each() -> void:
	NetManager.start_solo()
	session = SESSION_SCENE.instantiate() as CoopSession
	add_child_autofree(session)
	session.start()
	me = session.body(CoopSession.HOST_ID)
	me.player_input.enabled = false
	for slot: InventorySlot in me.inventory.slots:
		slot.clear()
	arena = Node2D.new()
	add_child_autofree(arena)


func after_each() -> void:
	NetManager.leave()


func _use(item_id: StringName, use_index: int = 0) -> bool:
	return session.use_for(CoopSession.HOST_ID, _slot_of(item_id), use_index, 0)


func _slot_of(item_id: StringName) -> int:
	for i: int in me.inventory.slots.size():
		if me.inventory.slots[i].item_id == item_id:
			return i
	return -1


func _uses_left(item_id: StringName) -> int:
	return me.inventory.slots[_slot_of(item_id)].uses_left


func _fires() -> Array[Node]:
	return get_tree().get_nodes_in_group(PlayerBody.FIRE_GROUP)


func test_one_offline_player_and_no_one_else() -> void:
	assert_eq(session.peer_ids().size(), 1)
	assert_not_null(me)


func test_a_solo_player_opens_a_can_with_the_pliers() -> void:
	me.meters.hunger = 40.0
	me.meters.energy = 40.0
	me.inventory.add(&"canned_food", 1)
	me.inventory.add(&"pliers", 1)
	assert_eq(me.inventory.count_id(&"knife"), 0, "no knife: the pliers do it alone")
	assert_eq(_uses_left(&"pliers"), 50, "new pliers")
	assert_true(_use(&"canned_food"))
	assert_almost_eq(me.meters.hunger, 70.0, 0.001)
	assert_almost_eq(me.meters.energy, 50.0, 0.001, "a meal gives +10 energy")
	assert_eq(me.inventory.count_id(&"canned_food"), 0, "the can is gone")
	assert_eq(_uses_left(&"pliers"), 49, "the can cost one pliers use")


func test_without_an_opener_the_can_stays() -> void:
	me.meters.hunger = 40.0
	me.inventory.add(&"canned_food", 1)
	me.inventory.add(&"machete", 1)
	assert_false(_use(&"canned_food"), "a machete opens coconuts, not cans")
	assert_eq(me.inventory.count_id(&"canned_food"), 1)
	assert_almost_eq(me.meters.hunger, 40.0, 0.001)
	assert_eq(_uses_left(&"machete"), 60, "nothing spent")


func test_a_solo_player_opens_a_coconut_with_a_machete() -> void:
	me.meters.thirst = 40.0
	me.meters.hunger = 40.0
	me.inventory.add(&"coco", 1)
	me.inventory.add(&"machete", 1)
	assert_eq(_uses_left(&"machete"), 60, "a new machete")
	assert_true(_use(&"coco"))
	assert_almost_eq(me.meters.thirst, 55.0, 0.001, "the coconut's water")
	assert_eq(me.inventory.count_id(&"coco"), 0, "the coconut is gone")
	assert_eq(_uses_left(&"machete"), 59, "one machete use per coconut")


func test_flint_and_steel_light_a_fire_in_10_s() -> void:
	var recipe := GameState.content.get_entry(&"recipes", &"fire") as RecipeData
	me.inventory.add(&"flint_steel", 1)
	me.inventory.add(&"driftwood", 3)
	me.inventory.add(&"dry_grass", 1)
	assert_eq(me.inventory.count_id(&"lighter"), 0, "no lighter")
	assert_almost_eq(me.crafter.recipe_time(recipe), 10.0, 0.001, "10 s, not the recipe's 30 s")
	var site := me.crafter.place_site(recipe, me.global_position + Vector2(8, 0), arena)
	assert_not_null(site)
	assert_eq(site.deposit(me), 4, "3 driftwood and 1 dry grass")
	var fires_before: int = _fires().size()
	assert_true(me.crafter.start_work(site))
	me.crafter.advance(9.75)
	assert_eq(_fires().size(), fires_before, "not yet")
	me.crafter.advance(0.25)
	assert_eq(_fires().size(), fires_before + 1, "a lit fire after 10 s of work")
	assert_eq(me.inventory.count_id(&"flint_steel"), 1, "the flint never wears out")


func test_eating_a_conch_leaves_its_horn() -> void:
	me.inventory.add(&"conch", 2)
	assert_eq(me.inventory.count_id(&"conch"), 2, "conchs still stack")
	assert_true(_use(&"conch"))
	assert_eq(me.inventory.count_id(&"conch"), 1)
	assert_eq(me.inventory.count_id(&"conch_horn"), 1, "the shell stays as a guamo")
	assert_true(_use(&"conch"))
	assert_eq(me.inventory.count_id(&"conch"), 0)
	assert_eq(me.inventory.count_id(&"conch_horn"), 2, "one horn per conch")
