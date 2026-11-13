extends GutTest
## art-pass "Foam meets the sand" on the made art (task 4.4; design.md D11, D13, K35, K37): the
## straight foam edge starts on the row after the straight sand tile's last sand row, with no gap
## and no second foam line. The PNGs are read from their bytes, so the check needs no import.
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
## Frame 0 is the foam at rest on the sand's edge; over the cycle the wash climbs at most this many
## rows onto the sand and falls back at most this many rows from it.
const REST_FRAME: int = 0
const WASH_ROWS: int = 2
## The sand's side edges are wavy and the foam is lace: on one line the foam may start one pixel
## after the pixel next to the sand, never further.
const LACE_GAP: int = 1


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


func test_the_straight_foam_edge_starts_on_the_row_after_the_sand_ends() -> void:
	var sand: Image = _sheet(SAND_SHEET)
	var foam: Image = _sheet(FOAM_SHEET)
	if sand == null or foam == null:
		return
	for mask: int in [SEA_SOUTH, SEA_NORTH]:
		var sand_rows: Array[int] = _rows(_sand(sand, mask))
		var foam_rows: Array[int] = _rows(_foam(foam, mask, REST_FRAME))
		assert_false(sand_rows.is_empty() or foam_rows.is_empty(), "mask %d has sand and foam" % mask)
		if sand_rows.is_empty() or foam_rows.is_empty():
			continue
		assert_eq(sand_rows[0], 0, "mask %d: the sand starts at the land side" % mask)
		assert_eq(foam_rows[0], sand_rows[-1] + 1, "mask %d: the foam starts where the sand ends" % mask)
		assert_eq(foam_rows.size(), foam_rows[-1] - foam_rows[0] + 1, "mask %d: one foam line, no empty row in it" % mask)
		assert_eq(foam_rows[-1], TILE - 1, "mask %d: the foam runs on to the sea side" % mask)


func test_on_every_straight_edge_the_foam_follows_the_sand_line_by_line() -> void:
	var sand: Image = _sheet(SAND_SHEET)
	var foam: Image = _sheet(FOAM_SHEET)
	if sand == null or foam == null:
		return
	for mask: int in TURNS_TO_SOUTH:
		var sand_tile: Image = _sand(sand, mask)
		var foam_tile: Image = _foam(foam, mask, REST_FRAME)
		for x: int in TILE:
			var sand_end: int = _column_end(sand_tile, x, true)
			var foam_start: int = _column_end(foam_tile, x, false)
			assert_ne(sand_end, -1, "mask %d line %d has sand" % [mask, x])
			assert_ne(foam_start, -1, "mask %d line %d has foam" % [mask, x])
			assert_gt(foam_start, sand_end, "mask %d line %d: no foam over the sand" % [mask, x])
			assert_lte(foam_start, sand_end + 1 + LACE_GAP, "mask %d line %d: no gap" % [mask, x])


func test_the_wash_stays_by_the_sand_edge_in_every_frame() -> void:
	var sand: Image = _sheet(SAND_SHEET)
	var foam: Image = _sheet(FOAM_SHEET)
	if sand == null or foam == null:
		return
	for mask: int in [SEA_SOUTH, SEA_NORTH]:
		var sand_rows: Array[int] = _rows(_sand(sand, mask))
		if sand_rows.is_empty():
			fail_test("mask %d has no sand" % mask)
			continue
		var rest_row: int = sand_rows[-1] + 1
		for frame: int in FOAM_FRAMES:
			var foam_rows: Array[int] = _rows(_foam(foam, mask, frame))
			assert_false(foam_rows.is_empty(), "mask %d frame %d has foam" % [mask, frame])
			if foam_rows.is_empty():
				continue
			assert_between(foam_rows[0], rest_row - WASH_ROWS, rest_row + WASH_ROWS, "mask %d frame %d" % [mask, frame])
