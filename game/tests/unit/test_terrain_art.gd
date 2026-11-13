extends GutTest
## art-pass "Foam meets the sand" on the made art (task 4.4; design.md D11, D13, K35 to K39): in
## every frame the foam is one band that lies on the sand's edge, washing a few pixels up the
## sand and out over the water, with no gap and no second foam line; the sheets hold the tile of
## each corner mask where the design says; and no upper-layer tile hangs over the sea. The PNGs
## are read from their bytes, so the checks need no import.
## Task 4.1 adds the corner rule, the layers, the terrain kinds and the variants to this file.

const SAND_SHEET: String = "res://assets/art/terrain/sand.png"
const FOAM_SHEET: String = "res://assets/art/sea/foam.png"
const TILE: int = 16
## A corner set sheet holds mask m at column m % 4, row m / 4 (design.md K36).
const SET_COLUMNS: int = 4
## The foam sheet holds frame f of mask m at column f, row m (design.md K37).
const FOAM_FRAMES: int = 8
## Corner masks (design.md D11: NW 1, NE 2, SW 4, SE 8) of the four straight edges, named by the
## side the sea is on, and the quarter turns clockwise that bring that side to the south.
const SEA_SOUTH: int = 3
const SEA_NORTH: int = 12
const SEA_EAST: int = 5
const SEA_WEST: int = 10
const TURNS_TO_SOUTH: Dictionary[int, int] = {SEA_SOUTH: 0, SEA_EAST: 1, SEA_NORTH: 2, SEA_WEST: 3}
## Over the cycle the wash climbs at most this many pixels up the sand from its edge (the side
## edges are wavy, so a line can be two pixels deeper than a straight one).
const WASH_PX: int = 6
## The wave at its fullest: every line of the edge has foam on the sand's last pixel or the first
## water pixel.
const FULL_FRAMES: Array[int] = [0, 7]
## The other frames are lace, but never bare: at least this many lines touch the sand's edge.
const LACE_LINES: int = 3
const CORNER_SETS: Array[String] = ["sand", "dune", "brush"]
const SHADE_SHEET: String = "res://assets/art/decals/shade.png"
const PLAIN_SHEET: String = "res://assets/art/terrain/plain.png"
const PLAIN_ROWS: int = 9
## The most full-tile variants a plain row has (the rock's), on columns 16 and after.
const PLAIN_VARIANTS_MAX: int = 3
const WATER_RAMPS: String = "res://assets/art/sea/water_ramps.png"
## The shore sheets (design.md K39): column = the cell's sand mask, row = the layer's own mask
## (plain: 16 rows per terrain).
const SHORE_SHEETS: Array[String] = ["dune_shore", "brush_shore", "plain_shore"]


func _sheet(path: String) -> Image:
	var image: Image = ArtChecks.read_png(path)
	assert_not_null(image, path)
	return image


## The tile at `cell` of `sheet`, turned so that the sea side of `mask` is at the south.
func _tile(sheet: Image, cell: Vector2i, mask: int) -> Image:
	var tile: Image = sheet.get_region(Rect2i(cell * TILE, Vector2i(TILE, TILE)))
	for _turn: int in TURNS_TO_SOUTH[mask]:
		tile.rotate_90(CLOCKWISE)
	return tile


func _sand(sheet: Image, mask: int) -> Image:
	@warning_ignore("integer_division")
	return _tile(sheet, Vector2i(mask % SET_COLUMNS, mask / SET_COLUMNS), mask)


func _foam(sheet: Image, mask: int, frame: int) -> Image:
	return _tile(sheet, Vector2i(frame, mask), mask)


## The rows of `tile` that hold a pixel, top to bottom.
func _rows(tile: Image) -> Array[int]:
	var rows: Array[int] = []
	for y: int in TILE:
		for x: int in TILE:
			if tile.get_pixel(x, y).a > 0.0:
				rows.append(y)
				break
	return rows


## The first (or last) row of column `x` that holds a pixel; -1 when the column is empty.
func _column_end(tile: Image, x: int, last: bool) -> int:
	var found: int = -1
	for y: int in TILE:
		if tile.get_pixel(x, y).a > 0.0:
			if not last:
				return y
			found = y
	return found


func test_the_sheets_hold_16_masks_and_8_foam_frames() -> void:
	var sand: Image = _sheet(SAND_SHEET)
	var foam: Image = _sheet(FOAM_SHEET)
	if sand == null or foam == null:
		return
	assert_eq(sand.get_width(), SET_COLUMNS * TILE)
	assert_gte(sand.get_height(), 4 * TILE, "four rows of masks, then the variants")
	assert_eq(foam.get_size(), Vector2i(FOAM_FRAMES * TILE, 16 * TILE), "a column per frame, a row per mask")


func test_in_every_frame_the_foam_is_one_band_on_the_sands_edge() -> void:
	var sand: Image = _sheet(SAND_SHEET)
	var foam: Image = _sheet(FOAM_SHEET)
	if sand == null or foam == null:
		return
	for mask: int in TURNS_TO_SOUTH:
		var sand_tile: Image = _sand(sand, mask)
		for frame: int in FOAM_FRAMES:
			var foam_tile: Image = _foam(foam, mask, frame)
			var touching: int = 0
			var border: int = 0
			for x: int in TILE:
				var sand_end: int = _column_end(sand_tile, x, true)
				assert_ne(sand_end, -1, "mask %d line %d has sand" % [mask, x])
				var foam_start: int = _column_end(foam_tile, x, false)
				if foam_start == -1:
					continue
				assert_gte(foam_start, sand_end - WASH_PX, "mask %d frame %d line %d: the wash stays by the edge" % [mask, frame, x])
				if foam_tile.get_pixel(x, sand_end).a > 0.0 or foam_tile.get_pixel(x, mini(sand_end + 1, TILE - 1)).a > 0.0:
					touching += 1
				if foam_tile.get_pixel(x, TILE - 1).a > 0.0:
					border += 1
			assert_gte(touching, TILE if frame in FULL_FRAMES else LACE_LINES, "mask %d frame %d: lines of foam on the sand's edge" % [mask, frame])
			assert_lt(border, TILE, "mask %d frame %d: the foam never ends as a full line on the cell's border" % [mask, frame])


func test_on_the_two_level_edges_the_foam_has_no_empty_row_in_any_frame() -> void:
	var foam: Image = _sheet(FOAM_SHEET)
	if foam == null:
		return
	for mask: int in [SEA_SOUTH, SEA_NORTH]:
		for frame: int in FOAM_FRAMES:
			var rows: Array[int] = _rows(_foam(foam, mask, frame))
			assert_false(rows.is_empty(), "mask %d frame %d has foam" % [mask, frame])
			if not rows.is_empty():
				assert_eq(rows.size(), rows[-1] - rows[0] + 1, "mask %d frame %d: one foam line, no empty row in it" % [mask, frame])


func test_every_mask_with_a_shore_has_foam_in_every_frame_and_the_full_tile_none() -> void:
	var foam: Image = _sheet(FOAM_SHEET)
	if foam == null:
		return
	for mask: int in 16:
		for frame: int in FOAM_FRAMES:
			var empty: bool = foam.get_region(Rect2i(frame * TILE, mask * TILE, TILE, TILE)).is_invisible()
			assert_eq(empty, mask == 15, "mask %d frame %d" % [mask, frame])


## A corner pixel of the tile at `cell` is drawn.
func _corner(sheet: Image, cell: Vector2i, corner: Vector2i) -> bool:
	return sheet.get_pixel(cell.x * TILE + corner.x * (TILE - 1), cell.y * TILE + corner.y * (TILE - 1)).a > 0.0


## The corner bits (NW 1, NE 2, SW 4, SE 8) whose corner pixel of the tile at `cell` is drawn.
func _corners(sheet: Image, cell: Vector2i) -> int:
	var found: int = 0
	for bit: int in 4:
		@warning_ignore("integer_division")
		if _corner(sheet, cell, Vector2i(bit % 2, bit / 2)):
			found |= 1 << bit
	return found


## Design.md K36: the tile of corner mask m is at column m % 4, row m / 4, and its four corner
## pixels are drawn exactly for the bits of m. The brush is a stamp, a bush on the cell and a
## quarter bush on each land corner, so its corner pixels follow the same bits.
func test_each_corner_set_holds_mask_m_at_its_place() -> void:
	var paths: Array[String] = [SHADE_SHEET]
	for id: String in CORNER_SETS:
		paths.append("res://assets/art/terrain/%s.png" % id)
	for path: String in paths:
		var sheet: Image = _sheet(path)
		if sheet == null:
			continue
		for mask: int in 16:
			@warning_ignore("integer_division")
			var cell: Vector2i = Vector2i(mask % SET_COLUMNS, mask / SET_COLUMNS)
			assert_eq(_corners(sheet, cell), mask, "%s: the corners of the tile at %s" % [path, cell])


## The pixels of `tile` that lie off the sand tile of `mask`, and (with `exact`) the sand tile's
## pixels that `tile` leaves bare.
func _off_the_sand(tile: Image, sand: Image, mask: int, exact: bool) -> int:
	@warning_ignore("integer_division")
	var origin: Vector2i = Vector2i(mask % SET_COLUMNS, mask / SET_COLUMNS) * TILE
	var count: int = 0
	for y: int in TILE:
		for x: int in TILE:
			var drawn: bool = tile.get_pixel(x, y).a > 0.0
			var in_sand: bool = sand.get_pixel(origin.x + x, origin.y + y).a > 0.0
			if (drawn and not in_sand) or (exact and in_sand and not drawn):
				count += 1
	return count


## Design.md K39: plain.png holds, per terrain row, the tile cut by the sand tile of mask m at
## column m.
func test_each_plain_tile_has_the_outline_of_the_sand_tile_of_its_column() -> void:
	var sand: Image = _sheet(SAND_SHEET)
	var plain: Image = _sheet(PLAIN_SHEET)
	if sand == null or plain == null:
		return
	assert_eq(plain.get_size(), Vector2i((16 + PLAIN_VARIANTS_MAX) * TILE, PLAIN_ROWS * TILE))
	for row: int in PLAIN_ROWS:
		for mask: int in 16:
			var tile: Image = plain.get_region(Rect2i(mask * TILE, row * TILE, TILE, TILE))
			assert_eq(_off_the_sand(tile, sand, mask, true), 0, "plain row %d mask %d" % [row, mask])


## Design.md K39, art-pass "Land edges": on a shore cell an upper layer's tile is cut by the sand
## tile under it, so no bush, dune or rock pixel lies over the sea. The tile at column s, row
## 16 * r + d exists exactly when every corner of d is a corner of s and s has a shore.
func test_no_shore_tile_of_an_upper_layer_leaves_the_sand_under_it() -> void:
	var sand: Image = _sheet(SAND_SHEET)
	if sand == null:
		return
	for id: String in SHORE_SHEETS:
		var sheet: Image = _sheet("res://assets/art/terrain/%s.png" % id)
		if sheet == null:
			continue
		assert_eq(sheet.get_width(), 16 * TILE, id)
		@warning_ignore("integer_division")
		var rows: int = sheet.get_height() / TILE
		assert_eq(rows % 16, 0, "%s: 16 rows per terrain" % id)
		for row: int in rows:
			var own: int = row % 16
			for shore: int in 16:
				var tile: Image = sheet.get_region(Rect2i(shore * TILE, row * TILE, TILE, TILE))
				var expected: bool = shore != 15 and (own & ~shore) == 0
				assert_eq(not tile.is_invisible(), expected, "%s: a tile at column %d, row %d" % [id, shore, row])
				assert_eq(_off_the_sand(tile, sand, shore, false), 0, "%s column %d row %d: pixels off the sand" % [id, shore, row])


## art-pass "No water in land tiles": a recipe that mapped a baked water strip or foam rim to a
## sea or foam colour, instead of keying it out, fails here.
func test_the_corner_sets_hold_no_sea_or_foam_colour() -> void:
	var ramps: Image = _sheet(WATER_RAMPS)
	var foam: Image = _sheet(FOAM_SHEET)
	if ramps == null or foam == null:
		return
	var colors: PackedColorArray = []
	for image: Image in [ramps, foam]:
		for y: int in image.get_height():
			for x: int in image.get_width():
				var color: Color = image.get_pixel(x, y)
				if color.a > 0.0 and not colors.has(color):
					colors.append(color)
	var water: Dictionary = ArtChecks.palette_from_colors(colors)
	assert_gte(water.size(), 13, "three ramps of four and the foam's white")
	for id: String in ["sand", "dune", "brush", "dune_shore", "brush_shore"]:
		var path: String = "res://assets/art/terrain/%s.png" % id
		var sheet: Image = _sheet(path)
		if sheet != null:
			assert_eq(ArtChecks.check_no_water(path, sheet, water), PackedStringArray(), id)


## The picks on row 4 replace the tile of one mask (sand and dune the full tile, brush the
## islet), have that mask's corners and are all different, and none is the mirror of another,
## which would flip the light (design.md K36).
func test_the_variants_on_row_4_have_their_masks_corners_and_differ() -> void:
	var counts: Dictionary[String, int] = {"sand": 4, "dune": 4, "brush": 4}
	var variant_of: Dictionary[String, int] = {"sand": 15, "dune": 15, "brush": 0}
	for id: String in counts:
		var sheet: Image = _sheet("res://assets/art/terrain/%s.png" % id)
		if sheet == null:
			continue
		var seen: Array[PackedByteArray] = []
		for column: int in SET_COLUMNS:
			var tile: Image = sheet.get_region(Rect2i(column * TILE, 4 * TILE, TILE, TILE))
			assert_eq(not tile.is_invisible(), column < counts[id], "%s variant %d" % [id, column])
			if column >= counts[id]:
				continue
			assert_eq(_corners(sheet, Vector2i(column, 4)), variant_of[id], "%s variant %d: its corners" % [id, column])
			assert_false(seen.has(tile.get_data()), "%s variant %d repeats another" % [id, column])
			var mirror: Image = tile.duplicate() as Image
			mirror.flip_x()
			assert_false(seen.has(mirror.get_data()), "%s variant %d is the mirror of another" % [id, column])
			seen.append(tile.get_data())


## The pixels of `tile` other than `fill` with every pixel within three of them drawn (the tile's
## outside counts as drawn): marks well inside the shape, such as a tuft, not its rim.
func _deep_marks(tile: Image, fill: Color) -> int:
	var count: int = 0
	for y: int in TILE:
		for x: int in TILE:
			if tile.get_pixel(x, y).a == 0.0 or tile.get_pixel(x, y) == fill:
				continue
			var deep: bool = true
			for dy: int in range(-3, 4):
				for dx: int in range(-3, 4):
					var at: Vector2i = Vector2i(x + dx, y + dy)
					if Rect2i(0, 0, TILE, TILE).has_point(at) and tile.get_pixel(at.x, at.y).a == 0.0:
						deep = false
			if deep:
				count += 1
	return count


## Design.md K39 (art round 2): a straight dune edge carries no tuft, so a long edge is not a row
## of identical tufts (tufts come from the full-tile picks), and the islet has the pack edge's
## character: a broken outline with gaps and 1-2 px spikes, and one small tuft.
func test_the_dune_edges_carry_no_tuft_and_the_islet_is_ragged() -> void:
	var sheet: Image = _sheet("res://assets/art/terrain/dune.png")
	if sheet == null:
		return
	var fill: Color = sheet.get_pixel(3 * TILE, 3 * TILE)
	for mask: int in [SEA_SOUTH, SEA_EAST, SEA_WEST, SEA_NORTH]:
		var tile: Image = sheet.get_region(Rect2i(_mask_atlas(mask) * TILE, Vector2i(TILE, TILE)))
		assert_eq(_deep_marks(tile, fill), 0, "dune mask %d has no tuft" % mask)
	var islet: Image = sheet.get_region(Rect2i(0, 0, TILE, TILE))
	var tuft: int = _deep_marks(islet, fill)
	assert_true(tuft > 0 and tuft <= 12, "the islet has one small tuft (%d px)" % tuft)
	var notches: int = 0
	var spikes: int = 0
	for y: int in TILE:
		var first: int = -1
		var last: int = -1
		for x: int in TILE:
			if islet.get_pixel(x, y).a > 0.0:
				last = x
				if first < 0:
					first = x
		for x: int in range(first + 1, last):
			if islet.get_pixel(x, y).a == 0.0:
				notches += 1
		for x: int in TILE:
			if islet.get_pixel(x, y).a == 0.0:
				continue
			var clear: int = 0
			for dy: int in range(-1, 2):
				for dx: int in range(-1, 2):
					var at: Vector2i = Vector2i(x + dx, y + dy)
					if not Rect2i(0, 0, TILE, TILE).has_point(at) or islet.get_pixel(at.x, at.y).a == 0.0:
						clear += 1
			if clear >= 5:
				spikes += 1
	assert_gte(notches, 2, "the islet's outline is broken, not a solid ring")
	assert_gte(spikes, 3, "the islet's outline has 1-2 px spikes")


## Design.md K39: a plain row's full-tile variants sit on columns 16 and after, as many as
## `terrain_art.tres` counts for the row; each is a whole tile and none repeats the full tile
## (column 15) or another variant.
func test_the_plain_variants_are_whole_tiles_that_differ_and_match_the_data() -> void:
	var plain: Image = _sheet(PLAIN_SHEET)
	if plain == null:
		return
	var counts: Dictionary[int, int] = TerrainArt.data().plain_variants
	assert_eq(counts.get(0, 0), 3, "the rock has the pack variant and two hand ones")
	@warning_ignore("integer_division")
	var columns: int = plain.get_width() / TILE
	for row: int in PLAIN_ROWS:
		var seen: Array[PackedByteArray] = [plain.get_region(Rect2i(15 * TILE, row * TILE, TILE, TILE)).get_data()]
		for column: int in range(16, columns):
			var tile: Image = plain.get_region(Rect2i(column * TILE, row * TILE, TILE, TILE))
			var expected: bool = column - 16 < counts.get(row, 0)
			assert_eq(not tile.is_invisible(), expected, "plain row %d column %d" % [row, column])
			if not expected:
				continue
			assert_eq(_off_the_sand(tile, _sheet(SAND_SHEET), 15, true), 0, "plain row %d column %d is a whole tile" % [row, column])
			assert_false(seen.has(tile.get_data()), "plain row %d column %d repeats another tile" % [row, column])
			seen.append(tile.get_data())


# --- The rules that pick a tile for a cell (task 4.1; design.md D11, D14, K39, K40) ---

const SANDBAR: IslandLayoutData = preload("res://resources/islands/sandbar.tres")
const COAST_CAY: IslandLayoutData = preload("res://resources/islands/coast_cay.tres")
const TERRAIN_TILES: String = "res://assets/art/terrain/terrain_tiles.tres"
## A full tile, and the brush's islet, are picks on row 4 of their sheet (design.md K36).
const PICK_ROW: int = 4
const ART_SCRIPTS: Array[String] = [
	"res://scripts/art/terrain_art.gd",
	"res://scripts/art/terrain_art_data.gd",
	"res://scripts/art/shore_rule.gd",
	"res://scripts/art/sea_mask.gd",
]


func _mask_atlas(mask: int) -> Vector2i:
	@warning_ignore("integer_division")
	return Vector2i(mask % SET_COLUMNS, mask / SET_COLUMNS)


## The tile `layer` gives the cell `at` of the hand-made `rows` ({} when the cell is not in it).
func _pick(layer: StringName, rows: PackedStringArray, at: Vector2i) -> Dictionary:
	return TerrainArt.tile(layer, at, &"test", TerrainRows.build(rows), TerrainRows.pools(rows))


func _sand_mask(rows: PackedStringArray, at: Vector2i) -> int:
	return TerrainArt.corner_mask(TerrainArt.SAND, at, TerrainRows.build(rows), TerrainRows.pools(rows))


func _assert_pick(tile: Dictionary, source: int, row_four: int, label: String) -> void:
	assert_eq(tile.get(&"source"), source, "%s: source" % label)
	assert_eq(tile.get(&"alternative"), 0, "%s: alternative" % label)
	var atlas: Vector2i = tile.get(&"atlas", Vector2i(-1, -1))
	assert_eq(atlas.y, PICK_ROW, "%s: a pick on row 4" % label)
	assert_true(atlas.x >= 0 and atlas.x < row_four, "%s: one of its %d picks" % [label, row_four])


func test_full_edge_and_outer_corner_tiles() -> void:
	var rows: PackedStringArray = PackedStringArray([".....", ".sss.", ".sss.", ".sss.", "....."])
	assert_eq(_sand_mask(rows, Vector2i(2, 2)), 15, "the middle cell has four land corners")
	_assert_pick(_pick(TerrainArt.SAND, rows, Vector2i(2, 2)), 0, 4, "full tile")
	var edge: Dictionary = _pick(TerrainArt.SAND, rows, Vector2i(2, 3))
	assert_eq(_sand_mask(rows, Vector2i(2, 3)), SEA_SOUTH)
	assert_eq(edge.get(&"source"), 0)
	assert_eq(edge.get(&"atlas"), _mask_atlas(SEA_SOUTH), "the straight south edge")
	var corner: Dictionary = _pick(TerrainArt.SAND, rows, Vector2i(3, 3))
	assert_eq(corner.get(&"atlas"), _mask_atlas(1), "the south-east outer corner has only its NW corner on land")
	assert_eq(_pick(TerrainArt.SAND, rows, Vector2i(0, 0)), {}, "a water cell has no sand tile")


func test_inner_corner_has_water_at_its_north_west() -> void:
	# art-pass "Inner corner"
	var rows: PackedStringArray = PackedStringArray([".ss", "sss", "sss"])
	assert_eq(_sand_mask(rows, Vector2i(1, 1)), 14, "every corner but the NW one is land")
	assert_eq(_pick(TerrainArt.SAND, rows, Vector2i(1, 1)).get(&"atlas"), _mask_atlas(14))


func test_both_diagonal_tiles() -> void:
	var ne_sw: PackedStringArray = PackedStringArray([".ss", "sss", "ss."])
	var nw_se: PackedStringArray = PackedStringArray(["ss.", "sss", ".ss"])
	assert_eq(_sand_mask(ne_sw, Vector2i(1, 1)), 2 + 4)
	assert_eq(_pick(TerrainArt.SAND, ne_sw, Vector2i(1, 1)).get(&"atlas"), _mask_atlas(6))
	assert_eq(_sand_mask(nw_se, Vector2i(1, 1)), 1 + 8)
	assert_eq(_pick(TerrainArt.SAND, nw_se, Vector2i(1, 1)).get(&"atlas"), _mask_atlas(9))


func test_a_lone_land_cell_gets_the_islet_tile() -> void:
	# art-pass "Lone land cell"
	var rows: PackedStringArray = PackedStringArray(["...", ".s.", "..."])
	assert_eq(_sand_mask(rows, Vector2i(1, 1)), 0)
	var tile: Dictionary = _pick(TerrainArt.SAND, rows, Vector2i(1, 1))
	assert_eq(tile.get(&"source"), 0)
	assert_eq(tile.get(&"atlas"), Vector2i(0, 0), "mask 0 is the islet")


func test_a_scrub_cell_inside_dune_gets_the_full_dune_tile_and_the_brush_islet() -> void:
	# art-pass "Scrub inside a dune"
	var rows: PackedStringArray = PackedStringArray(["sssss", "sddds", "sdbds", "sddds", "sssss"])
	var at: Vector2i = Vector2i(2, 2)
	_assert_pick(_pick(TerrainArt.SAND, rows, at), 0, 4, "sand")
	_assert_pick(_pick(TerrainArt.DUNE, rows, at), 1, 4, "dune")
	_assert_pick(_pick(TerrainArt.BRUSH, rows, at), 2, 4, "brush")
	assert_eq(_pick(TerrainArt.BRUSH, rows, Vector2i(2, 1)), {}, "dune is not in the brush layer")
	var terrain: GridTerrain = TerrainRows.build(rows)
	assert_eq(TerrainArt.layer_cells(TerrainArt.SAND, terrain, []).size(), 25, "sand counts every land kind")
	assert_eq(TerrainArt.layer_cells(TerrainArt.DUNE, terrain, []).size(), 9, "dune counts dune and scrub")
	assert_eq(TerrainArt.layer_cells(TerrainArt.BRUSH, terrain, []).size(), 1, "brush counts scrub only")


func test_an_upper_layer_cell_beside_water_takes_the_shore_tile_of_its_sand_mask() -> void:
	# design.md K39: (sand mask, 16 x terrain row + own mask) of the layer's shore source
	var dune: PackedStringArray = PackedStringArray([".....", ".ddd.", ".ddd.", ".ddd.", "....."])
	var tile: Dictionary = _pick(TerrainArt.DUNE, dune, Vector2i(2, 3))
	assert_eq(tile.get(&"source"), 4, "the dune shore source")
	assert_eq(tile.get(&"atlas"), Vector2i(SEA_SOUTH, SEA_SOUTH), "sand mask 3 over own mask 3")
	_assert_pick(_pick(TerrainArt.DUNE, dune, Vector2i(2, 2)), 1, 4, "dune interior")
	var brush: PackedStringArray = PackedStringArray(["...", ".b.", "..."])
	var islet: Dictionary = _pick(TerrainArt.BRUSH, brush, Vector2i(1, 1))
	assert_eq(islet.get(&"source"), 5, "the brush shore source")
	assert_eq(islet.get(&"atlas"), Vector2i(0, 0), "a lone bush: sand mask 0, own mask 0, no variant")
	var rock: PackedStringArray = PackedStringArray([".....", ".rrr.", ".rrr.", ".rrr.", "....."])
	var plain: Dictionary = _pick(TerrainArt.PLAIN, rock, Vector2i(2, 3))
	assert_eq(plain.get(&"source"), 6, "the plain shore source")
	assert_eq(plain.get(&"atlas"), Vector2i(SEA_SOUTH, SEA_SOUTH), "rock is row 0")


func test_a_plain_cell_inland_takes_the_tile_of_its_own_mask() -> void:
	var rows: PackedStringArray = PackedStringArray(["sssss", "srrrs", "srrrs", "srrrs", "sssss"])
	var corner: Dictionary = _pick(TerrainArt.PLAIN, rows, Vector2i(1, 1))
	assert_eq(corner.get(&"source"), 3)
	assert_eq(corner.get(&"atlas"), Vector2i(8, 0), "only its SE corner has four rock cells round it")
	assert_eq(_sand_mask(rows, Vector2i(1, 1)), 15, "the sand under it is whole")
	assert_eq(_pick(TerrainArt.PLAIN, rows, Vector2i(0, 0)), {}, "sand is not in the plain layer")


## Design.md K39: an inland whole plain tile (own mask 15, sand mask 15) takes the full tile or
## one of its row's variants by the cell's hash, the same on every build; an edge or a shore cell
## of the same patch never does.
func test_an_inland_whole_rock_cell_takes_a_variant_by_its_hash() -> void:
	var rows: PackedStringArray = PackedStringArray(["sssssssss"])
	for _y: int in 7:
		rows.append("srrrrrrrs")
	rows.append("sssssssss")
	var terrain: GridTerrain = TerrainRows.build(rows)
	var columns: Dictionary[int, bool] = {}
	for y: int in range(2, 7):
		for x: int in range(2, 7):
			var at: Vector2i = Vector2i(x, y)
			var tile: Dictionary = _pick(TerrainArt.PLAIN, rows, at)
			var atlas: Vector2i = tile.get(&"atlas", Vector2i(-1, -1))
			assert_eq(tile.get(&"source"), 3, "%s: the plain sheet" % at)
			assert_eq(atlas.y, 0, "%s: the rock's row" % at)
			assert_eq(atlas.x, 15 + (TerrainArt.cell_hash(&"test", at) >> 1) % 4, "%s: the full tile or a variant by the hash" % at)
			assert_eq(TerrainArt.tile(TerrainArt.PLAIN, at, &"test", terrain, []), tile, "%s: the same on every build" % at)
			columns[atlas.x] = true
	assert_gt(columns.size(), 2, "25 inland cells show more than two of the four tiles")
	assert_eq(_pick(TerrainArt.PLAIN, rows, Vector2i(1, 4)).get(&"atlas"), Vector2i(10, 0), "an edge cell keeps its own mask")
	var hammock: GridTerrain = GridTerrain.new()
	hammock.default_terrain = DataEnums.Terrain.BEACH
	hammock.fill_rect(Rect2i(1, 1, 3, 3), DataEnums.Terrain.HAMMOCK)
	var whole: Dictionary = TerrainArt.tile(TerrainArt.PLAIN, Vector2i(2, 2), &"test", hammock, [] as Array[Vector2i])
	assert_eq(whole.get(&"atlas"), Vector2i(15, 3), "a row with no variants keeps its full tile")



func test_tide_pool_cells_count_as_land_for_the_sand_layer_only() -> void:
	# design.md T3: the pool is shallows to the grid, land to the art
	var rows: PackedStringArray = PackedStringArray(["sssss", "sssss", "sspss", "sssss", "sssss"])
	var terrain: GridTerrain = TerrainRows.build(rows)
	var pools: Array[Vector2i] = TerrainRows.pools(rows)
	assert_eq(pools, [Vector2i(2, 2)] as Array[Vector2i])
	assert_eq(TerrainArt.corner_mask(TerrainArt.SAND, Vector2i(1, 1), terrain, pools), 15, "no inner corner at the pool")
	assert_eq(TerrainArt.corner_mask(TerrainArt.SAND, Vector2i(1, 1), terrain, []), 7, "without the list it is a water corner")
	assert_true(TerrainArt.is_member(TerrainArt.SAND, Vector2i(2, 2), terrain, pools))
	assert_false(TerrainArt.is_member(TerrainArt.SAND, Vector2i(2, 2), terrain, []))
	assert_false(TerrainArt.is_member(TerrainArt.DUNE, Vector2i(2, 2), terrain, pools), "a pool is not dune")
	assert_eq(terrain.terrain_at(Vector2i(2, 2)), DataEnums.Terrain.SHALLOWS, "the grid is unchanged")


func test_each_land_terrain_has_a_tile_in_the_terrain_art_data() -> void:
	# art-pass "Every terrain kind has a tile"; design.md T4
	var tile_set: TileSet = load(TERRAIN_TILES) as TileSet
	assert_not_null(tile_set)
	var land: int = 0
	for kind: DataEnums.Terrain in DataEnums.Terrain.values():
		if TerrainQuery.is_water(kind):
			continue
		land += 1
		var label: String = DataEnums.Terrain.keys()[kind]
		var terrain: GridTerrain = GridTerrain.new()
		terrain.default_terrain = DataEnums.Terrain.DEEP
		terrain.fill_rect(Rect2i(0, 0, 5, 5), kind)
		var layers: Array[StringName] = TerrainArt.layers_for(kind)
		assert_true(layers.has(TerrainArt.SAND), "%s lies on the sand" % label)
		for layer: StringName in layers:
			for at: Vector2i in [Vector2i(2, 2), Vector2i(2, 4), Vector2i(0, 0)]:
				var tile: Dictionary = TerrainArt.tile(layer, at, &"test", terrain, [] as Array[Vector2i])
				var source: TileSetAtlasSource = tile_set.get_source(tile.get(&"source", -1)) as TileSetAtlasSource if tile_set.has_source(tile.get(&"source", -1)) else null
				assert_not_null(source, "%s on %s at %s has a source" % [label, layer, at])
				if source != null:
					assert_true(source.has_tile(tile[&"atlas"]), "%s on %s at %s: tile %s" % [label, layer, at, tile[&"atlas"]])
	assert_eq(land, 12, "twelve land kinds")


func test_the_three_water_kinds_have_their_own_depth_step() -> void:
	var steps: Array[int] = []
	for kind: DataEnums.Terrain in [DataEnums.Terrain.DEEP, DataEnums.Terrain.SHALLOWS, DataEnums.Terrain.BRACKISH]:
		var step: int = TerrainArt.depth_step(kind)
		assert_true(step >= 0, "%s has a step" % DataEnums.Terrain.keys()[kind])
		assert_false(steps.has(step), "%s repeats a step" % DataEnums.Terrain.keys()[kind])
		steps.append(step)
	assert_eq(TerrainArt.depth_step(DataEnums.Terrain.BEACH), -1, "land has no depth step")


func test_layer_cell_counts_of_the_two_islands() -> void:
	# design.md T12: about 1,800 and 2,000 cells. The sandbar's Sand is T12's 991 plus its 3 tide pools (T3)
	var expected: Dictionary[StringName, Array] = {
		&"sandbar": [994, 422, 84, 0],
		&"coast_cay": [1021, 393, 29, 256],
	}
	var layouts: Dictionary[StringName, IslandLayoutData] = {&"sandbar": SANDBAR, &"coast_cay": COAST_CAY}
	for id: StringName in layouts:
		var built: IslandLayout = IslandLayout.build(layouts[id])
		var layers: Array[StringName] = [TerrainArt.SAND, TerrainArt.DUNE, TerrainArt.BRUSH, TerrainArt.PLAIN]
		for index: int in layers.size():
			assert_eq(TerrainArt.layer_cells(layers[index], built.terrain, built.tide_pools).size(), expected[id][index], "%s: %s" % [id, layers[index]])


## Every layer's tile of every cell of `layout`, by layer and cell.
func _all_tiles(layout: IslandLayoutData) -> Dictionary:
	var built: IslandLayout = IslandLayout.build(layout)
	var found: Dictionary = {}
	for layer: StringName in [TerrainArt.SAND, TerrainArt.DUNE, TerrainArt.BRUSH, TerrainArt.PLAIN]:
		for cell: Vector2i in TerrainArt.layer_cells(layer, built.terrain, built.tide_pools):
			found["%s %s" % [layer, cell]] = TerrainArt.tile(layer, cell, layout.id, built.terrain, built.tide_pools)
	return found


func test_variants_come_from_the_layout_and_the_cell_and_repeat_across_builds() -> void:
	# art-pass "Same layout, same variants"
	for layout: IslandLayoutData in [SANDBAR, COAST_CAY]:
		var first: Dictionary = _all_tiles(layout)
		assert_eq(_all_tiles(layout), first, "%s: two builds agree" % layout.id)
		var picks: Dictionary[Vector2i, bool] = {}
		for key: String in first:
			var atlas: Vector2i = first[key][&"atlas"]
			if atlas.y == PICK_ROW:
				picks[atlas] = true
		assert_gt(picks.size(), 1, "%s: the picks are not all the same tile" % layout.id)
	assert_eq(TerrainArt.cell_hash(&"sandbar", Vector2i(3, 4)), TerrainArt.cell_hash(&"sandbar", Vector2i(3, 4)))
	assert_ne(TerrainArt.cell_hash(&"sandbar", Vector2i(3, 4)), TerrainArt.cell_hash(&"coast_cay", Vector2i(3, 4)), "the layout is part of the seed")
	assert_ne(TerrainArt.cell_hash(&"sandbar", Vector2i(3, 4)), TerrainArt.cell_hash(&"sandbar", Vector2i(4, 3)), "so is the cell")


func test_building_the_art_leaves_the_spawners_next_roll_alone() -> void:
	# art-pass "Same layout, same variants"; design.md D14
	var world: CreatureWorld = CreatureWorld.new()
	world.rng.seed = CreatureSpawner.WORLD_SEED
	var without_art: int = world.rng.randi()
	world.rng.seed = CreatureSpawner.WORLD_SEED
	_all_tiles(SANDBAR)
	_all_tiles(COAST_CAY)
	assert_eq(world.rng.randi(), without_art)
	seed(5)
	var global_roll: int = randi()
	seed(5)
	_all_tiles(SANDBAR)
	assert_eq(randi(), global_roll, "the global generator is untouched too")


func test_the_art_scripts_call_no_random_number_generator() -> void:
	for path: String in ART_SCRIPTS:
		var source: String = FileAccess.get_file_as_string(path)
		assert_false(source.is_empty(), "%s exists" % path)
		for word: String in ["RandomNumberGenerator", "randi", "randf", "shuffle", "pick_random"]:
			assert_false(source.contains(word), "%s calls %s" % [path, word])


func test_a_solo_player_arrives_on_drawn_ground_offline() -> void:
	# one player, no host, no peer: the layout alone says where they land and what is drawn there
	var built: IslandLayout = IslandLayout.build(SANDBAR)
	assert_gt(built.landing_cells().size(), 0)
	for cell: Vector2i in [built.solo_spawn, built.landing_cells()[0]]:
		assert_true(TerrainArt.is_member(TerrainArt.SAND, cell, built.terrain, built.tide_pools), "%s is sand" % cell)
		assert_false(TerrainArt.tile(TerrainArt.SAND, cell, SANDBAR.id, built.terrain, built.tide_pools).is_empty())


func test_the_depth_mask_holds_one_step_per_cell_and_pools_are_shallows() -> void:
	# design.md D12, T3, T4
	var rows: PackedStringArray = PackedStringArray(["..~,", ".s~,", "spss"])
	var terrain: GridTerrain = TerrainRows.build(rows)
	var mask: PackedByteArray = SeaMask.depth_bytes(Vector2i(4, 3), terrain)
	assert_eq(mask.size(), 12)
	assert_eq(mask[0], TerrainArt.depth_step(DataEnums.Terrain.DEEP))
	assert_eq(mask[2], TerrainArt.depth_step(DataEnums.Terrain.SHALLOWS))
	assert_eq(mask[3], TerrainArt.depth_step(DataEnums.Terrain.BRACKISH))
	assert_eq(mask[9], TerrainArt.depth_step(DataEnums.Terrain.SHALLOWS), "a tide pool is shallows")
	assert_eq(mask[5], TerrainArt.depth_step(DataEnums.Terrain.DEEP), "land holds the commonest water step beside it, the lower step on a tie (3 deep, 3 shallows)")
