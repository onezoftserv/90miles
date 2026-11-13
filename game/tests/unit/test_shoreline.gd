extends GutTest
## The shore rule (task 4.2; design.md D13, T3, K39, K40): which land cells get foam, which piece,
## and the phase offset each cell starts its 8 frames at. Pure: grids and layouts, no node.

const SANDBAR: IslandLayoutData = preload("res://resources/islands/sandbar.tres")
const COAST_CAY: IslandLayoutData = preload("res://resources/islands/coast_cay.tres")
## Corner masks (NW 1, NE 2, SW 4, SE 8) of the three scenario cells.
const STRAIGHT_SOUTH: int = 3
const CONCAVE_SOUTH_EAST: int = 7
const CONVEX_SOUTH_EAST: int = 1
const FRAMES: int = 8
## Neighbouring shore cells start at most this many frames apart (design.md K39).
const MAX_STEP: int = 2


func _foam(rows: PackedStringArray, at: Vector2i) -> Dictionary:
	return ShoreRule.foam_tile(at, TerrainRows.build(rows), TerrainRows.pools(rows))


func _shore(rows: PackedStringArray) -> Array[Vector2i]:
	return ShoreRule.shore_cells(TerrainRows.build(rows), TerrainRows.pools(rows))


func test_edges_and_corners() -> void:
	# art-pass "Edges and corners": a straight south edge, a concave and a convex south-east corner
	var straight: PackedStringArray = PackedStringArray(["sss", "sss", "..."])
	var concave: PackedStringArray = PackedStringArray(["sss", "sss", "ss."])
	var convex: PackedStringArray = PackedStringArray(["ss.", "ss.", "..."])
	var at: Vector2i = Vector2i(1, 1)
	for case: Array in [[straight, STRAIGHT_SOUTH], [concave, CONCAVE_SOUTH_EAST], [convex, CONVEX_SOUTH_EAST]]:
		var rows: PackedStringArray = case[0]
		var foam: Dictionary = _foam(rows, at)
		assert_eq(foam.get(&"source"), 0, "the foam source")
		assert_eq(foam.get(&"atlas"), Vector2i(0, case[1]), "the piece of mask %d, frame 0" % case[1])
		assert_eq(foam.get(&"alternative"), 0)
		assert_true(_shore(rows).has(at), "%s is a shore cell" % at)
		for water: Vector2i in TerrainRows.build(rows).cells:
			if TerrainQuery.is_water(TerrainRows.build(rows).terrain_at(water)):
				assert_true(_foam(rows, water).is_empty(), "the water cell %s has no foam" % water)
				assert_false(_shore(rows).has(water))


func test_a_land_cell_deep_inland_is_not_a_shore_cell() -> void:
	var rows: PackedStringArray = PackedStringArray(["sssss", "sssss", "sssss", "sssss", "sssss"])
	var shore: Array[Vector2i] = _shore(rows)
	assert_false(shore.has(Vector2i(2, 2)))
	assert_true(_foam(rows, Vector2i(2, 2)).is_empty())
	assert_eq(shore.size(), 16, "the ring of the block, and only it")


func test_a_lone_land_cell_gets_the_islet_foam_piece() -> void:
	var rows: PackedStringArray = PackedStringArray(["...", ".s.", "..."])
	assert_eq(_shore(rows), [Vector2i(1, 1)] as Array[Vector2i])
	assert_eq(_foam(rows, Vector2i(1, 1)).get(&"atlas"), Vector2i(0, 0), "mask 0 is the islet")


func test_a_cell_in_any_land_kind_is_a_shore_cell() -> void:
	var rows: PackedStringArray = PackedStringArray(["....", ".dr.", ".bs.", "...."])
	assert_eq(_shore(rows).size(), 4)


func test_tide_pools_get_no_foam_ring() -> void:
	# design.md T3: a pool is land to the shore rule, so no cell of it or round it has a water corner
	var rows: PackedStringArray = PackedStringArray(["sssss", "sssss", "sspss", "sssss", "sssss"])
	assert_false(_shore(rows).has(Vector2i(2, 2)))
	assert_eq(_shore(rows).size(), 16)
	var terrain: GridTerrain = TerrainRows.build(rows)
	assert_eq(ShoreRule.shore_cells(terrain, []).size(), 16 + 9, "without the list the pool and its 8 neighbours get foam")
	var built: IslandLayout = IslandLayout.build(SANDBAR)
	assert_eq(built.tide_pools.size(), 3)
	var with_pools: Array[Vector2i] = ShoreRule.shore_cells(built.terrain, built.tide_pools)
	var without: Array[Vector2i] = ShoreRule.shore_cells(built.terrain, [])
	assert_eq(without.size() - with_pools.size(), 24, "design.md T3: 24 shore cells otherwise")
	for pool: Vector2i in built.tide_pools:
		assert_false(with_pools.has(pool))


func test_the_shore_cell_counts_of_the_two_islands() -> void:
	# design.md T12
	var sandbar: IslandLayout = IslandLayout.build(SANDBAR)
	assert_eq(ShoreRule.shore_cells(sandbar.terrain, sandbar.tide_pools).size(), 292)
	var cay: IslandLayout = IslandLayout.build(COAST_CAY)
	assert_eq(ShoreRule.shore_cells(cay.terrain, cay.tide_pools).size(), 265)


func test_phase_offsets_are_0_to_7_and_equal_across_builds() -> void:
	for layout: IslandLayoutData in [SANDBAR, COAST_CAY]:
		var built: IslandLayout = IslandLayout.build(layout)
		var seen: Dictionary[int, bool] = {}
		for cell: Vector2i in ShoreRule.shore_cells(built.terrain, built.tide_pools):
			var phase: int = ShoreRule.phase(layout.id, cell)
			assert_true(phase >= 0 and phase < FRAMES, "%s %s: %d" % [layout.id, cell, phase])
			assert_eq(ShoreRule.phase(layout.id, cell), phase, "equal when asked again")
			seen[phase] = true
		assert_gt(seen.size(), 4, "%s: the shore does not pulse all at once" % layout.id)


func test_neighbouring_shore_cells_start_at_most_two_steps_apart() -> void:
	# design.md K39: the phase is (x + y + a bit of the hash) % 8, circular over the 8 frames
	for layout: IslandLayoutData in [SANDBAR, COAST_CAY]:
		var built: IslandLayout = IslandLayout.build(layout)
		var shore: Array[Vector2i] = ShoreRule.shore_cells(built.terrain, built.tide_pools)
		var pairs: int = 0
		for cell: Vector2i in shore:
			for step: Vector2i in [Vector2i.RIGHT, Vector2i.DOWN]:
				if not shore.has(cell + step):
					continue
				pairs += 1
				var gap: int = absi(ShoreRule.phase(layout.id, cell) - ShoreRule.phase(layout.id, cell + step))
				gap = mini(gap, FRAMES - gap)
				assert_true(gap <= MAX_STEP, "%s %s and %s start %d apart" % [layout.id, cell, cell + step, gap])
		assert_gt(pairs, 100, "%s: the check met many neighbours" % layout.id)


func test_the_baked_phase_mask_holds_the_same_value_per_cell() -> void:
	for layout: IslandLayoutData in [SANDBAR, COAST_CAY]:
		var built: IslandLayout = IslandLayout.build(layout)
		var mask: PackedByteArray = SeaMask.phase_bytes(layout.id, built.size, built.terrain, built.tide_pools)
		assert_eq(mask.size(), built.size.x * built.size.y, "one value per cell")
		assert_eq(SeaMask.phase_bytes(layout.id, built.size, built.terrain, built.tide_pools), mask, "equal across builds")
		var shore: Array[Vector2i] = ShoreRule.shore_cells(built.terrain, built.tide_pools)
		for cell: Vector2i in shore:
			assert_eq(mask[cell.y * built.size.x + cell.x], ShoreRule.phase(layout.id, cell), "%s %s" % [layout.id, cell])
		assert_eq(mask[0], 0, "a cell with no foam holds 0")


func test_a_solo_player_on_the_sandbar_has_a_shore_to_walk() -> void:
	# one player, offline: the crescent's landing cell is on land and the island has foam to draw
	var built: IslandLayout = IslandLayout.build(SANDBAR)
	assert_false(TerrainQuery.is_water(built.terrain.terrain_at(built.solo_spawn)))
	assert_gt(ShoreRule.shore_cells(built.terrain, built.tide_pools).size(), 0)
