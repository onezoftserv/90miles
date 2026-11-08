extends GutTest
## crafting-inventory "Workbench", "Placing a build site" and "Placed sites on every peer" with
## exactly 1 player, offline, on the sandbar: a build-site structure chosen at the bench is placed
## by the host on the free land cell under the player or the nearest one within 1 tile, never the
## bench's; one unfinished site per recipe; nothing without a free cell, a bench in reach or a real
## bench; a placed fire built from its deposits stands once, lit once, morale +5 once; and the one
## entity spawn function still builds creatures, and now sites and structures.

const ISLAND_SCENE: PackedScene = preload("res://scenes/levels/sandbar_island.tscn")
const SESSION_SCENE: PackedScene = preload("res://scenes/net/coop_session.tscn")
const STEP_S: float = 0.1
const TILE: float = 16.0
## The hut's bench and the hut cell south of it.
const BENCH_CELL: Vector2i = Vector2i(51, 15)
const SOUTH_OF_BENCH: Vector2i = Vector2i(51, 16)

var island: SandbarIsland
var session: CoopSession
var body: PlayerBody
var bench: Workbench


func before_each() -> void:
	NetManager.start_solo()
	WeatherManager.stop()
	WeatherManager.sky.start_at(0.0)


func after_each() -> void:
	WeatherManager.stop()
	NetManager.leave()


func _run() -> void:
	island = ISLAND_SCENE.instantiate() as SandbarIsland
	add_child_autofree(island)
	session = SESSION_SCENE.instantiate() as CoopSession
	session.terrain = island.terrain
	session.climate = island.climate
	session.spawn_points = island.spawn_points(true)
	add_child_autofree(session)
	island.with_creatures = false
	island.furnish(session)
	session.start()
	body = session.body(1)
	body.player_input.enabled = false
	bench = session.get_node("HutWorkbench") as Workbench
	assert_eq(bench.position, IslandLayout.cell_center(BENCH_CELL))
	_stand(SOUTH_OF_BENCH)


func _stand(cell: Vector2i) -> void:
	body.global_position = IslandLayout.cell_center(cell)


func _bench_path() -> NodePath:
	return session.get_path_to(bench)


func _sites(recipe_id: StringName = &"") -> Array[BuildSite]:
	var found: Array[BuildSite] = []
	for node: Node in get_tree().get_nodes_in_group(BuildSite.GROUP):
		var site := node as BuildSite
		if site != null and session.is_ancestor_of(site) and not site.is_queued_for_deletion() \
				and (recipe_id.is_empty() or site.recipe.id == recipe_id):
			found.append(site)
	return found


func _cell_of(node: Node2D) -> Vector2i:
	return Vector2i(floori(node.position.x / TILE), floori(node.position.y / TILE))


func _fires() -> Array[Node]:
	var found: Array[Node] = []
	for node: Node in session.find_children("*", "Node2D", true, false):
		if node is Fire and not node.is_queued_for_deletion():
			found.append(node)
	return found


func _lit_fires() -> Array[Node]:
	var found: Array[Node] = []
	for node: Node in get_tree().get_nodes_in_group(PlayerBody.FIRE_GROUP):
		if session.is_ancestor_of(node):
			found.append(node)
	return found


# --- where it goes ----------------------------------------------------------------------------------

func test_a_fire_chosen_at_the_bench_lies_empty_on_the_cell_under_the_player() -> void:
	_run()
	assert_true(session.craft_for(1, &"fire", _bench_path()))
	var sites := _sites(&"fire")
	assert_eq(sites.size(), 1)
	if sites.is_empty():
		return
	var site := sites[0]
	assert_eq(site.position, IslandLayout.cell_center(SOUTH_OF_BENCH), "on the land cell under the player")
	assert_true(site.deposited.is_empty() and site.tags_deposited.is_empty(), "empty, ready for deposits")
	assert_eq(site.progress(), 0.0)
	assert_same(site.get_parent(), session.entities, "spawned through the session's entities")
	assert_true(site.synced and site.spawned)
	assert_same(site.climate, session.climate)


func test_a_taken_cell_sends_the_site_to_the_nearest_free_one() -> void:
	_run()
	assert_true(session.craft_for(1, &"rain_catcher", _bench_path()))
	assert_true(session.craft_for(1, &"fire", _bench_path()))
	var fire := _sites(&"fire")[0]
	var cell := _cell_of(fire)
	assert_ne(cell, SOUTH_OF_BENCH, "the player's cell is taken by the rain catcher's site")
	assert_ne(cell, BENCH_CELL, "never the bench's cell")
	assert_eq(fire.position.distance_to(body.global_position), TILE, "the nearest free cell: one tile off")
	assert_false(TerrainQuery.is_water(island.terrain.terrain_at(cell)), "on land")


func test_standing_on_the_benchs_cell_puts_the_site_beside_it() -> void:
	_run()
	_stand(BENCH_CELL)
	assert_true(session.craft_for(1, &"fire", _bench_path()))
	var cell := _cell_of(_sites(&"fire")[0])
	assert_ne(cell, BENCH_CELL)
	assert_eq(maxi(absi(cell.x - BENCH_CELL.x), absi(cell.y - BENCH_CELL.y)), 1, "within 1 tile")


func test_with_no_free_cell_nothing_is_placed() -> void:
	_run()
	var sea := GridTerrain.new()
	sea.default_terrain = DataEnums.Terrain.DEEP
	sea.set_cell(SOUTH_OF_BENCH, DataEnums.Terrain.BEACH)
	session.terrain = sea
	assert_true(session.craft_for(1, &"fire", _bench_path()), "the one land cell")
	assert_false(session.craft_for(1, &"rain_catcher", _bench_path()), "no free cell is left")
	assert_eq(_sites(&"rain_catcher").size(), 0)
	assert_eq(_sites(&"fire").size(), 1)


# --- what may be placed -------------------------------------------------------------------------------

func test_one_unfinished_site_per_recipe() -> void:
	_run()
	assert_true(session.craft_for(1, &"fire", _bench_path()))
	assert_false(session.craft_for(1, &"fire", _bench_path()), "a second unfinished fire")
	assert_eq(_sites(&"fire").size(), 1)
	var first := _sites(&"fire")[0]
	body.inventory.add(&"driftwood", 3)
	body.inventory.add(&"dry_grass", 1)
	first.deposit(body)
	assert_true(first.work(1.0))
	assert_eq(_sites(&"fire").size(), 0, "the fire is built")
	assert_true(session.craft_for(1, &"fire", _bench_path()), "once built, another may be placed")
	assert_eq(_sites(&"fire").size(), 1)


func test_not_a_workbench_or_out_of_reach_places_nothing() -> void:
	_run()
	var raft_site := session.get_node("RaftSite") as BuildSite
	body.global_position = raft_site.global_position
	assert_false(session.craft_for(1, &"fire", session.get_path_to(raft_site)), "the raft site is no bench")
	_stand(BENCH_CELL + Vector2i(0, 3))
	assert_false(session.craft_for(1, &"fire", _bench_path()), "3 tiles from the bench")
	assert_eq(_sites(&"fire").size(), 0)


func test_a_recipe_the_player_does_not_know_places_nothing() -> void:
	_run()
	var taught := (GameState.content.get_entry(&"recipes", &"fire") as RecipeData).duplicate() as RecipeData
	taught.availability = RecipeData.Availability.TAUGHT_BY_NPC
	body.crafter.register(taught)
	assert_false(session.craft_for(1, &"fire", _bench_path()), "a recipe an NPC teaches")
	taught.availability = RecipeData.Availability.NPC_CRAFTS
	assert_false(session.craft_for(1, &"fire", _bench_path()), "a recipe only an NPC makes")
	assert_eq(_sites(&"fire").size(), 0)
	assert_false(CraftList.offers(taught), "and the list offers neither")
	taught.availability = RecipeData.Availability.KNOWN
	assert_true(session.craft_for(1, &"fire", _bench_path()), "the same recipe, known, is placed")


# --- built once ---------------------------------------------------------------------------------------

func test_a_placed_fire_built_alone_stands_once_and_cheers_once() -> void:
	_run()
	assert_true(session.craft_for(1, &"fire", _bench_path()))
	var site := _sites(&"fire")[0]
	var site_path := session.get_path_to(site)
	body.inventory.add(&"driftwood", 3)
	body.inventory.add(&"dry_grass", 1)
	body.meters.morale = 50.0
	assert_true(session.deposit_for(1, site_path))
	assert_true(site.inputs_complete())
	for i: int in roundi(30.0 / STEP_S):
		body.crafter.advance(STEP_S)
	assert_false(is_instance_valid(site) and not site.is_queued_for_deletion(), "the site is gone")
	var fires := _fires()
	assert_eq(fires.size(), 1, "exactly one fire")
	if fires.is_empty():
		return
	var fire := fires[0] as Fire
	assert_true(fire.lit)
	assert_eq(fire.position, IslandLayout.cell_center(SOUTH_OF_BENCH), "where the site was")
	assert_eq(_lit_fires().size(), 1, "the only lit fire")
	assert_almost_eq(body.meters.morale, 55.0, 0.01, "morale rose by 5, once")
	assert_eq(fire.get_meta(&"recipe_id", &""), &"fire", "a finished structure of the fire recipe")


# --- the spawn function ----------------------------------------------------------------------------------

func test_the_entity_spawn_function_builds_creatures_sites_and_structures() -> void:
	_run()
	var gull: Variant = autofree(session._spawn_entity({"name": "Creature90", "id": &"seagull", "position": Vector2(40.0, 40.0)}))
	assert_true(gull is Creature, "no kind is a creature, as before")
	var crab: Variant = autofree(session._spawn_entity({"kind": "creature", "name": "Creature91", "id": &"land_crab", "position": Vector2(40.0, 40.0)}))
	assert_true(crab is Creature, "the creature kind")
	assert_null(session._spawn_entity({"kind": "boat", "name": "Thing1", "position": Vector2.ZERO}), "an unknown kind")
	var site := autofree(session._spawn_entity({"kind": "site", "name": "Site90", "recipe_id": &"fire", "position": Vector2(56.0, 72.0)})) as BuildSite
	assert_not_null(site, "a site")
	if site != null:
		assert_eq(site.recipe.id, &"fire")
		assert_eq(site.position, Vector2(56.0, 72.0))
		assert_true(site.synced and site.spawned)
		assert_eq(String(site.name), "Site90")
	var made: Variant = autofree(session._spawn_entity({"kind": "structure", "name": "Structure90", "recipe_id": &"rain_catcher", "position": Vector2(8.0, 8.0)}))
	assert_true(made is RainCatcher, "a structure")
	assert_null(session._spawn_entity({"kind": "site", "name": "Site91", "recipe_id": &"raft", "position": Vector2.ZERO}), "a vessel is no structure site")
	assert_null(session._spawn_entity({"kind": "site", "name": "Site92", "recipe_id": &"nothing", "position": Vector2.ZERO}), "an unknown recipe")
	assert_null(session._spawn_entity({"kind": "site", "name": "../Site93", "recipe_id": &"fire", "position": Vector2.ZERO}), "a path for a name")
	assert_null(session._spawn_entity({"kind": "structure", "name": "Structure91", "recipe_id": &"fire", "position": Vector2(INF, 0.0)}), "a position off the map")
	assert_null(session._spawn_entity({"kind": "site", "name": 7, "recipe_id": &"fire", "position": Vector2.ZERO}), "a name that is not text")
