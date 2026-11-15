extends GutTest
## guardacostas-stealth, group 6 (design.md decision 7): the trigger rules, pure. Distance to the
## sea on the two real islands (the measured table), the smoke rule by night, dawn, dusk and day,
## once per fire per lap, the noise rule, the water rule, fog, and a boat that is not in sight.
## Tiles everywhere except a fire's pixel position; a land cell's centre is (x + 0.5, y + 0.5).

const SANDBAR: IslandLayoutData = preload("res://resources/islands/sandbar.tres")
const COAST_CAY: IslandLayoutData = preload("res://resources/islands/coast_cay.tres")
const FIXTURES: String = "res://tests/fixtures/content"
const TOLERANCE: float = 0.000001
const TILE: float = 16.0
const NIGHT := DataEnums.DayPhase.NIGHT
const DAY := DataEnums.DayPhase.DAY
const DAWN := DataEnums.DayPhase.DAWN
const DUSK := DataEnums.DayPhase.DUSK
const NO_SENSES: Array[DataEnums.Sense] = []

var triggers: PatrolTriggers
var fires: Array[Node2D] = []


func before_each() -> void:
	fires = []
	triggers = _on_square()


func _patrol() -> PatrolData:
	return (GameState.content.get_entry(&"creatures", &"patrol_boat") as CreatureData).patrol


# A 20x20 beach at cells 10..29 on deep water: a cell's distance to the sea is its distance to the
# nearest edge column or row, counted from the sea cell beside the beach (x - 9, 30 - x, ...).
func _on_square() -> PatrolTriggers:
	var terrain := GridTerrain.new()
	terrain.default_terrain = DataEnums.Terrain.DEEP
	terrain.fill_rect(Rect2i(0, 0, 40, 40), DataEnums.Terrain.DEEP)
	terrain.fill_rect(Rect2i(10, 10, 20, 20), DataEnums.Terrain.BEACH)
	return PatrolTriggers.build(terrain, Vector2i(40, 40), _patrol())


func _real(layout: IslandLayoutData) -> PatrolTriggers:
	var built := IslandLayout.build(layout)
	return PatrolTriggers.build(built.terrain, built.size, _patrol())


# A fire node in cell (x, y), `fires` keeps it; `shaded` puts a roof over its cell.
func _fire(x: int, shaded: bool = false, y: int = 20) -> Node2D:
	var fire := Node2D.new()
	autofree(fire)
	fire.position = Vector2(x + 0.5, y + 0.5) * TILE
	fires.append(fire)
	if shaded:
		(triggers._terrain as GridTerrain).set_shaded(Rect2i(x, y, 1, 1))
	return fire


# --- the distance to the sea ---------------------------------------------------------------------

func test_the_sandbar_matches_the_measured_distances() -> void:
	var sandbar := _real(SANDBAR)
	assert_almost_eq(sandbar.farthest_land_tiles(), 5.7, 0.05)
	assert_eq(sandbar.land_beyond(2.0), 617)
	assert_eq(sandbar.land_beyond(3.0), 413)
	assert_eq(sandbar.land_beyond(6.0), 0)


func test_the_coast_cay_matches_the_measured_distances() -> void:
	var cay := _real(COAST_CAY)
	assert_almost_eq(cay.farthest_land_tiles(), 6.3, 0.05)
	assert_eq(cay.land_beyond(2.0), 632)
	assert_eq(cay.land_beyond(3.0), 436)
	assert_eq(cay.land_beyond(6.0), 2)


func test_the_coast_cay_lagoon_is_not_sea() -> void:
	var built := IslandLayout.build(COAST_CAY)
	var cay := PatrolTriggers.build(built.terrain, built.size, _patrol())
	var lagoon: int = 0
	var open: int = 0
	for cell: Vector2i in built.terrain.cells:
		match built.terrain.terrain_at(cell):
			DataEnums.Terrain.BRACKISH:
				lagoon += 1
				assert_false(cay.is_sea(cell), "brackish %s is not sea" % cell)
			DataEnums.Terrain.DEEP:
				open += 1
				assert_true(cay.is_sea(cell) or cay.distance_at(cell) == 0.0)
	assert_gt(lagoon, 0, "the coast cay has a lagoon")
	assert_gt(open, 0)
	assert_true(cay.is_sea(Vector2i(0, 0)), "the map edge is sea")


func test_distance_on_a_hand_built_island() -> void:
	assert_almost_eq(triggers.distance_at(Vector2i(10, 20)), 1.0, TOLERANCE)
	assert_almost_eq(triggers.distance_at(Vector2i(13, 20)), 4.0, TOLERANCE)
	assert_almost_eq(triggers.distance_at(Vector2i(10, 10)), 1.0, TOLERANCE)
	assert_almost_eq(triggers.distance_at(Vector2i(0, 0)), 0.0, TOLERANCE, "water is not land")


func test_enclosed_water_is_not_sea() -> void:
	var terrain := GridTerrain.new()
	terrain.default_terrain = DataEnums.Terrain.DEEP
	terrain.fill_rect(Rect2i(0, 0, 40, 40), DataEnums.Terrain.DEEP)
	terrain.fill_rect(Rect2i(10, 10, 20, 20), DataEnums.Terrain.BEACH)
	terrain.fill_rect(Rect2i(18, 18, 4, 4), DataEnums.Terrain.SHALLOWS)
	var island := PatrolTriggers.build(terrain, Vector2i(40, 40), _patrol())
	assert_false(island.is_sea(Vector2i(19, 19)), "a pond the land encloses")
	assert_true(island.is_sea(Vector2i(5, 5)))


# --- smoke ---------------------------------------------------------------------------------------

func test_at_night_a_fire_1_tile_from_the_sea_alerts_and_one_4_tiles_away_does_not() -> void:
	var near := _fire(10)
	var far := _fire(13)
	var roofed := _fire(10, true, 25)
	var alerts := triggers.smoke_alerts(fires, NIGHT, true)
	assert_true(alerts.has(near))
	assert_false(alerts.has(far))
	assert_false(alerts.has(roofed), "a fire under a roof is hidden")
	assert_eq(alerts.size(), 1)


func test_a_fire_exactly_2_tiles_from_the_sea_alerts_at_night() -> void:
	var edge := _fire(11)
	assert_eq(triggers.smoke_alerts(fires, NIGHT, true), [edge] as Array[Node2D])


func test_by_day_a_fire_5_tiles_from_the_sea_alerts_and_one_7_tiles_away_does_not() -> void:
	var near := _fire(14)
	var far := _fire(16)
	var alerts := triggers.smoke_alerts(fires, DAY, true)
	assert_eq(alerts, [near] as Array[Node2D])
	assert_false(alerts.has(far))


func test_by_day_a_roof_does_not_hide_the_smoke() -> void:
	var covered := _fire(12, true)
	assert_eq(triggers.smoke_alerts(fires, DAY, true), [covered] as Array[Node2D])


func test_dawn_and_dusk_follow_the_night_rule() -> void:
	var near := _fire(10)
	var mid := _fire(14)
	for phase: DataEnums.DayPhase in [DAWN, DUSK]:
		triggers.begin_lap()
		var alerts := triggers.smoke_alerts(fires, phase, true)
		assert_eq(alerts, [near] as Array[Node2D], "phase %s" % phase)
		assert_false(alerts.has(mid))


func test_a_fire_alerts_once_per_lap() -> void:
	var near := _fire(10)
	assert_eq(triggers.smoke_alerts(fires, NIGHT, true).size(), 1)
	assert_eq(triggers.smoke_alerts(fires, NIGHT, true).size(), 0, "the same fire stays quiet")
	var second := _fire(11)
	assert_eq(triggers.smoke_alerts(fires, NIGHT, true), [second] as Array[Node2D], "a new fire alerts")
	triggers.begin_lap()
	var again := triggers.smoke_alerts(fires, NIGHT, true)
	assert_eq(again.size(), 2, "the next lap forgets")
	assert_true(again.has(near))


# --- noise ---------------------------------------------------------------------------------------

func test_noise_of_radius_15_is_heard_at_12_tiles_and_not_at_20() -> void:
	var boat := Vector2(10.0, 10.0)
	assert_true(triggers.noise_heard(boat, boat + Vector2(12.0, 0.0), 15.0, true))
	assert_false(triggers.noise_heard(boat, boat + Vector2(20.0, 0.0), 15.0, true))


func test_noise_of_radius_6_is_not_heard_even_at_3_tiles() -> void:
	var boat := Vector2(10.0, 10.0)
	assert_false(triggers.noise_heard(boat, boat + Vector2(3.0, 0.0), 6.0, true))


func test_noise_of_exactly_the_minimum_radius_is_heard_at_its_edge() -> void:
	var boat := Vector2(10.0, 10.0)
	assert_true(triggers.noise_heard(boat, boat + Vector2(8.0, 0.0), 8.0, true))
	assert_false(triggers.noise_heard(boat, boat + Vector2(8.1, 0.0), 8.0, true))
	assert_false(triggers.noise_heard(boat, boat + Vector2(1.0, 0.0), 7.9, true), "7.9 is below the minimum")


# --- water ---------------------------------------------------------------------------------------

func test_a_swimmer_5_tiles_away_is_spotted_and_a_diver_3_tiles_away_is_not() -> void:
	var boat := Vector2(10.0, 10.0)
	assert_true(triggers.water_spots(MovementStep.Move.SWIM, boat + Vector2(5.0, 0.0), boat, NO_SENSES, true))
	assert_false(triggers.water_spots(MovementStep.Move.DIVE, boat + Vector2(3.0, 0.0), boat, NO_SENSES, true))


func test_a_floater_5_tiles_away_is_spotted() -> void:
	var boat := Vector2(10.0, 10.0)
	assert_true(triggers.water_spots(MovementStep.Move.FLOAT, boat + Vector2(0.0, 5.0), boat, NO_SENSES, true))


func test_the_water_rule_ends_at_6_tiles_and_ignores_walkers() -> void:
	var boat := Vector2(10.0, 10.0)
	assert_true(triggers.water_spots(MovementStep.Move.SWIM, boat + Vector2(6.0, 0.0), boat, NO_SENSES, true))
	assert_false(triggers.water_spots(MovementStep.Move.SWIM, boat + Vector2(6.5, 0.0), boat, NO_SENSES, true))
	for walking: MovementStep.Move in [MovementStep.Move.WALK, MovementStep.Move.RUN, MovementStep.Move.CROUCH, MovementStep.Move.CRAWL]:
		assert_false(triggers.water_spots(walking, boat + Vector2(2.0, 0.0), boat, NO_SENSES, true))


func test_the_water_rule_is_off_in_fog() -> void:
	var fog := ContentCatalog.new(FIXTURES).get_entry(&"weather", &"fog_test") as WeatherData
	assert_true(fog.disabled_senses.has(DataEnums.Sense.SIGHT))
	var boat := Vector2(10.0, 10.0)
	assert_false(triggers.water_spots(MovementStep.Move.SWIM, boat + Vector2(2.0, 0.0), boat, fog.disabled_senses, true))


# --- out of sight --------------------------------------------------------------------------------

func test_a_boat_that_is_not_in_sight_never_triggers() -> void:
	var boat := Vector2(10.0, 10.0)
	var near := _fire(10)
	assert_eq(triggers.smoke_alerts(fires, NIGHT, false).size(), 0)
	assert_false(triggers.noise_heard(boat, boat, 15.0, false))
	assert_false(triggers.water_spots(MovementStep.Move.SWIM, boat, boat, NO_SENSES, false))
	assert_eq(triggers.smoke_alerts(fires, NIGHT, true), [near] as Array[Node2D], "nothing was remembered while it was out of sight")
