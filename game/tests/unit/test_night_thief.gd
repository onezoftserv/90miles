extends GutTest
## creatures-ai "Land crab night theft", with exactly 1 player in every test.

var rig: CreatureRig


func before_each() -> void:
	rig = CreatureRig.make(self)
	rig.world.phase = DataEnums.DayPhase.NIGHT


func test_solo_crab_steals_one_food_at_60_s() -> void:
	var stash := rig.pickup(&"coco", 3, Vector2i(4, 15))
	var crab := rig.creature(&"land_crab", Vector2i(4, 14))
	rig.run(59.0)
	assert_eq(stash.count, 3)
	rig.run(1.1)
	assert_eq(stash.count, 2)
	assert_eq(crab.carried.get(&"coco", 0), 1)
	assert_eq(crab.state_name(), &"FLEE")


func test_crab_leaves_non_food_alone() -> void:
	var stash := rig.pickup(&"driftwood", 3, Vector2i(4, 15))
	rig.creature(&"land_crab", Vector2i(4, 14))
	rig.run(120.0)
	assert_eq(stash.count, 3)


func test_stash_by_a_lit_fire_is_safe_and_the_crab_keeps_out_of_the_light() -> void:
	var stash := rig.pickup(&"coco", 3, Vector2i(4, 15))
	var lit := rig.fire(Vector2i(4, 18))
	var crab := rig.creature(&"land_crab", Vector2i(4, 26))
	for step: int in 1200:
		rig.run(CreatureRig.STEP_S)
		assert_gte(crab.position.distance_to(lit.position), 5.0 * 16.0 - 0.5, "outside the light")
	assert_eq(stash.count, 3)


func test_crab_inside_the_light_leaves_it_at_once() -> void:
	var lit := rig.fire(Vector2i(3, 18))
	var crab := rig.creature(&"land_crab", Vector2i(3, 16))
	rig.run(1.5)
	assert_gte(crab.position.distance_to(lit.position), 5.0 * 16.0 - 0.5)


func test_solo_player_next_to_a_crab_is_pinched_for_5_a_second() -> void:
	var body := rig.player(Vector2i(4, 15))
	rig.creature(&"land_crab", Vector2i(4, 14))
	rig.run(1.1)
	assert_eq(body.meters.health, 95.0)
	rig.run(2.0)
	assert_eq(body.meters.health, 85.0)


func test_a_crab_going_for_a_stash_recomputes_its_path_at_most_twice_a_second() -> void:
	rig.pickup(&"coco", 3, Vector2i(4, 2))
	var crab := rig.creature(&"land_crab", Vector2i(4, 25))
	rig.run(1.0)
	assert_lte(crab.brain.path_computes, 2)
	assert_gt(crab.brain.path_computes, 0)


func test_a_crab_without_the_hosts_world_does_nothing() -> void:
	var stash := rig.pickup(&"coco", 3, Vector2i(4, 15))
	var crab := rig.creature(&"land_crab", Vector2i(4, 14))
	crab.world = null
	var start := crab.position
	rig.run(70.0)
	assert_eq(stash.count, 3)
	assert_eq(crab.position, start)
