extends GutTest
## creatures-ai "Seagull swoop and steal", with exactly 1 player in every test.

var rig: CreatureRig


func before_each() -> void:
	rig = CreatureRig.make(self)
	rig.world.phase = DataEnums.DayPhase.DAY


func _run_until(gull: Creature, state: StringName, limit_s: float) -> void:
	var left: float = limit_s
	while gull.state_name() != state and left > 0.0:
		rig.run(CreatureRig.STEP_S)
		left -= CreatureRig.STEP_S


func test_inventory_reports_the_first_food_slot_as_held() -> void:
	var body := rig.player(Vector2i(4, 9))
	assert_eq(body.inventory.held_food(), &"")
	body.inventory.add(&"rope", 1)
	body.inventory.add(&"coco", 2)
	assert_eq(body.inventory.held_food(), &"coco")


func test_solo_gull_takes_one_held_food_and_is_back_in_30_s() -> void:
	var body := rig.player(Vector2i(4, 9))
	body.inventory.add(&"coco", 2)
	var gull := rig.creature(&"seagull", Vector2i(4, 5))
	_run_until(gull, &"FLEE", 5.0)
	assert_eq(gull.state_name(), &"FLEE")
	assert_eq(body.inventory.count_id(&"coco"), 1)
	assert_eq(gull.carried.get(&"coco", 0), 1)
	rig.run(29.0)
	assert_ne(gull.state_name(), &"PERCH")
	rig.run(2.0)
	assert_eq(gull.state_name(), &"PERCH")
	assert_eq(body.inventory.count_id(&"coco"), 1, "perched again with no second theft")


func test_gull_takes_ground_food_within_8_tiles_only() -> void:
	var near := rig.pickup(&"coco", 2, Vector2i(4, 8))
	var far := rig.pickup(&"coco", 2, Vector2i(4, 14))
	rig.creature(&"seagull", Vector2i(4, 5))
	rig.run(25.0)
	assert_eq(near.count, 1)
	assert_eq(far.count, 2)


func test_gull_never_takes_non_food() -> void:
	var body := rig.player(Vector2i(4, 9))
	body.inventory.add(&"rope", 2)
	var wood := rig.pickup(&"driftwood", 2, Vector2i(4, 8))
	rig.creature(&"seagull", Vector2i(4, 5))
	rig.run(30.0)
	assert_eq(body.inventory.count_id(&"rope"), 2)
	assert_eq(wood.count, 2)


func test_solo_shoo_makes_it_flee_for_30_s_and_nothing_is_taken() -> void:
	var body := rig.player(Vector2i(4, 6))
	body.inventory.add(&"coco", 2)
	var gull := rig.creature(&"seagull", Vector2i(4, 5))
	assert_true(gull.shoo(body))
	rig.run(25.0)
	assert_eq(gull.state_name(), &"FLEE")
	assert_eq(body.inventory.count_id(&"coco"), 2)


func test_shoo_from_6_tiles_is_refused() -> void:
	var body := rig.player(Vector2i(4, 11))
	var gull := rig.creature(&"seagull", Vector2i(4, 5))
	assert_false(gull.shoo(body))
	assert_eq(gull.state_name(), &"PERCH")


func test_gull_perches_at_night() -> void:
	rig.world.phase = DataEnums.DayPhase.NIGHT
	var food := rig.pickup(&"coco", 2, Vector2i(4, 8))
	var gull := rig.creature(&"seagull", Vector2i(4, 5))
	rig.run(60.0)
	assert_eq(food.count, 2)
	assert_eq(gull.state_name(), &"PERCH")
