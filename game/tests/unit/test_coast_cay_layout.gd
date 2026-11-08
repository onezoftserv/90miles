extends GutTest
## island-generation "Handmade coast cay": the layout data file, its contents, the reach of every
## spot from every landing cell, the walks of one player alone and the content check.

const COAST_PATH: String = "res://resources/islands/coast_cay.tres"
const SANDBAR_PATH: String = "res://resources/islands/sandbar.tres"
const ISLAND_SCENE: PackedScene = preload("res://scenes/levels/sandbar_island.tscn")
const WALKABLE_LAND: Array[DataEnums.Terrain] = [
	DataEnums.Terrain.BEACH, DataEnums.Terrain.DUNE, DataEnums.Terrain.SCRUB, DataEnums.Terrain.ROCK,
]

var layout: IslandLayoutData
var built: IslandLayout


func before_each() -> void:
	layout = load(COAST_PATH) as IslandLayoutData
	built = IslandLayout.build(layout)


func _land(cell: Vector2i) -> bool:
	return WALKABLE_LAND.has(built.terrain.terrain_at(cell))


func _tiles(a: Vector2i, b: Vector2i) -> float:
	return Vector2(a).distance_to(Vector2(b))


func _by_item() -> Dictionary:
	var counts: Dictionary = {}
	for pickup: Dictionary in built.pickups:
		counts[pickup["item_id"]] = counts.get(pickup["item_id"], 0) + pickup["count"]
	return counts


func _cells_of(item_id: StringName) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for pickup: Dictionary in built.pickups:
		if pickup["item_id"] == item_id:
			cells.append(pickup["cell"])
	return cells


func test_the_coast_cay_is_data() -> void:
	assert_not_null(layout, "the layout file exists")
	assert_eq(built.problems().size(), 0)
	assert_gt(built.size.x * IslandLayout.TILE, 640)
	assert_gt(built.size.y * IslandLayout.TILE, 360)
	var land: int = 0
	for cell: Vector2i in built.terrain.cells:
		if _land(cell):
			land += 1
	assert_between(land, 1000, 1150, "land cells")
	assert_between(float(land) / float(built.size.x * built.size.y), 0.16, 0.22, "land share")
	assert_eq(layout.chain_family, DataEnums.ChainFamily.COAST)
	assert_eq(layout.next_island, &"", "the coast cay names no next island yet")
	assert_eq(layout.route_ids, [&"raft"] as Array[StringName])


func test_no_land_is_more_than_6_tiles_from_water() -> void:
	for cell: Vector2i in built.terrain.cells:
		if not _land(cell):
			continue
		var nearest: float = 99.0
		for dy: int in range(-6, 7):
			for dx: int in range(-6, 7):
				if not _land(cell + Vector2i(dx, dy)):
					nearest = minf(nearest, Vector2(dx, dy).length())
		assert_lte(nearest, 6.0, "%s is within 6 tiles of water" % cell)


func test_the_coast_cay_loads() -> void:
	assert_eq(built.palms.size(), 5)
	var coconuts: int = 0
	for count: int in built.palm_coconuts:
		coconuts += count
	assert_eq(coconuts, 10)
	var items: Dictionary = _by_item()
	var expected: Dictionary = {
		&"nails": 4, &"mirror": 1, &"aloe": 4, &"rope": 4, &"lighter": 1,
		&"inner_tube": 2, &"plastic_jug": 2, &"driftwood": 8,
	}
	assert_eq(items, expected)
	for pickup: Dictionary in built.pickups:
		var squall: bool = pickup["item_id"] in [&"inner_tube", &"plastic_jug", &"driftwood"]
		assert_eq(pickup["respawn"], DataEnums.RespawnTrigger.SQUALL if squall else DataEnums.RespawnTrigger.NEVER, "%s respawn" % pickup["item_id"])
		assert_true(_land(pickup["cell"]), "%s lies on land" % pickup["item_id"])
	assert_eq(built.signs.size(), 4, "the radio, two slogans and the crossed sticks")
	assert_eq(built.drink_spots.size(), 1)
	assert_ne(built.raft_site, Vector2i(-1, -1))
	assert_eq(built.terrain.shaded.size(), built.hut_cells.size())
	for cell: Vector2i in built.hut_cells:
		assert_true(_post_cell(cell), "only the observation post is shaded")


# The post is the block of shade; its nails and mirror lie on its cells.
func _post_cell(cell: Vector2i) -> bool:
	return built.terrain.is_shaded(cell)


func test_the_post_holds_the_nails_the_mirror_and_three_signs() -> void:
	for item_id: StringName in [&"nails", &"mirror"]:
		for cell: Vector2i in _cells_of(item_id):
			assert_true(built.terrain.is_shaded(cell), "%s is in the post" % item_id)
	var shaded_signs: int = 0
	for entry: Dictionary in built.signs:
		if built.terrain.is_shaded(entry["cell"]):
			shaded_signs += 1
	assert_eq(shaded_signs, 3, "the radio and two slogans are at the post; the crossed sticks are outside")


func test_the_landing_is_four_beach_cells_within_5_tiles() -> void:
	var landing: Array[Vector2i] = built.landing_cells()
	assert_eq(landing.size(), 4)
	for cell: Vector2i in landing:
		assert_eq(built.terrain.terrain_at(cell), DataEnums.Terrain.BEACH)
	for a: int in landing.size():
		for b: int in range(a + 1, landing.size()):
			assert_lte(_tiles(landing[a], landing[b]), 5.0, "landing %d and %d" % [a, b])
	assert_eq(built.solo_spawn, landing[0], "a lone arrival stands on the first landing cell")


func test_everything_is_in_reach_of_a_lone_arrival() -> void:
	var goals: Array[Vector2i] = [built.raft_site]
	goals.append_array(built.palms)
	goals.append_array(built.drink_spots)
	for entry: Dictionary in built.signs:
		goals.append(entry["cell"])
	for pickup: Dictionary in built.pickups:
		goals.append(pickup["cell"])
	for start: Vector2i in built.landing_cells():
		var reach: Dictionary[Vector2i, bool] = built.reachable_from(start)
		for goal: Vector2i in goals:
			assert_true(reach.has(goal), "%s reaches %s" % [start, goal])


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


func _band(astar: AStarGrid2D, cells: Array[Vector2i], low: float, high: float, what: String) -> void:
	assert_false(cells.is_empty(), "%s exists" % what)
	for cell: Vector2i in cells:
		assert_between(_seconds(astar, built.landing_cells()[0], cell), low, high, "%s at %s in seconds" % [what, cell])


func test_a_lone_arrivals_walks() -> void:
	var astar := _walk_grid()
	_band(astar, [built.raft_site], 0.5, 3.0, "the raft site")
	var flotsam: Array[Vector2i] = _cells_of(&"inner_tube") + _cells_of(&"plastic_jug")
	_band(astar, flotsam, 2.0, 7.0, "the flotsam line")
	_band(astar, built.drink_spots, 4.0, 9.0, "the lagoon drinking spot")
	_band(astar, _cells_of(&"aloe"), 7.0, 13.0, "the aloe")
	_band(astar, _cells_of(&"rope") + _cells_of(&"lighter"), 9.0, 15.0, "the rope cache")
	_band(astar, _cells_of(&"nails") + _cells_of(&"mirror"), 13.0, 19.0, "the observation post")


func test_the_island_scene_builds_the_layout_it_is_given() -> void:
	var island := ISLAND_SCENE.instantiate() as SandbarIsland
	island.layout = layout
	add_child_autofree(island)
	assert_eq(island.built.size, built.size, "the coast cay's size, not the sandbar's")
	assert_eq(island.bounds, Rect2i(Vector2i.ZERO, built.size * IslandLayout.TILE))
	assert_eq(island.terrain.cells.size(), built.terrain.cells.size())
	assert_eq(island.get_node("Palms").get_child_count(), 5, "the coast cay's palms")
	var sandbar := ISLAND_SCENE.instantiate() as SandbarIsland
	add_child_autofree(sandbar)
	assert_eq(sandbar.layout.id, &"sandbar", "the default is still the sandbar")
	assert_eq(sandbar.built.size, Vector2i(80, 72))
	assert_eq(sandbar.get_node("Palms").get_child_count(), 6)


func test_the_sandbar_names_the_coast_cay() -> void:
	var sandbar := load(SANDBAR_PATH) as IslandLayoutData
	assert_eq(sandbar.next_island, &"coast_cay")
	assert_eq(sandbar.chain_family, DataEnums.ChainFamily.SANDBAR)


func test_the_coast_cay_content_passes_the_check() -> void:
	var catalog := GameState.content
	for id: StringName in [&"nails", &"mirror", &"aloe", &"lighter"]:
		assert_not_null(catalog.get_entry(&"items", id), "%s loads" % id)
	assert_eq(catalog.get_entry(&"islands", &"coast_cay"), layout)
	assert_eq(ContentValidator.validate(catalog).size(), 0)
	for glyph: IslandGlyphData in layout.pickups:
		assert_true(catalog.has_entry(&"items", glyph.item_id), "%s resolves" % glyph.item_id)
	var names: Dictionary = {&"nails": "Clavos", &"mirror": "Espejo", &"aloe": "Sábila", &"lighter": "Fosforera"}
	for id: StringName in names:
		assert_eq((catalog.get_entry(&"items", id) as ItemData).name_es, names[id])


func test_the_lagoon_drinks_brackish_water_as_data() -> void:
	assert_eq(layout.drink_effects.size(), 2)
	assert_eq(layout.drink_effects[0].meter, DataEnums.Meter.THIRST)
	assert_eq(layout.drink_effects[0].amount, 10.0)
	assert_eq(layout.drink_effects[0].delay_s, 0.0)
	assert_eq(layout.drink_effects[1].meter, DataEnums.Meter.THIRST)
	assert_eq(layout.drink_effects[1].amount, -5.0)
	assert_eq(layout.drink_effects[1].delay_s, 30.0)
	assert_eq(layout.drink_hold_s, 2.0)
	var lagoon: int = 0
	for cell: Vector2i in built.terrain.cells:
		if built.terrain.cells[cell] == DataEnums.Terrain.BRACKISH:
			lagoon += 1
	assert_between(lagoon, 30, 60, "a small lagoon")


func test_every_sign_speaks_spanish_and_english() -> void:
	assert_eq(layout.signs.size(), 4)
	for sign_data: IslandSignData in layout.signs:
		assert_false(sign_data.text_es.is_empty())
		assert_false(sign_data.text_en.is_empty())
