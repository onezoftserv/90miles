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


## The most white pixels in any 8x8 patch of a 16x16 foam piece.
func _whitest_patch(piece: Image) -> int:
	var best: int = 0
	for y0: int in TILE - 7:
		for x0: int in TILE - 7:
			var count: int = 0
			for y: int in range(y0, y0 + 8):
				for x: int in range(x0, x0 + 8):
					var pixel: Color = piece.get_pixel(x, y)
					if pixel.a > 0.0 and pixel == Color.WHITE:
						count += 1
			best = maxi(best, count)
	return best


## art-pass "Corner foam is no heavier than a straight run" (art-coast-pass D5, review TR5): today
## an outer corner is a thick white L and an inner corner a near-solid white block (41 to 55 of an
## 8x8 patch's 64 pixels). The corners now wash only the sand's last two steps and fade from the
## second water step where the shore turns, while the straight edges keep their foam.
func test_corner_foam_is_no_heavier_than_a_straight_run() -> void:
	var foam: Image = _sheet(FOAM_SHEET)
	if foam == null:
		return
	var straight: int = 0
	for mask: int in TURNS_TO_SOUTH:
		for frame: int in FOAM_FRAMES:
			straight = maxi(straight, _whitest_patch(foam.get_region(Rect2i(frame * TILE, mask * TILE, TILE, TILE))))
	assert_gt(straight, 0, "the straight edges have white foam")
	for mask: int in 15:
		if TURNS_TO_SOUTH.has(mask):
			continue
		for frame: int in FOAM_FRAMES:
			var patch: int = _whitest_patch(foam.get_region(Rect2i(frame * TILE, mask * TILE, TILE, TILE)))
			assert_lte(patch, straight, "mask %d frame %d: no whiter than a straight edge (%d)" % [mask, frame, straight])
			if mask in [6, 7, 9, 11, 13, 14]:
				assert_lte(patch, 32, "inner corner %d frame %d: at most half white" % [mask, frame])
			elif mask in [1, 2, 4, 8]:
				assert_lte(patch, 36, "outer corner %d frame %d: about half white" % [mask, frame])


## The land corner pixel of each outer corner mask.
const OUTER_CORNER: Dictionary[int, Vector2i] = {1: Vector2i(0, 0), 2: Vector2i(15, 0), 4: Vector2i(0, 15), 8: Vector2i(15, 15)}


## art-pass "Coast corners are rounded" (art-coast-pass D3, review TR2): an outer corner's sand is a
## quarter arc round its land corner, so the pixel half way along the diagonal is sand and the one
## four steps further out is sea (a square block reaches it); an inner corner's bite is rounded, so
## the pixel three in from its water corner on the diagonal is sand (a square notch leaves it sea).
func test_coast_corners_are_rounded() -> void:
	var sand: Image = _sheet(SAND_SHEET)
	if sand == null:
		return
	for mask: int in OUTER_CORNER:
		var corner: Vector2i = OUTER_CORNER[mask]
		var inward: Vector2i = Vector2i(1 if corner.x == 0 else -1, 1 if corner.y == 0 else -1)
		var origin: Vector2i = _mask_atlas(mask) * TILE
		assert_gt(sand.get_pixelv(origin + corner + inward * 7).a, 0.0, "outer corner %d: sand half way along the diagonal" % mask)
		assert_eq(sand.get_pixelv(origin + corner + inward * 10).a, 0.0, "outer corner %d: sea where a square block would be" % mask)
	var water_corner: Dictionary[int, Vector2i] = {14: Vector2i(0, 0), 13: Vector2i(15, 0), 11: Vector2i(0, 15), 7: Vector2i(15, 15)}
	for mask: int in water_corner:
		var corner: Vector2i = water_corner[mask]
		var inward: Vector2i = Vector2i(1 if corner.x == 0 else -1, 1 if corner.y == 0 else -1)
		var origin: Vector2i = _mask_atlas(mask) * TILE
		assert_eq(sand.get_pixelv(origin + corner + inward * 2).a, 0.0, "inner corner %d: its bite" % mask)
		assert_gt(sand.get_pixelv(origin + corner + inward * 3).a, 0.0, "inner corner %d: the bite is rounded, not a square notch" % mask)


## art-pass "Coast corners are rounded": each tile's sand meets the cell's border where its
## neighbour's does, for every pair of masks that can sit side by side (they share the two corners
## on their common border), so no 1 px jog shows where a corner meets a straight edge.
func test_neighbouring_sand_tiles_join_without_a_jog() -> void:
	var sand: Image = _sheet(SAND_SHEET)
	if sand == null:
		return
	for left: int in 16:
		for right: int in 16:
			var a: Vector2i = _mask_atlas(left) * TILE
			var b: Vector2i = _mask_atlas(right) * TILE
			if bool(left & 2) == bool(right & 1) and bool(left & 8) == bool(right & 4):
				for y: int in TILE:
					assert_eq(sand.get_pixel(a.x + 15, a.y + y).a > 0.0, sand.get_pixel(b.x, b.y + y).a > 0.0, "mask %d beside mask %d, row %d" % [left, right, y])
			if bool(left & 4) == bool(right & 1) and bool(left & 8) == bool(right & 2):
				for x: int in TILE:
					assert_eq(sand.get_pixel(a.x + x, a.y + 15).a > 0.0, sand.get_pixel(b.x + x, b.y).a > 0.0, "mask %d above mask %d, column %d" % [left, right, x])


## art-pass "The beach has the same lip on every side" (review TR6): no sand tile but the islet keeps
## the pack's dark south ledge band, and the south edge and every corner end in the 1 px lip colour
## on each sand pixel beside the sea.
func test_the_beach_has_the_same_lip_on_every_side() -> void:
	var sand: Image = _sheet(SAND_SHEET)
	if sand == null:
		return
	var band := Color("#c08a5a")
	var lip := Color("#d9a066")
	for mask: int in range(1, 15):
		var origin: Vector2i = _mask_atlas(mask) * TILE
		for y: int in TILE:
			for x: int in TILE:
				var pixel: Color = sand.get_pixel(origin.x + x, origin.y + y)
				if pixel.a == 0.0:
					continue
				assert_ne(pixel, band, "mask %d (%d, %d): no ledge band" % [mask, x, y])
				if mask in [5, 10, 12]:
					continue
				var beside_sea: bool = false
				for d: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
					var n: Vector2i = Vector2i(x, y) + d
					if Rect2i(0, 0, TILE, TILE).has_point(n) and sand.get_pixelv(origin + n).a == 0.0:
						beside_sea = true
				if beside_sea:
					assert_eq(pixel, lip, "mask %d (%d, %d): the lip beside the sea" % [mask, x, y])


## art-pass "A walkable cell's middle is drawn as land", one player, offline: on the solo sandbar
## every shore cell's sand tile draws, for each land corner of its mask, the centre pixel toward
## that corner (a chamfered corner would leave a tip cell's middle in the sea).
func test_a_solo_sandbar_shore_cell_keeps_its_middle_on_land() -> void:
	var sand: Image = _sheet(SAND_SHEET)
	if sand == null:
		return
	var built: IslandLayout = IslandLayout.build(SANDBAR)
	var toward: Dictionary[int, Vector2i] = {1: Vector2i(7, 7), 2: Vector2i(8, 7), 4: Vector2i(7, 8), 8: Vector2i(8, 8)}
	var checked: int = 0
	for cell: Vector2i in TerrainArt.layer_cells(TerrainArt.SAND, built.terrain, built.tide_pools):
		var mask: int = TerrainArt.corner_mask(TerrainArt.SAND, cell, built.terrain, built.tide_pools)
		if mask == 15:
			continue
		checked += 1
		for bit: int in toward:
			if mask & bit:
				assert_gt(sand.get_pixelv(_mask_atlas(mask) * TILE + toward[bit]).a, 0.0, "%s (mask %d): its middle toward corner %d" % [cell, mask, bit])
	assert_gt(checked, 200, "the sandbar has its shore cells")


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


## The drawn bounding box of `tile` (an empty rect when nothing is drawn).
func _drawn_rect(tile: Image) -> Rect2i:
	var found: Rect2i = Rect2i()
	var any: bool = false
	for y: int in tile.get_height():
		for x: int in tile.get_width():
			if tile.get_pixel(x, y).a > 0.0:
				found = Rect2i(x, y, 1, 1) if not any else found.expand(Vector2i(x, y)).expand(Vector2i(x + 1, y + 1))
				any = true
	return found


## Whether `tile` is `piece` moved whole: the same pixels, every one, with nothing cut or added.
func _is_moved(tile: Image, piece: Image) -> bool:
	var a: Rect2i = _drawn_rect(tile)
	var b: Rect2i = _drawn_rect(piece)
	if a.size != b.size or a.size == Vector2i.ZERO:
		return false
	for y: int in a.size.y:
		for x: int in a.size.x:
			var mine: Color = tile.get_pixel(a.position.x + x, a.position.y + y)
			var theirs: Color = piece.get_pixel(b.position.x + x, b.position.y + y)
			if (mine.a > 0.0) != (theirs.a > 0.0) or (mine.a > 0.0 and mine != theirs):
				return false
	return true


## art-pass "A bush on a shore cell is drawn whole" (art-coast-pass D1, review TR1): a lone bush on
## a shore cell (own mask 0, sand masks 1-14) is the small pick, or the one hand-drawn tuft where
## the pick does not fit, moved whole onto the sand: no pixel cut, no rim. Today's cut bushes fail.
func test_no_shore_bush_pixel_is_cut() -> void:
	var brush: Image = _sheet("res://assets/art/terrain/brush.png")
	var shore: Image = _sheet("res://assets/art/terrain/brush_shore.png")
	if brush == null or shore == null:
		return
	var pick: Image = brush.get_region(Rect2i(1 * TILE, PICK_ROW * TILE, TILE, TILE))
	var tuft: Image = null
	for s: int in range(1, 15):
		var tile: Image = shore.get_region(Rect2i(s * TILE, 0, TILE, TILE))
		if _is_moved(tile, pick):
			continue
		var size: Vector2i = _drawn_rect(tile).size
		assert_true(size.x <= 8 and size.y <= 7 and size != Vector2i.ZERO, "sand mask %d: the pick moved whole, or a tuft of at most 8x7 (drawn %s)" % [s, size])
		if tuft == null:
			tuft = tile
		assert_true(_is_moved(tile, tuft), "sand mask %d: the same tuft as every other mask that needs one" % s)
	var islet: Image = shore.get_region(Rect2i(0, 0, TILE, TILE))
	assert_false(_is_moved(islet, pick), "a lone sand cell (mask 0) keeps the cut bush")


## One player, offline: the owner's spot. Shore scrub cell (20, 35) of the solo sandbar is drawn
## with the brush shore tile of its sand mask, and that tile is all 90 pixels of the small pick.
func test_a_solo_sandbar_shore_bush_is_whole() -> void:
	var built: IslandLayout = IslandLayout.build(SANDBAR)
	var cell: Vector2i = Vector2i(20, 35)
	assert_eq(built.terrain.terrain_at(cell), DataEnums.Terrain.SCRUB, "the owner's spot is scrub")
	var tile: Dictionary = TerrainArt.tile(TerrainArt.BRUSH, cell, SANDBAR.id, built.terrain, built.tide_pools)
	assert_eq(tile.get(&"source"), TerrainArt.data().shore_source_of[TerrainArt.BRUSH], "the brush shore source")
	assert_eq(tile.get(&"atlas"), Vector2i(10, 0), "sand mask 10 (sea to the west), own mask 0")
	var shore: Image = _sheet("res://assets/art/terrain/brush_shore.png")
	var brush: Image = _sheet("res://assets/art/terrain/brush.png")
	if shore == null or brush == null:
		return
	var drawn: Image = shore.get_region(Rect2i(Vector2i(tile[&"atlas"]) * TILE, Vector2i(TILE, TILE)))
	var pick: Image = brush.get_region(Rect2i(1 * TILE, PICK_ROW * TILE, TILE, TILE))
	var count: int = 0
	for y: int in TILE:
		for x: int in TILE:
			if drawn.get_pixel(x, y).a > 0.0:
				count += 1
	assert_eq(count, 90, "every pixel of the small bush")
	assert_true(_is_moved(drawn, pick), "and only the small bush, whole")


## art-terrain-polish TR14: the clear pixels of `tile` that no 4-connected run of clear pixels
## joins to the tile's border, so the ground shows through inside the drawing.
func _enclosed_clear(tile: Image) -> int:
	var size: Vector2i = tile.get_size()
	var seen: Dictionary[Vector2i, bool] = {}
	var todo: Array[Vector2i] = []
	for y: int in size.y:
		for x: int in size.x:
			var edge: bool = x == 0 or y == 0 or x == size.x - 1 or y == size.y - 1
			if edge and tile.get_pixel(x, y).a == 0.0:
				todo.append(Vector2i(x, y))
	while not todo.is_empty():
		var at: Vector2i = todo.pop_back()
		if seen.has(at):
			continue
		seen[at] = true
		for step: Vector2i in [Vector2i.RIGHT, Vector2i.LEFT, Vector2i.DOWN, Vector2i.UP]:
			var next: Vector2i = at + step
			var inside: bool = next.x >= 0 and next.y >= 0 and next.x < size.x and next.y < size.y
			if inside and not seen.has(next) and tile.get_pixel(next.x, next.y).a == 0.0:
				todo.append(next)
	var holes: int = 0
	for y: int in size.y:
		for x: int in size.x:
			if tile.get_pixel(x, y).a == 0.0 and not seen.has(Vector2i(x, y)):
				holes += 1
	return holes


## art-terrain-polish TR14 ("Scrub varies", "No hole in a bush"): every lone-bush pick on row 4 of
## the brush sheet is solid inside its outline.
func test_no_brush_pick_has_a_hole_inside_its_outline() -> void:
	var brush: Image = _sheet("res://assets/art/terrain/brush.png")
	if brush == null:
		return
	for column: int in SET_COLUMNS:
		var pick: Image = brush.get_region(Rect2i(column * TILE, PICK_ROW * TILE, TILE, TILE))
		assert_eq(_enclosed_clear(pick), 0, "brush pick %d has no hole inside its outline" % column)


## One player, offline: every lone bush on the solo sandbar (a brush pick on row 4) is drawn with
## no sand showing through inside it. Reads the sheet's bytes, not a render.
func test_a_solo_sandbar_lone_bush_has_no_hole() -> void:
	var built: IslandLayout = IslandLayout.build(SANDBAR)
	var brush: Image = _sheet("res://assets/art/terrain/brush.png")
	if brush == null:
		return
	var lone: int = 0
	for cell: Vector2i in TerrainArt.layer_cells(TerrainArt.BRUSH, built.terrain, built.tide_pools):
		var tile: Dictionary = TerrainArt.tile(TerrainArt.BRUSH, cell, SANDBAR.id, built.terrain, built.tide_pools)
		var atlas: Vector2i = tile.get(&"atlas", Vector2i(-1, -1))
		if tile.get(&"source") != TerrainArt.data().source_of[TerrainArt.BRUSH] or atlas.y != PICK_ROW:
			continue
		lone += 1
		var drawn: Image = brush.get_region(Rect2i(atlas * TILE, Vector2i(TILE, TILE)))
		assert_eq(_enclosed_clear(drawn), 0, "the lone bush at %s (pick %d) has no hole" % [cell, atlas.x])
	assert_gt(lone, 0, "the sandbar has lone bushes")


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


## Design.md K39 (art round 2): the tide pool is an irregular pool, not a stone-ringed porthole:
## it leaves at least one cell edge bare, holds water in two shades, three or four stones of
## different sizes and a wet-sand lip, with the lip's dark colour under a south stone.
func test_the_tide_pool_is_irregular_with_a_few_stones_and_a_wet_sand_lip() -> void:
	var pool: Image = _sheet("res://assets/art/terrain/tide_pool.png")
	if pool == null:
		return
	var water: Dictionary[Color, bool] = {}
	var stones: Dictionary[Vector2i, bool] = {}
	var lip: Dictionary[Color, int] = {Color.html("#d9a066"): 0, Color.html("#c08a5a"): 0}
	var stone_colors: Array[Color] = [Color.html("#9badb7"), Color.html("#847e87"), Color.html("#696a6a"), Color.html("#595652")]
	var edges: int = 0
	for side: Rect2i in [Rect2i(0, 0, TILE, 1), Rect2i(0, TILE - 1, TILE, 1), Rect2i(0, 0, 1, TILE), Rect2i(TILE - 1, 0, 1, TILE)]:
		if not pool.get_region(side).is_invisible():
			edges += 1
	assert_lt(edges, 4, "the pool does not touch all four cell edges")
	for y: int in TILE:
		for x: int in TILE:
			var color: Color = pool.get_pixel(x, y)
			if color.a == 0.0:
				continue
			if stone_colors.has(color):
				stones[Vector2i(x, y)] = true
			elif lip.has(color):
				lip[color] += 1
			else:
				water[color] = true
	assert_eq(water.size(), 2, "water in two shades")
	for color: Color in lip:
		assert_gt(lip[color], 0, "the lip has %s" % color.to_html(false))
	var sizes: Array[int] = []
	var seen: Dictionary[Vector2i, bool] = {}
	var shadowed: bool = false
	for start: Vector2i in stones:
		if seen.has(start):
			continue
		var size: int = 0
		var todo: Array[Vector2i] = [start]
		seen[start] = true
		while not todo.is_empty():
			var at: Vector2i = todo.pop_back()
			size += 1
			var below: Vector2i = at + Vector2i.DOWN
			if below.y < TILE and pool.get_pixel(below.x, below.y) == Color.html("#c08a5a") and at.y > TILE / 2:
				shadowed = true
			for step: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
				if stones.has(at + step) and not seen.has(at + step):
					seen[at + step] = true
					todo.append(at + step)
		sizes.append(size)
	assert_true(sizes.size() >= 3 and sizes.size() <= 4, "three or four stones, not a ring (%s)" % [sizes])
	sizes.sort()
	for index: int in range(1, sizes.size()):
		assert_ne(sizes[index], sizes[index - 1], "the stones differ in size (%s)" % [sizes])
	assert_true(shadowed, "a south stone has the lip's dark colour under it")


## Design.md K39 (art round 2): a plain row's full tile is seamless, so a field of it shows no
## dash or line on every cell: each colour on its first column or row also appears within
## SEAM_REACH pixels on the opposite edge. The pack's own rock, shingle, cliff, reef flat and
## coral tiles hold a texel or two that meets its match two pixels along. The cliff (a ledge per
## cell: a lit lip on top, a dark foot) and the wreck interior (planks: a board's lit top under the
## seam of the cell above) are bands across the tile, so only their east edge is checked.
const SEAM_REACH: Dictionary[int, int] = {0: 2, 1: 2, 2: 2, 3: 1, 4: 1, 5: 2, 6: 2, 7: 1, 8: 1}
const BANDED_ROWS: Array[int] = [2, 8]


func test_each_plain_full_tile_is_seamless() -> void:
	var plain: Image = _sheet(PLAIN_SHEET)
	if plain == null:
		return
	for row: int in SEAM_REACH:
		var tile: Image = plain.get_region(Rect2i(15 * TILE, row * TILE, TILE, TILE))
		var reach: int = SEAM_REACH[row]
		for i: int in TILE:
			var across: Array[Color] = []
			var down: Array[Color] = []
			for j: int in range(maxi(0, i - reach), mini(TILE, i + reach + 1)):
				across.append(tile.get_pixel(TILE - 1, j))
				down.append(tile.get_pixel(j, TILE - 1))
			assert_true(across.has(tile.get_pixel(0, i)), "plain row %d: (0, %d) meets its colour on the east edge" % [row, i])
			if not BANDED_ROWS.has(row):
				assert_true(down.has(tile.get_pixel(i, 0)), "plain row %d: (%d, 0) meets its colour on the south edge" % [row, i])


func _row_luminance(tile: Image, y: int) -> float:
	var total: float = 0.0
	for x: int in TILE:
		total += ArtChecks.luminance(tile.get_pixel(x, y))
	return total / TILE


## Design.md K39 (art round 2): the cliff reads as a height, not as dark rock: its top row is
## lighter and its bottom row darker than its middle. The wreck interior is long boards, not
## brick paving: whole rows of one colour (the seams and the boards' lit tops) cross the tile,
## and at most one vertical joint breaks a board.
func test_the_cliff_has_a_lit_lip_and_a_dark_foot_and_the_wreck_has_long_boards() -> void:
	var plain: Image = _sheet(PLAIN_SHEET)
	if plain == null:
		return
	var cliff: Image = plain.get_region(Rect2i(15 * TILE, 2 * TILE, TILE, TILE))
	var middle: float = (_row_luminance(cliff, 7) + _row_luminance(cliff, 8)) / 2.0
	assert_gt(_row_luminance(cliff, 0), middle, "the cliff's top row is lit")
	assert_lt(_row_luminance(cliff, TILE - 1), middle, "the cliff's foot is dark")
	var wreck: Image = plain.get_region(Rect2i(15 * TILE, 8 * TILE, TILE, TILE))
	var whole_rows: int = 0
	for y: int in TILE:
		var flat: bool = true
		for x: int in TILE:
			flat = flat and wreck.get_pixel(x, y) == wreck.get_pixel(0, y)
		if flat:
			whole_rows += 1
	assert_gte(whole_rows, 5, "seams and board tops run across the whole tile")
	var joints: int = 0
	for x: int in TILE:
		var dark_run: int = 0
		for y: int in TILE:
			dark_run = dark_run + 1 if ArtChecks.luminance(wreck.get_pixel(x, y)) < ArtChecks.luminance(Color.html("#663931")) else 0
			if dark_run == 4:
				joints += 1
	assert_lte(joints, 1, "at most one board joint in the tile")


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
		# art-terrain-polish C9: with the palms, the dune gains each palm with 3 or 4 dune sides.
		var joined: int = 0
		for palm: Vector2i in built.palms:
			if TerrainArt.is_member(TerrainArt.DUNE, palm, built.terrain, built.tide_pools, built.palms) and not TerrainArt.is_member(TerrainArt.DUNE, palm, built.terrain, built.tide_pools):
				joined += 1
		var dune: int = TerrainArt.layer_cells(TerrainArt.DUNE, built.terrain, built.tide_pools, built.palms).size()
		assert_eq(dune, int(expected[id][1]) + joined, "%s: the dune with its palms" % id)
		if id == &"sandbar":
			assert_eq(dune, 425, "the sandbar's dune with its three palms")
		assert_eq(TerrainArt.layer_cells(TerrainArt.BRUSH, built.terrain, built.tide_pools, built.palms).size(), expected[id][2], "%s: no palm on the brush" % id)


# --- art-terrain-polish C9, TR11: a palm counts for the dune by its neighbours (design D1) ---

## The tile `layer` gives cell `at` of `rows`, or {}, with `palms` as the palm cells (beach `s`).
func _palm_pick(layer: StringName, rows: PackedStringArray, at: Vector2i, palms: Array[Vector2i]) -> Dictionary:
	return TerrainArt.tile(layer, at, &"test", TerrainRows.build(rows), TerrainRows.pools(rows), palms)


func test_a_palm_with_three_or_four_dune_sides_is_on_the_dune_and_never_the_brush() -> void:
	# art-pass "A palm stands in its dune"
	var rows := PackedStringArray([".......", ".ddddd.", ".ddsdd.", ".ddbdd.", ".ddddd.", "......."])
	var palm: Vector2i = Vector2i(3, 2)
	var palms: Array[Vector2i] = [palm]
	var terrain: GridTerrain = TerrainRows.build(rows)
	assert_true(TerrainArt.is_member(TerrainArt.DUNE, palm, terrain, [], palms), "four dune sides")
	assert_false(TerrainArt.is_member(TerrainArt.BRUSH, palm, terrain, [], palms), "never the brush")
	assert_eq(TerrainArt.corner_mask(TerrainArt.DUNE, palm, terrain, [], palms), TerrainArt.FULL, "an enclosed palm is whole dune")
	assert_eq(TerrainArt.corner_mask(TerrainArt.DUNE, Vector2i(2, 2), terrain, [], palms), TerrainArt.FULL, "the dune beside it keeps its corners")
	assert_false(TerrainArt.is_member(TerrainArt.DUNE, palm, terrain, []), "with no palms, today's rule")
	assert_eq(TerrainArt.corner_mask(TerrainArt.DUNE, Vector2i(2, 2), terrain, []), TerrainArt.NW | TerrainArt.SW, "and today's bite")


func test_notch_palms_take_the_dune_edge_tiles() -> void:
	var north := PackedStringArray([".....", ".ddd.", ".dsd.", ".sss.", "....."])
	var west := PackedStringArray([".....", ".sdd.", ".ssd.", ".sdd.", "....."])
	var palms: Array[Vector2i] = [Vector2i(2, 2)]
	var terrain_n: GridTerrain = TerrainRows.build(north)
	var terrain_w: GridTerrain = TerrainRows.build(west)
	assert_eq(TerrainArt.corner_mask(TerrainArt.DUNE, Vector2i(2, 2), terrain_n, [], palms), TerrainArt.NW | TerrainArt.NE, "dune to the north: mask 3")
	assert_eq(TerrainArt.corner_mask(TerrainArt.DUNE, Vector2i(2, 2), terrain_w, [], palms), TerrainArt.NE | TerrainArt.SE, "dune to the east: mask 10")
	assert_eq(_palm_pick(TerrainArt.DUNE, north, Vector2i(2, 2), palms).get(&"atlas"), Vector2i(3, 0), "the north edge tile")


func test_a_palm_out_on_the_beach_is_on_no_upper_layer() -> void:
	var rows := PackedStringArray([".....", ".sss.", ".ssd.", ".sss.", "....."])
	var palms: Array[Vector2i] = [Vector2i(2, 2)]
	assert_eq(_palm_pick(TerrainArt.DUNE, rows, Vector2i(2, 2), palms), {}, "one dune side is not enough")
	assert_eq(_palm_pick(TerrainArt.BRUSH, rows, Vector2i(2, 2), palms), {}, "nor the brush")
	assert_eq(_palm_pick(TerrainArt.SAND, rows, Vector2i(2, 2), palms), _pick(TerrainArt.SAND, rows, Vector2i(2, 2)), "its sand tile is unchanged")


## One player, offline: the sandbar's palms in the dune join it; the coast cay's palms with all
## eight neighbours in the dune take its full tile (found from the layout, so a reshape keeps it).
func test_a_solo_sandbars_palms_stand_in_their_dune() -> void:
	var built: IslandLayout = IslandLayout.build(SANDBAR)
	for palm: Vector2i in [Vector2i(23, 31), Vector2i(23, 36), Vector2i(24, 42)]:
		assert_true(built.palms.has(palm), "%s is a palm" % palm)
		assert_true(TerrainArt.is_member(TerrainArt.DUNE, palm, built.terrain, built.tide_pools, built.palms), "palm %s is on the dune" % palm)
		assert_false(TerrainArt.is_member(TerrainArt.BRUSH, palm, built.terrain, built.tide_pools, built.palms), "palm %s is not on the brush" % palm)
	assert_eq(TerrainArt.corner_mask(TerrainArt.DUNE, Vector2i(23, 31), built.terrain, built.tide_pools, built.palms), 7, "(23, 31): beach at its south-east diagonal")
	var cay: IslandLayout = IslandLayout.build(COAST_CAY)
	for palm: Vector2i in cay.palms:
		var around: int = 0
		for y: int in range(-1, 2):
			for x: int in range(-1, 2):
				if (x != 0 or y != 0) and TerrainArt.is_member(TerrainArt.DUNE, palm + Vector2i(x, y), cay.terrain, cay.tide_pools):
					around += 1
		if around == 8:
			assert_eq(TerrainArt.corner_mask(TerrainArt.DUNE, palm, cay.terrain, cay.tide_pools, cay.palms), TerrainArt.FULL, "cay palm %s is whole dune" % palm)
	# How many cay palms stand inside a dune is the layout's business (coast-cay-reshape may move
	# them); the fixture test above pins the whole-dune rule itself.


# --- art-terrain-polish D9: the dune's inland corners are rounded ("Dune corners are rounded") ---

const DUNE_SHEET: String = "res://assets/art/terrain/dune.png"
## The outer corners (one dune corner) by their dune corner, and the inner corners and saddles by
## their water corners, as a corner of the tile (0 or 15 on each axis).
const DUNE_OUTER: Dictionary[int, Vector2i] = {1: Vector2i(0, 0), 2: Vector2i(15, 0), 4: Vector2i(0, 15), 8: Vector2i(15, 15)}
const DUNE_INNER: Dictionary[int, Array] = {
	7: [Vector2i(15, 15)], 11: [Vector2i(0, 15)], 13: [Vector2i(15, 0)], 14: [Vector2i(0, 0)],
	6: [Vector2i(0, 0), Vector2i(15, 15)], 9: [Vector2i(15, 0), Vector2i(0, 15)],
}
## Today's pack corners sat 19-38 px off the arc; a redrawn corner sits on it.
const DUNE_ARC_SLACK: int = 4
## The straight dune edges cross the cell border 3 px from a water corner, so a bite is 2 px deep
## along the diagonal at most; the pack's mask 7 had 1.
const DUNE_BITE_MIN: int = 2


func _drawn(tile: Image, at: Vector2i) -> bool:
	return tile.get_pixel(at.x, at.y).a > 0.0


## How many pixels of the outer-corner `tile` lie off the quarter ellipse round its dune corner
## `corner` whose semi-axes are the tile's own reach along its two border strips.
func _arc_misfit(tile: Image, corner: Vector2i) -> int:
	var step: Vector2i = Vector2i(1 if corner.x == 0 else -1, 1 if corner.y == 0 else -1)
	var across: int = 0
	while across < TILE and _drawn(tile, Vector2i(corner.x + step.x * across, corner.y)):
		across += 1
	var down: int = 0
	while down < TILE and _drawn(tile, Vector2i(corner.x, corner.y + step.y * down)):
		down += 1
	if across == 0 or down == 0:
		return TILE * TILE
	var misfit: int = 0
	for y: int in TILE:
		for x: int in TILE:
			var u: float = absf(x - corner.x) + 0.5
			var v: float = absf(y - corner.y) + 0.5
			var inside: bool = (u / across) * (u / across) + (v / down) * (v / down) <= 1.0
			if inside != _drawn(tile, Vector2i(x, y)):
				misfit += 1
	return misfit


## How many clear pixels run along the diagonal from the water corner `corner` of `tile`.
func _bite_run(tile: Image, corner: Vector2i) -> int:
	var step: Vector2i = Vector2i(1 if corner.x == 0 else -1, 1 if corner.y == 0 else -1)
	var run: int = 0
	var at: Vector2i = corner
	while at.x >= 0 and at.y >= 0 and at.x < TILE and at.y < TILE and not _drawn(tile, at):
		run += 1
		at += step
	return run


func _dune_tile(sheet: Image, mask: int) -> Image:
	return sheet.get_region(Rect2i(_mask_atlas(mask) * TILE, Vector2i(TILE, TILE)))


func test_the_dune_corners_are_rounded() -> void:
	var sheet: Image = _sheet(DUNE_SHEET)
	if sheet == null:
		return
	for mask: int in DUNE_OUTER:
		var misfit: int = _arc_misfit(_dune_tile(sheet, mask), DUNE_OUTER[mask])
		assert_true(misfit <= DUNE_ARC_SLACK, "dune mask %d is a quarter arc (%d px off)" % [mask, misfit])
	for mask: int in DUNE_INNER:
		for corner: Vector2i in DUNE_INNER[mask]:
			var run: int = _bite_run(_dune_tile(sheet, mask), corner)
			assert_true(run >= DUNE_BITE_MIN, "dune mask %d bites %d px at %s" % [mask, run, corner])


## Two tiles side by side share a border; neighbouring dune tiles meet on it without a jog.
func test_neighbouring_dune_tiles_meet_without_a_jog() -> void:
	var sheet: Image = _sheet(DUNE_SHEET)
	if sheet == null:
		return
	var jogs: Array[String] = []
	for left: int in 16:
		for right: int in 16:
			var beside: bool = bool(left & TerrainArt.NE) == bool(right & TerrainArt.NW) and bool(left & TerrainArt.SE) == bool(right & TerrainArt.SW)
			var below: bool = bool(left & TerrainArt.SW) == bool(right & TerrainArt.NW) and bool(left & TerrainArt.SE) == bool(right & TerrainArt.NE)
			var a: Image = _dune_tile(sheet, left)
			var b: Image = _dune_tile(sheet, right)
			var side: int = 0
			var under: int = 0
			for i: int in TILE:
				if _drawn(a, Vector2i(TILE - 1, i)) != _drawn(b, Vector2i(0, i)):
					side += 1
				if _drawn(a, Vector2i(i, TILE - 1)) != _drawn(b, Vector2i(i, 0)):
					under += 1
			if beside and side > 2:
				jogs.append("%d|%d" % [left, right])
			if below and under > 2:
				jogs.append("%d/%d" % [left, right])
	assert_eq(jogs, [] as Array[String], "dune tiles that can sit side by side meet without a jog")


## One player, offline: every inland dune cell of the sandbar (its tile from the dune's own sheet,
## not the coast's cut dune shore) with a corner or a diagonal mask is drawn rounded, and its four
## corner pixels still say which corners are dune.
func test_a_solo_sandbars_dune_corners_are_rounded() -> void:
	var built: IslandLayout = IslandLayout.build(SANDBAR)
	var sheet: Image = _sheet(DUNE_SHEET)
	if sheet == null:
		return
	var checked: int = 0
	for cell: Vector2i in TerrainArt.layer_cells(TerrainArt.DUNE, built.terrain, built.tide_pools, built.palms):
		var tile: Dictionary = TerrainArt.tile(TerrainArt.DUNE, cell, SANDBAR.id, built.terrain, built.tide_pools, built.palms)
		var atlas: Vector2i = tile.get(&"atlas", Vector2i(-1, -1))
		if tile.get(&"source") != TerrainArt.data().source_of[TerrainArt.DUNE] or atlas.y >= PICK_ROW:
			continue
		var mask: int = atlas.y * SET_COLUMNS + atlas.x
		var drawn: Image = _dune_tile(sheet, mask)
		if DUNE_OUTER.has(mask):
			assert_true(_arc_misfit(drawn, DUNE_OUTER[mask]) <= DUNE_ARC_SLACK, "dune corner at %s (mask %d) is rounded" % [cell, mask])
			checked += 1
		elif DUNE_INNER.has(mask):
			for corner: Vector2i in DUNE_INNER[mask]:
				assert_true(_bite_run(drawn, corner) >= DUNE_BITE_MIN, "dune bite at %s (mask %d)" % [cell, mask])
			checked += 1
		else:
			continue
		assert_eq(_corners(sheet, atlas), mask, "%s: the corner pixels of mask %d" % [cell, mask])
	assert_gt(checked, 0, "the sandbar has inland dune corners")


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


## art-pass "Neighbouring cells are not striped" (art-coast-pass D2, review TR8): the string hash
## alone gave a pick among four equal to its north-east neighbour's 92% of the time and (x, y) always
## equal to (y, x). Through the avalanche the picks of a 16x16 block look random.
func test_neighbouring_picks_are_not_striped() -> void:
	for layout_id: StringName in [&"sandbar", &"coast_cay", &"test"]:
		var same_as_north_east: int = 0
		var mirrored_same: int = 0
		var mirrored_pairs: int = 0
		for y: int in range(1, 17):
			for x: int in 16:
				var seed_value: int = TerrainArt.cell_hash(layout_id, Vector2i(x, y))
				assert_true(seed_value >= 0 and seed_value < 1 << 32, "%s %d,%d: a 32-bit seed" % [layout_id, x, y])
				var pick: int = (seed_value >> 1) % 4
				if pick == (TerrainArt.cell_hash(layout_id, Vector2i(x + 1, y - 1)) >> 1) % 4:
					same_as_north_east += 1
				if x != y:
					mirrored_pairs += 1
					if pick == (TerrainArt.cell_hash(layout_id, Vector2i(y, x)) >> 1) % 4:
						mirrored_same += 1
		assert_lt(same_as_north_east, 256 * 40 / 100, "%s: picks equal to the north-east neighbour's" % layout_id)
		assert_lt(mirrored_same, mirrored_pairs, "%s: (x, y) and (y, x) are not always the same pick" % layout_id)


## One player, offline: the solo sandbar's arrival cells get the same picks on every build, and the
## seed is the documented mix of the string hash, so every peer computes it the same way.
func test_a_solo_sandbar_build_picks_the_same_tiles_twice() -> void:
	var built: IslandLayout = IslandLayout.build(SANDBAR)
	for cell: Vector2i in [built.solo_spawn, built.landing_cells()[0]]:
		for layer: StringName in TerrainArt.layers_for(built.terrain.terrain_at(cell)):
			var first: Dictionary = TerrainArt.tile(layer, cell, SANDBAR.id, built.terrain, built.tide_pools)
			var again: IslandLayout = IslandLayout.build(SANDBAR)
			assert_eq(TerrainArt.tile(layer, cell, SANDBAR.id, again.terrain, again.tide_pools), first, "%s on %s" % [cell, layer])
	# murmur3's fmix32 of 0x12345678, worked by hand: pins the mix, not just its determinism.
	assert_eq(TerrainArt.mix32(0x12345678), 0xe37cd1bc)
	assert_eq(TerrainArt.mix32(0), 0)


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
