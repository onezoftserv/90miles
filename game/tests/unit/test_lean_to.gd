extends GutTest
## art-pass "Lean-to over the hut" ("Standing in the hut", "Behind the roof"; design.md D15, D18),
## with exactly 1 player, offline, through the game shell: the sandbar's lean-to stands on the
## hut's back edge with its roof over the row north of it; a player on the hut's back row and the
## tarp and driftwood lying there sort in front of it, on the shade decal's cells, and a player one
## tile north of the hut sorts behind the roof; the coast cay's shaded cells get no lean-to. The
## order is read from the tree by Godot's 2D rules (DrawOrder; a headless run renders nothing).

const SHELL_SCENE: PackedScene = preload("res://scenes/shell/game_shell.tscn")
var settings_path: String = UserTmp.path("test_lean_to_settings.cfg")
const LEAN_TO_PATH: String = "res://scenes/art/lean_to.tscn"
## The node SandbarIsland places its shelter as.
const SHELTER: NodePath = ^"Shelter"
const TILE: float = 16.0
const COAST: StringName = &"coast_cay"
const HUT_ITEMS: Array[StringName] = [&"tarp", &"driftwood"]


func before_each() -> void:
	NetManager.start_solo()
	WeatherManager.stop()
	WeatherManager.sky.start_at(0.0)


func after_each() -> void:
	WeatherManager.stop()
	NetManager.leave()
	if FileAccess.file_exists(settings_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(settings_path))


func _shell() -> GameShell:
	var shell := SHELL_SCENE.instantiate() as GameShell
	shell.settings_path = settings_path
	add_child_autofree(shell)
	(shell.screen as TitleScreen).solo_requested.emit()
	shell.session.body(CoopSession.HOST_ID).player_input.enabled = false
	return shell


func _cell_of(at: Vector2) -> Vector2i:
	return Vector2i(floori(at.x / TILE), floori(at.y / TILE))


# The hut's back row: the northmost row of its cells.
func _back_row(hut: Array[Vector2i]) -> int:
	var row: int = hut[0].y
	for cell: Vector2i in hut:
		row = mini(row, cell.y)
	return row


# The hut's cells on its back row, west to east.
func _back_cells(hut: Array[Vector2i]) -> Array[Vector2i]:
	var row: int = _back_row(hut)
	var cells: Array[Vector2i] = []
	for cell: Vector2i in hut:
		if cell.y == row:
			cells.append(cell)
	cells.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return a.x < b.x)
	return cells


# The hut's middle in x, in island pixels: the lean-to is centred on it.
func _hut_centre_x(hut: Array[Vector2i]) -> float:
	var west: int = hut[0].x
	var east: int = hut[0].x
	for cell: Vector2i in hut:
		west = mini(west, cell.x)
		east = maxi(east, cell.x)
	return (west + east + 1) * TILE / 2.0


func _lean_to(island: SandbarIsland) -> Sprite2D:
	return island.get_node_or_null(SHELTER) as Sprite2D


func test_the_lean_to_stands_on_the_hut_back_edge_with_its_roof_over_the_row_north() -> void:
	var shell := _shell()
	var island := shell.island
	var hut := island.built.hut_cells
	assert_false(hut.is_empty(), "the sandbar has a hut")
	var lean_to := _lean_to(island)
	assert_not_null(lean_to, "the sandbar's shelter is placed as %s" % SHELTER)
	if lean_to == null or hut.is_empty():
		return
	assert_eq(lean_to.scene_file_path, LEAN_TO_PATH, "the shelter shelter_art.tres names for the sandbar")
	assert_true(lean_to.is_in_group(&"art_view"), "drawing only")
	assert_same(lean_to.get_parent(), island, "it sorts with the island's palms and the session")
	var back_edge: float = _back_row(hut) * TILE
	assert_eq(lean_to.position, Vector2(_hut_centre_x(hut), back_edge), "origin on the hut's back edge, centred on the hut")
	var rect: Rect2 = lean_to.get_rect()
	assert_eq(lean_to.position.y + rect.end.y, back_edge, "the frame stands on the back edge")
	assert_lte(lean_to.position.y + rect.position.y, back_edge - TILE, "the roof rises over the row north of the hut")


func test_a_solo_player_in_the_hut_and_its_tarp_and_driftwood_sort_in_front_on_the_shade() -> void:
	var shell := _shell()
	var island := shell.island
	var hut := island.built.hut_cells
	var lean_to := _lean_to(island)
	assert_not_null(lean_to, "the sandbar's lean-to")
	if lean_to == null:
		return
	var body := shell.session.body(CoopSession.HOST_ID)
	var back_cells := _back_cells(hut)
	var spot: Vector2i = back_cells[back_cells.size() / 2]
	body.global_position = IslandLayout.cell_center(spot)
	assert_true(island.terrain.shaded.has(_cell_of(body.global_position)), "the player stands on the shade")
	assert_true(DrawOrder.drawn_after(body, lean_to), "the player on the back row is drawn in front of the lean-to")
	var found: Dictionary[StringName, int] = {}
	for node: Node in shell.session.get_node(^"Pickups").get_children():
		var item := node as WorldItem
		if item == null or not HUT_ITEMS.has(item.item_id) or not hut.has(_cell_of(item.global_position)):
			continue
		found[item.item_id] = found.get(item.item_id, 0) + 1
		assert_eq(_cell_of(item.global_position).y, _back_row(hut), "%s lies on the back row" % item.item_id)
		assert_true(island.terrain.shaded.has(_cell_of(item.global_position)), "%s on the shade" % item.item_id)
		assert_true(DrawOrder.drawn_after(item, lean_to), "%s is drawn in front of the lean-to" % item.item_id)
	assert_eq(found.get(&"tarp", 0), 1, "the hut's tarp")
	assert_eq(found.get(&"driftwood", 0), 2, "both driftwood")


func test_a_solo_player_one_tile_north_of_the_hut_sorts_behind_the_roof() -> void:
	var shell := _shell()
	var island := shell.island
	var lean_to := _lean_to(island)
	assert_not_null(lean_to, "the sandbar's lean-to")
	if lean_to == null:
		return
	var body := shell.session.body(CoopSession.HOST_ID)
	var back_cells := _back_cells(island.built.hut_cells)
	var north: Vector2i = back_cells[back_cells.size() / 2] + Vector2i.UP
	assert_false(island.built.hut_cells.has(north), "north of the hut")
	body.global_position = IslandLayout.cell_center(north)
	assert_true(DrawOrder.drawn_after(lean_to, body), "the roof is drawn over the player")
	assert_true(lean_to.get_rect().has_point(body.global_position - lean_to.global_position), "and covers where they stand")


func test_the_coast_cay_shaded_cells_get_no_lean_to() -> void:
	var shell := _shell()
	shell.travel.travel(COAST)
	await wait_process_frames(2)
	var island := shell.island
	assert_eq(island.layout.id, COAST)
	assert_false(island.built.hut_cells.is_empty(), "the cay has shaded cells (its watch post)")
	assert_null(ShelterArtData.standard().shelter_for(COAST), "no shelter named for the cay")
	assert_null(_lean_to(island), "no shelter placed")
	for node: Node in island.find_children("*", "", true, false):
		assert_ne(node.scene_file_path, LEAN_TO_PATH, "no lean-to anywhere on the cay")

# --- art-prop-polish D5: a frond shelter, its post shadows and the hut's shade ------------------

## The roof band: the frame's top rows, where only the roof is drawn.
const ROOF_BAND_ROWS: int = 16
## D5's slight sag in the ridge: the most the roof's top may vary across its width.
const RIDGE_SAG_PX: int = 2
## The structures' dark tones: the back wall and the outline, never the thatch.
const DARK_TONES: PackedStringArray = ["222034", "45283c", "323c39"]
## The hut-shade rows of decals/shade.png (TerrainView.HUT_SHADE_ROW): one corner set per depth band.
const HUT_SHADE_ROW: int = 5
const SHADE_SOURCE: int = 1


func _frame() -> Image:
	var lean_to := (load(LEAN_TO_PATH) as PackedScene).instantiate() as Sprite2D
	var image: Image = ArtChecks.read_png(lean_to.texture.resource_path)
	lean_to.free()
	return image


func _opaque(image: Image, x: int, y: int) -> bool:
	return image.get_pixel(x, y).a > 0.0


# The posts: runs of columns of wood on the frame's second-last row (its last is outline), as
# (first, last) x. The back wall and the outline are dark tones, never wood.
func _posts(image: Image) -> Array[Vector2i]:
	var posts: Array[Vector2i] = []
	var row: int = image.get_height() - 2
	for x: int in image.get_width():
		var pixel: Color = image.get_pixel(x, row)
		if pixel.a == 0.0 or DARK_TONES.has(pixel.to_html(false)):
			continue
		if not posts.is_empty() and posts[-1].y == x - 1:
			posts[-1].y = x
		else:
			posts.append(Vector2i(x, x))
	return posts


## A closed roof (D5, the spec's "A closed roof"): every column of the roof's width, the columns with
## any pixel in the roof band, is opaque from its top down through the band, and the tops differ by
## no more than the ridge's sag. A stepped corner fails: its outer columns start rows lower, and
## the transparent step between them lies inside the roof's outline.
func test_the_lean_to_frame_is_64x48_with_a_closed_roof() -> void:
	var image := _frame()
	assert_eq(image.get_size(), Vector2i(64, 48), "the same 64x48 frame")
	var tops: Array[int] = []
	var holes: Array[String] = []
	for x: int in image.get_width():
		var top: int = -1
		for y: int in ROOF_BAND_ROWS:
			if _opaque(image, x, y):
				top = y
				break
		if top < 0:
			continue
		tops.append(top)
		for y: int in range(top, ROOF_BAND_ROWS):
			if not _opaque(image, x, y):
				holes.append("(%d, %d)" % [x, y])
	assert_gt(tops.size(), 56, "the roof spans the frame")
	assert_lte(tops.max() - tops.min(), RIDGE_SAG_PX, "closed top corners: the roof's top varies by the sag only (%d to %d)" % [tops.min(), tops.max()])
	assert_eq(holes, [] as Array[String], "no transparent pixel inside the roof")


## A ragged eave: between the posts, each column's lowest thatch pixel (the lowest that is not a dark
## tone of the back wall or the outline) is not on one row; frond tips hang 2 to 4 px below the eave.
func test_the_lean_to_eave_is_ragged_with_frond_tips_hanging_2_to_4_px() -> void:
	var image := _frame()
	var posts := _posts(image)
	assert_eq(posts.size(), 2, "two posts reach the ground: %s" % [posts])
	if posts.size() != 2:
		return
	var lows: Array[int] = []
	for x: int in range(posts[0].y + 1, posts[1].x):
		var low: int = -1
		for y: int in image.get_height():
			var pixel: Color = image.get_pixel(x, y)
			if pixel.a > 0.0 and not DARK_TONES.has(pixel.to_html(false)):
				low = y
		lows.append(low)
	var line: int = lows.min()
	var tips: int = 0
	for index: int in lows.size():
		if lows[index] >= line + 2 and (index == 0 or lows[index - 1] < line + 2):
			tips += 1
	assert_between(lows.max() - line, 2, 4, "the tips hang 2 to 4 px below the eave line (row %d)" % line)
	assert_gte(tips, 3, "at least three separate tips: %s" % [lows])


func test_each_lean_to_post_has_a_contact_shadow_behind_it() -> void:
	var lean_to := (load(LEAN_TO_PATH) as PackedScene).instantiate() as Sprite2D
	add_child_autofree(lean_to)
	var posts := _posts(_frame())
	assert_eq(posts.size(), 2, "two posts")
	var shadows: Array[DropShadow] = []
	for child: Node in lean_to.get_children():
		if child is DropShadow:
			shadows.append(child as DropShadow)
	assert_eq(shadows.size(), posts.size(), "a shadow per post")
	for post: Vector2i in posts:
		var foot_x: float = (post.x + post.y + 1) / 2.0 + lean_to.offset.x
		var found: DropShadow = null
		for shadow: DropShadow in shadows:
			if absf(shadow.position.x - foot_x) <= 1.0:
				found = shadow
		assert_not_null(found, "a shadow under the post at x %.1f" % foot_x)
		if found == null:
			continue
		assert_between(found.position.y, -2.0, 0.0, "at the post's foot, on the back edge")
		assert_true(found.show_behind_parent, "drawn under the post, not over its foot")
		assert_true(found.visible)


## The 1-player test of art-prop-polish 5.1: on the sandbar built for one offline player, all 12
## shaded cells have a shade decal whose alpha is highest on its north rows; walked down each of the
## hut's columns the shade never darkens going south, and its first row under the roof is darkest.
func test_on_the_solo_sandbar_the_hut_shade_is_darkest_under_the_roof_and_fades_south() -> void:
	var shell := _shell()
	await wait_physics_frames(2)
	var island := shell.island
	var hut := island.built.hut_cells
	assert_eq(hut.size(), 12, "the sandbar's 12 shaded hut cells")
	var decals := island.get_node_or_null(^"Terrain/Decals") as TileMapLayer
	assert_not_null(decals, "the decal layer")
	if decals == null:
		return
	var source := decals.tile_set.get_source(SHADE_SOURCE) as TileSetAtlasSource
	var sheet: Image = ArtChecks.read_png(source.texture.resource_path)
	var west: int = hut[0].x
	var east: int = hut[0].x
	for cell: Vector2i in hut:
		west = mini(west, cell.x)
		east = maxi(east, cell.x)
	for x: int in range(west, east + 1):
		var walk: Array[int] = []
		for y: int in range(_back_row(hut), _back_row(hut) + 3):
			var cell := Vector2i(x, y)
			assert_eq(decals.get_cell_source_id(cell), SHADE_SOURCE, "%s has a shade decal" % cell)
			var atlas: Vector2i = decals.get_cell_atlas_coords(cell)
			assert_true(source.has_tile(atlas), "%s: its tile %s exists" % [cell, atlas])
			assert_gte(atlas.y, HUT_SHADE_ROW, "%s takes the hut shade" % cell)
			if not source.has_tile(atlas):
				continue
			var tile: Image = sheet.get_region(Rect2i(atlas * 16, Vector2i(16, 16)))
			var rows: Array[int] = []
			for row: int in 16:
				rows.append(tile.get_pixel(8, row).a8)
			assert_eq(rows.max(), rows[0], "%s: highest on its north row" % cell)
			walk.append_array(rows)
		var sorted_walk: Array[int] = walk.duplicate()
		sorted_walk.sort()
		sorted_walk.reverse()
		assert_eq(walk, sorted_walk, "column %d: never darker going south" % x)
		assert_eq(walk.max(), walk[0], "column %d: darkest on the hut's north edge" % x)
