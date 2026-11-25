extends GutTest
## island-generator tasks 6.1 and 8.1, with exactly 1 player, offline (no hosting, no port, no second
## peer): the island scene builds a generated reef, its art keys on the island hash, a lone arrival
## reaches everything, builds a raft from what lies there, meets the reef's creatures, and a solo
## crossing from the coast cay lands on the reef the run seed names.

const ISLAND_SCENE: PackedScene = preload("res://scenes/levels/sandbar_island.tscn")
const SHELL_SCENE: PackedScene = preload("res://scenes/shell/game_shell.tscn")
const T := DataEnums.Terrain
const REEF: StringName = &"reef_traps"
const ARRIVAL: Dictionary = {"health": 100.0, "energy": 100.0}

var settings_path: String = UserTmp.path("test_island_generator_solo_settings.cfg")
var island: GeneratedIsland


func before_all() -> void:
	island = ReefSamples.island(1)


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
	shell.session.body(1).player_input.enabled = false
	shell.session.world_state["run_seed"] = 1
	return shell


# A solo run standing on island 3 of the reef for run seed 1, landed the way the host's travel lands.
func _on_the_reef() -> GameShell:
	var shell := _shell()
	shell.session.travel_to(String(REEF), 3, island.island_hash, {1: ARRIVAL}, 0.0)
	await wait_process_frames(2)
	return shell


func _view(of_island: SandbarIsland) -> TerrainView:
	return of_island.get_node("Terrain") as TerrainView


func test_the_island_scene_builds_a_generated_reef() -> void:
	var scene := ISLAND_SCENE.instantiate() as SandbarIsland
	scene.layout = island.layout
	scene.with_creatures = false
	add_child_autofree(scene)
	assert_eq(scene.built.size, Vector2i(96, 64))
	assert_eq(scene.bounds, Rect2i(0, 0, 1536, 1024), "1,536 x 1,024 px")
	assert_eq(scene.terrain.cells.size(), island.built.terrain.cells.size())
	assert_eq(scene.palms.size(), island.built.palms.size())
	assert_true(scene.palms.size() in [0, 3], "a grove of 3 palms or none")
	assert_eq(island.layout.chain_family, DataEnums.ChainFamily.REEF, "the spawner reads REEF")


func test_the_art_keys_on_the_island_hash() -> void:
	var first := ISLAND_SCENE.instantiate() as SandbarIsland
	first.layout = island.layout
	first.with_creatures = false
	add_child_autofree(first)
	var second := ISLAND_SCENE.instantiate() as SandbarIsland
	second.layout = ReefSamples.island(2).layout
	second.with_creatures = false
	add_child_autofree(second)
	await wait_process_frames(1)
	assert_eq(_view(first).layout_id, StringName(island.island_hash), "the first reef's key is its hash")
	assert_eq(_view(second).layout_id, StringName(ReefSamples.island(2).island_hash))
	assert_ne(_view(first).layout_id, _view(second).layout_id, "two run seeds, two keys")
	assert_eq(island.layout.id, ReefSamples.island(2).layout.id, "while both are reef_traps_3")
	var sandbar := ISLAND_SCENE.instantiate() as SandbarIsland
	sandbar.with_creatures = false
	add_child_autofree(sandbar)
	await wait_process_frames(1)
	assert_eq(_view(sandbar).layout_id, &"sandbar", "a handmade layout keeps its id")


func test_a_lone_arrivals_walks_on_the_reef() -> void:
	for run_seed: int in range(1, 51):
		var reef: GeneratedIsland = ReefSamples.island(run_seed)
		var failures := IslandValidator.check(ReefSamples.chain(), reef.built, reef.pois, GameState.content)
		var walks := PackedStringArray()
		for failure: String in failures:
			if failure.begins_with("walk") or failure.begins_with("reach"):
				walks.append(failure)
		assert_eq(walks, PackedStringArray(), "run seed %d walks" % run_seed)
		assert_eq(reef.built.coop_spawns[0], reef.built.landing_cells()[0], "run seed %d: measured from the first landing cell" % run_seed)


func test_a_solo_player_builds_a_raft_on_the_reef() -> void:
	var shell := await _on_the_reef()
	var body := shell.session.body(1)
	assert_eq(shell.travel.island.layout.id, &"reef_traps_3")
	var wanted: Dictionary[StringName, int] = {&"driftwood": 6, &"inner_tube": 2, &"rope": 3}
	for node: Node in shell.session.pickups.get_children():
		var item := node as WorldItem
		if item == null or not wanted.has(item.item_id) or wanted[item.item_id] <= 0:
			continue
		wanted[item.item_id] -= item.count
		body.global_position = item.global_position
		item.interactable.interacted.emit(body)
	assert_eq(body.inventory.count_id(&"driftwood"), 6, "6 driftwood taken")
	assert_eq(body.inventory.count_id(&"inner_tube"), 2, "both inner tubes")
	assert_gte(body.inventory.count_id(&"rope"), 3, "3 rope")
	var site := shell.session.get_node("RaftSite") as BuildSite
	body.global_position = site.global_position
	site.deposit(body)
	site.work(60.0)
	var raft := shell.session.get_node_or_null("Raft") as Raft
	assert_not_null(raft, "a raft stands on the site")
	if raft != null:
		assert_eq(raft.integrity, 100.0)


func test_a_player_on_the_rock_beside_a_trap_takes_its_rope() -> void:
	var shell := await _on_the_reef()
	var body := shell.session.body(1)
	var trap: WorldItem = null
	var rock := Vector2i(-1, -1)
	for node: Node in shell.session.pickups.get_children():
		var item := node as WorldItem
		if item == null or item.item_id != &"rope":
			continue
		var cell := CreatureNav.cell_of(item.global_position)
		if shell.island.terrain.terrain_at(cell) != T.SHALLOWS:
			continue
		for step: Vector2i in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
			if shell.island.terrain.terrain_at(cell + step) == T.ROCK:
				trap = item
				rock = cell + step
		if trap != null:
			break
	assert_not_null(trap, "a trap's rope in the shallows beside rock")
	if trap == null:
		return
	body.global_position = IslandLayout.cell_center(rock)
	var picked := InteractionPicker.pick(body.global_position, [trap.interactable] as Array[Interactable], body)
	assert_eq(picked, trap.interactable, "in reach from the rock")
	picked.interacted.emit(body)
	assert_eq(body.inventory.count_id(&"rope"), 1, "the trap's rope")


func test_a_solo_reefs_routes() -> void:
	assert_eq(island.layout.route_ids, [&"raft", &"binoculars_swim"] as Array[StringName])
	var raft := GameState.content.get_entry(&"recipes", &"raft") as RecipeData
	assert_true(island.built.raft_site.x >= 0, "a raft site")
	var astar := ReefSamples.walk_grid(island.built)
	var path := astar.get_id_path(island.built.landing_cells()[0], island.built.raft_site)
	assert_false(path.is_empty(), "the site is reachable from the first landing cell")
	var units: Dictionary[StringName, int] = {}
	for spec: Dictionary in island.built.pickups:
		units[spec["item_id"]] = units.get(spec["item_id"], 0) + spec["count"]
	for item_id: StringName in raft.inputs:
		assert_gte(units.get(item_id, 0), raft.inputs[item_id], "%s lies on the island, no starting item needed" % item_id)
	var route := GameState.content.get_entry(&"routes", &"raft") as RouteData
	assert_not_null(route)


func test_a_solo_reefs_creatures() -> void:
	var shell := await _on_the_reef()
	await wait_frames(3)
	var spawner := shell.session.get_node("Creatures") as CreatureSpawner
	var sharks: Array[Creature] = spawner.creatures(&"reef_shark")
	assert_eq(sharks.size(), 3, "three reef sharks")
	for shark: Creature in sharks:
		var cell: Vector2i = CreatureNav.cell_of(shark.position)
		assert_eq(shell.island.terrain.terrain_at(cell), T.DEEP, "in deep water")
		assert_gte(spawner.nav.land_distance(cell), 2, "at least 2 tiles from shore")
	assert_eq(spawner.creatures(&"seagull").size(), 0, "no gulls")
	assert_eq(spawner.creatures(&"land_crab").size(), 0, "crabs come out at night")
	spawner.apply_phase(DataEnums.DayPhase.NIGHT)
	var crabs: Array[Creature] = spawner.creatures(&"land_crab")
	var beaches: Array[PackedVector2Array] = spawner.nav.beach_groups(8)
	assert_gt(beaches.size(), 0, "a beach of 8 or more cells")
	assert_eq(crabs.size(), 6 * beaches.size(), "6 crabs on each beach of 8+ cells")
	for crab: Creature in crabs:
		assert_eq(shell.island.terrain.terrain_at(CreatureNav.cell_of(crab.position)), T.BEACH)


func test_a_solo_reefs_grids() -> void:
	var nav := CreatureNav.build(island.built.terrain, island.built.size)
	var seen: Dictionary[int, bool] = {}
	for cell: Vector2i in island.built.terrain.cells:
		var kind: int = island.built.terrain.cells[cell]
		if seen.has(kind):
			continue
		seen[kind] = true
		match kind:
			T.ROCK, T.SCRUB:
				assert_eq(nav.land.get_point_weight_scale(cell), 1.0, "%d costs 1" % kind)
			T.DEEP:
				assert_true(nav.land.is_point_solid(cell), "deep water is solid")
	var water := nav.water(0)
	for cell: Vector2i in island.built.terrain.cells:
		var kind: int = island.built.terrain.cells[cell]
		if not water.is_point_solid(cell):
			assert_true(kind == T.DEEP or kind == T.SHALLOWS, "the water grid is only water")
