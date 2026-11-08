extends GutTest
## creatures-ai "Reef shark patrol, circle and strike", with exactly 1 player in every test.

var rig: CreatureRig


func before_each() -> void:
	rig = CreatureRig.make(self)


func _swimmer(cell: Vector2i, energy: float = 100.0, bleeding: bool = false) -> PlayerBody:
	var body := rig.player(cell)
	body.meters.energy = energy
	body.meters.set_status(DataEnums.Status.BLEEDING, bleeding)
	return body


func test_solo_clean_swimmer_is_circled_and_left_alone() -> void:
	var body := _swimmer(Vector2i(16, 15))
	var shark := rig.shark(Vector2i(20, 15))
	rig.run(15.0)
	assert_eq(body.meters.health, 100.0)
	assert_eq(shark.state_name(), &"PATROL")
	for expected: StringName in [&"INVESTIGATE", &"CIRCLE", &"LEAVE", &"PATROL"]:
		assert_true(shark.brain.history.has(expected), "went through %s" % expected)
	rig.run(5.0)
	assert_eq(shark.state_name(), &"PATROL", "the swimmer is ignored for 20 s")


func test_solo_bleeding_swimmer_is_struck_once_then_circled_again() -> void:
	var body := _swimmer(Vector2i(16, 15), 100.0, true)
	var shark := rig.shark(Vector2i(19, 15))
	rig.run(6.1)
	assert_eq(body.meters.health, 75.0)
	assert_true(body.meters.has_status(DataEnums.Status.BLEEDING))
	assert_eq(shark.state_name(), &"RETREAT")
	rig.run(4.2)
	assert_eq(shark.state_name(), &"CIRCLE")
	assert_eq(body.meters.health, 75.0, "one strike only so far")


func test_solo_tired_swimmer_below_20_energy_is_struck() -> void:
	var body := _swimmer(Vector2i(16, 15), 19.0)
	rig.shark(Vector2i(19, 15))
	rig.run(6.1)
	assert_eq(body.meters.health, 75.0)
	assert_true(body.meters.has_status(DataEnums.Status.BLEEDING))


func test_swimmer_at_exactly_20_energy_is_not_struck() -> void:
	var body := _swimmer(Vector2i(16, 15), 20.0)
	rig.shark(Vector2i(19, 15))
	rig.run(9.0)
	assert_eq(body.meters.health, 100.0)


func test_shark_never_enters_land_or_water_next_to_land() -> void:
	var body := _swimmer(Vector2i(12, 15), 100.0, true)
	var shark := rig.shark(Vector2i(14, 15))
	for step: int in 600:
		if step == 30:
			body.global_position = CreatureRig.center(Vector2i(3, 15))
		rig.run(CreatureRig.STEP_S)
		var cell := Vector2i(shark.position / 16.0)
		var terrain := rig.terrain.terrain_at(cell)
		assert_true(terrain == DataEnums.Terrain.DEEP or terrain == DataEnums.Terrain.SHALLOWS, "water at %s" % cell)
		assert_gte(rig.world.nav.land_distance(cell), 2, "2 tiles from land at %s" % cell)


func test_solo_tired_swimmer_escapes_to_the_shallows() -> void:
	var body := _swimmer(Vector2i(12, 15), 15.0)
	var shark := rig.shark(Vector2i(15, 15))
	var swim_px: float = 3.0 * 16.0 * CreatureRig.STEP_S
	var steps: int = 0
	while body.global_position.x > CreatureRig.center(Vector2i(6, 15)).x and steps < 60:
		body.global_position.x -= swim_px
		rig.run(CreatureRig.STEP_S)
		steps += 1
		assert_eq(body.meters.health, 100.0, "never struck on the way")
	assert_lt(steps * CreatureRig.STEP_S, 6.0, "reached the shallows before the circle ends")
	rig.run(10.0)
	assert_eq(body.meters.health, 100.0)
	assert_gte(rig.world.nav.land_distance(Vector2i(shark.position / 16.0)), 2)


func test_a_creature_without_the_hosts_world_never_strikes() -> void:
	var body := _swimmer(Vector2i(16, 15), 100.0, true)
	var shark := rig.shark(Vector2i(19, 15))
	shark.world = null
	rig.run(7.0)
	assert_eq(body.meters.health, 100.0)
