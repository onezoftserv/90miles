extends GutTest
## island-generation "The reef cay's landmass" over 200 run seeds, and "A POI roll never moves the
## land".

const T := DataEnums.Terrain
const LAND: Array[int] = [T.BEACH, T.DUNE, T.SCRUB, T.ROCK]
const WATER: Array[int] = [T.DEEP, T.SHALLOWS]

var islands: Array[GeneratedIsland] = []
var chain: ChainData


func before_all() -> void:
	chain = ReefSamples.chain()
	islands = ReefSamples.islands()


func _grid() -> IslandGrid:
	return IslandGrid.new(96, 64)


func test_two_hundred_reefs_were_generated() -> void:
	assert_eq(islands.size(), 200)
	for island: GeneratedIsland in islands:
		assert_not_null(island.layout)
		assert_eq(island.built.size, Vector2i(96, 64))


func test_land_count_share_margin_and_one_landmass() -> void:
	var grid := _grid()
	for k: int in islands.size():
		var terrain: PackedInt32Array = ReefSamples.terrain_of(islands[k].built)
		var land: PackedInt32Array = grid.mask_of(terrain, LAND)
		var count: int = 0
		var margin: int = 0
		for i: int in land.size():
			if land[i] == 0:
				continue
			count += 1
			var cell: Vector2i = grid.cell_of(i)
			if cell.x < 8 or cell.y < 8 or cell.x >= 88 or cell.y >= 56:
				margin += 1
		var what: String = "run seed %d" % (k + 1)
		assert_between(count, 1000, 1300, "%s land cells" % what)
		assert_between(float(count) / 6144.0, 0.16, 0.22, "%s land share" % what)
		assert_eq(margin, 0, "%s keeps its margin" % what)
		assert_eq((grid.label_bodies(land)["sizes"] as PackedInt32Array).size(), 1, "%s is one 4-connected landmass" % what)


func test_every_land_cell_is_within_10_tiles_of_water() -> void:
	var grid := _grid()
	for k: int in islands.size():
		var terrain: PackedInt32Array = ReefSamples.terrain_of(islands[k].built)
		var water: PackedInt32Array = grid.mask_of(terrain, WATER)
		var rings: PackedInt32Array = grid.chebyshev_from(water)
		var worst: float = 0.0
		for i: int in terrain.size():
			# Euclidean distance is at most √2 × the Chebyshev ring: only deep cells need the window.
			if water[i] != 0 or rings[i] <= 7:
				worst = maxf(worst, float(rings[i]) if water[i] == 0 else 0.0)
				continue
			var cell: Vector2i = grid.cell_of(i)
			var nearest: float = 99.0
			for dy: int in range(-10, 11):
				for dx: int in range(-10, 11):
					var next := cell + Vector2i(dx, dy)
					if not grid.has(next) or water[grid.index_of(next)] != 0:
						nearest = minf(nearest, Vector2(dx, dy).length())
			worst = maxf(worst, nearest)
		assert_lte(worst, 10.0, "run seed %d: the farthest land from water, in tiles" % (k + 1))


func test_shallows_ring_the_land_and_deep_water_lies_beyond() -> void:
	var grid := _grid()
	for k: int in islands.size():
		var terrain: PackedInt32Array = ReefSamples.terrain_of(islands[k].built)
		var to_land: PackedInt32Array = grid.chebyshev_from(grid.mask_of(terrain, LAND))
		var wrong: int = 0
		for i: int in terrain.size():
			if LAND.has(terrain[i]):
				continue
			var expected: int = T.SHALLOWS if to_land[i] <= 2 else T.DEEP
			if terrain[i] != expected:
				wrong += 1
		assert_eq(wrong, 0, "run seed %d: water within 2 of land is shallows, the rest deep" % (k + 1))


# Coast cells whose ray west reaches the edge over water only.
func _lee_coast(grid: IslandGrid, land: PackedInt32Array, to_water: PackedInt32Array) -> PackedInt32Array:
	var lee := grid.filled(0)
	for i: int in land.size():
		if land[i] == 0 or to_water[i] != 1:
			continue
		var open: bool = true
		var cell: Vector2i = grid.cell_of(i) + Vector2i.LEFT
		while open and grid.has(cell):
			open = land[grid.index_of(cell)] == 0
			cell += Vector2i.LEFT
		lee[i] = 1 if open else 0
	return lee


func test_the_shore_is_rock_with_a_beach_on_the_lee() -> void:
	var grid := _grid()
	for k: int in islands.size():
		var island: GeneratedIsland = islands[k]
		var terrain: PackedInt32Array = ReefSamples.terrain_of(island.built)
		var land: PackedInt32Array = grid.mask_of(terrain, LAND)
		var to_water: PackedInt32Array = grid.chebyshev_from(grid.mask_of(terrain, WATER))
		var width: int = island.report["attempts"][island.attempts - 1]["shore_width"]
		var lee: PackedInt32Array = ReefRingPainter.lee_shore(grid, land, to_water, _lee_coast(grid, land, to_water), width)
		var what: String = "run seed %d" % (k + 1)
		assert_between(width, 2, 4, "%s shore width" % what)
		var bad: int = 0
		var beach_off_lee: int = 0
		var rock_on_lee: int = 0
		var interior: int = 0
		var rock: int = 0
		for i: int in terrain.size():
			if land[i] == 0:
				continue
			if to_water[i] <= width:
				if terrain[i] != T.BEACH and terrain[i] != T.ROCK:
					bad += 1
				elif terrain[i] == T.BEACH and lee[i] == 0:
					beach_off_lee += 1
				elif terrain[i] == T.ROCK and lee[i] != 0:
					rock_on_lee += 1
			else:
				interior += 1
				if terrain[i] == T.ROCK:
					rock += 1
				elif terrain[i] != T.SCRUB:
					bad += 1
		assert_eq(bad, 0, "%s: the shore is beach or rock and the interior rock or scrub" % what)
		assert_eq(beach_off_lee, 0, "%s: every beach cell is near a lee coast cell" % what)
		assert_eq(rock_on_lee, 0, "%s: no rock shore cell is near a lee coast cell" % what)
		if interior > 0:
			assert_between(float(rock) / float(interior), 0.2, 0.4, "%s: rock share of the interior" % what)


func test_the_terrain_is_the_same_when_generated_twice() -> void:
	for run_seed: int in [1, 2, 3]:
		var again: GeneratedIsland = IslandGenerator.generate(run_seed, 3, chain)
		assert_eq(again.layout.rows, ReefSamples.island(run_seed).layout.rows, "run seed %d" % run_seed)


func test_a_poi_roll_never_moves_the_land() -> void:
	var always := chain.duplicate() as ChainData
	always.poi_chances = {&"palm_grove": 1.0}
	var groves: int = 0
	for run_seed: int in [1, 2, 3, 4, 5]:
		var first: PackedInt32Array = IslandGenerator.attempt_island(run_seed, 3, chain, GameState.content, 0, false).report["terrain"]
		var grove: GeneratedIsland = IslandGenerator.attempt_island(run_seed, 3, always, GameState.content, 0, false)
		assert_eq(grove.report["terrain"], first, "run seed %d: the same terrain, cell for cell" % run_seed)
		for placed: Dictionary in grove.pois:
			if placed["id"] == &"palm_grove":
				groves += 1
	assert_gt(groves, 0, "the copy's grove was placed on some of them")
