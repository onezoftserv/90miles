extends GutTest
## The almendrón flotante on the crossing (vessel-car-board design D3), on the `test_car` fixture
## route: the car is the raft's shared-vessel path with the car's numbers, integrity 160 and the
## squall times 1.5, its 4x2 deck and its lashing. Solo, offline.

const SQUALL := CrossingBeat.Kind.SQUALL
const SHARK := CrossingBeat.Kind.SHARK_PASS


func before_each() -> void:
	NetManager.start_solo()
	WeatherManager.stop()
	WeatherManager.sky.start_at(0.0)
	FixtureRoutes.put_in()


func after_each() -> void:
	WeatherManager.stop()
	NetManager.leave()
	FixtureRoutes.take_out()


func _beats(list: Array) -> Array[RefCounted]:
	var beats: Array[RefCounted] = []
	for pair: Array in list:
		beats.append(CrossingRig.beat(pair[0], pair[1]))
	return beats


func test_the_car_is_one_shared_vessel_with_a_lashing() -> void:
	var crossing := CrossingRig.make(self, &"test_car", 1, 0.0, 90.0)
	assert_false(crossing.is_board_route())
	assert_true(crossing.boards.is_empty())
	assert_eq(crossing.integrity.maximum, 160.0, "the route's integrity")
	assert_eq(crossing.deck_rect().size, Vector2(Crossing.DECK_TILES) * Crossing.TILE_PX)
	assert_eq(crossing.vessel_of(1), crossing.integrity)
	assert_eq(crossing.rider_state(1), Crossing.Rider.ABOARD)


func test_solo_car_through_a_squall_and_a_shark() -> void:
	var crossing := CrossingRig.make(self, &"test_car", 1, 0.0, 90.0, _beats([[1.0, SQUALL], [2.0, SHARK]]))
	crossing.tie(1)
	CrossingRig.run(crossing, 1.1)
	assert_eq(crossing.integrity.value, 115.0, "the squall hits 30 x 1.5")
	CrossingRig.run(crossing, 1.0)
	assert_eq(crossing.integrity.value, 95.0, "160 - 45 - 20")
	assert_false(crossing.integrity.broken)


func test_the_cars_lashing_holds_a_solo_rider_through_a_squall() -> void:
	var crossing := CrossingRig.make(self, &"test_car", 1, 0.0, 90.0, _beats([[1.0, SQUALL]]))
	crossing.tie(1)
	assert_eq(crossing.rider_state(1), Crossing.Rider.TIED)
	CrossingRig.run(crossing, 1.1)
	assert_eq(crossing.rider_state(1), Crossing.Rider.TIED, "tied down, not thrown in")


func test_an_untied_rider_goes_over_the_side_in_a_squall() -> void:
	var crossing := CrossingRig.make(self, &"test_car", 1, 0.0, 90.0, _beats([[1.0, SQUALL]]))
	CrossingRig.run(crossing, 1.1)
	assert_eq(crossing.rider_state(1), Crossing.Rider.IN_WATER)


func test_a_rolled_car_plan_stays_within_its_duration() -> void:
	var route := GameState.content.get_entry(&"routes", &"test_car") as RouteData
	var tuning := CrossingTuning.standard()
	for seed_value: int in 60:
		var rng := RandomNumberGenerator.new()
		rng.seed = seed_value
		var plan := CrossingPlan.roll(route, DataEnums.DistanceBand.COAST, WeatherManager.sky, rng, tuning)
		assert_between(plan.length_s, 60.0, 90.0, "seed %d" % seed_value)
