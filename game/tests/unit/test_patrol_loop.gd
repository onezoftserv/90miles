extends GutTest
## guardacostas-stealth, group 2 (design.md decision 3): the loop is the island's convex hull
## pushed out 4 tiles with mitred corners, sampled every half tile, run clockwise from the most
## easterly point, with its phases and the party's staggered clocks. Pure: no scene, no physics.

const SANDBAR: IslandLayoutData = preload("res://resources/islands/sandbar.tres")
const COAST_CAY: IslandLayoutData = preload("res://resources/islands/coast_cay.tres")
const LAP_S: float = 100.0
const PERIOD_S: float = 180.0
const WARNING_S: float = 20.0
const TOLERANCE: float = 0.000001
## Vector2 holds 32-bit floats, so a distance measured through one is good to about 1e-5.
const GEOMETRY: float = 0.0001


func _loop_of(layout: IslandLayoutData) -> PatrolLoop:
	var built := IslandLayout.build(layout)
	return PatrolLoop.build(built.terrain, built.size, LAP_S)


func _small(kind: StringName = SmallIsland.PLAIN) -> PatrolLoop:
	var island := SmallIsland.make(kind)
	return PatrolLoop.build(island.terrain, island.size, LAP_S)


# Distance from `point` to the closed polygon `ring`.
func _distance_to_ring(point: Vector2, ring: PackedVector2Array) -> float:
	var best: float = INF
	for i: int in ring.size():
		var closest: Vector2 = Geometry2D.get_closest_point_to_segment(point, ring[i], ring[(i + 1) % ring.size()])
		best = minf(best, point.distance_to(closest))
	return best


func _all_deep(loop: PatrolLoop, terrain: TerrainQuery) -> bool:
	for sample: Vector2 in loop.samples:
		if terrain.terrain_at(Vector2i(floori(sample.x), floori(sample.y))) != DataEnums.Terrain.DEEP:
			return false
	return true


# --- the shape ---------------------------------------------------------------------------------

func test_both_islands_get_a_loop_of_deep_water_four_tiles_from_the_hull() -> void:
	for layout: IslandLayoutData in [SANDBAR, COAST_CAY]:
		var built := IslandLayout.build(layout)
		var loop := PatrolLoop.build(built.terrain, built.size, LAP_S)
		assert_true(loop.valid, layout.resource_path)
		assert_gt(loop.samples.size(), 100)
		assert_true(_all_deep(loop, built.terrain), "every half-tile sample is deep: %s" % layout.resource_path)
		var nearest: float = INF
		for sample: Vector2 in loop.samples:
			nearest = minf(nearest, _distance_to_ring(sample, loop.hull))
		assert_gte(nearest, 4.0 - GEOMETRY, "no sample closer than 4 tiles: %s" % layout.resource_path)
		assert_almost_eq(nearest, 4.0, 0.01, "and the mitre keeps it at 4: %s" % layout.resource_path)
		assert_eq(loop.extra_push, 0)


func test_the_perimeter_matches_the_measured_loop() -> void:
	assert_almost_eq(_loop_of(SANDBAR).perimeter, 180.0, 1.0)
	# coast-cay-reshape: the reshaped hull (the rock's point, the arms' ends) is 196.8 tiles (was 195).
	assert_almost_eq(_loop_of(COAST_CAY).perimeter, 196.8, 1.0)


func test_samples_are_every_half_tile() -> void:
	var loop := _loop_of(SANDBAR)
	for i: int in loop.samples.size():
		var gap: float = loop.samples[i].distance_to(loop.samples[(i + 1) % loop.samples.size()])
		assert_lte(gap, 0.5 + TOLERANCE)
	# Each edge is cut into whole pieces of at most half a tile, so the count is the perimeter's
	# plus at most one piece per corner.
	assert_gte(loop.samples.size() * 0.5, loop.perimeter - GEOMETRY)
	assert_lte(loop.samples.size() * 0.5, loop.perimeter + loop.points.size() * 0.5)


func test_the_hull_is_convex_and_holds_every_land_cell_centre() -> void:
	var built := IslandLayout.build(SANDBAR)
	var loop := PatrolLoop.build(built.terrain, built.size, LAP_S)
	for cell: Vector2i in built.terrain.cells:
		if not TerrainQuery.is_water(built.terrain.terrain_at(cell)):
			var centre := Vector2(cell) + Vector2(0.5, 0.5)
			assert_true(Geometry2D.is_point_in_polygon(centre, loop.hull) or _distance_to_ring(centre, loop.hull) < TOLERANCE, str(cell))
	var turns: int = 0
	for i: int in loop.hull.size():
		var a: Vector2 = loop.hull[i]
		var b: Vector2 = loop.hull[(i + 1) % loop.hull.size()]
		var c: Vector2 = loop.hull[(i + 2) % loop.hull.size()]
		turns += 1 if (b - a).cross(c - b) > 0.0 else -1
	assert_eq(absi(turns), loop.hull.size(), "every corner turns the same way")


func test_a_concave_island_still_gets_its_convex_loop() -> void:
	var island := SmallIsland.make(SmallIsland.L_SHAPE)
	var loop := PatrolLoop.build(island.terrain, island.size, LAP_S)
	assert_true(loop.valid)
	assert_true(_all_deep(loop, island.terrain))
	for sample: Vector2 in loop.samples:
		assert_gte(_distance_to_ring(sample, loop.hull), 4.0 - GEOMETRY)


func test_the_centroid_is_the_mean_of_the_land_cell_centres() -> void:
	# The plain island is the 5x4 block at (17,18): centres 17.5..21.5 by 18.5..21.5.
	assert_eq(_small().centroid, Vector2(19.5, 20.0))


# --- the start and the pose ----------------------------------------------------------------------

func test_the_lap_starts_at_the_most_easterly_point_and_goes_south_first() -> void:
	for loop: PatrolLoop in [_loop_of(SANDBAR), _loop_of(COAST_CAY), _small(), _small(SmallIsland.L_SHAPE)]:
		var start: Vector2 = loop.points[0]
		for point: Vector2 in loop.points:
			assert_lte(point.x, start.x + TOLERANCE, "nothing is further east than the start")
			if absf(point.x - start.x) <= TOLERANCE:
				assert_gte(point.y, start.y - TOLERANCE, "on a tie the start is the most northerly")
		assert_gt(loop.pose_at(0.5).y, start.y, "clockwise as seen on screen: south first")


func test_the_loop_runs_clockwise_as_seen_on_screen() -> void:
	# With y growing downward, a clockwise ring has a positive shoelace sum.
	for loop: PatrolLoop in [_loop_of(SANDBAR), _loop_of(COAST_CAY), _small()]:
		var area: float = 0.0
		for i: int in loop.points.size():
			area += loop.points[i].cross(loop.points[(i + 1) % loop.points.size()])
		assert_gt(area, 0.0)


func test_the_pose_is_the_start_at_0_and_at_the_end_of_the_lap() -> void:
	for loop: PatrolLoop in [_loop_of(SANDBAR), _loop_of(COAST_CAY), _small()]:
		assert_eq(loop.pose_at(0.0), loop.points[0])
		assert_almost_eq(loop.pose_at(LAP_S).distance_to(loop.points[0]), 0.0, 0.0001)


func test_the_boat_moves_at_perimeter_over_lap_tiles_per_second() -> void:
	var loop := _loop_of(SANDBAR)
	assert_almost_eq(loop.speed_tiles_s(), loop.perimeter / LAP_S, TOLERANCE)
	# The first edge is longer than a tile, so a tenth of a second is a straight step.
	var step: float = loop.pose_at(0.15).distance_to(loop.pose_at(0.05))
	assert_almost_eq(step, loop.perimeter / LAP_S * 0.1, 0.0001)
	# Over the whole lap the steps add up to the perimeter.
	var walked: float = 0.0
	var last: Vector2 = loop.pose_at(0.0)
	for i: int in 1000:
		var now: Vector2 = loop.pose_at(LAP_S * (i + 1) / 1000.0)
		walked += last.distance_to(now)
		last = now
	assert_almost_eq(walked, loop.perimeter, 0.5)


func test_the_pose_in_pixels_is_the_tile_pose_times_16() -> void:
	var loop := _loop_of(SANDBAR)
	assert_eq(loop.pose_px(37.0), loop.pose_at(37.0) * 16.0)


func test_the_lap_time_beyond_a_lap_wraps() -> void:
	var loop := _small()
	assert_almost_eq(loop.pose_at(LAP_S + 12.5).distance_to(loop.pose_at(12.5)), 0.0, 0.0001)


# --- the phases ----------------------------------------------------------------------------------

func test_the_phases_of_a_180_s_loop() -> void:
	var cases: Dictionary[float, PatrolLoop.Phase] = {
		0.0: PatrolLoop.Phase.HORIZON, 19.0: PatrolLoop.Phase.HORIZON,
		20.0: PatrolLoop.Phase.LAP, 60.0: PatrolLoop.Phase.LAP, 119.0: PatrolLoop.Phase.LAP,
		120.0: PatrolLoop.Phase.AWAY, 179.0: PatrolLoop.Phase.AWAY,
		180.0: PatrolLoop.Phase.HORIZON, 200.0: PatrolLoop.Phase.LAP,
	}
	for clock: float in cases:
		assert_eq(PatrolLoop.phase_at(clock, PERIOD_S, WARNING_S, LAP_S), cases[clock], "at %s s" % clock)


func test_the_lap_time_starts_when_the_warning_ends() -> void:
	assert_almost_eq(PatrolLoop.lap_time(20.0, WARNING_S), 0.0, TOLERANCE)
	assert_almost_eq(PatrolLoop.lap_time(70.0, WARNING_S), 50.0, TOLERANCE)


func test_experiencia_level_2_stretches_the_period_to_200_s_and_leaves_the_lap() -> void:
	var patrol := GameState.content.get_entry(&"creatures", &"patrol_boat").patrol as PatrolData
	assert_eq(PatrolLoop.experiencia_level(), 0, "no Experiencia exists yet")
	assert_almost_eq(PatrolLoop.period_s(patrol), 180.0, TOLERANCE)
	assert_almost_eq(PatrolLoop.period_s(patrol, 2), 200.0, TOLERANCE)
	assert_almost_eq(patrol.route_lap_s, 100.0, TOLERANCE)
	assert_eq(PatrolLoop.phase_at(119.0, 200.0, WARNING_S, LAP_S), PatrolLoop.Phase.LAP)
	assert_eq(PatrolLoop.phase_at(199.0, 200.0, WARNING_S, LAP_S), PatrolLoop.Phase.AWAY)
	assert_eq(PatrolLoop.phase_at(200.0, 200.0, WARNING_S, LAP_S), PatrolLoop.Phase.HORIZON)


func test_four_boats_run_45_s_behind_each_other() -> void:
	var clocks: Array[float] = []
	for k: int in 4:
		clocks.append(PatrolLoop.boat_clock(100.0, k, 4, PERIOD_S))
	assert_almost_eq(clocks[0], 100.0, TOLERANCE)
	assert_almost_eq(clocks[1], 55.0, TOLERANCE)
	assert_almost_eq(clocks[2], 10.0, TOLERANCE)
	assert_almost_eq(clocks[3], 145.0, TOLERANCE, "wraps round the period")
	assert_almost_eq(PatrolLoop.boat_clock(100.0, 0, 1, PERIOD_S), 100.0, TOLERANCE, "one boat has no offset")
	assert_almost_eq(PatrolLoop.boat_clock(100.0, 1, 2, PERIOD_S), 10.0, TOLERANCE, "two boats are half a period apart")


# --- no loop and determinism -----------------------------------------------------------------------

func test_an_island_with_no_deep_water_gets_no_loop_and_a_warning() -> void:
	var island := SmallIsland.make(SmallIsland.SHALLOW_ALL)
	var loop := PatrolLoop.build(island.terrain, island.size, LAP_S)
	assert_false(loop.valid)
	assert_eq(loop.samples.size(), 0)
	assert_eq(loop.pose_at(10.0), Vector2.ZERO)
	assert_push_warning_count(1)


func test_an_island_with_no_land_gets_no_loop_and_a_warning() -> void:
	var island := SmallIsland.make()
	island.terrain.fill_rect(Rect2i(Vector2i.ZERO, island.size), DataEnums.Terrain.DEEP)
	var loop := PatrolLoop.build(island.terrain, island.size, LAP_S)
	assert_false(loop.valid)
	assert_push_warning_count(1)


func test_a_loop_pushed_out_by_shallows_stays_within_four_extra_tiles() -> void:
	# A ring of shallows one tile wide round the beach: the 4-tile loop would be deep, so the
	# shallows must be wider than 4 tiles to force a push. Shallows 5 tiles out push it once or more.
	var island := SmallIsland.make()
	island.terrain.fill_rect(Rect2i(12, 13, 15, 14), DataEnums.Terrain.SHALLOWS)
	island.terrain.fill_rect(Rect2i(17, 18, 5, 4), DataEnums.Terrain.BEACH)
	var loop := PatrolLoop.build(island.terrain, island.size, LAP_S)
	assert_true(loop.valid)
	assert_gt(loop.extra_push, 0)
	assert_lte(loop.extra_push, 4)
	assert_true(_all_deep(loop, island.terrain))


func test_every_result_is_the_same_on_a_second_build() -> void:
	for layout: IslandLayoutData in [SANDBAR, COAST_CAY]:
		var first := _loop_of(layout)
		var second := _loop_of(layout)
		assert_eq(first.points, second.points)
		assert_eq(first.samples, second.samples)
		assert_eq(first.hull, second.hull)
		assert_eq(first.perimeter, second.perimeter)
		assert_eq(first.centroid, second.centroid)
