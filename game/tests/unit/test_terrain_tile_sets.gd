extends GutTest
## The tile sets of the made terrain art (task 4.4; design.md D11, D13, K36): every sheet is an
## atlas source of 16 px tiles with a tile exactly where the sheet has art, so the atlas
## coordinates the design names exist, and no tile set has a physics, navigation or occlusion
## layer, so art never blocks movement.

const TILE: Vector2i = Vector2i(16, 16)
const TERRAIN_TILES: String = "res://assets/art/terrain/terrain_tiles.tres"
const SHORE_TILES: String = "res://assets/art/sea/shore_tiles.tres"
const DECAL_TILES: String = "res://assets/art/decals/decal_tiles.tres"
## Each tile set's sheets, in source id order (design.md K36).
const SHEETS: Dictionary = {
	TERRAIN_TILES: [
		"res://assets/art/terrain/sand.png",
		"res://assets/art/terrain/dune.png",
		"res://assets/art/terrain/brush.png",
		"res://assets/art/terrain/plain.png",
		"res://assets/art/terrain/dune_shore.png",
		"res://assets/art/terrain/brush_shore.png",
		"res://assets/art/terrain/plain_shore.png",
	],
	SHORE_TILES: ["res://assets/art/sea/foam.png"],
	DECAL_TILES: ["res://assets/art/terrain/tide_pool.png", "res://assets/art/decals/shade.png"],
}
## Tiles per sheet: a corner set has 16 masks and 4 variants (the brush 2); plain.png 16 shapes of
## 9 terrains; a shore sheet the 65 pairs of an own mask inside a sand mask that has a shore;
## foam.png 8 frames of the 15 masks that have a shore; shade.png 16 masks and 3 spots.
const TILE_COUNTS: Dictionary = {
	TERRAIN_TILES: [20, 20, 18, 144, 65, 65, 585],
	SHORE_TILES: [120],
	DECAL_TILES: [1, 19],
}


func _tile_set(path: String) -> TileSet:
	var tile_set: TileSet = load(path) as TileSet
	assert_not_null(tile_set, path)
	return tile_set


func _source(tile_set: TileSet, id: int) -> TileSetAtlasSource:
	if not tile_set.has_source(id):
		return null
	return tile_set.get_source(id) as TileSetAtlasSource


## The cells of `sheet` that hold a pixel.
func _cells_with_art(sheet: Image) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	var grid: Vector2i = sheet.get_size() / TILE
	for y: int in grid.y:
		for x: int in grid.x:
			var cell: Vector2i = Vector2i(x, y)
			if not sheet.get_region(Rect2i(cell * TILE, TILE)).is_invisible():
				cells.append(cell)
	return cells


func test_no_tile_set_has_a_physics_navigation_or_occlusion_layer() -> void:
	for path: String in SHEETS:
		var tile_set: TileSet = _tile_set(path)
		if tile_set == null:
			continue
		assert_eq(tile_set.tile_size, TILE, path)
		assert_eq(tile_set.get_physics_layers_count(), 0, path)
		assert_eq(tile_set.get_navigation_layers_count(), 0, path)
		assert_eq(tile_set.get_occlusion_layers_count(), 0, path)


func test_every_source_has_a_tile_exactly_where_its_sheet_has_art() -> void:
	for path: String in SHEETS:
		var tile_set: TileSet = _tile_set(path)
		if tile_set == null:
			continue
		var sheets: PackedStringArray = PackedStringArray(SHEETS[path])
		var counts: PackedInt32Array = PackedInt32Array(TILE_COUNTS[path])
		assert_eq(tile_set.get_source_count(), sheets.size(), path)
		for id: int in sheets.size():
			var source: TileSetAtlasSource = _source(tile_set, id)
			assert_not_null(source, "%s source %d" % [path, id])
			if source == null:
				continue
			assert_eq(source.texture.resource_path, sheets[id], "%s source %d" % [path, id])
			assert_eq(source.texture_region_size, TILE, sheets[id])
			assert_eq(source.margins, Vector2i.ZERO, sheets[id])
			assert_eq(source.separation, Vector2i.ZERO, sheets[id])
			var art: Array[Vector2i] = _cells_with_art(ArtChecks.read_png(sheets[id]))
			assert_eq(art.size(), counts[id], "%s: cells with art" % sheets[id])
			assert_eq(source.get_tiles_count(), counts[id], "%s: tiles" % sheets[id])
			for cell: Vector2i in art:
				assert_true(source.has_tile(cell), "%s has no tile at %s" % [sheets[id], cell])
				if source.has_tile(cell):
					assert_eq(source.get_tile_size_in_atlas(cell), Vector2i.ONE, "%s %s is one cell" % [sheets[id], cell])
					assert_eq(source.get_alternative_tiles_count(cell), 1, "%s %s has no alternative" % [sheets[id], cell])


## The shore shader plays the 8 frames by stepping whole tiles along the sheet (design.md D13),
## which only works on the sheet itself, not on Godot's padded copy of it.
func test_the_foam_source_has_no_texture_padding() -> void:
	var tile_set: TileSet = _tile_set(SHORE_TILES)
	if tile_set == null:
		return
	var source: TileSetAtlasSource = _source(tile_set, 0)
	assert_not_null(source)
	if source != null:
		assert_false(source.use_texture_padding)
