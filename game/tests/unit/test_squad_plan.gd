extends GutTest
## guardacostas-capture, group 6 (design.md §6, specs "Squad search", "Last known position", "The squad
## leaves"): the squad's plan as pure rules. The landing on the beach nearest the boat, the dinghy's
## row at 2 tiles/s, the points (fires nearest the landing first, then the last known position), who
## takes which, the nearest free soldier taking a new last known position, the 3 s point search that
## finds within 2 tiles and not at 3, the seeded random walk, and when the squad leaves.

const TOLERANCE: float = 0.000001
const NO_CELL := SquadPlan.NO_CELL

var patrol: PatrolData


func before_each() -> void:
	patrol = (GameState.content.get_entry(&"creatures", &"patrol_boat") as CreatureData).patrol


# A beach along y = 10 from x = 0 to 19, scrub behind it, deep water above.
func _island() -> Dictionary:
	var cells: Dictionary = {}
	for x: int in 20:
		for y: int in range(0, 10):
			cells[Vector2i(x, y)] = DataEnums.Terrain.DEEP
		cells[Vector2i(x, 10)] = DataEnums.Terrain.BEACH
		for y: int in range(11, 16):
			cells[Vector2i(x, y)] = DataEnums.Terrain.SCRUB
	return cells


func _land(cells: Dictionary) -> Array[Vector2i]:
	var land: Array[Vector2i] = []
	for cell: Vector2i in cells:
		if not TerrainQuery.is_water(cells[cell]):
			land.append(cell)
	return land


func _plan(fires: Array[Vector2i] = [], last_known: Vector2i = NO_CELL, seed_value: int = 7) -> SquadPlan:
	var cells := _island()
	return SquadPlan.build(patrol, Vector2i(10, 10), fires, last_known, _land(cells), seed_value)


func test_the_landing_is_the_beach_cell_nearest_the_boat() -> void:
	var cells := _island()
	assert_eq(SquadPlan.landing_cell(Vector2(4.5, 6.0), cells), Vector2i(4, 10))
	assert_eq(SquadPlan.landing_cell(Vector2(15.2, 2.0), cells), Vector2i(15, 10))


func test_with_no_beach_on_the_boats_side_the_nearest_land() -> void:
	var cells := _island()
	# Rock at the east end, far from the beach.
	for y: int in range(0, 10):
		cells[Vector2i(40, y)] = DataEnums.Terrain.ROCK
	assert_eq(SquadPlan.landing_cell(Vector2(42.5, 4.5), cells), Vector2i(40, 4), "the rock, not a beach 20 tiles off")


func test_the_dinghy_rows_at_2_tiles_per_second() -> void:
	assert_almost_eq(SquadPlan.row_time_s(Vector2(10.5, 4.5), Vector2i(10, 10), patrol.landing_speed_tiles_s), 3.0, TOLERANCE, "6 tiles at 2 tiles/s")


func test_fires_come_first_nearest_the_landing_then_the_last_known_position() -> void:
	var plan := _plan([Vector2i(19, 12), Vector2i(12, 13), Vector2i(2, 12)] as Array[Vector2i], Vector2i(5, 14))
	var order: Array[Vector2i] = []
	for point: SquadPlan.Point in plan.points:
		order.append(point.cell)
	assert_eq(order, [Vector2i(12, 13), Vector2i(2, 12), Vector2i(19, 12), Vector2i(5, 14)] as Array[Vector2i])
	# Two fires as far from the landing go in reading order.
	var tie := _plan([Vector2i(18, 12), Vector2i(2, 12)] as Array[Vector2i])
	assert_eq(tie.points[0].cell, Vector2i(2, 12))
	assert_eq(plan.points[3].kind, SquadPlan.PointKind.LAST_KNOWN)
	assert_eq(plan.last_known(), Vector2i(5, 14))


func test_each_soldier_takes_the_next_point_nobody_has_taken_then_walks() -> void:
	var plan := _plan([Vector2i(12, 13)] as Array[Vector2i], Vector2i(5, 14))
	assert_eq(plan.take_point(0).cell, Vector2i(12, 13), "soldier 0: the fire")
	assert_eq(plan.take_point(1).cell, Vector2i(5, 14), "soldier 1: the last known position")
	assert_null(plan.take_point(2), "soldier 2 walks")
	assert_eq(plan.take_point(0).cell, Vector2i(12, 13), "a soldier keeps its point until searched")
	plan.searched(0)
	assert_null(plan.take_point(0), "the fire is searched: soldier 0 walks too")
	plan.drop_point(1)
	assert_eq(plan.take_point(2).cell, Vector2i(5, 14), "a dropped point is taken by the next")


func test_a_new_last_known_position_goes_to_the_nearest_free_soldier() -> void:
	var plan := _plan([] as Array[Vector2i], Vector2i(5, 14))
	plan.take_point(0)
	var free: Dictionary = {1: Vector2(15.5, 12.5), 2: Vector2(3.5, 12.5)}
	assert_eq(plan.set_last_known(Vector2i(17, 13), free), 1, "the nearer one")
	assert_eq(plan.last_known(), Vector2i(17, 13), "it replaces the old one")
	assert_eq(plan.take_point(1).cell, Vector2i(17, 13))
	assert_null(plan.point_of(0), "soldier 0's old point is gone")
	assert_eq(plan.set_last_known(Vector2i(1, 11), {} as Dictionary), SquadPlan.NOBODY, "nobody free: it waits")
	assert_eq(plan.take_point(2).cell, Vector2i(1, 11))


func test_a_point_search_takes_3_s_and_finds_within_2_tiles_but_not_3() -> void:
	var plan := _plan()
	assert_almost_eq(plan.point_search_s, 3.0, TOLERANCE)
	var point := Vector2i(10, 12)
	assert_true(plan.finds(point, SquadPlan.center(point) + Vector2(2.0, 0.0)))
	assert_true(plan.finds(point, SquadPlan.center(point) + Vector2(1.2, 1.2)))
	assert_false(plan.finds(point, SquadPlan.center(point) + Vector2(3.0, 0.0)))


func test_the_random_walk_is_the_same_for_the_same_seed() -> void:
	var a := _plan([] as Array[Vector2i], NO_CELL, 42)
	var b := _plan([] as Array[Vector2i], NO_CELL, 42)
	var c := _plan([] as Array[Vector2i], NO_CELL, 43)
	var walk_a: Array[Vector2i] = []
	var walk_b: Array[Vector2i] = []
	var walk_c: Array[Vector2i] = []
	for i: int in 12:
		walk_a.append(a.next_walk_cell())
		walk_b.append(b.next_walk_cell())
		walk_c.append(c.next_walk_cell())
	assert_eq(walk_a, walk_b, "the same cells in the same order")
	assert_ne(walk_a, walk_c, "another seed walks elsewhere")
	for cell: Vector2i in walk_a:
		assert_false(TerrainQuery.is_water(_island()[cell]), "on land")


func test_the_squad_leaves_after_180_s() -> void:
	var plan := _plan()
	plan.advance(179.9)
	assert_false(plan.should_leave(1, false))
	plan.advance(0.1)
	assert_true(plan.should_leave(1, false))


func test_a_late_capture_holds_the_squad_60_s() -> void:
	var plan := _plan()
	plan.advance(170.0)
	plan.note_capture()
	plan.advance(10.0)
	assert_false(plan.should_leave(1, false), "180 s, but only 10 s since the capture")
	plan.advance(49.9)
	assert_false(plan.should_leave(1, false))
	plan.advance(0.1)
	assert_true(plan.should_leave(1, false), "60 s after the capture")


func test_it_leaves_at_once_with_no_free_player_or_in_a_squall() -> void:
	var plan := _plan()
	plan.advance(40.0)
	assert_false(plan.should_leave(1, false))
	assert_true(plan.should_leave(0, false), "no free player left on the island")
	assert_true(plan.should_leave(1, true), "a squall recalls it")
