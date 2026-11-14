extends GutTest
## secret-cay on coast-cay's island-generation "Any handmade layout builds the island" (which
## test_coast_cay_layout.gd already covers for the coast cay): the dev hunt layout and the secret
## cay build the island scene with their own size, palms, coconuts and spawn points, and a layout
## with no workbench gets none, nor creatures when it is off-graph; island-generation "Off-graph
## handmade layouts": the one listing of numbered islands never names an off-graph layout. With
## exactly 1 player, offline.

const ISLAND_SCENE: PackedScene = preload("res://scenes/levels/sandbar_island.tscn")
const SESSION_SCENE: PackedScene = preload("res://scenes/net/coop_session.tscn")
const HUNT_PATH: String = "res://scenes/dev/secret_hunt_layout.tres"
const CAY_PATH: String = "res://resources/islands/cayo_sin_norte.tres"
const ROOT: String = "user://test_handmade_layouts"


func before_each() -> void:
	NetManager.start_solo()
	WeatherManager.stop()
	FsHelpers.remove_tree(ROOT)


func after_each() -> void:
	WeatherManager.stop()
	NetManager.leave()


func after_all() -> void:
	FsHelpers.remove_tree(ROOT)


# The island scene with `layout` set before it enters the tree, furnished into a solo session.
func _furnished(layout: IslandLayoutData) -> Array:
	var island := ISLAND_SCENE.instantiate() as SandbarIsland
	island.layout = layout
	add_child_autofree(island)
	var session := SESSION_SCENE.instantiate() as CoopSession
	session.terrain = island.terrain
	session.spawn_points = island.spawn_points(true)
	add_child_autofree(session)
	island.furnish(session)
	session.start()
	return [island, session]


func _coconuts(island: SandbarIsland) -> int:
	var total: int = 0
	for palm: Node in island.get_node(^"Palms").get_children():
		total += (palm as Palm).coconuts
	return total


func _assert_builds_its_own(layout: IslandLayoutData, size: Vector2i, palms: int, coconuts: int) -> void:
	var built := IslandLayout.build(layout)
	var made: Array = _furnished(layout)
	var island: SandbarIsland = made[0]
	var session: CoopSession = made[1]
	assert_eq(island.built.size, size, "%s's size, not the sandbar's" % layout.id)
	assert_eq(island.bounds, Rect2i(Vector2i.ZERO, size * IslandLayout.TILE))
	assert_eq(island.get_node(^"Palms").get_child_count(), palms, "%s's palms" % layout.id)
	assert_eq(_coconuts(island), coconuts, "%s's coconuts" % layout.id)
	assert_eq(island.spawn_points(true), [IslandLayout.cell_center(built.solo_spawn)] as Array[Vector2], "the solo spawn")
	var coop: Array[Vector2] = []
	for cell: Vector2i in built.coop_spawns:
		coop.append(IslandLayout.cell_center(cell))
	assert_eq(island.spawn_points(false), coop, "the co-op spawns")
	assert_null(session.get_node_or_null(NodePath(SandbarIsland.BENCH_NAME)), "no workbench when the layout has none")
	assert_null(session.get_node_or_null(NodePath(SandbarIsland.CREATURES_NAME)), "no creatures on an off-graph layout")
	assert_eq(session.body(CoopSession.HOST_ID).position, IslandLayout.cell_center(built.solo_spawn), "the one player stands on the solo spawn")


func test_the_hunt_layout_builds_the_island_scene() -> void:
	var hunt := load(HUNT_PATH) as IslandLayoutData
	assert_not_null(hunt)
	if hunt != null:
		_assert_builds_its_own(hunt, Vector2i(56, 34), 2, 4)


func test_the_secret_cay_builds_the_island_scene() -> void:
	var cay := load(CAY_PATH) as IslandLayoutData
	assert_not_null(cay)
	if cay != null:
		_assert_builds_its_own(cay, Vector2i(48, 27), 3, 7)


func test_the_cay_draws_its_scenery_over_the_ground() -> void:
	var made: Array = _furnished(load(CAY_PATH) as IslandLayoutData)
	var island: SandbarIsland = made[0]
	var session: CoopSession = made[1]
	var decor := island.get_node_or_null(^"Decor") as DecorView
	assert_not_null(decor, "a DecorView child")
	if decor != null:
		assert_true(decor.is_in_group(&"art_view"), "drawing only")
		assert_gt(decor.get_index(), island.get_node(^"Terrain").get_index(), "after the ground, so over it")
	assert_not_null(session.get_node_or_null(NodePath(Chest.NAME)), "the chest")
	assert_not_null(island.get_node_or_null(NodePath(SandbarIsland.SHELTER_NAME)), "the lean-to over its shade")


func test_the_sandbar_keeps_its_workbench_and_creatures() -> void:
	var made: Array = _furnished(load("res://resources/islands/sandbar.tres") as IslandLayoutData)
	var session: CoopSession = made[1]
	assert_not_null(session.get_node_or_null(NodePath(SandbarIsland.BENCH_NAME)), "the sandbar's workbench")
	assert_not_null(session.get_node_or_null(NodePath(SandbarIsland.CREATURES_NAME)), "the sandbar's creatures")


func test_numbered_islands_are_the_catalog_layouts_but_off_graph_ones() -> void:
	var numbered: Array[IslandLayoutData] = IslandLayouts.numbered(GameState.content)
	var ids: Array[StringName] = []
	for layout: IslandLayoutData in numbered:
		ids.append(layout.id)
		assert_false(layout.off_graph, "%s is not off-graph" % layout.id)
	assert_has(ids, &"sandbar")
	assert_has(ids, &"coast_cay")
	assert_does_not_have(ids, &"cayo_sin_norte", "the secret cay is never a numbered island")
	assert_true(GameState.content.has_entry(&"islands", &"cayo_sin_norte"), "though the catalog holds it")


func test_an_off_graph_layout_is_never_numbered() -> void:
	var listed := IslandLayoutData.new()
	listed.id = &"listed"
	listed.name_es = "Listado"
	var hidden := IslandLayoutData.new()
	hidden.id = &"hidden"
	hidden.name_es = "Escondido"
	hidden.off_graph = true
	assert_eq(FsHelpers.save_content(ROOT, "islands", "listed", listed), OK)
	assert_eq(FsHelpers.save_content(ROOT, "islands", "hidden", hidden), OK)
	var catalog := ContentCatalog.new(ROOT, {&"islands": IslandLayoutData})
	var ids: Array[StringName] = []
	for layout: IslandLayoutData in IslandLayouts.numbered(catalog):
		ids.append(layout.id)
	assert_eq(ids, [&"listed"] as Array[StringName])
