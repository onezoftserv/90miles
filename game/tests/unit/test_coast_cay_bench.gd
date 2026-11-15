extends GutTest
## island-generation "Coast cay workbench", "Coast cay workbench out of the patrol's sight" and
## "Fire at the coast cay's workbench" (coast-cay-bench), with exactly 1 player, offline: the bench
## is layout data on an unshaded beach cell that holds nothing else, every landing cell reaches it,
## the first within 1-4 s, no fire placed at it is within 2 tiles of the sea, 2 dry grass lie on the
## dune beside it (owner, 2026-11-14), and a solo player who lands on the cay carrying nothing lights
## a fire there with the cache's lighter, the beach's driftwood and that dry grass.

const COAST_PATH: String = "res://resources/islands/coast_cay.tres"
const SHELL_SCENE: PackedScene = preload("res://scenes/shell/game_shell.tscn")
const SETTINGS_PATH: String = "user://test_coast_cay_bench_settings.cfg"
const COAST: StringName = &"coast_cay"
const BENCH_NAME: StringName = &"HutWorkbench"
## The coast cay's land cells before the bench (island-generation "Handmade coast cay").
const LAND_CELLS: int = 1021
## guardacostas-stealth smoke rule: a lit fire within this many tiles of the sea is seen at night.
const NIGHT_SMOKE_TILES: float = 2.0
## A fire placed at the bench lands on the player's cell or the nearest free one within 1 tile, and
## the player stands within 1 tile of the bench.
const FIRE_REACH_TILES: int = 2
const STEP_S: float = 0.1
const WALKABLE_LAND: Array[DataEnums.Terrain] = [
	DataEnums.Terrain.BEACH, DataEnums.Terrain.DUNE, DataEnums.Terrain.SCRUB, DataEnums.Terrain.ROCK,
]
const STEPS: Array[Vector2i] = [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]

var layout: IslandLayoutData
var built: IslandLayout


func before_each() -> void:
	layout = load(COAST_PATH) as IslandLayoutData
	built = IslandLayout.build(layout)


func after_each() -> void:
	WeatherManager.stop()
	NetManager.leave()
	if FileAccess.file_exists(SETTINGS_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SETTINGS_PATH))


# --- the layout ---------------------------------------------------------------------------------------

func _land(cell: Vector2i) -> bool:
	return WALKABLE_LAND.has(built.terrain.terrain_at(cell))


# Every cell another feature of the island stands on.
func _features() -> Dictionary[Vector2i, String]:
	var found: Dictionary[Vector2i, String] = {}
	for cell: Vector2i in built.palms:
		found[cell] = "a palm"
	for pickup: Dictionary in built.pickups:
		found[pickup["cell"]] = "a pick-up"
	for entry: Dictionary in built.signs:
		found[entry["cell"]] = "a sign"
	for cell: Vector2i in built.coop_spawns:
		found[cell] = "a spawn point"
	found[built.solo_spawn] = "the solo spawn"
	for cell: Vector2i in built.drink_spots:
		found[cell] = "a drinking spot"
	for cell: Vector2i in built.tide_pools:
		found[cell] = "a tide pool"
	found[built.raft_site] = "the raft site"
	return found


# guardacostas-stealth: the sea is deep or shallow water joined to the map edge (not the lagoon).
func _sea() -> Array[Vector2i]:
	var water: Array[DataEnums.Terrain] = [DataEnums.Terrain.DEEP, DataEnums.Terrain.SHALLOWS]
	var seen: Dictionary[Vector2i, bool] = {}
	var queue: Array[Vector2i] = []
	for y: int in built.size.y:
		for x: int in built.size.x:
			var cell := Vector2i(x, y)
			var edge: bool = x == 0 or y == 0 or x == built.size.x - 1 or y == built.size.y - 1
			if edge and water.has(built.terrain.terrain_at(cell)):
				seen[cell] = true
				queue.append(cell)
	var head: int = 0
	while head < queue.size():
		var cell: Vector2i = queue[head]
		head += 1
		for step: Vector2i in STEPS:
			var next: Vector2i = cell + step
			if seen.has(next) or next.x < 0 or next.y < 0 or next.x >= built.size.x or next.y >= built.size.y:
				continue
			if water.has(built.terrain.terrain_at(next)):
				seen[next] = true
				queue.append(next)
	return seen.keys() as Array[Vector2i]


func _nearest_sea(cell: Vector2i, sea: Array[Vector2i]) -> Vector2i:
	var best: Vector2i = sea[0]
	for water: Vector2i in sea:
		if Vector2(cell).distance_squared_to(Vector2(water)) < Vector2(cell).distance_squared_to(Vector2(best)):
			best = water
	return best


func _walk_grid() -> AStarGrid2D:
	var astar := AStarGrid2D.new()
	astar.region = Rect2i(Vector2i.ZERO, built.size)
	astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	astar.default_compute_heuristic = AStarGrid2D.HEURISTIC_EUCLIDEAN
	astar.default_estimate_heuristic = AStarGrid2D.HEURISTIC_EUCLIDEAN
	astar.update()
	for y: int in built.size.y:
		for x: int in built.size.x:
			var cell := Vector2i(x, y)
			astar.set_point_solid(cell, not IslandLayout.WALKABLE.has(built.terrain.terrain_at(cell)))
	return astar


func _seconds(astar: AStarGrid2D, from: Vector2i, to: Vector2i) -> float:
	var path: PackedVector2Array = astar.get_point_path(from, to)
	var total: float = 0.0
	for i: int in range(1, path.size()):
		total += path[i - 1].distance_to(path[i])
	return total / MovementModel.WALK_SPEED


func test_the_bench_is_data() -> void:
	assert_eq(built.problems().size(), 0)
	assert_ne(built.workbench, Vector2i(-1, -1), "the coast cay has a workbench")
	assert_false(layout.workbench_glyph.is_empty(), "named by the layout's bench glyph")
	var bench: Vector2i = built.workbench
	assert_eq(built.terrain.terrain_at(bench), DataEnums.Terrain.BEACH, "on beach")
	assert_false(built.terrain.is_shaded(bench), "unshaded")
	var features: Dictionary[Vector2i, String] = _features()
	assert_false(features.has(bench), "the bench's cell holds %s" % features.get(bench, "nothing"))
	assert_eq(built.terrain.shaded.size(), built.hut_cells.size(), "the post's cells are still the only shade")
	var land: int = 0
	for cell: Vector2i in built.terrain.cells:
		if _land(cell):
			land += 1
	assert_eq(land, LAND_CELLS, "the land count is unchanged")


func test_the_bench_is_on_the_bay_side_of_the_west_arm() -> void:
	var bench: Vector2i = built.workbench
	assert_lt(bench.x, built.size.x / 3, "in the west arm")
	var sea := _sea()
	assert_gt(_nearest_sea(bench, sea).x, bench.x, "the nearest sea is the bay, east of it")


func test_no_fire_placed_at_the_bench_is_within_2_tiles_of_the_sea() -> void:
	var sea := _sea()
	var bench: Vector2i = built.workbench
	var checked: int = 0
	for dy: int in range(-FIRE_REACH_TILES, FIRE_REACH_TILES + 1):
		for dx: int in range(-FIRE_REACH_TILES, FIRE_REACH_TILES + 1):
			var cell := bench + Vector2i(dx, dy)
			if not _land(cell):
				continue
			checked += 1
			var tiles: float = Vector2(cell).distance_to(Vector2(_nearest_sea(cell, sea)))
			assert_gt(tiles, NIGHT_SMOKE_TILES, "%s is %.1f tiles from the sea" % [cell, tiles])
	assert_eq(checked, 25, "all 25 cells round the bench are land")


func test_every_landing_cell_reaches_the_bench_and_the_first_within_1_to_4_s() -> void:
	assert_ne(built.workbench, Vector2i(-1, -1), "the coast cay has a workbench")
	if built.workbench.x < 0:
		return
	for start: Vector2i in built.landing_cells():
		assert_true(built.reachable_from(start).has(built.workbench), "%s reaches the bench" % start)
	var seconds: float = _seconds(_walk_grid(), built.landing_cells()[0], built.workbench)
	assert_between(seconds, 1.0, 4.0, "the walk from the first landing cell in seconds")


func test_two_dry_grass_lie_on_the_dune_beside_the_bench() -> void:
	var bench: Vector2i = built.workbench
	var grass: Array[Dictionary] = []
	for pickup: Dictionary in built.pickups:
		if pickup["item_id"] == &"dry_grass":
			grass.append(pickup)
	assert_eq(grass.size(), 2, "two dry grass pick-ups")
	for pickup: Dictionary in grass:
		var cell: Vector2i = pickup["cell"]
		var off: Vector2i = (cell - bench).abs()
		assert_eq(pickup["count"], 1)
		assert_eq(pickup["respawn"], DataEnums.RespawnTrigger.NEVER, "the cay's tinder does not come back")
		assert_eq(built.terrain.terrain_at(cell), DataEnums.Terrain.DUNE, "%s is dune" % cell)
		assert_lte(maxi(off.x, off.y), 3, "%s is within 3 tiles of the bench" % cell)
		assert_gt(maxi(off.x, off.y), 1, "%s is outside the bench's 8 neighbours, where its sites go" % cell)
		assert_true(built.reachable_from(built.landing_cells()[0]).has(cell), "%s can be reached" % cell)


# --- one player lights a fire at the bench ---------------------------------------------------------------

func _shell() -> GameShell:
	NetManager.start_solo()
	WeatherManager.stop()
	WeatherManager.sky.start_at(0.0)
	var shell := SHELL_SCENE.instantiate() as GameShell
	shell.settings_path = SETTINGS_PATH
	add_child_autofree(shell)
	(shell.screen as TitleScreen).solo_requested.emit()
	shell.session.body(1).player_input.enabled = false
	return shell


# A solo run that has landed on the coast cay; the sandbar is freed by the time this returns.
func _on_the_cay() -> GameShell:
	var shell := _shell()
	shell.travel.travel(COAST)
	await wait_process_frames(2)
	return shell


# The body picks up `count` of the cay's `item_id` pick-ups, walking onto each one.
func _take(shell: GameShell, body: PlayerBody, item_id: StringName, count: int) -> int:
	var taken: int = 0
	for node: Node in shell.session.pickups.get_children():
		var item := node as WorldItem
		if taken >= count or item == null or item.item_id != item_id or item.is_queued_for_deletion():
			continue
		body.global_position = item.global_position
		item.interactable.interacted.emit(body)
		taken += 1
	return taken


func _lit_fires(session: CoopSession) -> Array[Fire]:
	var found: Array[Fire] = []
	for node: Node in get_tree().get_nodes_in_group(PlayerBody.FIRE_GROUP):
		if session.is_ancestor_of(node) and not node.is_queued_for_deletion():
			found.append(node as Fire)
	return found


func _fire_site(session: CoopSession) -> BuildSite:
	for node: Node in session.entities.get_children():
		var site := node as BuildSite
		if site != null and not site.is_queued_for_deletion() and site.recipe.id == &"fire":
			return site
	return null


func _cell_of(node: Node2D) -> Vector2i:
	return Vector2i(floori(node.position.x / IslandLayout.TILE), floori(node.position.y / IslandLayout.TILE))


func _lighter_uses(body: PlayerBody) -> int:
	for slot: InventorySlot in body.inventory.slots:
		if slot != null and slot.item_id == &"lighter":
			return slot.uses_left
	return -1


func test_solo_lights_a_fire_at_the_coast_cays_bench() -> void:
	var shell := await _on_the_cay()
	assert_eq(shell.island.layout.id, COAST)
	var session := shell.session
	var body := session.body(1)
	var bench := session.get_node_or_null(NodePath(BENCH_NAME)) as Workbench
	assert_not_null(bench, "the coast cay's bench is in the session")
	if bench == null:
		return
	assert_eq(bench.position, IslandLayout.cell_center(shell.island.built.workbench), "on the layout's cell")
	assert_eq(body.inventory.count_id(&"dry_grass"), 0, "the player lands carrying no tinder")
	assert_eq(_take(shell, body, &"lighter", 1), 1, "the rope cache's lighter")
	assert_eq(_take(shell, body, &"driftwood", 3), 3, "3 driftwood off the beach")
	assert_eq(_take(shell, body, &"dry_grass", 1), 1, "dry grass off the dune beside the bench")
	assert_eq(_lighter_uses(body), 20)
	body.global_position = bench.global_position + Vector2(0.0, IslandLayout.TILE)
	assert_true(session.craft_for(1, &"fire", session.get_path_to(bench)), "the fire is chosen at the bench")
	var site := _fire_site(session)
	assert_not_null(site, "a fire site lies by the bench")
	if site == null:
		return
	var from_bench: Vector2i = (_cell_of(site) - shell.island.built.workbench).abs()
	assert_lte(maxi(from_bench.x, from_bench.y), FIRE_REACH_TILES, "within 2 tiles of the bench")
	body.global_position = site.global_position
	assert_true(session.deposit_for(1, session.get_path_to(site)), "everything in, and the work starts")
	assert_true(site.inputs_complete())
	for i: int in 9:
		body.crafter.advance(STEP_S)
	assert_eq(_lit_fires(session).size(), 0, "no fire at 0.9 s")
	body.crafter.advance(STEP_S)
	var fires := _lit_fires(session)
	assert_eq(fires.size(), 1, "one lit fire at 1 s")
	if fires.is_empty():
		return
	assert_true(fires[0].lit)
	assert_eq(fires[0].position, site.position, "where the site was")
	assert_eq(_lighter_uses(body), 19, "the lighter has 19 uses left")
	assert_eq(body.inventory.count_id(&"dry_grass"), 0, "the tinder went in")
	assert_eq(body.inventory.count_id(&"driftwood"), 0, "and the 3 driftwood")
