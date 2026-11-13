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
	assert_eq(plain.get_size(), Vector2i(16 * TILE, PLAIN_ROWS * TILE))
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
## islet), have that mask's corners and are all different (design.md K36).
func test_the_variants_on_row_4_have_their_masks_corners_and_differ() -> void:
	var counts: Dictionary[String, int] = {"sand": 4, "dune": 4, "brush": 2}
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
			seen.append(tile.get_data())
