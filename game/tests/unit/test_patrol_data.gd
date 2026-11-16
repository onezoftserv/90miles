extends GutTest
## guardacostas-stealth, group 1: PatrolData's new fields and their defaults, patrol_boat.tres
## with every number of design.md section 12, the content check's PATROL rules and the fixtures
## later groups use.

const BROKEN: String = "res://tests/fixtures/patrol_broken"
const FIXTURES: String = "res://tests/fixtures/content"
const TOLERANCE: float = 0.000001
const CONTRACTIONS: Array[String] = ["pa'", "'tá", "'toy", "na'", "to'"]


func _boat() -> CreatureData:
	return GameState.content.get_entry(&"creatures", &"patrol_boat") as CreatureData


func test_the_new_fields_default_to_today_behaviour() -> void:
	var data := PatrolData.new()
	assert_eq(data.route_lap_s, 0.0)
	assert_eq(data.route_offshore_tiles, 4.0)
	assert_eq(data.searchlight_arc_deg, 0.0)
	assert_eq(data.spot_fill_per_s, 1.0)
	assert_eq(data.spot_drain_per_s, 0.5)
	assert_eq(data.alert_s, 0.0)
	assert_eq(data.alert_sweep_deg, 0.0)
	assert_eq(data.alert_lines_es, PackedStringArray())
	assert_eq(data.alert_lines_en, PackedStringArray())
	assert_eq(data.give_up_lines_es, PackedStringArray())
	assert_eq(data.give_up_lines_en, PackedStringArray())
	# The old fields keep their defaults.
	assert_eq(data.route_period_s, 0.0)
	assert_eq(data.spot_time_s, 2.0)
	assert_eq(data.noise_alert_min_radius_tiles, 8.0)


func test_the_patrol_boat_loads_with_its_creature_fields() -> void:
	var boat := _boat()
	assert_not_null(boat)
	assert_eq(boat.id, &"patrol_boat")
	assert_eq(boat.name_es, "La lancha")
	assert_eq(boat.name_en, "The patrol boat")
	assert_eq(boat.category, CreatureData.Category.HUMAN)
	assert_eq(boat.creature_tags, [DataEnums.CreatureTag.PATROL])
	assert_eq(boat.domains, [CreatureData.Domain.DEEP])
	assert_eq(boat.behavior, CreatureData.Behavior.PATROL_ROUTE)
	assert_eq(boat.health, 0)
	assert_eq(boat.senses, [DataEnums.Sense.SIGHT, DataEnums.Sense.HEARING, DataEnums.Sense.SMOKE])
	assert_eq(boat.party_rate_mult_per_extra_player, 1.0)
	assert_eq(boat.party_extra_count_every_n_players, 2)
	for text: String in [boat.description_es, boat.description_en, boat.hint_es, boat.hint_en]:
		assert_false(text.is_empty())


func test_the_patrol_boat_has_two_spawn_rules() -> void:
	var rules := _boat().spawn_rules
	assert_eq(rules.size(), 2)
	assert_eq(rules[0].chain_families, [DataEnums.ChainFamily.SANDBAR])
	assert_eq(rules[0].count, Vector2i(1, 1))
	assert_eq(rules[0].terrain, [DataEnums.Terrain.DEEP])
	assert_eq(rules[1].chain_families, [DataEnums.ChainFamily.COAST])
	assert_eq(rules[1].count, Vector2i(1, 2))
	assert_eq(rules[1].terrain, [DataEnums.Terrain.DEEP])


func test_the_patrol_boat_carries_every_patrol_number() -> void:
	var patrol := _boat().patrol
	assert_not_null(patrol)
	assert_almost_eq(patrol.route_period_s, 180.0, TOLERANCE)
	assert_almost_eq(patrol.horizon_warning_s, 20.0, TOLERANCE)
	assert_almost_eq(patrol.route_lap_s, 100.0, TOLERANCE)
	assert_almost_eq(patrol.route_offshore_tiles, 4.0, TOLERANCE)
	assert_almost_eq(patrol.searchlight_cone_deg, 60.0, TOLERANCE)
	assert_almost_eq(patrol.searchlight_range_tiles, 10.0, TOLERANCE)
	assert_almost_eq(patrol.searchlight_sweep_deg_s, 30.0, TOLERANCE)
	assert_almost_eq(patrol.searchlight_arc_deg, 120.0, TOLERANCE)
	assert_eq(patrol.searchlight_phases, [DataEnums.DayPhase.NIGHT])
	assert_almost_eq(patrol.spot_time_s, 2.0, TOLERANCE)
	assert_almost_eq(patrol.spot_fill_per_s, 1.0, TOLERANCE)
	assert_almost_eq(patrol.spot_drain_per_s, 0.5, TOLERANCE)
	assert_almost_eq(patrol.water_spot_radius_tiles, 6.0, TOLERANCE)
	assert_almost_eq(patrol.smoke_shore_tiles_night, 2.0, TOLERANCE)
	assert_almost_eq(patrol.smoke_shore_tiles_day, 6.0, TOLERANCE)
	assert_almost_eq(patrol.noise_alert_min_radius_tiles, 8.0, TOLERANCE)
	assert_almost_eq(patrol.alert_s, 20.0, TOLERANCE)
	assert_almost_eq(patrol.alert_sweep_deg, 30.0, TOLERANCE)


func test_the_loudhailer_has_lines_in_both_languages_and_the_spanish_is_formal() -> void:
	var patrol := _boat().patrol
	assert_eq(patrol.alert_lines_es.size(), 2)
	assert_eq(patrol.give_up_lines_es.size(), 1)
	assert_gt(patrol.alert_lines_en.size(), 0)
	assert_gt(patrol.give_up_lines_en.size(), 0)
	assert_eq(patrol.alert_lines_en.size(), patrol.alert_lines_es.size())
	assert_eq(patrol.give_up_lines_en.size(), patrol.give_up_lines_es.size())
	for line: String in patrol.alert_lines_es + patrol.give_up_lines_es:
		for contraction: String in CONTRACTIONS:
			assert_false(contraction in line, "official voice stays formal: %s" % line)
	for line: String in patrol.alert_lines_es + patrol.alert_lines_en + patrol.give_up_lines_es + patrol.give_up_lines_en:
		assert_false(line.strip_edges().is_empty())


func test_the_content_check_reports_nothing_for_shipped_content() -> void:
	assert_eq(ContentValidator.validate(GameState.content), PackedStringArray())


# The shared fixture catalog has older files that point at shipped content (weather/squall), so
# only the three files this change adds are held to the check.
func test_the_content_check_reports_nothing_for_the_new_fixtures() -> void:
	var mine: Array[String] = []
	for message: String in ContentValidator.validate(ContentCatalog.new(FIXTURES)):
		for prefix: String in ["creatures/patrol_test", "weather/fog_test", "items/noise_test"]:
			if message.begins_with(prefix):
				mine.append(message)
	assert_eq(mine, [] as Array[String])


func test_each_broken_patrol_is_reported_once_with_its_reason() -> void:
	var expected: Dictionary[StringName, String] = {
		&"lap_too_long": "route_lap_s",
		&"cone_zero": "searchlight_cone_deg",
		&"cone_wide": "searchlight_cone_deg",
		&"range_zero": "searchlight_range_tiles",
		&"drain_zero": "spot_drain_per_s",
		&"no_alert_en": "alert_lines_en",
		&"no_give_up_es": "give_up_lines_es",
		&"lap_zero": "route_lap_s",
		&"spot_time_zero": "spot_time_s",
		&"alert_zero": "alert_s",
	}
	var errors := ContentValidator.validate(ContentCatalog.new(BROKEN))
	for id: StringName in expected:
		var mine: Array[String] = []
		for message: String in errors:
			if message.begins_with("creatures/%s:" % id):
				mine.append(message)
		assert_eq(mine.size(), 1, "%s reports exactly one problem: %s" % [id, mine])
		if mine.size() == 1:
			assert_true(expected[id] in mine[0], "%s names %s: %s" % [id, expected[id], mine[0]])
	assert_eq(errors.size(), expected.size(), "nothing else is reported: %s" % [errors])


func test_a_lap_equal_to_period_minus_warning_is_refused() -> void:
	var boat := _boat().duplicate() as CreatureData
	boat.patrol = boat.patrol.duplicate() as PatrolData
	boat.patrol.route_lap_s = boat.patrol.route_period_s - boat.patrol.horizon_warning_s
	assert_eq(ContentValidator._check_patrol("creatures/x", boat).size(), 1)
	boat.patrol.route_lap_s = boat.patrol.route_period_s - boat.patrol.horizon_warning_s - 1.0
	assert_eq(ContentValidator._check_patrol("creatures/x", boat).size(), 0)


func test_a_patrol_creature_without_a_patrol_part_is_reported() -> void:
	var boat := _boat().duplicate() as CreatureData
	boat.patrol = null
	assert_eq(ContentValidator._check_patrol("creatures/x", boat).size(), 1)


func test_other_creatures_are_not_held_to_the_patrol_rules() -> void:
	var shark := GameState.content.get_entry(&"creatures", &"reef_shark") as CreatureData
	assert_eq(ContentValidator._check_patrol("creatures/reef_shark", shark).size(), 0)


# --- fixtures ----------------------------------------------------------------------------------

func test_the_fog_fixture_disables_sight() -> void:
	var fog := ContentCatalog.new(FIXTURES).get_entry(&"weather", &"fog_test") as WeatherData
	assert_not_null(fog)
	assert_eq(fog.disabled_senses, [DataEnums.Sense.SIGHT])


func test_the_noise_fixture_makes_a_radius_15_noise() -> void:
	var item := ContentCatalog.new(FIXTURES).get_entry(&"items", &"noise_test") as ItemData
	assert_not_null(item)
	assert_eq(item.uses.size(), 1)
	var effects := item.uses[0].effects
	assert_eq(effects.size(), 1)
	assert_eq(effects[0].kind, EffectData.Kind.NOISE)
	assert_almost_eq(effects[0].radius_tiles, 15.0, TOLERANCE)


func test_the_patrol_test_fixture_is_a_retuned_copy_with_no_spawn_rules() -> void:
	var catalog := ContentCatalog.new(FIXTURES)
	var copy := catalog.get_entry(&"creatures", &"patrol_test") as CreatureData
	assert_not_null(copy)
	assert_almost_eq(copy.patrol.searchlight_cone_deg, 45.0, TOLERANCE)
	assert_almost_eq(copy.patrol.route_lap_s, 90.0, TOLERANCE)
	assert_eq(copy.patrol.route_period_s, _boat().patrol.route_period_s)
	assert_eq(copy.behavior, CreatureData.Behavior.PATROL_ROUTE)
	assert_true(copy.spawn_rules.is_empty(), "spawned by a test, never by the island")


func test_the_small_island_helper_builds_a_beach_on_deep_water() -> void:
	var island := SmallIsland.make()
	assert_eq(island.terrain.terrain_at(Vector2i(18, 19)), DataEnums.Terrain.BEACH)
	assert_eq(island.terrain.terrain_at(Vector2i(2, 2)), DataEnums.Terrain.DEEP)
	assert_eq(SmallIsland.make(SmallIsland.SHALLOW_ALL).terrain.terrain_at(Vector2i(2, 2)), DataEnums.Terrain.SHALLOWS)
