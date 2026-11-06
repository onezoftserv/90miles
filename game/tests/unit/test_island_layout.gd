extends GutTest
## island-generation "Handmade sandbar": the layout data file and the pure builder that reads it.

const SANDBAR_PATH: String = "res://resources/islands/sandbar.tres"

var built: IslandLayout


func before_each() -> void:
	built = IslandLayout.build(load(SANDBAR_PATH) as IslandLayoutData)


func _fixture() -> IslandLayoutData:
	var layout := IslandLayoutData.new()
	layout.rows = PackedStringArray(["~-.P.", "~-.kS", "~-.1H"])
	layout.terrain_glyphs = {
		"~": DataEnums.Terrain.DEEP,
		"-": DataEnums.Terrain.SHALLOWS,
		".": DataEnums.Terrain.BEACH,
		"P": DataEnums.Terrain.BEACH,
		"k": DataEnums.Terrain.BEACH,
		"S": DataEnums.Terrain.BEACH,
		"1": DataEnums.Terrain.BEACH,
		"H": DataEnums.Terrain.BEACH,
	} as Dictionary[String, DataEnums.Terrain]
	layout.shade_glyphs = "Hk"
	layout.palm_glyph = "P"
	layout.coconut_total = 3
	layout.solo_spawn_glyph = "S"
	layout.coop_spawn_glyphs = "1"
	var knife := IslandGlyphData.new()
	knife.glyph = "k"
	knife.item_id = &"knife"
	knife.group = &"hut"
	layout.pickups = [knife] as Array[IslandGlyphData]
	return layout


func _land(cell: Vector2i) -> bool:
	return built.terrain.terrain_at(cell) in [DataEnums.Terrain.BEACH, DataEnums.Terrain.DUNE, DataEnums.Terrain.SCRUB]


func _tiles(a: Vector2i, b: Vector2i) -> float:
	return Vector2(a).distance_to(Vector2(b))


func _by_group(group: StringName) -> Dictionary:
	var counts: Dictionary = {}
	for pickup: Dictionary in built.pickups:
		if pickup["group"] == group:
			counts[pickup["item_id"]] = counts.get(pickup["item_id"], 0) + pickup["count"]
	return counts


func test_new_content_validates() -> void:
	var catalog := GameState.content
	for id: StringName in [&"inner_tube", &"plastic_jug", &"rope"]:
		assert_not_null(catalog.get_entry(&"items", id), "%s loads" % id)
	var layout := catalog.get_entry(&"islands", &"sandbar") as IslandLayoutData
	assert_not_null(layout)
	assert_eq(layout.coconut_total, 10)
	assert_eq(layout.climb_effects.size(), 1)
	assert_eq(layout.climb_effects[0].meter, DataEnums.Meter.ENERGY)
	assert_eq(layout.climb_effects[0].amount, -5.0)
	assert_eq(layout.climb_hold_s, 2.0)
	assert_eq(ContentValidator.new(catalog).validate().size(), 0)


func test_new_items_names_and_tags() -> void:
	var names: Dictionary = {&"inner_tube": "Cámara", &"plastic_jug": "Pomo plástico", &"rope": "Soga"}
	for id: StringName in names:
		var item := GameState.content.get_entry(&"items", id) as ItemData
		assert_eq(item.name_es, names[id])
		assert_true(item.tags.has(DataEnums.ItemTag.MATERIAL))
	assert_true((GameState.content.get_entry(&"items", &"plastic_jug") as ItemData).tags.has(DataEnums.ItemTag.CONTAINER))


func test_a_tiny_fixture_parses() -> void:
	var tiny := IslandLayout.build(_fixture())
	assert_eq(tiny.size, Vector2i(5, 3))
	assert_eq(tiny.terrain.terrain_at(Vector2i(1, 0)), DataEnums.Terrain.SHALLOWS)
	assert_eq(tiny.palms, [Vector2i(3, 0)] as Array[Vector2i])
	assert_eq(tiny.palm_coconuts, [3] as Array[int])
	assert_eq(tiny.solo_spawn, Vector2i(4, 1))
	assert_eq(tiny.coop_spawns, [Vector2i(3, 2)] as Array[Vector2i])
	assert_eq(tiny.pickups.size(), 1)
	assert_eq(tiny.pickups[0]["cell"], Vector2i(3, 1))
	assert_eq(tiny.problems().size(), 0)


func test_unknown_glyphs_and_ragged_rows_are_problems() -> void:
	var bad := _fixture()
	bad.rows = PackedStringArray(["~-.P.", "~-?kS", "~-.1"])
	assert_gt(IslandLayout.build(bad).problems().size(), 1, "an unknown glyph and a short row")


func test_sandbar_has_6_palms_and_10_coconuts() -> void:
	assert_eq(built.palms.size(), 6)
	assert_eq(built.palm_coconuts, [2, 2, 2, 2, 1, 1] as Array[int])
	assert_eq(built.problems().size(), 0)
	assert_eq(built.size, Vector2i(64, 40))


func test_only_the_hut_is_shaded() -> void:
	assert_gt(built.hut_cells.size(), 0)
	assert_eq(built.terrain.shaded.size(), built.hut_cells.size())
	for cell: Vector2i in built.hut_cells:
		assert_true(built.terrain.is_shaded(cell))
	for palm: Vector2i in built.palms:
		assert_false(built.terrain.is_shaded(palm))
	assert_true(built.terrain.is_shaded(built.workbench), "the workbench is in the hut")


func test_hut_loot_and_flotsam_line() -> void:
	assert_eq(_by_group(&"hut"), {&"tarp": 1, &"driftwood": 2, &"knife": 1})
	assert_eq(_by_group(&"flotsam"), {&"inner_tube": 2, &"plastic_jug": 3, &"rope": 1})
	assert_eq(_by_group(&"beach"), {&"driftwood": 6})
	assert_eq(_by_group(&"dune"), {&"dry_grass": 3})
	for pickup: Dictionary in built.pickups:
		var cell: Vector2i = pickup["cell"]
		assert_true(_land(cell), "%s lies on land" % pickup["item_id"])
		match pickup["group"]:
			&"hut":
				assert_true(built.terrain.is_shaded(cell))
				assert_eq(pickup["respawn"], DataEnums.RespawnTrigger.NEVER)
			&"flotsam", &"beach":
				assert_eq(pickup["respawn"], DataEnums.RespawnTrigger.SQUALL)
		if pickup["group"] == &"flotsam":
			var wet: bool = false
			for dy: int in range(-1, 2):
				for dx: int in range(-1, 2):
					wet = wet or built.terrain.terrain_at(cell + Vector2i(dx, dy)) == DataEnums.Terrain.SHALLOWS
			assert_true(wet, "flotsam lies at the water's edge")


func test_tide_pools_are_shallows_in_the_sand() -> void:
	assert_gt(built.tide_pools.size(), 0)
	for pool: Vector2i in built.tide_pools:
		assert_eq(built.terrain.terrain_at(pool), DataEnums.Terrain.SHALLOWS)
		var sandy: bool = false
		for step: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			sandy = sandy or _land(pool + step)
		assert_true(sandy)


func test_land_share_and_inland_distance() -> void:
	var land: Array[Vector2i] = []
	for cell: Vector2i in built.terrain.cells:
		var kind: DataEnums.Terrain = built.terrain.cells[cell]
		assert_true(kind in [DataEnums.Terrain.DEEP, DataEnums.Terrain.SHALLOWS, DataEnums.Terrain.BEACH, DataEnums.Terrain.DUNE, DataEnums.Terrain.SCRUB])
		if _land(cell):
			land.append(cell)
	var share: float = float(land.size()) / float(built.size.x * built.size.y)
	assert_between(share, 0.10, 0.20)
	for cell: Vector2i in land:
		var nearest: float = 99.0
		for dy: int in range(-6, 7):
			for dx: int in range(-6, 7):
				if not _land(cell + Vector2i(dx, dy)):
					nearest = minf(nearest, Vector2(dx, dy).length())
		assert_lte(nearest, 6.0, "%s is within 6 tiles of water" % cell)


func test_coop_spawns_are_10_to_20_tiles_apart() -> void:
	assert_eq(built.coop_spawns.size(), 4)
	for cell: Vector2i in built.coop_spawns:
		assert_true(_land(cell))
	for a: int in 4:
		for b: int in range(a + 1, 4):
			assert_between(_tiles(built.coop_spawns[a], built.coop_spawns[b]), 10.0, 20.0, "spawns %d and %d" % [a + 1, b + 1])


func test_a_solo_spawn_near_the_hut() -> void:
	assert_true(_land(built.solo_spawn))
	assert_false(built.terrain.is_shaded(built.solo_spawn))
	var nearest: float = 99.0
	for cell: Vector2i in built.hut_cells:
		nearest = minf(nearest, _tiles(cell, built.solo_spawn))
	assert_lte(nearest, 4.0)


func test_everything_is_in_reach_of_every_spawn() -> void:
	var starts: Array[Vector2i] = [built.solo_spawn]
	starts.append_array(built.coop_spawns)
	var goals: Array[Vector2i] = [built.workbench]
	goals.append_array(built.palms)
	goals.append_array(built.tide_pools)
	for pickup: Dictionary in built.pickups:
		goals.append(pickup["cell"])
	for start: Vector2i in starts:
		var reach: Dictionary[Vector2i, bool] = built.reachable_from(start)
		for goal: Vector2i in goals:
			assert_true(reach.has(goal), "%s reaches %s" % [start, goal])
