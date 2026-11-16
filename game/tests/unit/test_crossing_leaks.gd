extends GutTest
## crossing "Leaks" and "Raft integrity on the crossing" with exactly 1 player, offline: debris opens
## a leak that drains 0.5 a second until a 2 s hold plugs it, letting go early does not plug, a
## fourth hole opens nothing, a leak can finish a raft, and a board rider plugs their own board.

const K := CrossingBeat.Kind


func after_each() -> void:
	FixtureRoutes.take_out()


# `body` stands on leak `leak`.
func _on_leak(crossing: Crossing, body: PlayerBody, leak: Dictionary) -> void:
	body.global_position = crossing.leak_position(leak)


func test_an_unplugged_leak_drains_the_raft() -> void:
	var crossing := CrossingRig.make(self, &"raft", 1, 100.0, 60.0, [CrossingBeat.create(20.0, K.DEBRIS, 1)])
	CrossingRig.run(crossing, 20.0)
	assert_eq(crossing.integrity.value, 95.0, "the debris takes 5")
	assert_eq(crossing.leaks.list.size(), 1, "and opens a leak")
	assert_gt(float(crossing.leaks.list[0]["x"]), 0.0, "on the east half, nearer the debris in lane 1")
	var hazards := crossing.get_node("Hazards") as CrossingHazards
	assert_eq(hazards.shown_leaks(), [crossing.leak_position(crossing.leaks.list[0])] as Array[Vector2], "drawn where it is")
	CrossingRig.run(crossing, 10.0)
	assert_almost_eq(crossing.integrity.value, 90.0, 0.06, "0.5 a second for 10 s")


func test_solo_plugs_a_leak() -> void:
	var crossing := CrossingRig.make(self, &"raft", 1, 100.0, 60.0, [CrossingBeat.create(20.0, K.DEBRIS, 1)])
	var body := crossing.body_of(1)
	CrossingRig.run(crossing, 22.0)
	_on_leak(crossing, body, crossing.leaks.list[0])
	CrossingRig.hold(crossing, body, 2.1)
	CrossingRig.release(crossing, body)
	assert_eq(crossing.leaks.list.size(), 0, "plugged")
	CrossingRig.run(crossing, 30.0 - crossing.elapsed_s)
	assert_almost_eq(crossing.integrity.value, 93.0, 0.15, "it drained 2 s before the plug")


func test_letting_go_early_does_not_plug() -> void:
	var crossing := CrossingRig.make(self, &"raft", 1, 100.0, 60.0, [CrossingBeat.create(5.0, K.DEBRIS, 0)])
	var body := crossing.body_of(1)
	CrossingRig.run(crossing, 6.0)
	_on_leak(crossing, body, crossing.leaks.list[0])
	CrossingRig.hold(crossing, body, 1.5)
	CrossingRig.release(crossing, body)
	assert_eq(crossing.leaks.list.size(), 1, "still open after 1.5 s")
	CrossingRig.hold(crossing, body, 2.1)
	CrossingRig.release(crossing, body)
	assert_eq(crossing.leaks.list.size(), 0, "plugged after a whole 2 s")


func test_a_fourth_hole_opens_nothing() -> void:
	var beats: Array[RefCounted] = [
		CrossingBeat.create(5.0, K.DEBRIS, 0), CrossingBeat.create(6.0, K.DEBRIS, 0),
		CrossingBeat.create(7.0, K.DEBRIS, 1), CrossingBeat.create(8.0, K.DEBRIS, 1),
	]
	var crossing := CrossingRig.make(self, &"raft", 1, 100.0, 60.0, beats)
	CrossingRig.run(crossing, 7.0)
	assert_eq(crossing.leaks.list.size(), 3)
	var before: float = crossing.integrity.value
	CrossingRig.run(crossing, 1.0)
	assert_eq(crossing.leaks.list.size(), 3, "still 3 open leaks")
	assert_almost_eq(crossing.integrity.value, before - 5.0 - 1.5, 0.1, "the hit took 5, the three leaks 1.5 over the second")


func test_a_leak_finishes_a_raft() -> void:
	var crossing := CrossingRig.make(self, &"raft", 1, 100.0, 60.0, [CrossingBeat.create(5.0, K.DEBRIS, 0)])
	CrossingRig.run(crossing, 5.0)
	crossing.integrity.value = 3.0
	CrossingRig.run(crossing, 6.1)
	assert_true(crossing.integrity.broken, "the raft broke")
	assert_eq(crossing.rider_state(1), Crossing.Rider.IN_WATER)
	assert_eq(crossing.leaks.list.size(), 0, "the leaks went down with it")


func test_a_board_rider_plugs_their_own_board() -> void:
	FixtureRoutes.put_in()
	var crossing := CrossingRig.make(self, &"test_board", 1, 60.0, 60.0, [CrossingBeat.create(5.0, K.DEBRIS, 0)])
	var body := crossing.body_of(1)
	CrossingRig.run(crossing, 5.0)
	assert_eq(crossing.boards[1].value, 55.0)
	assert_eq(crossing.leaks.count_on(1), 1, "the leak is on the board")
	_on_leak(crossing, body, crossing.leaks.list[0])
	CrossingRig.hold(crossing, body, 2.1)
	CrossingRig.release(crossing, body)
	assert_eq(crossing.leaks.list.size(), 0)
	assert_almost_eq(crossing.boards[1].value, 54.0, 0.15)


func test_a_tied_rider_cannot_plug() -> void:
	var crossing := CrossingRig.make(self, &"raft", 1, 100.0, 60.0, [CrossingBeat.create(5.0, K.DEBRIS, 0)])
	var body := crossing.body_of(1)
	CrossingRig.hold(crossing, body, 1.0)
	CrossingRig.release(crossing, body)
	assert_eq(crossing.rider_state(1), Crossing.Rider.TIED)
	CrossingRig.run(crossing, 6.0 - crossing.elapsed_s)
	CrossingRig.hold(crossing, body, 2.1)
	CrossingRig.release(crossing, body)
	assert_eq(crossing.leaks.list.size(), 1, "a tied rider keeps only untying")


func test_solo_plugs_before_paddling() -> void:
	# crossing "Which job a press takes": at the east edge with the paddle and a leak in reach.
	var crossing := CrossingRig.make(self, &"raft", 1, 100.0, 60.0, [CrossingBeat.create(5.0, K.DEBRIS, 1)])
	var body := crossing.body_of(1)
	CrossingRig.run(crossing, 6.0)
	var deck := crossing.deck_rect()
	body.global_position = Vector2(deck.end.x - 10.0, crossing.leak_position(crossing.leaks.list[0]).y)
	CrossingRig.hold(crossing, body, 2.1)
	CrossingRig.release(crossing, body)
	assert_eq(crossing.leaks.list.size(), 0, "the press plugged the leak")
	assert_eq(crossing.steer.position, 0.0, "and the raft has not moved")
