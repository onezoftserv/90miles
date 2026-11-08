extends GutTest
## coop-reconnect with crossing: a reclaimed body keeps the node name of the peer it first spawned
## under, so the crossing takes a rider's peer from the session, and its riders, their states and
## their rescue points follow the body to its new peer. Offline: peer 2 comes back as peer 9.

const FIRST_PEER: int = 2
const REJOINED: int = 9


func before_each() -> void:
	NetManager.start_solo()
	WeatherManager.stop()
	WeatherManager.sky.start_at(0.0)


func after_each() -> void:
	WeatherManager.stop()
	NetManager.leave()


# A raft crossing for the host and a player who rejoined before it started.
func _rejoined_before() -> Crossing:
	var session := CrossingRig.make_session(self, 2)
	session._rebind_body(FIRST_PEER, REJOINED)
	var ids: Array[int] = [1, REJOINED]
	return CrossingRig.launch_on(session, &"raft", ids, 60.0, 90.0)


# A raft crossing of `length_s` whose second rider drops and rejoins once it is under way.
func _rejoined_during(length_s: float = 90.0) -> Crossing:
	var crossing := CrossingRig.make(self, &"raft", 2, 60.0, length_s)
	(crossing.get_parent() as CoopSession)._rebind_body(FIRST_PEER, REJOINED)
	return crossing


func test_a_rider_who_rejoined_before_ties_down() -> void:
	var crossing := _rejoined_before()
	var body := crossing.body_of(REJOINED)
	assert_eq(String(body.name), str(FIRST_PEER), "the node keeps its first name")
	CrossingRig.hold(crossing, body, 1.0)
	assert_eq(crossing.rider_state(REJOINED), Crossing.Rider.TIED)


func test_a_rider_who_rejoined_before_climbs_by_their_own_point() -> void:
	var crossing := _rejoined_before()
	var body := crossing.body_of(REJOINED)
	crossing.throw_in(REJOINED)
	CrossingRig.put_beside_deck(crossing, body, 8.0)
	CrossingRig.hold(crossing, body, 3.0)
	assert_eq(crossing.rider_state(REJOINED), Crossing.Rider.ABOARD)


func test_a_rider_who_rejoins_during_keeps_their_place() -> void:
	var crossing := _rejoined_during()
	assert_eq(crossing.peers(), [1, REJOINED])
	assert_eq(crossing.rider_state(REJOINED), Crossing.Rider.ABOARD)
	assert_eq(crossing.rider_state(FIRST_PEER), Crossing.Rider.DEAD, "nothing left under the old peer")
	crossing.tie(REJOINED)
	assert_eq(crossing.rider_state(REJOINED), Crossing.Rider.TIED)


func test_a_rider_who_rejoins_in_the_water_climbs_back() -> void:
	var crossing := CrossingRig.make(self, &"raft", 2, 60.0, 90.0)
	crossing.throw_in(FIRST_PEER)
	(crossing.get_parent() as CoopSession)._rebind_body(FIRST_PEER, REJOINED)
	var body := crossing.body_of(REJOINED)
	CrossingRig.put_beside_deck(crossing, body, 8.0)
	CrossingRig.hold(crossing, body, 3.0)
	assert_eq(crossing.rider_state(REJOINED), Crossing.Rider.ABOARD)


func test_a_teammate_pulls_in_a_rider_who_rejoined_in_the_water() -> void:
	var crossing := CrossingRig.make(self, &"raft", 2, 60.0, 90.0)
	crossing.throw_in(FIRST_PEER)
	(crossing.get_parent() as CoopSession)._rebind_body(FIRST_PEER, REJOINED)
	var swimmer := crossing.body_of(REJOINED)
	CrossingRig.put_beside_deck(crossing, swimmer, 1.0)
	crossing.body_of(1).global_position = swimmer.global_position - Vector2(6.0, 0.0)
	CrossingRig.hold(crossing, crossing.body_of(1), 2.0)
	assert_eq(crossing.rider_state(REJOINED), Crossing.Rider.ABOARD)


func test_the_result_names_the_rider_by_their_current_peer() -> void:
	var crossing := _rejoined_during(5.0)
	CrossingRig.run(crossing, 5.0)
	assert_true(crossing.finished)
	if crossing.finished:
		assert_true(crossing.result.riders.has(REJOINED))
		assert_false(crossing.result.riders.has(FIRST_PEER))
