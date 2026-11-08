extends GutTest
## crossing "Rescue timing": a teammate pulls in 2 s, a lone swimmer climbs in 3 s, nobody boards a
## broken raft, and a swimmer with no energy drowns.

const ROCK := CrossingBeat.Kind.ROCK


func before_each() -> void:
	NetManager.start_solo()
	WeatherManager.stop()
	WeatherManager.sky.start_at(0.0)


func after_each() -> void:
	NetManager.leave()


func test_teammate_pulls_in_2s() -> void:
	var crossing := CrossingRig.make(self, &"raft", 2, 60.0, 90.0)
	crossing.throw_in(2)
	CrossingRig.put_beside_deck(crossing, crossing.body_of(2), 1.0)
	crossing.body_of(1).global_position = crossing.body_of(2).global_position - Vector2(6.0, 0.0)
	CrossingRig.hold(crossing, crossing.body_of(1), 1.9)
	assert_eq(crossing.rider_state(2), Crossing.Rider.IN_WATER)
	CrossingRig.hold(crossing, crossing.body_of(1), 0.1)
	assert_eq(crossing.rider_state(2), Crossing.Rider.ABOARD)
	assert_true(crossing.deck_rect().has_point(crossing.body_of(2).global_position))


func test_solo_climbs_in_3s_and_2s_does_not() -> void:
	var crossing := CrossingRig.make(self, &"raft", 1, 60.0, 90.0)
	var body := crossing.body_of(1)
	crossing.throw_in(1)
	CrossingRig.put_beside_deck(crossing, body, 8.0)
	CrossingRig.hold(crossing, body, 2.0)
	CrossingRig.release(crossing, body)
	assert_eq(crossing.rider_state(1), Crossing.Rider.IN_WATER)
	assert_eq(body.interaction_hold.progress_s, 0.0)
	CrossingRig.hold(crossing, body, 3.0)
	assert_eq(crossing.rider_state(1), Crossing.Rider.ABOARD)


func test_a_swimmer_beyond_one_tile_cannot_climb() -> void:
	var crossing := CrossingRig.make(self, &"raft", 1, 60.0, 90.0)
	var body := crossing.body_of(1)
	crossing.throw_in(1)
	CrossingRig.put_beside_deck(crossing, body, 20.0)
	CrossingRig.hold(crossing, body, 3.5)
	assert_eq(crossing.rider_state(1), Crossing.Rider.IN_WATER)


func test_a_climb_point_belongs_to_its_swimmer() -> void:
	var crossing := CrossingRig.make(self, &"raft", 2, 60.0, 90.0)
	crossing.throw_in(1)
	crossing.throw_in(2)
	CrossingRig.put_beside_deck(crossing, crossing.body_of(1), 1.0)
	CrossingRig.put_beside_deck(crossing, crossing.body_of(2), 1.0)
	crossing.body_of(2).global_position.y += 3.0
	CrossingRig.hold(crossing, crossing.body_of(1), 3.1)
	assert_eq(crossing.rider_state(1), Crossing.Rider.ABOARD, "climbed alone")
	assert_eq(crossing.rider_state(2), Crossing.Rider.IN_WATER, "their own point is not offered to others")


func test_cannot_climb_broken_raft() -> void:
	var crossing := CrossingRig.make(self, &"raft", 1, 40.0, 90.0, [CrossingRig.beat(0.5, ROCK)])
	var body := crossing.body_of(1)
	CrossingRig.run(crossing, 0.6)
	assert_true(crossing.integrity.broken)
	CrossingRig.put_beside_deck(crossing, body, 4.0)
	CrossingRig.hold(crossing, body, 3.5)
	assert_eq(crossing.rider_state(1), Crossing.Rider.IN_WATER)


func test_drowning_at_zero_energy() -> void:
	var crossing := CrossingRig.make(self, &"raft", 1, 60.0, 90.0)
	var body := crossing.body_of(1)
	body.meters.energy = 0.0
	crossing.throw_in(1)
	CrossingRig.run(crossing, 5.0)
	assert_almost_eq(body.meters.health, 50.0, 0.01)
	assert_eq(body.movement_state, MovementStep.Move.FLOAT)


func test_a_swimmer_cannot_walk_onto_the_deck() -> void:
	var crossing := CrossingRig.make(self, &"raft", 1, 60.0, 90.0)
	crossing.throw_in(1)
	crossing.body_of(1).global_position = crossing.deck_rect().get_center()
	CrossingRig.run(crossing, 0.1)
	assert_false(crossing.deck_rect().has_point(crossing.body_of(1).global_position))
