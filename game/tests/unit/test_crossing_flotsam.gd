extends GutTest
## crossing "Flotsam" with exactly 1 player, offline: a rider at the deck edge takes a piece passing
## within reach, a piece out of reach passes by, a plank mends the raft up to the route's full
## integrity, a full inventory leaves the piece in the sea, and a swimmer takes a piece by touch.

const K := CrossingBeat.Kind

var tuning: CrossingTuning


func before_each() -> void:
	tuning = CrossingTuning.standard()


func _piece(id: StringName) -> int:
	return tuning.flotsam_items.find(id)


func _east_edge(crossing: Crossing, body: PlayerBody) -> void:
	var deck := crossing.deck_rect()
	body.global_position = Vector2(deck.end.x - 1.0, deck.get_center().y)


# Holds interact from `from_s` for `hold_s`, then lets go.
func _hold_at(crossing: Crossing, body: PlayerBody, from_s: float, hold_s: float) -> void:
	CrossingRig.run(crossing, from_s - crossing.elapsed_s)
	CrossingRig.hold(crossing, body, hold_s)
	CrossingRig.release(crossing, body)


func test_solo_grabs_a_coconut() -> void:
	var crossing := CrossingRig.make(self, &"raft", 1, 100.0, 60.0, [CrossingBeat.create(40.0, K.FLOTSAM, 3, _piece(&"coco"))])
	var body := crossing.body_of(1)
	var before: int = body.inventory.count_id(&"coco")
	_east_edge(crossing, body)
	_hold_at(crossing, body, 39.8, 0.5)
	assert_eq(body.inventory.count_id(&"coco"), before + 1, "one more coconut")
	assert_true(crossing.taken.has(0))
	assert_false(crossing.beat_shown(crossing.plan.beat_at(0)), "the piece is gone from the sea")


func test_out_of_reach() -> void:
	var crossing := CrossingRig.make(self, &"raft", 1, 100.0, 60.0, [CrossingBeat.create(40.0, K.FLOTSAM, 6, _piece(&"rope"))])
	var body := crossing.body_of(1)
	var before: int = body.inventory.count_id(&"rope")
	_east_edge(crossing, body)
	_hold_at(crossing, body, 39.8, 0.5)
	assert_eq(body.inventory.count_id(&"rope"), before, "the rope passes by")
	assert_false(crossing.taken.has(0))


func test_solo_lashes_a_plank() -> void:
	var beats: Array[RefCounted] = [
		CrossingBeat.create(20.0, K.FLOTSAM, 3, _piece(CrossingTuning.PLANK_ID)),
		CrossingBeat.create(40.0, K.FLOTSAM, 3, _piece(CrossingTuning.PLANK_ID)),
	]
	var crossing := CrossingRig.make(self, &"raft", 1, 70.0, 60.0, beats)
	var body := crossing.body_of(1)
	assert_eq(crossing.integrity.maximum, 100.0, "a raft launched at 70 can be mended to the route's 100")
	_east_edge(crossing, body)
	_hold_at(crossing, body, 19.8, 0.5)
	assert_eq(crossing.integrity.value, 80.0)
	crossing.integrity.value = 95.0
	_hold_at(crossing, body, 39.8, 0.5)
	assert_eq(crossing.integrity.value, 100.0, "no higher than 100")


func test_a_full_inventory_leaves_the_piece() -> void:
	var crossing := CrossingRig.make(self, &"raft", 1, 100.0, 60.0, [CrossingBeat.create(40.0, K.FLOTSAM, 3, _piece(&"driftwood"))])
	var body := crossing.body_of(1)
	while body.inventory.add(&"driftwood", 1) > 0:
		pass
	var before: int = body.inventory.count_id(&"driftwood")
	_east_edge(crossing, body)
	_hold_at(crossing, body, 39.8, 0.5)
	assert_eq(body.inventory.count_id(&"driftwood"), before)
	assert_false(crossing.taken.has(0), "the driftwood stays in the sea")


func test_a_swimmer_touches_a_piece() -> void:
	var crossing := CrossingRig.make(self, &"raft", 1, 100.0, 60.0, [CrossingBeat.create(40.0, K.FLOTSAM, 3, _piece(&"rope"))])
	var body := crossing.body_of(1)
	var before: int = body.inventory.count_id(&"rope")
	CrossingRig.run(crossing, 30.0)
	crossing.throw_in(1)
	body.global_position = crossing.deck_center() + Vector2(3.0 * Crossing.TILE_PX, 0.0)
	CrossingRig.run(crossing, 11.0)
	assert_eq(body.inventory.count_id(&"rope"), before + 1, "the swimmer took the rope")
	assert_true(crossing.taken.has(0))


func test_a_tied_rider_cannot_grab() -> void:
	var crossing := CrossingRig.make(self, &"raft", 1, 100.0, 60.0, [CrossingBeat.create(40.0, K.FLOTSAM, 3, _piece(&"coco"))])
	var body := crossing.body_of(1)
	CrossingRig.hold(crossing, body, 1.0)
	CrossingRig.release(crossing, body)
	assert_eq(crossing.rider_state(1), Crossing.Rider.TIED)
	_hold_at(crossing, body, 39.8, 0.5)
	assert_false(crossing.taken.has(0))


func test_two_riders_reach_for_one_coconut() -> void:
	var crossing := CrossingRig.make(self, &"raft", 2, 100.0, 60.0, [CrossingBeat.create(40.0, K.FLOTSAM, 3, _piece(&"coco"))])
	var first := crossing.body_of(1)
	var second := crossing.body_of(2)
	_east_edge(crossing, first)
	_east_edge(crossing, second)
	var before_first: int = first.inventory.count_id(&"coco")
	var before_second: int = second.inventory.count_id(&"coco")
	CrossingRig.run(crossing, 39.8)
	second.intent = MoveIntent.create(Vector2.ZERO, false, false, true)
	CrossingRig.run(crossing, 0.1)
	first.intent = MoveIntent.create(Vector2.ZERO, false, false, true)
	CrossingRig.run(crossing, 0.5)
	first.intent = MoveIntent.new()
	second.intent = MoveIntent.new()
	assert_eq(second.inventory.count_id(&"coco"), before_second + 1, "the hold that completed first gets it")
	assert_eq(first.inventory.count_id(&"coco"), before_first, "the other gets nothing")
