extends GutTest
## art-pass "Lean-to over the hut" ("Standing in the hut", "Behind the roof"; design.md D15, D18),
## with exactly 1 player, offline, through the game shell: the sandbar's lean-to stands on the
## hut's back edge with its roof over the row north of it; a player on the hut's back row and the
## tarp and driftwood lying there sort in front of it, on the shade decal's cells, and a player one
## tile north of the hut sorts behind the roof; the coast cay's shaded cells get no lean-to. The
## order is read from the tree by Godot's 2D rules (DrawOrder; a headless run renders nothing).

const SHELL_SCENE: PackedScene = preload("res://scenes/shell/game_shell.tscn")
const SETTINGS_PATH: String = "user://test_lean_to_settings.cfg"
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
	if FileAccess.file_exists(SETTINGS_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SETTINGS_PATH))


func _shell() -> GameShell:
	var shell := SHELL_SCENE.instantiate() as GameShell
	shell.settings_path = SETTINGS_PATH
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
