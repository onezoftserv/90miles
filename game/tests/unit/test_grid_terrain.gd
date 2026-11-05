extends GutTest
## player-movement: terrain classification and the GridTerrain test/playground implementation.

const T := DataEnums.Terrain


func test_water_terrains() -> void:
	for t: DataEnums.Terrain in [T.DEEP, T.SHALLOWS, T.BRACKISH]:
		assert_true(TerrainQuery.is_water(t), "%s is water" % t)
	for t: DataEnums.Terrain in [T.BEACH, T.DUNE, T.MANGROVE, T.ROCK, T.SCRUB]:
		assert_false(TerrainQuery.is_water(t), "%s is land" % t)


func test_brush_terrains() -> void:
	assert_true(TerrainQuery.is_brush(T.SCRUB))
	assert_true(TerrainQuery.is_brush(T.MANGROVE))
	assert_false(TerrainQuery.is_brush(T.BEACH))
	assert_false(TerrainQuery.is_brush(T.DEEP))


func test_default_current_is_one_tile_per_second_east() -> void:
	assert_eq(TerrainQuery.DEFAULT_CURRENT, Vector2(1.0, 0.0))
	assert_eq(GridTerrain.new().current_at(Vector2i.ZERO), Vector2(1.0, 0.0))


func test_grid_returns_set_cells_and_the_default_elsewhere() -> void:
	var grid := GridTerrain.new()
	grid.set_cell(Vector2i(2, 3), T.SCRUB)
	assert_eq(grid.terrain_at(Vector2i(2, 3)), T.SCRUB)
	assert_eq(grid.terrain_at(Vector2i(9, 9)), grid.default_terrain)


func test_fill_rect_covers_every_cell() -> void:
	var grid := GridTerrain.new()
	grid.fill_rect(Rect2i(1, 1, 3, 2), T.DEEP)
	assert_eq(grid.cells.size(), 6)
	assert_eq(grid.terrain_at(Vector2i(3, 2)), T.DEEP)
	assert_ne(grid.terrain_at(Vector2i(4, 2)), T.DEEP)


func test_current_can_be_changed() -> void:
	var grid := GridTerrain.new()
	grid.current = Vector2(0.0, 2.0)
	assert_eq(grid.current_at(Vector2i(5, 5)), Vector2(0.0, 2.0))
