extends GutTest
## crossing "Squall line on the crossing", "Tying down" and "Falling in": the squall hits the raft,
## throws in whoever is not tied, and a broken raft throws in everyone.

const SQUALL := CrossingBeat.Kind.SQUALL
const ROCK := CrossingBeat.Kind.ROCK


func before_each() -> void:
	NetManager.start_solo()
	WeatherManager.stop()
	WeatherManager.sky.start_at(0.0)


func after_each() -> void:
	WeatherManager.stop()
	NetManager.leave()


func _beats(list: Array) -> Array[RefCounted]:
	var beats: Array[RefCounted] = []
	for pair: Array in list:
		beats.append(CrossingRig.beat(pair[0], pair[1]))
	return beats


func test_warning_comes_60s_ahead() -> void:
	var crossing := CrossingRig.make(self, &"raft", 1, 100.0, 90.0, _beats([[10.0, CrossingBeat.Kind.SQUALL_WARN], [70.0, SQUALL]]))
	watch_signals(WeatherManager)
	CrossingRig.run(crossing, 9.9)
	assert_signal_not_emitted(WeatherManager, "weather_warned")
	assert_false(WeatherManager.sky.horizon_line_visible())
	CrossingRig.run(crossing, 0.1)
	assert_signal_emitted_with_parameters(WeatherManager, "weather_warned", [&"squall", 60.0])
	assert_true(WeatherManager.sky.horizon_line_visible())
	CrossingRig.run(crossing, 59.9)
	assert_eq(crossing.integrity.value, 100.0, "not hit before 70 s")
	CrossingRig.run(crossing, 0.2)
	assert_eq(crossing.integrity.value, 70.0)


func test_tied_player_not_thrown_in() -> void:
	var crossing := CrossingRig.make(self, &"raft", 2, 100.0, 90.0, _beats([[1.0, SQUALL]]))
	crossing.tie(1)
	CrossingRig.run(crossing, 1.1)
	assert_eq(crossing.integrity.value, 70.0)
	assert_eq(crossing.rider_state(1), Crossing.Rider.TIED)
	assert_eq(crossing.rider_state(2), Crossing.Rider.IN_WATER)
	assert_true(crossing.body_of(1).pinned, "a tied rider cannot move")


func test_squall_rock_squall_everyone_falls_in() -> void:
	var crossing := CrossingRig.make(self, &"raft", 2, 100.0, 90.0, _beats([[1.0, SQUALL], [2.0, ROCK], [3.0, SQUALL]]))
	crossing.tie(1)
	CrossingRig.run(crossing, 3.1)
	assert_eq(crossing.integrity.value, 0.0)
	assert_true(crossing.integrity.broken)
	assert_eq(crossing.rider_state(1), Crossing.Rider.IN_WATER, "the tied one too")
	assert_eq(crossing.rider_state(2), Crossing.Rider.IN_WATER)
	assert_false(crossing.body_of(1).pinned)
	for node: Node in get_tree().get_nodes_in_group(Interactable.GROUP):
		if node is RescuePoint:
			assert_false((node as RescuePoint).enabled, "nobody can climb or be pulled back")


func test_solo_squall_throws_in_the_lone_untied_player() -> void:
	var crossing := CrossingRig.make(self, &"raft", 1, 100.0, 90.0, _beats([[1.0, SQUALL]]))
	CrossingRig.run(crossing, 1.1)
	assert_eq(crossing.integrity.value, 70.0)
	assert_eq(crossing.rider_state(1), Crossing.Rider.IN_WATER)


func test_thrown_in_costs_energy() -> void:
	var crossing := CrossingRig.make(self, &"raft", 2, 100.0, 90.0, _beats([[0.95, SQUALL]]))
	crossing.tie(1)
	crossing.body_of(2).meters.energy = 80.0
	CrossingRig.run(crossing, 1.0)
	assert_almost_eq(crossing.body_of(2).meters.energy, 70.0 - 0.3, 0.01, "10 for the fall, then 3/s")
	CrossingRig.run(crossing, 4.9)
	assert_almost_eq(crossing.body_of(2).meters.energy, 55.0, 0.01)


func test_swim_route_riders_start_in_the_water_and_take_no_hits() -> void:
	var crossing := CrossingRig.make(self, &"binoculars_swim", 1, 0.0, 60.0, _beats([[1.0, ROCK]]))
	assert_eq(crossing.rider_state(1), Crossing.Rider.IN_WATER)
	assert_false(crossing.integrity.has_integrity())
	CrossingRig.run(crossing, 1.1)
	assert_false(crossing.integrity.broken)
	assert_almost_eq(crossing.body_of(1).meters.energy, 100.0 - 1.1 * 3.0 * 0.4, 0.01, "no fall-in cost")
