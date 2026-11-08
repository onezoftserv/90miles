extends GutTest
## crossing-late-join, offline: a crossing under way as a snapshot (what a joiner receives), the
## checks on a snapshot that arrived over the network, and a crossing restored from one in another
## session, as a joiner builds it. Two sessions in one tree stand in for host and joiner.

const SQUALL := CrossingBeat.Kind.SQUALL
const SERIAL: int = 3
const ELAPSED_S: float = 20.0

var rng := RandomNumberGenerator.new()


func before_each() -> void:
	NetManager.start_solo()
	WeatherManager.stop()
	WeatherManager.sky.start_at(0.0)


func after_each() -> void:
	WeatherManager.stop()
	NetManager.leave()


# A raft crossing numbered SERIAL for riders 1 and 2, ELAPSED_S in: the raft at 70 of 100, rider 1
# tied down and rider 2 in the water 6 px off the deck.
func _under_way() -> Crossing:
	var session := CrossingRig.make_session(self, 2)
	var crossing := _crossing_on(session, &"raft", [1, 2] as Array[int], 100.0, SERIAL)
	CrossingRig.run(crossing, ELAPSED_S)
	crossing.hit_vessel(30.0)
	crossing.tie(1)
	crossing.throw_in(2)
	CrossingRig.put_beside_deck(crossing, crossing.body_of(2), 6.0)
	return crossing


func _crossing_on(session: CoopSession, route_id: StringName, ids: Array[int], integrity: float, serial: int) -> Crossing:
	var route := GameState.content.get_entry(&"routes", route_id) as RouteData
	var crossing := Crossing.SCENE.instantiate() as Crossing
	crossing.name = "Crossing%d" % serial
	session.add_child(crossing)
	var beats: Array[RefCounted] = [CrossingRig.beat(60.0, SQUALL)]
	crossing.setup(session, route, ids, integrity, CrossingPlan.create(90.0, beats), serial)
	crossing.advance(0.0)
	return crossing


# What arrives on a joiner: the dictionary after a trip through the wire encoding.
func _over_the_wire(snapshot: CrossingSnapshot) -> Variant:
	return bytes_to_var(var_to_bytes(snapshot.to_dict()))


func _restored_in_new_session(snapshot: CrossingSnapshot, players: int = 2) -> Crossing:
	var joiner := CrossingRig.make_session(self, players)
	return Crossing.restore(joiner, CrossingSnapshot.from_dict(_over_the_wire(snapshot)))


# --- the snapshot -------------------------------------------------------------------------------

func test_a_snapshot_keeps_the_crossing_as_it_is() -> void:
	var crossing := _under_way()
	var received := CrossingSnapshot.from_dict(_over_the_wire(CrossingSnapshot.of(crossing)))
	assert_not_null(received)
	if received == null:
		return
	assert_eq(received.serial, SERIAL)
	assert_eq(received.route_id, &"raft")
	assert_eq(received.riders, [1, 2] as Array[int], "slot order")
	assert_eq(received.plan.to_array(), crossing.plan.to_array())
	assert_almost_eq(received.elapsed_s, ELAPSED_S, 0.001)
	assert_eq(received.maximum, 100.0, "the raft's maximum")
	assert_eq(received.value, 70.0, "apart from its value")
	assert_false(received.broken)
	assert_eq(received.states[1], Crossing.Rider.TIED)
	assert_eq(received.states[2], Crossing.Rider.IN_WATER)
	assert_eq(received.positions[2], crossing.body_of(2).global_position)


func test_slot_order_is_kept() -> void:
	var session := CrossingRig.make_session(self, 3)
	var crossing := _crossing_on(session, &"raft", [3, 1, 2] as Array[int], 100.0, 0)
	assert_eq(CrossingSnapshot.of(crossing).riders, [3, 1, 2] as Array[int])


func test_a_broken_raft_stays_broken() -> void:
	var crossing := _under_way()
	crossing.hit_vessel(100.0)
	var received := CrossingSnapshot.from_dict(_over_the_wire(CrossingSnapshot.of(crossing)))
	assert_true(received.broken)
	assert_eq(received.value, 0.0)


func test_a_malformed_snapshot_is_refused() -> void:
	var good: Dictionary = _over_the_wire(CrossingSnapshot.of(_under_way()))
	assert_not_null(CrossingSnapshot.from_dict(good), "the unchanged dictionary is accepted")
	var cases: Dictionary = {
		"negative serial": ["serial", -1],
		"serial as text": ["serial", "3"],
		"unknown route": ["route", "no_such_route"],
		"route not text": ["route", 7],
		"no riders": ["riders", []],
		"five riders": ["riders", [1, 2, 3, 4, 5]],
		"a rider twice": ["riders", [1, 1]],
		"a rider not a peer": ["riders", [1, "2"]],
		"a peer id below 1": ["riders", [1, 0]],
		"malformed plan": ["plan", [1.0]],
		"time not finite": ["elapsed_s", INF],
		"time not a number": ["elapsed_s", NAN],
		"maximum not finite": ["maximum", INF],
		"value not a number": ["value", NAN],
		"broken not a bool": ["broken", 1],
		"a state out of range": ["states", {1: 99, 2: 2}],
		"a negative state": ["states", {1: -1, 2: 2}],
		"a rider without a state": ["states", {1: 1}],
		"a position not finite": ["positions", {1: Vector2(INF, 0.0)}],
		"positions not a dictionary": ["positions", []],
	}
	for label: String in cases:
		var bad: Dictionary = good.duplicate(true)
		bad[cases[label][0]] = cases[label][1]
		assert_null(CrossingSnapshot.from_dict(bad), label)
	for key: String in good:
		var missing: Dictionary = good.duplicate(true)
		missing.erase(key)
		assert_null(CrossingSnapshot.from_dict(missing), "without %s" % key)
	assert_null(CrossingSnapshot.from_dict([]), "not a dictionary")


func test_out_of_range_numbers_are_clamped() -> void:
	var good: Dictionary = _over_the_wire(CrossingSnapshot.of(_under_way()))
	good["value"] = 500.0
	good["elapsed_s"] = 1000.0
	good["states"][7] = 1
	var received := CrossingSnapshot.from_dict(good)
	assert_eq(received.value, 100.0, "never above the maximum")
	assert_eq(received.elapsed_s, 90.0, "never past the plan's end")
	assert_false(received.states.has(7), "only riders keep a state")


# --- the restore --------------------------------------------------------------------------------

func test_a_joiner_builds_the_crossing_from_the_snapshot() -> void:
	var host_crossing := _under_way()
	var restored := _restored_in_new_session(CrossingSnapshot.of(host_crossing))
	assert_not_null(restored)
	if restored == null:
		return
	assert_eq(String(restored.name), "Crossing%d" % SERIAL)
	assert_eq(restored.origin, host_crossing.origin, "the same sea")
	assert_eq(restored.peers(), [1, 2] as Array[int])
	assert_eq(restored.route.id, &"raft")
	assert_eq(restored.plan.to_array(), host_crossing.plan.to_array())
	assert_almost_eq(restored.elapsed_s, ELAPSED_S, 0.001)
	assert_eq(restored.integrity.maximum, 100.0)
	assert_eq(restored.integrity.value, 70.0)
	assert_eq(restored.rider_state(1), Crossing.Rider.TIED)
	assert_eq(restored.rider_state(2), Crossing.Rider.IN_WATER)


func test_the_riders_are_in_the_sea_where_the_host_has_them() -> void:
	var host_crossing := _under_way()
	var restored := _restored_in_new_session(CrossingSnapshot.of(host_crossing))
	var rect := restored.sea_rect()
	for peer: int in [1, 2]:
		var body := restored.body_of(peer)
		assert_same(body.terrain, restored.sea, "rider %d on sea ground" % peer)
		assert_eq(body.global_position, host_crossing.body_of(peer).global_position, "rider %d where the host has them" % peer)
		assert_eq(body.camera.limit_left, int(rect.position.x))
		assert_eq(body.camera.limit_top, int(rect.position.y))
		assert_eq(body.camera.limit_right, int(rect.end.x))
		assert_eq(body.camera.limit_bottom, int(rect.end.y))
	assert_true(restored.body_of(1).pinned, "the tied rider is pinned")
	assert_false(restored.body_of(2).pinned)


func test_a_position_outside_the_sea_is_kept_inside() -> void:
	var host_crossing := _under_way()
	var snapshot := CrossingSnapshot.of(host_crossing)
	snapshot.positions[2] = Vector2(-90000.0, 0.0)
	var restored := _restored_in_new_session(snapshot)
	assert_true(restored.sea_rect().has_point(restored.body_of(2).global_position))


func test_restoring_twice_keeps_one_crossing() -> void:
	var snapshot := CrossingSnapshot.of(_under_way())
	var joiner := CrossingRig.make_session(self, 2)
	var first := Crossing.restore(joiner, snapshot)
	snapshot.states[2] = Crossing.Rider.ABOARD
	snapshot.value = 50.0
	var second := Crossing.restore(joiner, snapshot)
	assert_same(second, first, "the crossing already there is refreshed")
	var count: int = 0
	for child: Node in joiner.get_children():
		if child is Crossing:
			count += 1
	assert_eq(count, 1)
	assert_eq(first.rider_state(2), Crossing.Rider.ABOARD)
	assert_eq(first.integrity.value, 50.0)


func test_a_restored_crossing_fires_nothing_that_already_happened() -> void:
	var session := CrossingRig.make_session(self, 1)
	var early: Array[RefCounted] = [CrossingRig.beat(10.0, SQUALL)]
	var crossing := CrossingRig.launch_on(session, &"raft", [1] as Array[int], 100.0, 90.0, early)
	CrossingRig.run(crossing, ELAPSED_S)
	var snapshot := CrossingSnapshot.of(crossing)
	snapshot.serial = SERIAL
	var restored := _restored_in_new_session(snapshot, 1)
	restored.advance(0.1)
	assert_eq(restored.integrity.value, crossing.integrity.value, "the squall at 10 s is not replayed")


func test_following_the_hosts_serial_names_the_next_crossing_alike() -> void:
	var joiner := CrossingRig.make_session(self, 1)
	Crossing.follow_serial(joiner, 4)
	Crossing.follow_serial(joiner, 2)
	var route := GameState.content.get_entry(&"routes", &"raft") as RouteData
	var next := Crossing.launch(joiner, route, [1] as Array[int], 100.0, DataEnums.DistanceBand.COAST, rng)
	assert_eq(String(next.name), "Crossing4", "the counter only moves up")


func test_a_restore_without_a_snapshot_builds_nothing() -> void:
	var joiner := CrossingRig.make_session(self, 1)
	assert_null(Crossing.restore(joiner, null))


# --- 1 player, offline --------------------------------------------------------------------------

func test_solo_swimmer_restores_at_its_elapsed_time() -> void:
	var source := CrossingRig.make_session(self, 1)
	var swim := _crossing_on(source, &"binoculars_swim", [1] as Array[int], 0.0, 0)
	CrossingRig.run(swim, 30.0)
	var restored := _restored_in_new_session(CrossingSnapshot.of(swim), 1)
	assert_almost_eq(restored.elapsed_s, 30.0, 0.001)
	assert_false(restored.integrity.has_integrity(), "swimmers have no vessel")
	assert_eq(restored.rider_state(1), Crossing.Rider.IN_WATER)
	assert_same(restored.body_of(1).terrain, restored.sea)
