extends GutTest
## art-sprite-polish "Cover over a crouched body" (C8, design D5): a player on a scrub cell is drawn
## with that cell's bush in front of the body. `Look/BushFront` copies the island Brush layer's exact
## tile at `body.cell()` (a whole-cell pick and a fitted shore bush included), shows only the bush's
## front rows, stays at the cell and is drawn after the body sprite; anything sorted in front of the
## player still draws over it. Off scrub, swimming and diving it is hidden. Drawing only.

const SHELL_SCENE: PackedScene = preload("res://scenes/shell/game_shell.tscn")
const ISLAND_SCENE: PackedScene = preload("res://scenes/levels/sandbar_island.tscn")
const TILE: float = 16.0
## The sandbar's inland bushes are lone bushes, drawn with the brush's islet picks on row 4 of its
## sheet (art-terrain-polish C10a puts the whole-cell picks on row 5; the sandbar has no whole cell).
const ISLET_PICK_ROW: int = 4

var settings_path: String = UserTmp.path("test_bush_front_settings.cfg")
var net: NetHarness


func before_each() -> void:
	NetManager.start_solo()
	WeatherManager.stop()
	WeatherManager.sky.start_at(0.0)


func after_each() -> void:
	if net != null:
		net.teardown()
		net = null
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


func _brush(island: Node) -> TileMapLayer:
	return island.get_node(^"Terrain/Brush") as TileMapLayer


func _look(body: PlayerBody) -> PlayerLook:
	return body.get_node(^"Look") as PlayerLook


func _front(body: PlayerBody) -> Sprite2D:
	return body.get_node(^"Look/BushFront") as Sprite2D


# Puts the body in the middle of `cell` (bodies and islands share the world's origin) and draws it.
func _stand(body: PlayerBody, cell: Vector2i, move: MovementStep.Move = MovementStep.Move.WALK) -> void:
	body.position = Vector2(cell) * TILE + Vector2(TILE / 2.0, TILE / 2.0)
	body.movement_state = move
	_look(body).step(0.0)


# The first Brush cell, in the layer's order, whose tile is from `source` on row `row` (-1: any row).
func _brush_cell(brush: TileMapLayer, source: int, row: int) -> Vector2i:
	var cells: Array[Vector2i] = brush.get_used_cells()
	cells.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return a.y < b.y or (a.y == b.y and a.x < b.x))
	for cell: Vector2i in cells:
		if brush.get_cell_source_id(cell) == source and (row < 0 or brush.get_cell_atlas_coords(cell).y == row):
			return cell
	return Vector2i(-1, -1)


func _assert_copies(body: PlayerBody, brush: TileMapLayer, cell: Vector2i, label: String) -> void:
	var front := _front(body)
	assert_true(front.visible, "%s: the bush front shows" % label)
	var source: int = brush.get_cell_source_id(cell)
	var atlas: Vector2i = brush.get_cell_atlas_coords(cell)
	assert_eq(_look(body).bush_tile, [source, atlas, brush.get_cell_alternative_tile(cell)], "%s: the Brush layer's tile at the body's cell" % label)
	assert_same(front.texture, (brush.tile_set.get_source(source) as TileSetAtlasSource).texture, "%s: from its sheet" % label)
	assert_eq(front.region_rect, Rect2(Vector2(atlas) * TILE + Vector2(0.0, PlayerLook.BUSH_FRONT_TOP), Vector2(TILE, PlayerLook.BUSH_FRONT_ROWS)), "%s: only the bush's front rows" % label)
	var cell_top_left: Vector2 = brush.to_global(brush.map_to_local(cell)) - Vector2(TILE, TILE) / 2.0
	assert_eq(front.global_position, cell_top_left + Vector2(0.0, PlayerLook.BUSH_FRONT_TOP), "%s: at the cell, not on the body" % label)
	assert_gt(front.get_index(), _look(body).sprite.get_index(), "%s: drawn after the body sprite" % label)


## One player, offline: crouched on a lone bush (a row-4 pick, by the cell's hash) and standing on a
## fitted shore bush.
func test_a_solo_player_in_scrub_is_drawn_behind_its_bush() -> void:
	var shell := _shell()
	var body := shell.session.body(CoopSession.HOST_ID)
	var brush := _brush(shell.island)
	var art := TerrainArt.data()
	var whole: Vector2i = _brush_cell(brush, art.source_of[TerrainArt.BRUSH], ISLET_PICK_ROW)
	var shore: Vector2i = _brush_cell(brush, art.shore_source_of[TerrainArt.BRUSH], -1)
	assert_ne(whole, Vector2i(-1, -1), "the sandbar has a lone bush on an islet pick")
	assert_ne(shore, Vector2i(-1, -1), "and a shore bush")
	_stand(body, whole, MovementStep.Move.CROUCH)
	_assert_copies(body, brush, whole, "crouched in scrub")
	body.global_position += Vector2(3.0, -2.0)
	_look(body).step(0.0)
	_assert_copies(body, brush, whole, "moved inside the cell, the bush stays")
	_stand(body, shore, MovementStep.Move.WALK)
	_assert_copies(body, brush, shore, "standing on a shore bush")


func test_off_scrub_swimming_or_diving_no_bush_front_shows() -> void:
	var shell := _shell()
	var body := shell.session.body(CoopSession.HOST_ID)
	var brush := _brush(shell.island)
	var whole: Vector2i = _brush_cell(brush, TerrainArt.data().source_of[TerrainArt.BRUSH], ISLET_PICK_ROW)
	var sand: Vector2i = Vector2i(-1, -1)
	for cell: Vector2i in shell.island.terrain.cells:
		if shell.island.terrain.terrain_at(cell) == DataEnums.Terrain.BEACH and brush.get_cell_source_id(cell) < 0:
			sand = cell
			break
	_stand(body, sand)
	assert_false(_front(body).visible, "on sand")
	_stand(body, whole, MovementStep.Move.SWIM)
	assert_false(_front(body).visible, "swimming")
	_stand(body, whole, MovementStep.Move.DIVE)
	assert_false(_front(body).visible, "diving")
	_stand(body, whole, MovementStep.Move.CROUCH)
	assert_true(_front(body).visible, "and back on its feet in scrub")


func test_a_palm_south_of_the_player_still_draws_over_the_bush_front() -> void:
	var shell := _shell()
	var body := shell.session.body(CoopSession.HOST_ID)
	var whole: Vector2i = _brush_cell(_brush(shell.island), TerrainArt.data().source_of[TerrainArt.BRUSH], ISLET_PICK_ROW)
	_stand(body, whole, MovementStep.Move.CROUCH)
	var south: Palm = null
	for node: Node in shell.island.get_node(^"Palms").get_children():
		var palm := node as Palm
		if palm != null and palm.global_position.y > body.global_position.y + TILE and (south == null or palm.global_position.y < south.global_position.y):
			south = palm
	assert_not_null(south, "a palm south of the player")
	if south == null:
		return
	assert_true(DrawOrder.drawn_after(south, _front(body)), "the palm draws over the bush front")
	assert_true(DrawOrder.drawn_after(_front(body), _look(body).sprite), "and the bush front over the body")


# The shell's order on each branch: the island beside the session.
func _setup(session: CoopSession) -> void:
	var island := ISLAND_SCENE.instantiate() as SandbarIsland
	island.with_creatures = false
	island.name = "Island"
	session.get_parent().add_child(island)
	session.terrain = island.terrain
	session.climate = island.climate
	session.spawn_points = island.spawn_points(false)
	island.furnish(session)


func test_host_and_client_show_the_same_bush_in_front_of_the_clients_player() -> void:
	net = NetHarness.new(self)
	var host := net.add_host(_setup)
	var client := await net.join(_setup)
	assert_not_null(client, "the client joined")
	if client == null:
		return
	var id: int = net.peer_id(client)
	var on_host := host.body(id)
	var on_client := client.body(id)
	assert_not_null(on_host)
	assert_not_null(on_client)
	if on_host == null or on_client == null:
		return
	var brush := _brush(host.get_parent().get_node(^"Island"))
	var whole: Vector2i = _brush_cell(brush, TerrainArt.data().source_of[TerrainArt.BRUSH], ISLET_PICK_ROW)
	_stand(on_host, whole)
	_stand(on_client, whole)
	assert_true(_front(on_host).visible and _front(on_client).visible, "both peers show it")
	assert_eq(_look(on_client).bush_tile, _look(on_host).bush_tile, "the same tile")
	assert_eq(_front(on_client).global_position, _front(on_host).global_position, "at the same place")
