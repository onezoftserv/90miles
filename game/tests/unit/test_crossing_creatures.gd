extends GutTest
## creature-perch-ride "Crossing creature roll" and "Crossing creatures leave with the crossing":
## the host rolls every creature's CROSSING spawn rules when a crossing launches, places the
## chance-1.0 ones and at most 2 rolled ones, and removes them when the crossing ends. One offline
## player throughout.

const FIXTURES: String = "res://tests/fixtures/content"
const SANDBAR: IslandLayoutData = preload("res://resources/islands/sandbar.tres")
const F := DataEnums.ChainFamily
const B := DataEnums.DistanceBand
const P := DataEnums.DayPhase


func before_each() -> void:
	NetManager.start_solo()
	WeatherManager.stop()
	WeatherManager.sky.start_at(0.0)


func after_each() -> void:
	NetManager.leave()


static func _rule(chance: float, context: DataEnums.SceneContext = DataEnums.SceneContext.CROSSING) -> CreatureSpawnRuleData:
	var rule := CreatureSpawnRuleData.new()
	rule.context = context
	rule.chance = chance
	return rule


static func _creature(id: StringName, rules: Array[CreatureSpawnRuleData], max_per_run: int = 0) -> CreatureData:
	var data := CreatureData.new()
	data.id = id
	data.behavior = CreatureData.Behavior.AMBIENT
	data.domains = [CreatureData.Domain.AIR] as Array[CreatureData.Domain]
	data.spawn_rules = rules
	data.max_per_run = max_per_run
	return data


static func _ids(placed: Array[CreatureData]) -> Array[String]:
	var ids: Array[String] = []
	for data: CreatureData in placed:
		ids.append(String(data.id))
	return ids


static func _dice(seed_value: int = 1) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return rng


func _roll(pool: Array[CreatureData], family: DataEnums.ChainFamily = F.COAST, band: DataEnums.DistanceBand = B.COAST, phase: DataEnums.DayPhase = P.DAY, weather: StringName = &"calm", record: RunRecord = RunRecord.new()) -> Array[String]:
	return _ids(CrossingCreatures.roll(pool, family, band, phase, weather, _dice(), 2, record))


func test_rules_are_filtered_by_family_band_phase_and_weather() -> void:
	var family_rule := _rule(1.0)
	family_rule.chain_families = [F.FINAL] as Array[DataEnums.ChainFamily]
	var band_rule := _rule(1.0)
	band_rule.distance_bands = [B.MID, B.FAR] as Array[DataEnums.DistanceBand]
	var phase_rule := _rule(1.0)
	phase_rule.phases = [P.DAWN] as Array[DataEnums.DayPhase]
	var weather_rule := _rule(1.0)
	weather_rule.weather_ids = [&"squall"] as Array[StringName]
	var calm_shy := _rule(1.0)
	calm_shy.excluded_weather_ids = [&"calm"] as Array[StringName]
	var pool: Array[CreatureData] = [
		_creature(&"a_family", [family_rule] as Array[CreatureSpawnRuleData]),
		_creature(&"b_band", [band_rule] as Array[CreatureSpawnRuleData]),
		_creature(&"c_phase", [phase_rule] as Array[CreatureSpawnRuleData]),
		_creature(&"d_weather", [weather_rule] as Array[CreatureSpawnRuleData]),
		_creature(&"e_calm_shy", [calm_shy] as Array[CreatureSpawnRuleData]),
		_creature(&"f_any", [_rule(1.0)] as Array[CreatureSpawnRuleData]),
	]
	assert_eq(_roll(pool), ["f_any"] as Array[String], "a coast crossing by day in calm")
	assert_eq(_roll(pool, F.FINAL, B.FAR, P.DAWN, &"squall"), ["a_family", "b_band", "c_phase", "d_weather", "e_calm_shy", "f_any"] as Array[String], "every filter met")


func test_chance_one_is_always_placed_and_rolled_ones_are_capped_at_2() -> void:
	var pool: Array[CreatureData] = [
		_creature(&"a_rolled", [_rule(0.99)] as Array[CreatureSpawnRuleData]),
		_creature(&"b_rolled", [_rule(0.99)] as Array[CreatureSpawnRuleData]),
		_creature(&"c_rolled", [_rule(0.99)] as Array[CreatureSpawnRuleData]),
		_creature(&"d_sure", [_rule(1.0)] as Array[CreatureSpawnRuleData]),
	]
	var placed := _roll(pool)
	assert_eq(placed, ["d_sure", "a_rolled", "b_rolled"] as Array[String], "the sure one first, then two of three rolled")


func test_the_galleguito_rule_stays_out_of_a_coast_crossing() -> void:
	var catalog := ContentCatalog.new(FIXTURES)
	var gull := catalog.get_entry(&"creatures", &"galleguito_prueba") as CreatureData
	assert_not_null(gull)
	assert_false(_roll([gull] as Array[CreatureData]).has("galleguito_prueba"), "out of a coast-family island")
	assert_true(_roll([gull] as Array[CreatureData], F.FINAL).has("galleguito_prueba"), "out of a final-family island")


func test_a_creature_capped_per_run_comes_once() -> void:
	var record := RunRecord.new()
	var pool: Array[CreatureData] = [_creature(&"once", [_rule(1.0)] as Array[CreatureSpawnRuleData], 1)]
	assert_eq(_roll(pool, F.COAST, B.COAST, P.DAY, &"calm", record), ["once"] as Array[String], "the first crossing")
	assert_eq(_roll(pool, F.COAST, B.COAST, P.DAY, &"calm", record), [] as Array[String], "not the second")
	assert_eq(record.creature_count(&"once"), 1)


func test_island_rules_never_ride_along() -> void:
	var pool: Array[CreatureData] = [_creature(&"islander", [_rule(1.0, DataEnums.SceneContext.ISLAND)] as Array[CreatureSpawnRuleData])]
	assert_eq(_roll(pool), [] as Array[String])


func test_the_creature_roll_leaves_the_plans_dice_alone() -> void:
	var route := (GameState.content.get_entry(&"routes", &"raft") as RouteData)
	var tuning := CrossingTuning.standard()
	var plain := _dice(5)
	var with_creatures := _dice(5)
	var first := CrossingPlan.roll(route, B.COAST, WeatherManager.sky, plain, tuning)
	var second := CrossingPlan.roll(route, B.COAST, WeatherManager.sky, plain, tuning)
	var session := _session()
	var crossing := Crossing.launch(session, route, [1] as Array[int], 100.0, B.COAST, with_creatures)
	CrossingCreatures.attach(crossing, F.COAST, B.COAST, [_booby(1.0)] as Array[CreatureData])
	assert_eq(crossing.plan.to_array(), first.to_array(), "the same beats with the creature roll after it")
	assert_eq(CrossingPlan.roll(route, B.COAST, WeatherManager.sky, with_creatures, tuning).to_array(), second.to_array(), "and the next crossing's plan is unchanged too")


func _session() -> CoopSession:
	var session := CrossingRig.make_session(self, 1)
	session.creature_catalog = ContentCatalog.new(FIXTURES)
	return session


# The fixture booby with its crossing rule at `chance`.
func _booby(chance: float) -> CreatureData:
	var data := (ContentCatalog.new(FIXTURES).get_entry(&"creatures", &"pajaro_bobo_prueba") as CreatureData).duplicate() as CreatureData
	data.spawn_rules = [_rule(chance)] as Array[CreatureSpawnRuleData]
	return data


func test_a_solo_crossing_places_a_sure_booby_at_the_north_edge_and_drops_it_at_the_end() -> void:
	var session := CrossingRig.make_session(self, 1)
	var spawner := CreatureSpawner.new()
	session.add_child(spawner)
	spawner.setup(session, SANDBAR)
	spawner.spawn_permanent()
	var island_count := spawner.creatures().size()
	session.creature_catalog = ContentCatalog.new(FIXTURES)
	var crossing := CrossingRig.launch_on(session, &"raft", [1] as Array[int], 100.0, 90.0)
	var riders := CrossingCreatures.attach(crossing, F.COAST, B.COAST, [_booby(1.0)] as Array[CreatureData])
	assert_not_null(riders)
	if riders == null:
		return
	var boobies := riders.creatures()
	assert_eq(boobies.size(), 1, "one booby rides along")
	if boobies.is_empty():
		return
	var booby := boobies[0]
	assert_eq(booby.data.id, &"pajaro_bobo_prueba")
	assert_eq(booby.get_parent(), session.entities, "through the session's entity spawner")
	assert_true(booby.is_passing())
	assert_almost_eq(booby.position.y, crossing.sea_rect().position.y + CrossingCreatures.EDGE_INSET_PX, 0.01, "at the sea's north edge")
	assert_true(crossing.deck_rect().grow(4.0).has_point(booby.nest), "its station is by the deck")
	assert_eq(spawner.creatures().size(), island_count, "the island never counts it")
	assert_eq(session.run_record.creature_count(&"pajaro_bobo_prueba"), 1, "the run counts it")
	CrossingRig.run(crossing, 90.0)
	assert_true(crossing.finished)
	assert_true(booby.is_queued_for_deletion(), "gone when the crossing ends")

