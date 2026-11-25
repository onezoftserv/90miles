extends GutTest
## island-generation "Chain template as data" and "The reef cay's template loads": the reef cay's
## chain template, its four POI files, the creature rules that read REEF and the party-scaling
## default of a handmade glyph.

const T := DataEnums.Terrain

var catalog: ContentCatalog
var chain: ChainData


func before_each() -> void:
	catalog = GameState.content
	chain = catalog.get_entry(&"chains", &"reef_traps") as ChainData


func _poi(poi_id: StringName) -> PoiData:
	return catalog.get_entry(&"pois", poi_id) as PoiData


func test_the_reef_template_loads_with_every_value() -> void:
	assert_not_null(chain, "chains/reef_traps.tres loads as ChainData")
	if chain == null:
		return
	assert_eq(chain.grid_size, Vector2i(96, 64))
	assert_eq(chain.edge_margin_tiles, 8)
	assert_eq(chain.land_cells, Vector2i(1000, 1300))
	assert_eq(chain.land_fraction, Vector2(0.16, 0.22))
	assert_eq(chain.landmass_count, 1)
	assert_eq(chain.max_inland_distance_tiles, 10)
	assert_eq(chain.shallows_width_tiles, Vector2i(2, 2))
	assert_eq(chain.beach_width_tiles, Vector2i(2, 4))
	assert_eq(chain.shore_terrain, T.ROCK)
	assert_eq(chain.lee_terrain, T.BEACH)
	assert_eq(chain.lee_facing, Vector2i(-1, 0))
	assert_eq(chain.biome_weights, {T.SCRUB: 0.7, T.ROCK: 0.3})
	assert_eq(chain.shape_length_tiles, Vector2i(50, 66))
	assert_eq(chain.shape_bend_degrees, Vector2i(0, 60))
	assert_eq(chain.shape_half_width_tiles, Vector2i(7, 11))
	assert_eq(chain.landing_cell_count, 4)
	assert_eq(chain.landing_spread_tiles, 5)
	assert_eq(chain.raft_site_walk_s, Vector2(0.5, 3.0))
	assert_eq(chain.far_end_walk_s, Vector2(9.0, 22.0))
	assert_eq(chain.poi_walk_s, {
		&"flotsam_line": Vector2(1, 7), &"limestone_cave": Vector2(6, 18),
		&"lobster_traps": Vector2(6, 22), &"palm_grove": Vector2(3, 15),
	})
	assert_eq(chain.poi_count, Vector2i(3, 6))
	assert_eq(chain.signature_poi_id, &"lobster_traps")
	assert_eq(chain.guaranteed_poi_ids, [&"limestone_cave", &"flotsam_line"] as Array[StringName])
	assert_eq(chain.poi_chances, {&"palm_grove": 0.5})
	assert_eq(chain.route_count, Vector2i(2, 3))
	assert_eq(chain.routes.size(), 2)
	if chain.routes.size() == 2:
		assert_eq(chain.routes[0].route_id, &"raft")
		assert_true(chain.routes[0].guaranteed, "the raft is guaranteed")
		assert_eq(chain.routes[1].route_id, &"binoculars_swim")
		assert_false(chain.routes[1].guaranteed)
		assert_eq(chain.routes[1].weight, 1.0)
	assert_eq(chain.ambient_resources.size(), 1)
	if chain.ambient_resources.size() == 1:
		var wood: SpawnEntryData = chain.ambient_resources[0]
		assert_eq(wood.ref_id, &"driftwood")
		assert_eq(wood.count, Vector2i(8, 8))
		assert_eq(wood.per_cell, 1)
		assert_eq(wood.on_terrain, [T.BEACH] as Array[DataEnums.Terrain])
		assert_eq(wood.apart_tiles, 3)
		assert_eq(wood.respawn, DataEnums.RespawnTrigger.SQUALL)
		assert_eq(wood.party_scaling_per_extra_player, 0.8)
		assert_eq(wood.group, &"beach")
	assert_eq(chain.set_piece_chance, 0.0)
	assert_eq(chain.bottle_note_count, Vector2i(0, 0))
	assert_eq(chain.important_text_count, 0)
	assert_eq(chain.max_attempts, 50)
	assert_eq(chain.relaxed_attempts, 5)
	assert_eq(chain.fallback_seed, 9090)
	assert_eq(chain.family, DataEnums.ChainFamily.REEF)
	assert_eq(chain.distance_band, DataEnums.DistanceBand.MID)
	assert_eq(chain.layout_rule, ChainData.LayoutRule.REEF_RING)


func test_the_lobster_traps() -> void:
	var traps := _poi(&"lobster_traps")
	assert_not_null(traps)
	if traps == null:
		return
	assert_eq(traps.placement, DataEnums.Placement.SHORELINE)
	assert_eq(traps.anchor_terrain, [T.ROCK] as Array[DataEnums.Terrain])
	assert_eq(traps.loot.size(), 1)
	if traps.loot.size() == 1:
		var rope: SpawnEntryData = traps.loot[0]
		assert_eq(rope.ref_id, &"rope")
		assert_eq(rope.count, Vector2i(6, 6))
		assert_eq(rope.per_cell, 1)
		assert_eq(rope.on_terrain, [T.SHALLOWS] as Array[DataEnums.Terrain])
		assert_eq(rope.beside_terrain, [T.ROCK] as Array[DataEnums.Terrain])
		assert_eq(rope.within_tiles, 10)
		assert_eq(rope.apart_tiles, 3)
		assert_eq(rope.respawn, DataEnums.RespawnTrigger.NEVER)
		assert_eq(rope.group, &"traps")


func test_the_limestone_cave() -> void:
	var cave := _poi(&"limestone_cave")
	assert_not_null(cave)
	if cave == null:
		return
	assert_eq(cave.placement, DataEnums.Placement.INTERIOR)
	assert_eq(cave.anchor_terrain, [T.ROCK] as Array[DataEnums.Terrain])
	assert_eq(cave.anchor_min_water_tiles, 3)
	assert_eq(cave.shade_tiles, 1)
	assert_eq(cave.features, [PoiData.Feature.SHADE] as Array[PoiData.Feature])
	assert_eq(cave.water_item_id, &"rain_cup")
	assert_eq(cave.water_capacity_cups, 2)
	assert_eq(cave.water_refill, PoiData.WaterRefill.DAILY)


func test_the_flotsam_line() -> void:
	var flotsam := _poi(&"flotsam_line")
	assert_not_null(flotsam)
	if flotsam == null:
		return
	assert_eq(flotsam.placement, DataEnums.Placement.SHORELINE)
	assert_eq(flotsam.anchor_terrain, [T.BEACH] as Array[DataEnums.Terrain])
	assert_true(flotsam.needs_shoreline_access)
	var counts: Dictionary = {}
	for entry: SpawnEntryData in flotsam.loot:
		counts[entry.ref_id] = entry.count
		assert_eq(entry.per_cell, 1, "%s per cell" % entry.ref_id)
		assert_eq(entry.on_terrain, [T.BEACH] as Array[DataEnums.Terrain])
		assert_eq(entry.within_tiles, 6)
		assert_eq(entry.apart_tiles, 2)
		assert_eq(entry.respawn, DataEnums.RespawnTrigger.SQUALL)
		assert_eq(entry.group, &"flotsam")
	assert_eq(counts, {&"inner_tube": Vector2i(2, 2), &"plastic_jug": Vector2i(2, 3), &"rope": Vector2i(2, 2)})


func test_the_palm_grove() -> void:
	var grove := _poi(&"palm_grove")
	assert_not_null(grove)
	if grove == null:
		return
	assert_eq(grove.placement, DataEnums.Placement.BEACH)
	assert_eq(grove.palm_count, Vector2i(3, 3))
	assert_eq(grove.palm_coconuts, Vector2i(5, 5))
	assert_eq(grove.palm_terrain, T.BEACH)
	assert_eq(grove.palm_within_tiles, 5)
	assert_eq(grove.palm_apart_tiles, 2)
	assert_eq(grove.harvest_effects.size(), 1)
	if grove.harvest_effects.size() == 1:
		assert_eq(grove.harvest_effects[0].meter, DataEnums.Meter.ENERGY)
		assert_eq(grove.harvest_effects[0].amount, -5.0)


func test_every_new_file_speaks_spanish_and_english() -> void:
	var entries: Array[ContentData] = [chain]
	for poi_id: StringName in [&"lobster_traps", &"limestone_cave", &"flotsam_line", &"palm_grove"]:
		entries.append(_poi(poi_id))
	for entry: ContentData in entries:
		assert_not_null(entry)
		if entry == null:
			continue
		assert_false(entry.name_es.is_empty(), "%s has a Spanish name" % entry.id)
		assert_false(entry.name_en.is_empty(), "%s has an English name" % entry.id)
	assert_eq(chain.name_es, "El cayo del arrecife")
	assert_eq(chain.name_en, "The reef cay")
	assert_false(chain.description_es.is_empty(), "the reef's lore in Spanish")
	assert_false(chain.description_en.is_empty(), "the reef's lore in English")


func test_the_content_check_passes_and_reads_the_walk_bands_as_pois() -> void:
	assert_eq(ContentValidator.validate(catalog), PackedStringArray())
	assert_eq(chain.get_reference_fields().get(&"poi_walk_s"), &"pois")
	for poi_id: StringName in chain.poi_walk_s:
		assert_true(catalog.has_entry(&"pois", poi_id), "%s resolves" % poi_id)


func test_a_walk_band_naming_no_poi_fails_the_check() -> void:
	var broken := chain.duplicate() as ChainData
	broken.poi_walk_s = {&"no_such_poi": Vector2(1, 2)}
	var problems := ContentValidator._check_references(catalog, "chains/broken", broken)
	assert_gt(problems.size(), 0, "an unknown POI in poi_walk_s is reported")


func test_every_chain_names_a_painted_rule() -> void:
	var ids: Array[StringName] = catalog.list_ids(&"chains")
	assert_true(ids.has(&"reef_traps"))
	for chain_id: StringName in ids:
		var data := catalog.get_entry(&"chains", chain_id) as ChainData
		assert_true(IslandGenerator.PAINTERS.has(data.layout_rule), "%s's layout rule has a painter" % chain_id)


func _rules(creature_id: StringName) -> Array[CreatureSpawnRuleData]:
	return (catalog.get_entry(&"creatures", creature_id) as CreatureData).spawn_rules


func test_three_reef_sharks_on_the_reef() -> void:
	var reef: Array[CreatureSpawnRuleData] = []
	var coast: Array[CreatureSpawnRuleData] = []
	for rule: CreatureSpawnRuleData in _rules(&"reef_shark"):
		if rule.chain_families.has(DataEnums.ChainFamily.REEF):
			reef.append(rule)
		if rule.chain_families.has(DataEnums.ChainFamily.SANDBAR) and rule.chain_families.has(DataEnums.ChainFamily.COAST):
			coast.append(rule)
	assert_eq(reef.size(), 1, "one rule for REEF")
	assert_eq(coast.size(), 1, "the sandbar and coast rule is kept")
	if reef.size() == 1:
		assert_eq(reef[0].count, Vector2i(3, 3))
		assert_eq(reef[0].terrain, [T.DEEP] as Array[DataEnums.Terrain])
		assert_eq(reef[0].min_shore_distance_tiles, 2)
		assert_false(reef[0].chain_families.has(DataEnums.ChainFamily.SANDBAR))
	if coast.size() == 1:
		assert_eq(coast[0].count, Vector2i(1, 1))


func test_crabs_but_no_gulls_on_the_reef() -> void:
	var crab := false
	for rule: CreatureSpawnRuleData in _rules(&"land_crab"):
		crab = crab or rule.chain_families.has(DataEnums.ChainFamily.REEF)
	assert_true(crab, "the land crab's rule lists REEF")
	for rule: CreatureSpawnRuleData in _rules(&"seagull"):
		assert_false(rule.chain_families.has(DataEnums.ChainFamily.REEF), "no gulls on the reef")


func test_a_handmade_glyph_keeps_its_count() -> void:
	assert_eq(IslandGlyphData.new().party_scaling_per_extra_player, 1.0)
	for path: String in ["res://resources/islands/sandbar.tres", "res://resources/islands/coast_cay.tres"]:
		var layout := load(path) as IslandLayoutData
		for glyph: IslandGlyphData in layout.pickups:
			assert_eq(glyph.party_scaling_per_extra_player, 1.0, "%s glyph %s" % [layout.id, glyph.glyph])
