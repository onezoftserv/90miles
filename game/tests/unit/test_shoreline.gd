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
	assert_eq(ShoreRule.shore_cells(terrain, []).size(), 16 + 8, "without the list the pool's 8 neighbours get foam")
	var built: IslandLayout = IslandLayout.build(SANDBAR)
	assert_eq(built.tide_pools.size(), 3)
	var with_pools: Array[Vector2i] = ShoreRule.shore_cells(built.terrain, built.tide_pools)
	var without: Array[Vector2i] = ShoreRule.shore_cells(built.terrain, [])
	assert_eq(without.size() - with_pools.size(), 24, "design.md T3: 24 shore cells otherwise")
	for pool: Vector2i in built.tide_pools:
		assert_false(with_pools.has(pool))


func test_the_shore_cell_counts_of_the_two_islands() -> void:
	# design.md T12 (292 without the pools, 24 fewer with them; T3)
	var sandbar: IslandLayout = IslandLayout.build(SANDBAR)
	# coast-cay-reshape QC1: the four filled bay tips leave 4 fewer shore cells (was 268).
	assert_eq(ShoreRule.shore_cells(sandbar.terrain, sandbar.tide_pools).size(), 264, "T12's 292 counts the 24 cells round the pools, which T3 takes away; 4 fewer since the tips were filled")
	var cay: IslandLayout = IslandLayout.build(COAST_CAY)
	# coast-cay-reshape: the jogs, the bight and the rock's taper lengthen the coast (was 265).
	assert_eq(ShoreRule.shore_cells(cay.terrain, cay.tide_pools).size(), 291)


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


func test_the_phase_mask_takes_the_shore_cells_it_is_given_and_finds_them_when_not() -> void:
	for layout: IslandLayoutData in [SANDBAR, COAST_CAY]:
		var built: IslandLayout = IslandLayout.build(layout)
		var found: PackedByteArray = SeaMask.phase_bytes(layout.id, built.size, built.terrain, built.tide_pools)
		var shore: Array[Vector2i] = ShoreRule.shore_cells(built.terrain, built.tide_pools)
		assert_eq(SeaMask.phase_bytes(layout.id, built.size, built.terrain, built.tide_pools, shore), found, "%s: the same mask from the cells TerrainView already found" % layout.id)
		var one: Array[Vector2i] = [shore[shore.size() >> 1]]
		var only: PackedByteArray = SeaMask.phase_bytes(layout.id, built.size, built.terrain, built.tide_pools, one)
		for cell: Vector2i in shore:
			var expected: int = ShoreRule.phase(layout.id, cell) if cell == one[0] else 0
			assert_eq(only[cell.y * built.size.x + cell.x], expected, "%s %s: only the cells it is given are read" % [layout.id, cell])


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


# --- art-terrain-polish C13, TR13: still water is still (design D2) ---

const POND: PackedStringArray = [
	".........",
	".sssssss.",
	".sssssss.",
	".ss,,,ss.",
	".ss,,,ss.",
	".sssssss.",
	".sssssss.",
	".........",
]


func test_a_pond_with_no_deep_cell_is_still_and_a_bay_joined_to_deep_is_not() -> void:
	var still: Dictionary[Vector2i, bool] = ShoreRule.still_water(TerrainRows.build(POND))
	assert_eq(still.size(), 6, "the pond's six cells")
	for cell: Vector2i in still:
		assert_eq(TerrainRows.build(POND).terrain_at(cell), DataEnums.Terrain.BRACKISH, "%s is the pond" % cell)
	var bay := PackedStringArray([".........", ".sssssss.", ".ss~~~ss.", ".ss~~~...", ".sssssss.", "........."])
	assert_true(ShoreRule.still_water(TerrainRows.build(bay)).is_empty(), "a bay that reaches deep water is open")
	var pool := PackedStringArray(["....", ".sp.", ".ss.", "...."])
	assert_true(ShoreRule.still_water(TerrainRows.build(pool), TerrainRows.pools(pool)).is_empty(), "a tide pool is land, never a still body")


func test_a_shore_cell_on_still_water_takes_the_still_piece() -> void:
	var terrain: GridTerrain = TerrainRows.build(POND)
	var still: Dictionary[Vector2i, bool] = ShoreRule.still_water(terrain)
	var inner: Dictionary = ShoreRule.foam_tile(Vector2i(3, 2), terrain, [], still)
	assert_eq(inner.get(&"source"), ShoreRule.STILL_SOURCE, "the pond's rim is still")
	assert_eq(inner.get(&"atlas"), Vector2i(0, 3), "with the same piece of its mask")
	assert_eq(ShoreRule.foam_tile(Vector2i(1, 1), terrain, [], still).get(&"source"), ShoreRule.FOAM_SOURCE, "the outer coast keeps its surf")
	assert_eq(ShoreRule.foam_tile(Vector2i(3, 2), terrain, []).get(&"source"), ShoreRule.FOAM_SOURCE, "with no still water given, today's surf")
	var thin := PackedStringArray([".......", ".sssss.", ".s,,,s.", ".sssss.", "......."])
	var thin_terrain: GridTerrain = TerrainRows.build(thin)
	var thin_still: Dictionary[Vector2i, bool] = ShoreRule.still_water(thin_terrain)
	assert_eq(ShoreRule.foam_tile(Vector2i(2, 1), thin_terrain, [], thin_still).get(&"source"), ShoreRule.FOAM_SOURCE, "a cell touching the sea and the pond keeps the surf")
	assert_true(ShoreRule.shore_cells(terrain, []).has(Vector2i(3, 2)), "a still cell is still a shore cell")


## One player, offline: the coast cay's lagoon is found from the layout (the water body with no
## deep cell: the brackish water and the shallows ring round it), its rim takes the still piece and every shore cell on open water keeps the surf.
func test_a_solo_coast_cay_lagoon_has_a_still_edge() -> void:
	var cay: IslandLayout = IslandLayout.build(COAST_CAY)
	var still: Dictionary[Vector2i, bool] = ShoreRule.still_water(cay.terrain, cay.tide_pools)
	assert_false(still.is_empty(), "the cay has a lagoon")
	for cell: Vector2i in cay.terrain.cells:
		if cay.terrain.terrain_at(cell) == DataEnums.Terrain.BRACKISH:
			assert_true(still.has(cell), "%s: the brackish lagoon is still water" % cell)
	for cell: Vector2i in still:
		assert_true(cay.terrain.terrain_at(cell) in [DataEnums.Terrain.BRACKISH, DataEnums.Terrain.SHALLOWS], "%s: the lagoon and its shallow ring" % cell)
	var rim: int = 0
	var open: int = 0
	for cell: Vector2i in ShoreRule.shore_cells(cay.terrain, cay.tide_pools):
		var wet_still: bool = false
		var wet_open: bool = false
		for y: int in range(-1, 2):
			for x: int in range(-1, 2):
				var next: Vector2i = cell + Vector2i(x, y)
				if TerrainQuery.is_water(cay.terrain.terrain_at(next)) and not cay.tide_pools.has(next):
					if still.has(next):
						wet_still = true
					else:
						wet_open = true
		var source: int = ShoreRule.foam_tile(cell, cay.terrain, cay.tide_pools, still).get(&"source", -1)
		if wet_still and not wet_open:
			rim += 1
			assert_eq(source, ShoreRule.STILL_SOURCE, "lagoon rim %s is still" % cell)
		else:
			open += 1
			assert_eq(source, ShoreRule.FOAM_SOURCE, "open shore %s keeps its surf" % cell)
	assert_gt(rim, 0, "the lagoon has a rim")
	assert_eq(rim + open, 291, "every shore cell is one or the other (291 since coast-cay-reshape)")
	var sandbar: IslandLayout = IslandLayout.build(SANDBAR)
	assert_true(ShoreRule.still_water(sandbar.terrain, sandbar.tide_pools).is_empty(), "the sandbar has no still water")
