extends GutTest
## art-pass "Terrain tile layers", "Land edges", "Tide pools and contact shade" and "Drawing never
## changes the simulation" through the island's TerrainView (task 4.3; design.md D11, D13, D15, T3,
## T12, T14, K39): a host and a client on the net harness build every layer cell alike, no land cell
## is left empty, building leaves the grid as it was, no tile set can block, a solo player walks
## across tile edges, pools and palm bases get their decals, rock and dune shores get their layer's
## shore tiles, and the build of both islands is timed and bounded.

const ISLAND_SCENE: PackedScene = preload("res://scenes/levels/sandbar_island.tscn")
const SHELL_SCENE: PackedScene = preload("res://scenes/shell/game_shell.tscn")
const SANDBAR: IslandLayoutData = preload("res://resources/islands/sandbar.tres")
const COAST_CAY: IslandLayoutData = preload("res://resources/islands/coast_cay.tres")
const SETTINGS_PATH: String = "user://test_terrain_view_settings.cfg"
const VIEW_NAME: NodePath = ^"Terrain"
const TILE: float = 16.0
## design.md D15: every layer the view builds and its z_index.
const LAYER_Z: Dictionary[StringName, int] = {
	&"Sea": -40, &"Sand": -30, &"Dune": -29, &"Plain": -27, &"Shore": -26, &"Brush": -25, &"Decals": -10,
}
const TILE_LAYERS: Array[StringName] = [&"Sand", &"Dune", &"Plain", &"Shore", &"Brush", &"Decals"]
const LAND_LAYERS: Array[StringName] = [&"Sand", &"Dune", &"Brush", &"Plain"]
const SEA_SHADER: String = "res://scenes/art/sea/world_sea.gdshader"
const SHORE_SHADER: String = "res://scenes/art/sea/shore.gdshader"
## Decal sources (design.md K36): the tide pool, and the shade set whose row 4 holds the palm's foot.
const POOL_SOURCE: int = 0
const SHADE_SOURCE: int = 1
const PALM_SHADE: Vector2i = Vector2i(0, 4)
## The two halves of the wide spot shade on row 4, under the raft site (design.md K39).
const WIDE_WEST: Vector2i = Vector2i(1, 4)
const WIDE_EAST: Vector2i = Vector2i(2, 4)
## The bound on one island's layer build (design.md T12); about 300 ms on the dev laptop.
const BUILD_BOUND_MS: float = 1500.0
## Frames a one-tile walk may take at walking speed, with room to spare.
const WALK_FRAMES: int = 240

var net: NetHarness


func before_each() -> void:
	WeatherManager.stop()
	WeatherManager.sky.start_at(0.0)


func after_each() -> void:
	if net != null:
		net.teardown()
		net = null
	WeatherManager.stop()
	NetManager.leave()
	if FileAccess.file_exists(SETTINGS_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SETTINGS_PATH))


func _island(layout: IslandLayoutData) -> SandbarIsland:
	var island := ISLAND_SCENE.instantiate() as SandbarIsland
	island.layout = layout
	island.with_creatures = false
	add_child_autofree(island)
	return island


func _view(island: Node) -> TerrainView:
	return island.get_node_or_null(VIEW_NAME) as TerrainView


func _layer(island: Node, layer: StringName) -> TileMapLayer:
	var view := _view(island)
	return null if view == null else view.get_node_or_null(NodePath(layer)) as TileMapLayer


# Every set cell of `layer` as cell -> [source, atlas, alternative].
func _cells(island: Node, layer: StringName) -> Dictionary:
	var found: Dictionary = {}
	var tiles := _layer(island, layer)
	if tiles == null:
		return found
	for cell: Vector2i in tiles.get_used_cells():
		found[cell] = [tiles.get_cell_source_id(cell), tiles.get_cell_atlas_coords(cell), tiles.get_cell_alternative_tile(cell)]
	return found


func _tile_at(island: Node, layer: StringName, cell: Vector2i) -> Array:
	var tiles := _layer(island, layer)
	if tiles == null:
		return []
	return [tiles.get_cell_source_id(cell), tiles.get_cell_atlas_coords(cell), tiles.get_cell_alternative_tile(cell)]


func _as_list(tile: Dictionary) -> Array:
	return [] if tile.is_empty() else [tile[&"source"], tile[&"atlas"], tile[&"alternative"]]


func _is_land(terrain: GridTerrain, cell: Vector2i) -> bool:
	return not TerrainQuery.is_water(terrain.terrain_at(cell))


# --- host and client ----------------------------------------------------------------------------

# The shell's order on each branch: the island beside the session, its ground and spawn points.
func _setup(session: CoopSession) -> void:
	var island := ISLAND_SCENE.instantiate() as SandbarIsland
	island.with_creatures = false
	island.name = "Island"
	session.get_parent().add_child(island)
	session.terrain = island.terrain
	session.climate = island.climate
	session.spawn_points = island.spawn_points(false)
	island.furnish(session)


func test_host_and_client_draw_the_same_island() -> void:
	net = NetHarness.new(self)
	var host := net.add_host(_setup)
	var client := await net.join(_setup)
	assert_not_null(client, "the client joined")
	if client == null:
		return
	var host_island: Node = host.get_parent().get_node(^"Island")
	var client_island: Node = client.get_parent().get_node(^"Island")
	assert_not_null(_view(host_island), "the host's island has a TerrainView")
	assert_not_null(_view(client_island), "the client's island has a TerrainView")
	if _view(host_island) == null or _view(client_island) == null:
		return
	for layer: StringName in TILE_LAYERS:
		var on_host: Dictionary = _cells(host_island, layer)
		var on_client: Dictionary = _cells(client_island, layer)
		assert_eq(on_client.size(), on_host.size(), "%s: as many cells on both peers" % layer)
		var differ: int = 0
		for cell: Vector2i in on_host:
			if on_client.get(cell, []) != on_host[cell]:
				differ += 1
		assert_eq(differ, 0, "%s: every cell has the same source, atlas and alternative" % layer)
	assert_eq(_view(client_island).phase_bytes, _view(host_island).phase_bytes, "the same phase mask")
	assert_eq(_view(client_island).depth_bytes, _view(host_island).depth_bytes, "the same depth mask")
	assert_gt(_view(host_island).phase_bytes.size(), 0, "the phase mask is built")


# --- the layers ---------------------------------------------------------------------------------

func test_the_view_has_the_layers_of_d15_at_their_z() -> void:
	var island := _island(SANDBAR)
	var view := _view(island)
	assert_not_null(view, "the island has a TerrainView named Terrain")
	if view == null:
		return
	assert_true(view.is_in_group(&"art_view"), "the view is art")
	for layer: StringName in LAYER_Z:
		var node := view.get_node_or_null(NodePath(layer)) as CanvasItem
		assert_not_null(node, String(layer))
		if node != null:
			assert_eq(node.z_index, LAYER_Z[layer], "%s z" % layer)
			assert_true(node.z_as_relative, "%s z is relative to the view at 0" % layer)
	assert_eq(view.z_index, 0)
	var sea := view.get_node_or_null(^"Sea") as CanvasItem
	var shore := _layer(island, &"Shore")
	if sea != null and shore != null:
		assert_eq(((sea.material as ShaderMaterial).shader as Shader).resource_path, SEA_SHADER)
		assert_eq(((shore.material as ShaderMaterial).shader as Shader).resource_path, SHORE_SHADER)


# The sea scenarios of "Scrolling sea" that can run without a window. That the drawn pixels of a
# shallows cell are lighter than a deep cell's, as the eye sees them, is covered by task 4.6's capture.
func test_the_sea_shader_runs_on_the_shader_clock_and_reads_the_mask() -> void:
	var source: String = SeaShaderChecks.source()
	assert_true(RegEx.create_from_string("\\bTIME\\b").search(source) != null, "the sea reads TIME, so it moves with nothing simulated")
	for texture: String in ["depth_mask", "water", "ramps"]:
		assert_true(RegEx.create_from_string("uniform\\s+sampler2D\\s+%s\\b" % texture).search(source) != null, "%s is a uniform texture" % texture)
	var fragment: String = source.substr(source.find("void fragment"))
	assert_true(fragment.contains("texture(depth_mask"), "fragment() samples the depth mask")
	assert_true(fragment.contains("shallows_row") and fragment.contains("brackish_row") and fragment.contains("deep_row"), "and picks a ramp row by it")


func test_the_islands_sea_drifts_five_px_a_second_east_and_holds_its_mask() -> void:
	var island := _island(SANDBAR)
	var material := (_view(island).get_node(^"Sea") as Polygon2D).material as ShaderMaterial
	assert_eq(SeaShaderChecks.drift_of(material), Vector2(SeaShaderChecks.DRIFT_PX_PER_S, 0.0), "5 px/s east")
	for name: StringName in [&"depth_mask", &"water", &"ramps"]:
		assert_not_null(material.get_shader_parameter(name), "%s is set" % name)


func test_a_shallows_cell_picks_the_shallows_row_and_a_deep_cell_the_deep_row() -> void:
	var island := _island(SANDBAR)
	var terrain: GridTerrain = island.terrain
	var art: TerrainArtData = TerrainArt.data()
	var deep_row: int = art.depth_steps[DataEnums.Terrain.DEEP]
	var shallows_row: int = art.depth_steps[DataEnums.Terrain.SHALLOWS]
	var brackish_row: int = art.depth_steps[DataEnums.Terrain.BRACKISH]
	var material := (_view(island).get_node(^"Sea") as Polygon2D).material as ShaderMaterial
	var mask := (material.get_shader_parameter(&"depth_mask") as Texture2D).get_image()
	if mask == null or mask.is_empty():
		pending("the dummy renderer keeps no image of the mask; task 4.6's capture covers it")
		return
	var checked: Dictionary[int, int] = {}
	for cell: Vector2i in terrain.cells:
		var kind: int = terrain.terrain_at(cell)
		if kind != DataEnums.Terrain.DEEP and kind != DataEnums.Terrain.SHALLOWS and kind != DataEnums.Terrain.BRACKISH:
			continue
		var wanted: int = art.depth_steps[kind]
		assert_eq(SeaShaderChecks.row_for(mask.get_pixelv(cell), deep_row, shallows_row, brackish_row), wanted, "cell %s (terrain %d) picks its own row" % [cell, kind])
		checked[kind] = checked.get(kind, 0) + 1
	assert_gt(checked.get(DataEnums.Terrain.DEEP, 0), 0, "the sandbar has deep cells")
	assert_gt(checked.get(DataEnums.Terrain.SHALLOWS, 0), 0, "and shallows")
	var ramps := (load(ArtTuning.STANDARD_PATH) as ArtTuning).sea_ramps.get_image()
	var deep_light: float = _row_light(ramps, deep_row)
	assert_gt(_row_light(ramps, shallows_row), deep_light, "the shallows ramp is lighter than the deep one")


func _row_light(ramps: Image, row: int) -> float:
	var total: float = 0.0
	for shade: int in ramps.get_width():
		total += ramps.get_pixel(shade, row).get_luminance()
	return total / ramps.get_width()


func test_every_land_cell_has_a_sand_tile_and_every_layer_its_rule() -> void:
	for layout: IslandLayoutData in [SANDBAR, COAST_CAY]:
		var island := _island(layout)
		var pools: Array[Vector2i] = island.built.tide_pools
		var terrain: GridTerrain = island.terrain
		var sand: Dictionary = _cells(island, &"Sand")
		var empty: int = 0
		for cell: Vector2i in terrain.cells:
			if _is_land(terrain, cell) and not sand.has(cell):
				empty += 1
		assert_eq(empty, 0, "%s: no land cell without a sand tile" % layout.id)
		for layer: StringName in LAND_LAYERS:
			var drawn: Dictionary = _cells(island, layer)
			var expected: Array[Vector2i] = TerrainArt.layer_cells(layer, terrain, pools)
			assert_eq(drawn.size(), expected.size(), "%s %s: one tile per member cell" % [layout.id, layer])
			var wrong: int = 0
			for cell: Vector2i in expected:
				if drawn.get(cell, []) != _as_list(TerrainArt.tile(layer, cell, layout.id, terrain, pools)):
					wrong += 1
			assert_eq(wrong, 0, "%s %s: every cell is TerrainArt's tile" % [layout.id, layer])
		var shore: Dictionary = _cells(island, &"Shore")
		var foam_cells: Array[Vector2i] = ShoreRule.shore_cells(terrain, pools)
		assert_eq(shore.size(), foam_cells.size(), "%s: one foam tile per shore cell" % layout.id)
		var wrong_foam: int = 0
		for cell: Vector2i in foam_cells:
			if shore.get(cell, []) != _as_list(ShoreRule.foam_tile(cell, terrain, pools)):
				wrong_foam += 1
		assert_eq(wrong_foam, 0, "%s: every shore cell has its foam piece" % layout.id)
		var size: Vector2i = island.built.size
		assert_eq(_view(island).phase_bytes, SeaMask.phase_bytes(layout.id, size, terrain, pools), "%s: the phase mask" % layout.id)
		assert_eq(_view(island).depth_bytes, SeaMask.depth_bytes(size, terrain), "%s: the depth mask" % layout.id)


func test_building_leaves_the_grid_unchanged() -> void:
	var before: IslandLayout = IslandLayout.build(SANDBAR)
	var island := _island(SANDBAR)
	assert_eq(_cells(island, &"Sand").is_empty(), false, "the view was built")
	assert_eq(island.terrain.cells, before.terrain.cells, "the cells")
	assert_eq(island.terrain.shaded, before.terrain.shaded, "the shade")
	assert_eq(island.terrain.default_terrain, before.terrain.default_terrain)
	assert_eq(island.built.tide_pools, before.tide_pools)


func test_no_tile_set_can_block_on_either_island() -> void:
	for layout: IslandLayoutData in [SANDBAR, COAST_CAY]:
		var island := _island(layout)
		for layer: StringName in TILE_LAYERS:
			var tiles := _layer(island, layer)
			assert_not_null(tiles, "%s %s" % [layout.id, layer])
			if tiles == null or tiles.tile_set == null:
				continue
			var label: String = "%s %s (%s)" % [layout.id, layer, tiles.tile_set.resource_path]
			assert_eq(tiles.tile_set.get_physics_layers_count(), 0, label + " physics")
			assert_eq(tiles.tile_set.get_navigation_layers_count(), 0, label + " navigation")
			assert_eq(tiles.tile_set.get_occlusion_layers_count(), 0, label + " occlusion")


func test_pools_get_the_pool_tile_and_palm_bases_the_shade() -> void:
	var island := _island(SANDBAR)
	assert_eq(island.built.tide_pools.size(), 3)
	for pool: Vector2i in island.built.tide_pools:
		assert_eq(_tile_at(island, &"Decals", pool), [POOL_SOURCE, Vector2i.ZERO, 0], "pool %s" % pool)
	assert_eq(island.built.palms.size(), 6)
	for palm: Vector2i in island.built.palms:
		assert_eq(_tile_at(island, &"Decals", palm), [SHADE_SOURCE, PALM_SHADE, 0], "palm base %s" % palm)


func test_the_raft_site_holds_the_wide_shade_and_the_workbench_is_shaded() -> void:
	var island := _island(SANDBAR)
	var site: Vector2i = island.built.raft_site
	assert_true(site.x > 0, "the sandbar has a raft site")
	assert_eq(_tile_at(island, &"Decals", site), [SHADE_SOURCE, WIDE_EAST, 0], "the site's cell")
	assert_eq(_tile_at(island, &"Decals", site + Vector2i.LEFT), [SHADE_SOURCE, WIDE_WEST, 0], "its west neighbour")
	var bench: Vector2i = island.built.workbench
	assert_true(bench.x > 0, "the sandbar has a workbench")
	assert_eq(_tile_at(island, &"Decals", bench)[0], SHADE_SOURCE, "the workbench cell is shaded")


func test_the_coast_cays_shaded_cells_get_the_corner_set() -> void:
	var island := _island(COAST_CAY)
	var terrain: GridTerrain = island.terrain
	assert_gt(terrain.shaded.size(), 0)
	var site: Vector2i = island.built.raft_site
	for cell: Vector2i in terrain.shaded:
		if island.built.tide_pools.has(cell) or cell == site or cell == site + Vector2i.LEFT:
			continue
		var mask: int = TerrainView._shade_mask(cell, terrain)
		@warning_ignore("integer_division")
		var atlas := Vector2i(mask % TerrainArt.COLUMNS, mask / TerrainArt.COLUMNS)
		assert_eq(_tile_at(island, &"Decals", cell), [SHADE_SOURCE, atlas, 0], "shaded cell %s" % cell)


func test_rock_on_the_coast_cay_takes_the_plain_tiles_of_its_own_mask() -> void:
	var island := _island(COAST_CAY)
	var terrain: GridTerrain = island.terrain
	var none: Array[Vector2i] = []
	var art: TerrainArtData = TerrainArt.data()
	var row: int = art.plain_row[DataEnums.Terrain.ROCK]
	var shore_cell := Vector2i(-1, -1)
	var inland_cell := Vector2i(-1, -1)
	for cell: Vector2i in terrain.cells:
		if terrain.terrain_at(cell) != DataEnums.Terrain.ROCK:
			continue
		var sand: int = TerrainArt.corner_mask(TerrainArt.SAND, cell, terrain, none)
		var own: int = TerrainArt.corner_mask(TerrainArt.PLAIN, cell, terrain, none)
		var beside_sand: bool = false
		for step: Vector2i in IslandLayout.STEPS:
			beside_sand = beside_sand or terrain.terrain_at(cell + step) == DataEnums.Terrain.BEACH
		if sand != TerrainArt.FULL and shore_cell.x < 0:
			shore_cell = cell
			assert_eq(_tile_at(island, &"Plain", cell), [art.shore_source_of[TerrainArt.PLAIN], Vector2i(sand, 16 * row + own), 0], "rock shore %s" % cell)
		elif sand == TerrainArt.FULL and beside_sand and own != TerrainArt.FULL and inland_cell.x < 0:
			inland_cell = cell
			assert_eq(_tile_at(island, &"Plain", cell), [art.source_of[TerrainArt.PLAIN], Vector2i(own, row), 0], "inland rock %s" % cell)
	assert_gte(shore_cell.x, 0, "the cay has a rock shore cell")
	assert_gte(inland_cell.x, 0, "the cay has an inland rock cell beside sand")


func test_dune_and_scrub_shore_cells_on_the_sandbar_take_their_shore_sheets() -> void:
	var island := _island(SANDBAR)
	var terrain: GridTerrain = island.terrain
	var pools: Array[Vector2i] = island.built.tide_pools
	var art: TerrainArtData = TerrainArt.data()
	var seen: Dictionary[StringName, int] = {TerrainArt.DUNE: 0, TerrainArt.BRUSH: 0}
	for cell: Vector2i in ShoreRule.shore_cells(terrain, pools):
		var kind: DataEnums.Terrain = terrain.terrain_at(cell)
		var layer: StringName = TerrainArt.BRUSH if kind == DataEnums.Terrain.SCRUB else TerrainArt.DUNE
		if kind != DataEnums.Terrain.SCRUB and kind != DataEnums.Terrain.DUNE:
			continue
		var sand: int = TerrainArt.corner_mask(TerrainArt.SAND, cell, terrain, pools)
		var own: int = TerrainArt.corner_mask(layer, cell, terrain, pools)
		assert_eq(_tile_at(island, layer, cell), [art.shore_source_of[layer], Vector2i(sand, own), 0], "%s shore %s" % [layer, cell])
		seen[layer] += 1
	assert_gt(seen[TerrainArt.DUNE], 0, "the sandbar has dune shore cells")
	assert_gt(seen[TerrainArt.BRUSH], 0, "the sandbar has scrub shore cells")


func test_the_layer_build_of_both_islands_is_timed_and_bounded() -> void:
	for layout: IslandLayoutData in [SANDBAR, COAST_CAY]:
		var island := _island(layout)
		var view := _view(island)
		assert_not_null(view)
		if view == null:
			continue
		var ms: float = view.build_usec / 1000.0
		var counts: PackedStringArray = []
		for layer: StringName in TILE_LAYERS:
			counts.append("%s %d" % [layer, _cells(island, layer).size()])
		gut.p("%s: layers built in %.1f ms (%s)" % [layout.id, ms, ", ".join(counts)])
		assert_gt(view.build_usec, 0, "%s: the build was timed" % layout.id)
		assert_lt(ms, BUILD_BOUND_MS, "%s: built within %d ms" % [layout.id, BUILD_BOUND_MS])


# --- one player, offline ------------------------------------------------------------------------

func _shell() -> GameShell:
	NetManager.start_solo()
	var shell := SHELL_SCENE.instantiate() as GameShell
	shell.settings_path = SETTINGS_PATH
	add_child_autofree(shell)
	(shell.screen as TitleScreen).solo_requested.emit()
	shell.session.body(CoopSession.HOST_ID).player_input.enabled = false
	return shell


# A land cell whose east neighbour is land drawn on other layers (sand to dune, or dune to brush).
func _edge_cell(island: SandbarIsland) -> Vector2i:
	var terrain: GridTerrain = island.terrain
	for cell: Vector2i in terrain.cells:
		var east: Vector2i = cell + Vector2i.RIGHT
		var here: DataEnums.Terrain = terrain.terrain_at(cell)
		var there: DataEnums.Terrain = terrain.terrain_at(east)
		if here == DataEnums.Terrain.BEACH and there == DataEnums.Terrain.DUNE and terrain.terrain_at(east + Vector2i.RIGHT) == DataEnums.Terrain.DUNE:
			return cell
	return Vector2i(-1, -1)


func test_a_solo_player_walks_across_a_tile_edge_on_the_sandbar() -> void:
	var shell := _shell()
	var island: SandbarIsland = shell.island
	assert_not_null(_view(island), "the solo run's island has a TerrainView")
	assert_gt(_cells(island, &"Dune").size(), 0, "the dune layer is drawn")
	var cell := _edge_cell(island)
	assert_gte(cell.x, 0, "a beach cell with dune to its east")
	if cell.x < 0:
		return
	var body := shell.session.body(CoopSession.HOST_ID)
	body.global_position = IslandLayout.cell_center(cell)
	var edge_x: float = (cell.x + 1) * TILE
	body.intent = MoveIntent.create(Vector2.RIGHT, false, false, false)
	var frames: int = 0
	while body.global_position.x < edge_x + TILE * 0.5 and frames < WALK_FRAMES:
		await wait_physics_frames(1)
		frames += 1
	body.intent = MoveIntent.new()
	assert_gte(body.global_position.x, edge_x + TILE * 0.5, "walked over the sand-to-dune edge in %d frames" % frames)
	assert_eq(floori(body.global_position.y / TILE), cell.y, "kept its row: nothing pushed it aside")
