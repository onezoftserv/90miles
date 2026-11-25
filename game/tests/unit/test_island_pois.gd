extends GutTest
## island-generation "The reef cay's POIs", "A solo reef's contents", "Where a solo reef's pieces
## lie", "The reef's landing", "A generated island builds like a handmade one" and "A reef with no
## grove is sound", over 200 run seeds.

const T := DataEnums.Terrain
const R := DataEnums.RespawnTrigger

var islands: Array[GeneratedIsland] = []


func before_all() -> void:
	islands = ReefSamples.islands()


func _anchor(island: GeneratedIsland, poi_id: StringName) -> Vector2i:
	for placed: Dictionary in island.pois:
		if placed["id"] == poi_id:
			return placed["anchor"]
	return Vector2i(-1, -1)


func _pieces(island: GeneratedIsland, group: StringName) -> Array[Dictionary]:
	var found: Array[Dictionary] = []
	for pickup: Dictionary in island.built.pickups:
		if pickup["group"] == group:
			found.append(pickup)
	return found


func _units(pieces: Array[Dictionary], item_id: StringName) -> int:
	var units: int = 0
	for pickup: Dictionary in pieces:
		if pickup["item_id"] == item_id:
			units += pickup["count"]
	return units


func _of(pieces: Array[Dictionary], item_id: StringName) -> Array[Dictionary]:
	var found: Array[Dictionary] = []
	for pickup: Dictionary in pieces:
		if pickup["item_id"] == item_id:
			found.append(pickup)
	return found


func _beside(built: IslandLayout, cell: Vector2i, kind: int) -> bool:
	for step: Vector2i in IslandLayout.STEPS:
		if built.terrain.terrain_at(cell + step) == kind:
			return true
	return false


func _apart(pieces: Array[Dictionary], tiles: int, what: String) -> void:
	for a: int in pieces.size():
		for b: int in range(a + 1, pieces.size()):
			var d: float = Vector2(pieces[a]["cell"]).distance_to(Vector2(pieces[b]["cell"]))
			assert_gte(d, float(tiles), "%s: two pieces %.1f tiles apart" % [what, d])


func test_the_traps_cave_and_flotsam_on_every_reef_and_a_grove_on_about_half() -> void:
	var groves: int = 0
	for k: int in islands.size():
		var island: GeneratedIsland = islands[k]
		var what: String = "run seed %d" % (k + 1)
		var kinds: Array[StringName] = []
		for placed: Dictionary in island.pois:
			assert_false(kinds.has(placed["id"]), "%s: %s once" % [what, placed["id"]])
			kinds.append(placed["id"])
		for poi_id: StringName in [&"lobster_traps", &"limestone_cave", &"flotsam_line"]:
			assert_true(kinds.has(poi_id), "%s has %s" % [what, poi_id])
		if kinds.has(&"palm_grove"):
			groves += 1
		assert_between(kinds.size(), 3, 4, "%s POI count" % what)
		for a: int in island.pois.size():
			for b: int in range(a + 1, island.pois.size()):
				var d: float = Vector2(island.pois[a]["anchor"]).distance_to(Vector2(island.pois[b]["anchor"]))
				assert_gte(d, 12.0, "%s: %s and %s anchors" % [what, island.pois[a]["id"], island.pois[b]["id"]])
	assert_between(float(groves) / islands.size(), 0.35, 0.65, "share of reefs with a grove")


func test_a_solo_reefs_contents() -> void:
	for k: int in islands.size():
		var island: GeneratedIsland = islands[k]
		var what: String = "run seed %d" % (k + 1)
		var traps: Array[Dictionary] = _pieces(island, &"traps")
		var flotsam: Array[Dictionary] = _pieces(island, &"flotsam")
		var beach: Array[Dictionary] = _pieces(island, &"beach")
		var seep: Array[Dictionary] = _pieces(island, &"limestone_cave")
		assert_eq(_units(traps, &"rope"), 6, "%s trap rope" % what)
		assert_eq(traps.size(), 6, "%s: one rope per trap" % what)
		assert_eq(_units(flotsam, &"inner_tube"), 2, "%s inner tubes" % what)
		assert_between(_units(flotsam, &"plastic_jug"), 2, 3, "%s plastic jugs" % what)
		assert_eq(_units(flotsam, &"rope"), 2, "%s flotsam rope" % what)
		assert_eq(_units(beach, &"driftwood"), 8, "%s driftwood" % what)
		assert_eq(seep.size(), 1, "%s: one seep pick-up" % what)
		if seep.size() == 1:
			assert_eq(seep[0]["item_id"], &"rain_cup")
			assert_eq(seep[0]["count"], 2, "%s: two cups" % what)
			assert_eq(seep[0]["respawn"], R.DAILY)
			assert_eq(seep[0]["cell"], _anchor(island, &"limestone_cave"), "%s: on the cave's anchor" % what)
		assert_eq(island.built.pickups.size(), traps.size() + flotsam.size() + beach.size() + seep.size(), "%s: nothing else lies there" % what)


func test_where_a_solo_reefs_pieces_lie() -> void:
	for k: int in islands.size():
		var island: GeneratedIsland = islands[k]
		var built: IslandLayout = island.built
		var what: String = "run seed %d" % (k + 1)
		var traps: Vector2i = _anchor(island, &"lobster_traps")
		assert_eq(built.terrain.terrain_at(traps), T.ROCK, "%s: the traps' anchor is rock" % what)
		for pickup: Dictionary in _pieces(island, &"traps"):
			var cell: Vector2i = pickup["cell"]
			assert_eq(built.terrain.terrain_at(cell), T.SHALLOWS, "%s trap rope in the shallows" % what)
			assert_true(_beside(built, cell, T.ROCK), "%s trap rope beside rock" % what)
			assert_lte(Vector2(cell).distance_to(Vector2(traps)), 10.0, "%s trap rope near the traps" % what)
			assert_eq(pickup["respawn"], R.NEVER)
		_apart(_pieces(island, &"traps"), 3, "%s traps" % what)
		var flotsam: Vector2i = _anchor(island, &"flotsam_line")
		assert_eq(built.terrain.terrain_at(flotsam), T.BEACH, "%s: the flotsam's anchor is beach" % what)
		for pickup: Dictionary in _pieces(island, &"flotsam"):
			assert_eq(built.terrain.terrain_at(pickup["cell"]), T.BEACH, "%s flotsam on beach" % what)
			assert_lte(Vector2(pickup["cell"]).distance_to(Vector2(flotsam)), 6.0, "%s flotsam near its line" % what)
			assert_eq(pickup["respawn"], R.SQUALL)
		for item_id: StringName in [&"inner_tube", &"plastic_jug", &"rope"]:
			_apart(_of(_pieces(island, &"flotsam"), item_id), 2, "%s flotsam %s (apart within one entry)" % [what, item_id])
		for pickup: Dictionary in _pieces(island, &"beach"):
			assert_eq(built.terrain.terrain_at(pickup["cell"]), T.BEACH, "%s driftwood on beach" % what)
			assert_eq(pickup["respawn"], R.SQUALL)
		_apart(_pieces(island, &"beach"), 3, "%s driftwood" % what)
		for glyph: IslandGlyphData in island.layout.pickups:
			var scaled: float = 0.8 if glyph.item_id == &"driftwood" else 1.0
			assert_eq(glyph.party_scaling_per_extra_player, scaled, "%s %s scaling" % [what, glyph.item_id])


func test_the_cave_is_the_only_shade_and_its_nine_cells_are_land() -> void:
	for k: int in islands.size():
		var island: GeneratedIsland = islands[k]
		var built: IslandLayout = island.built
		var cave: Vector2i = _anchor(island, &"limestone_cave")
		var what: String = "run seed %d" % (k + 1)
		assert_eq(built.terrain.terrain_at(cave), T.ROCK, "%s: the cave is in rock" % what)
		assert_eq(built.terrain.shaded.size(), 9, "%s: nine shaded cells" % what)
		for dy: int in range(-1, 2):
			for dx: int in range(-1, 2):
				var cell := cave + Vector2i(dx, dy)
				assert_true(built.terrain.is_shaded(cell), "%s: %s is shaded" % [what, cell])
				assert_true(built.terrain.terrain_at(cell) in [T.BEACH, T.SCRUB, T.ROCK], "%s: %s is land" % [what, cell])


func test_three_palms_with_five_coconuts_or_none() -> void:
	for k: int in islands.size():
		var island: GeneratedIsland = islands[k]
		var built: IslandLayout = island.built
		var what: String = "run seed %d" % (k + 1)
		var grove: Vector2i = _anchor(island, &"palm_grove")
		if grove.x < 0:
			assert_eq(built.palms.size(), 0, "%s: no grove, no palms" % what)
			assert_eq(island.layout.palm_glyph, "")
			continue
		assert_eq(built.palms.size(), 3, "%s palms" % what)
		var coconuts: int = 0
		for count: int in built.palm_coconuts:
			coconuts += count
		assert_eq(coconuts, 5, "%s coconuts" % what)
		for palm: Vector2i in built.palms:
			assert_eq(built.terrain.terrain_at(palm), T.BEACH)
			assert_lte(Vector2(palm).distance_to(Vector2(grove)), 5.0, "%s palm near the grove" % what)
		for a: int in 3:
			for b: int in range(a + 1, 3):
				assert_gte(Vector2(built.palms[a]).distance_to(Vector2(built.palms[b])), 2.0, "%s palms apart" % what)
		assert_eq(island.layout.climb_effects.size(), 1, "%s: the grove's climb" % what)
		assert_eq(island.layout.climb_effects[0].amount, -5.0)
		assert_eq(island.layout.climb_hold_s, 2.0)


func test_the_reefs_landing() -> void:
	for k: int in islands.size():
		var built: IslandLayout = islands[k].built
		var what: String = "run seed %d" % (k + 1)
		var landing: Array[Vector2i] = built.landing_cells()
		assert_eq(landing.size(), 4, "%s landing cells" % what)
		assert_eq(built.solo_spawn, landing[0], "%s: a lone arrival stands on the first" % what)
		for cell: Vector2i in landing:
			assert_eq(built.terrain.terrain_at(cell), T.BEACH, "%s: %s is beach" % [what, cell])
			assert_true(_beside(built, cell, T.SHALLOWS), "%s: %s is beside shallows" % [what, cell])
		for a: int in 4:
			for b: int in range(a + 1, 4):
				assert_lte(Vector2(landing[a]).distance_to(Vector2(landing[b])), 5.0, "%s: landing cells within 5 tiles" % what)
		assert_eq(built.terrain.terrain_at(built.raft_site), T.BEACH, "%s: the raft site is beach" % what)
		assert_false(landing.has(built.raft_site), "%s: the raft site is off the landing" % what)


func test_a_generated_island_builds_like_a_handmade_one() -> void:
	for k: int in islands.size():
		var island: GeneratedIsland = islands[k]
		var layout: IslandLayoutData = island.layout
		var what: String = "run seed %d" % (k + 1)
		assert_eq(layout.id, &"reef_traps_3", what)
		assert_eq(layout.chain_family, DataEnums.ChainFamily.REEF)
		assert_eq(layout.next_island, &"")
		assert_eq(layout.route_ids, [&"raft", &"binoculars_swim"] as Array[StringName], "%s routes" % what)
		assert_eq(layout.workbench_glyph, "", "%s: no workbench" % what)
		assert_eq(layout.drink_glyph, "", "%s: no drinking spot" % what)
		assert_eq(layout.tide_pool_glyph, "", "%s: no tide pool" % what)
		assert_eq(layout.signs.size(), 0, "%s: no sign" % what)
		assert_eq(layout.name_es, "El cayo del arrecife")
		assert_eq(IslandLayout.build(layout).problems(), PackedStringArray(), "%s reads with no problems" % what)


func test_a_reef_with_no_grove_is_sound() -> void:
	var without: int = 0
	for island: GeneratedIsland in islands:
		if _anchor(island, &"palm_grove").x >= 0:
			continue
		without += 1
		assert_eq(island.built.problems(), PackedStringArray(), "a palm-less reef reads with no problems")
	assert_gt(without, 0, "some reefs have no grove")
