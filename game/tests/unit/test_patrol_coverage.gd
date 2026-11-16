extends GutTest
## guardacostas-stealth task 3.4: pins the tuning (design.md "The geometry, measured"). One 100 s
## lap is stepped at 0.1 s with the real loop, beam and meter, for a still, unhidden player on
## every land cell (hidden states are ignored here), at night with sight enabled. The spotted share
## of the land is 45% (sandbar) and 34% (coast cay), each within 3 points, and the sandbar's raft
## site is never lit while the coast cay's is. If a retune moves these, edit the pins on purpose.

const SANDBAR: IslandLayoutData = preload("res://resources/islands/sandbar.tres")
const COAST_CAY: IslandLayoutData = preload("res://resources/islands/coast_cay.tres")
const STEP_S: float = 0.1
const SHARE_TOLERANCE: float = 0.03


# What one lap does to a still player on each land cell: {land, spotted, raft_lit}.
func _lap(layout: IslandLayoutData) -> Dictionary:
	var patrol := (GameState.content.get_entry(&"creatures", &"patrol_boat") as CreatureData).patrol
	var built := IslandLayout.build(layout)
	var loop := PatrolLoop.build(built.terrain, built.size, patrol.route_lap_s, patrol.route_offshore_tiles)
	var light := Searchlight.from_patrol(patrol)
	# Land cells, and of those the ones some loop sample can reach (the others are never lit).
	var land: Array[Vector2i] = []
	for cell: Vector2i in built.terrain.cells:
		if not TerrainQuery.is_water(built.terrain.terrain_at(cell)):
			land.append(cell)
	var reach_sq: float = patrol.searchlight_range_tiles * patrol.searchlight_range_tiles
	var reachable: Array[Vector2i] = []
	for cell: Vector2i in land:
		var centre := Vector2(cell) + Vector2(0.5, 0.5)
		for sample: Vector2 in loop.samples:
			if centre.distance_squared_to(sample) <= reach_sq:
				reachable.append(cell)
				break
	var meters: Dictionary[Vector2i, SpotMeter] = {}
	var spotted: Dictionary[Vector2i, bool] = {}
	for cell: Vector2i in reachable:
		meters[cell] = SpotMeter.from_patrol(patrol)
	var raft_lit: bool = false
	var steps: int = roundi(patrol.route_lap_s / STEP_S)
	for step: int in steps:
		var t: float = step * STEP_S
		var boat: Vector2 = loop.pose_at(t)
		var beam: float = light.beam_deg(boat, loop.centroid, t)
		for cell: Vector2i in reachable:
			var centre := Vector2(cell) + Vector2(0.5, 0.5)
			var lit: bool = light.is_lit(centre, boat, beam)
			if cell == built.raft_site and lit:
				raft_lit = true
			if meters[cell].step(lit, false, STEP_S):
				spotted[cell] = true
	return {"land": land.size(), "spotted": spotted.size(), "raft_lit": raft_lit, "raft_site": built.raft_site}


func test_the_sandbar_spots_45_percent_of_its_land_in_one_lap() -> void:
	var lap := _lap(SANDBAR)
	var share: float = float(lap["spotted"]) / float(lap["land"])
	gut.p("sandbar: %d of %d land cells spotted (%.1f%%)" % [lap["spotted"], lap["land"], share * 100.0])
	assert_almost_eq(share, 0.45, SHARE_TOLERANCE)


func test_the_coast_cay_spots_34_percent_of_its_land_in_one_lap() -> void:
	var lap := _lap(COAST_CAY)
	var share: float = float(lap["spotted"]) / float(lap["land"])
	gut.p("coast cay: %d of %d land cells spotted (%.1f%%)" % [lap["spotted"], lap["land"], share * 100.0])
	assert_almost_eq(share, 0.34, SHARE_TOLERANCE)


func test_the_sandbar_raft_site_is_never_lit_and_the_coast_cays_is() -> void:
	var sandbar := _lap(SANDBAR)
	assert_ne(sandbar["raft_site"], Vector2i(-1, -1), "the sandbar names a raft site")
	assert_false(sandbar["raft_lit"], "inside the C's bay")
	var coast := _lap(COAST_CAY)
	assert_ne(coast["raft_site"], Vector2i(-1, -1), "the coast cay names a raft site")
	assert_true(coast["raft_lit"], "island 2 has more teeth")
