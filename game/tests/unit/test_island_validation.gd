extends GutTest
## island-generation "Validation": each check rejects an island broken on purpose (a generated
## island with its grid or placements edited in the test), every reef is accepted within the cap,
## "The cap gives the fallback island" and "The last attempts drop rolled POIs".

const T := DataEnums.Terrain

var chain: ChainData
var island: GeneratedIsland


func before_all() -> void:
	chain = ReefSamples.chain()
	island = ReefSamples.island(1)


func _fresh() -> IslandLayout:
	return IslandLayout.build(island.layout)


func _pois() -> Array[Dictionary]:
	var pois: Array[Dictionary] = []
	for placed: Dictionary in island.pois:
		pois.append(placed.duplicate())
	return pois


func _failures(built: IslandLayout, pois: Array[Dictionary] = _pois(), template: ChainData = chain) -> PackedStringArray:
	return IslandValidator.check(template, built, pois, GameState.content)


func _has(failures: PackedStringArray, check: String) -> bool:
	for failure: String in failures:
		if failure.begins_with(check):
			return true
	return false


func _land(built: IslandLayout, cell: Vector2i) -> bool:
	return built.terrain.terrain_at(cell) in [T.BEACH, T.SCRUB, T.ROCK]


func test_the_untouched_island_passes() -> void:
	assert_eq(_failures(_fresh()), PackedStringArray())


func test_land_outside_its_band() -> void:
	var built := _fresh()
	var removed: int = 0
	for cell: Vector2i in built.terrain.cells.keys():
		if removed < 400 and built.terrain.cells[cell] == T.SCRUB:
			built.terrain.set_cell(cell, T.DEEP)
			removed += 1
	var failures := _failures(built)
	assert_true(_has(failures, "land count"), str(failures))


func test_land_in_the_margin() -> void:
	var built := _fresh()
	built.terrain.set_cell(Vector2i(2, 2), T.BEACH)
	assert_true(_has(_failures(built), "margin"))


func _islet(built: IslandLayout) -> Vector2i:
	for y: int in range(10, 54):
		for x: int in range(10, 86):
			var clear: bool = true
			for dy: int in range(-4, 5):
				for dx: int in range(-4, 5):
					if built.terrain.terrain_at(Vector2i(x + dx, y + dy)) != T.DEEP:
						clear = false
			if clear:
				return Vector2i(x, y)
	return Vector2i(-1, -1)


func test_two_landmasses() -> void:
	var built := _fresh()
	var spot: Vector2i = _islet(built)
	assert_ne(spot, Vector2i(-1, -1), "open deep water inside the margin")
	built.terrain.set_cell(spot, T.BEACH)
	built.terrain.set_cell(spot + Vector2i.RIGHT, T.BEACH)
	assert_true(_has(_failures(built), "landmass"))


func test_a_land_cell_11_tiles_from_water() -> void:
	var built := _fresh()
	var middle := Vector2i(48, 32)
	for dy: int in range(-11, 12):
		for dx: int in range(-11, 12):
			built.terrain.set_cell(middle + Vector2i(dx, dy), T.SCRUB)
	assert_true(_has(_failures(built), "inland"))


func test_a_missing_guaranteed_poi() -> void:
	var pois: Array[Dictionary] = []
	for placed: Dictionary in _pois():
		if placed["id"] != &"limestone_cave":
			pois.append(placed)
	assert_true(_has(_failures(_fresh(), pois), "pois: guaranteed limestone_cave"))


func test_two_anchors_11_tiles_apart() -> void:
	var pois: Array[Dictionary] = _pois()
	pois[1]["anchor"] = (pois[0]["anchor"] as Vector2i) + Vector2i(11, 0)
	assert_true(_has(_failures(_fresh(), pois), "poi spacing"))


func test_a_pickup_on_an_islet_beyond_deep_water() -> void:
	var built := _fresh()
	var spot: Vector2i = _islet(built)
	built.terrain.set_cell(spot, T.BEACH)
	built.pickups.append({"cell": spot, "item_id": &"rope", "count": 1, "respawn": 0, "group": &"traps"})
	assert_true(_has(_failures(built), "reach"))


func test_a_landing_pair_6_tiles_apart() -> void:
	var built := _fresh()
	var first: Vector2i = built.coop_spawns[0]
	var away := first + Vector2i(0, 6)
	if not _land(built, away):
		away = first + Vector2i(0, -6)
	built.terrain.set_cell(away, T.BEACH)
	built.coop_spawns[3] = away
	assert_true(_has(_failures(built), "landing"))


func test_a_raft_site_4_seconds_away() -> void:
	var built := _fresh()
	var grid := IslandGrid.new(built.size.x, built.size.y)
	var terrain: PackedInt32Array = ReefSamples.terrain_of(built)
	var walk: PackedInt32Array = grid.chamfer_walk(grid.mask_of(terrain, IslandLayout.WALKABLE), built.coop_spawns[0])
	var site := Vector2i(-1, -1)
	for i: int in walk.size():
		if terrain[i] == T.BEACH and walk[i] >= 32 and walk[i] <= 33:
			site = grid.cell_of(i)
			break
	assert_ne(site, Vector2i(-1, -1), "a beach cell 4 s away")
	built.raft_site = site
	assert_true(_has(_failures(built), "walk: raft site"))


func test_a_far_end_beyond_its_band() -> void:
	# A causeway long enough to put land 23 s out does not fit every map, so the template's band is
	# moved below this island's far end instead: the check must reject it the same way.
	var built := _fresh()
	var grid := IslandGrid.new(built.size.x, built.size.y)
	var terrain: PackedInt32Array = ReefSamples.terrain_of(built)
	var walk: PackedInt32Array = grid.chamfer_walk(grid.mask_of(terrain, IslandLayout.WALKABLE), built.coop_spawns[0])
	var far: int = 0
	for i: int in walk.size():
		if _land(built, grid.cell_of(i)):
			far = maxi(far, walk[i])
	var short := chain.duplicate() as ChainData
	short.far_end_walk_s = Vector2(9.0, far / PoiPlacer.HALF_TILES_PER_S - 1.0)
	assert_true(_has(_failures(built, _pois(), short), "walk: far end"))
	assert_false(_has(_failures(built), "walk: far end"), "inside the real band")


func test_every_reef_is_accepted_within_the_cap() -> void:
	var total: int = 0
	var worst: int = 0
	for generated: GeneratedIsland in ReefSamples.islands():
		assert_false(generated.fallback, "accepted without the fallback")
		total += generated.attempts
		worst = maxi(worst, generated.attempts)
	var mean: float = float(total) / ReefSamples.SEEDS
	gut.p("attempts over %d reefs: mean %.2f, max %d" % [ReefSamples.SEEDS, mean, worst])
	assert_lte(mean, 2.0, "mean attempts")
	assert_lte(worst, 50, "most attempts")


func test_the_cap_gives_the_fallback_island() -> void:
	var never := func(_candidate: GeneratedIsland) -> PackedStringArray:
		return PackedStringArray(["test: rejected"])
	var capped: GeneratedIsland = IslandGenerator.generate(1, 3, chain, GameState.content, never)
	var spare: GeneratedIsland = IslandGenerator.generate(9090, 0, chain)
	assert_true(capped.fallback, "the fallback was used")
	assert_eq(capped.attempts, 50)
	assert_eq(capped.layout.id, &"reef_traps_3", "under the requested island's id")
	assert_eq(capped.layout.rows, spare.layout.rows, "the fallback island's map")
	assert_eq(capped.report["attempts"].size(), 50)
	assert_eq(_failures(capped.built, capped.pois), PackedStringArray(), "the fallback passes every check")


func test_the_last_attempts_drop_rolled_pois() -> void:
	var always := chain.duplicate() as ChainData
	always.poi_chances = {&"palm_grove": 1.0}
	var late := func(candidate: GeneratedIsland) -> PackedStringArray:
		return PackedStringArray() if candidate.report["relaxed"] else PackedStringArray(["test: too early"])
	var relaxed: GeneratedIsland = IslandGenerator.generate(1, 3, always, GameState.content, late)
	assert_false(relaxed.fallback)
	assert_eq(relaxed.attempts, 46, "the first relaxed attempt")
	for placed: Dictionary in relaxed.pois:
		assert_ne(placed["id"], &"palm_grove", "no rolled POI in a relaxed attempt")
	var attempts: Array = relaxed.report["attempts"]
	for k: int in attempts.size():
		assert_eq(attempts[k]["relaxed"], k >= 45, "attempt %d relaxed" % k)


func test_the_fallback_island_of_the_reef_passes_every_check() -> void:
	var spare: GeneratedIsland = IslandGenerator.generate(chain.fallback_seed, 0, chain)
	assert_false(spare.fallback, "the fallback island is found without a fallback")
	assert_eq(_failures(spare.built, spare.pois), PackedStringArray())
