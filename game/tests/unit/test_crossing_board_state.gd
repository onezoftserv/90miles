extends GutTest
## crossing "Board crossing state" (vessel-car-board), offline: a board crossing's snapshot keeps
## every board by rider and is checked like the rest of a snapshot, a joiner restores the boards
## (a broken one gone), a resync carries them, and the result holds each rider's board. Two
## sessions in one tree stand in for host and joiner, as in test_crossing_snapshot.gd.

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


# A board crossing for riders 1 and 2, 10 s in: rider 1's board at 20 after a rock, rider 2's
# broken and rider 2 in the water.
func _under_way() -> Crossing:
	var session := CrossingRig.make_session(self, 2)
	var crossing := CrossingRig.launch_on(session, &"test_board", [1, 2] as Array[int], 0.0, 90.0)
	CrossingRig.run(crossing, 10.0)
	crossing.hit_vessel(40.0)
	crossing.hit_vessel(60.0)
	return crossing


# What arrives on a joiner: the dictionary after a trip through the wire encoding.
func _over_the_wire(snapshot: CrossingSnapshot) -> Variant:
	return bytes_to_var(var_to_bytes(snapshot.to_dict()))


func _restored(host_crossing: Crossing) -> Crossing:
	var joiner := CrossingRig.make_session(self, 2)
	return Crossing.restore(joiner, CrossingSnapshot.from_dict(_over_the_wire(CrossingSnapshot.of(host_crossing))))


func _cell_of(rect: Rect2) -> Vector2i:
	return Vector2i((rect.get_center() / Crossing.TILE_PX).floor())


# --- the snapshot -------------------------------------------------------------------------------

func test_a_board_snapshot_keeps_every_board() -> void:
	var crossing := _under_way()
	assert_eq(crossing.boards[1].value, 20.0)
	assert_true(crossing.boards[2].broken)
	var received := CrossingSnapshot.from_dict(_over_the_wire(CrossingSnapshot.of(crossing)))
	assert_not_null(received)
	if received == null:
		return
	assert_eq(received.boards.size(), 2)
	assert_eq(received.boards.get(1), 20.0)
	assert_eq(received.boards.get(2), 0.0, "0 is a broken board")
	assert_eq(received.maximum, 0.0, "no shared vessel")


func test_a_raft_snapshot_has_no_boards() -> void:
	var session := CrossingRig.make_session(self, 1)
	var crossing := CrossingRig.launch_on(session, &"raft", [1] as Array[int], 100.0, 90.0)
	var received := CrossingSnapshot.from_dict(_over_the_wire(CrossingSnapshot.of(crossing)))
	assert_not_null(received)
	assert_true(received.boards.is_empty())


func test_malformed_boards_are_refused() -> void:
	var good: Dictionary = _over_the_wire(CrossingSnapshot.of(_under_way()))
	assert_not_null(CrossingSnapshot.from_dict(good), "the unchanged dictionary is accepted")
	var cases: Dictionary = {
		"a board not finite": {1: INF, 2: 0.0},
		"a board not a number": {1: NAN, 2: 0.0},
		"a board as text": {1: "20", 2: 0.0},
		"a board keyed by text": {"1": 20.0},
		"boards not a dictionary": [],
	}
	for label: String in cases:
		var bad: Dictionary = good.duplicate(true)
		bad["boards"] = cases[label]
		assert_null(CrossingSnapshot.from_dict(bad), label)
	var missing: Dictionary = good.duplicate(true)
	missing.erase("boards")
	assert_null(CrossingSnapshot.from_dict(missing), "without boards")


func test_board_values_are_clamped_and_only_riders_keep_one() -> void:
	var good: Dictionary = _over_the_wire(CrossingSnapshot.of(_under_way()))
	good["boards"] = {1: 500.0, 2: -5.0, 9: 30.0}
	var received := CrossingSnapshot.from_dict(good)
	assert_not_null(received)
	if received == null:
		return
	assert_eq(received.boards.get(1), 60.0, "never above the route's board")
	assert_eq(received.boards.get(2), 0.0, "never below 0")
	assert_false(received.boards.has(9), "only riders keep a board")


# --- the restore and the resync -----------------------------------------------------------------

func test_a_joiner_sees_a_broken_board_as_gone() -> void:
	var host_crossing := _under_way()
	var restored := _restored(host_crossing)
	assert_not_null(restored)
	if restored == null:
		return
	assert_true(restored.is_board_route())
	assert_eq(restored.boards[1].value, 20.0)
	assert_false(restored.boards[1].broken)
	assert_true(restored.boards[2].broken, "the broken board is gone")
	assert_eq(restored.sea.terrain_at(_cell_of(restored.deck_rect_of(1))), DataEnums.Terrain.BEACH)
	assert_eq(restored.sea.terrain_at(_cell_of(restored.deck_rect_of(2))), DataEnums.Terrain.DEEP)
	assert_eq(restored.rider_state(2), Crossing.Rider.IN_WATER)
	assert_eq(restored.body_of(2).global_position, host_crossing.body_of(2).global_position, "where the host has them")


func test_a_resync_carries_the_boards() -> void:
	var restored := _restored(_under_way())
	restored._apply_state({}, 0.0, 12.0, {1: 10.0, 2: 0.0})
	assert_eq(restored.boards[1].value, 10.0)
	restored._apply_state({}, 0.0, 13.0, {1: 0.0, 2: 0.0})
	assert_true(restored.boards[1].broken)
	assert_eq(restored.sea.terrain_at(_cell_of(restored.deck_rect_of(1))), DataEnums.Terrain.DEEP)


func test_a_resync_ignores_bad_board_values() -> void:
	var restored := _restored(_under_way())
	restored._apply_state({}, 0.0, 12.0, {1: NAN, 7: 5.0, "1": 1.0})
	assert_eq(restored.boards[1].value, 20.0)
	assert_false(restored.boards.has(7))


func test_a_raft_resync_without_boards_is_unchanged() -> void:
	var session := CrossingRig.make_session(self, 1)
	var crossing := CrossingRig.launch_on(session, &"raft", [1] as Array[int], 100.0, 90.0)
	crossing._apply_state({}, 70.0, 5.0)
	assert_eq(crossing.integrity.value, 70.0)
	assert_true(crossing.boards.is_empty())


# --- the result ---------------------------------------------------------------------------------

func test_solo_result_holds_the_board() -> void:
	var crossing := CrossingRig.make(self, &"test_board", 1, 0.0, 30.0, [CrossingRig.beat(1.0, SHARK)])
	var body := crossing.body_of(1)
	CrossingRig.run(crossing, 1.1)
	assert_eq(crossing.rider_state(1), Crossing.Rider.IN_WATER, "the shark dumped them")
	CrossingRig.hold(crossing, body, 3.0)
	CrossingRig.release(crossing, body)
	assert_eq(crossing.rider_state(1), Crossing.Rider.ABOARD)
	CrossingRig.run(crossing, 30.0)
	assert_true(crossing.finished)
	var ended := crossing.result
	assert_eq(ended.integrity, 0.0, "no shared vessel")
	assert_false(ended.broken)
	assert_eq(ended.riders[1].get("board"), 40.0)
	assert_eq(ended.riders[1].get("board_broken"), false)
	assert_eq(ended.riders[1].get("aboard"), true)
	assert_eq(ended.riders[1].get("dead"), false)
	var back := CrossingResult.from_dict(bytes_to_var(var_to_bytes(ended.to_dict())))
	assert_eq(back.riders[1].get("board"), 40.0, "it travels with the result")


func test_a_broken_board_in_the_result() -> void:
	var crossing := CrossingRig.make(self, &"test_board", 1, 0.0, 5.0)
	crossing.boards[1].hit(60.0)
	CrossingRig.run(crossing, 5.0)
	assert_eq(crossing.result.riders[1].get("board"), 0.0)
	assert_eq(crossing.result.riders[1].get("board_broken"), true)
	assert_eq(crossing.result.riders[1].get("aboard"), false)


func test_a_raft_result_has_no_board() -> void:
	var crossing := CrossingRig.make(self, &"raft", 1, 100.0, 5.0)
	CrossingRig.run(crossing, 5.0)
	assert_false(crossing.result.riders[1].has("board"))
	assert_false(crossing.result.riders[1].has("board_broken"))
