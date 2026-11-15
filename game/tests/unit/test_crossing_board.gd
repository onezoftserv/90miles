extends GutTest
## crossing "Per-rider boards", "Board hits", "Shark dumps" and "Board rescue" (vessel-car-board),
## with in-process riders on the `test_board` fixture route: one board each at 60, no lashing, a
## squall on every board, rocks and sharks taking the boards in turn, a 3 s climb back onto one's
## own board or a teammate's 2 s pull.

const SQUALL := CrossingBeat.Kind.SQUALL
const ROCK := CrossingBeat.Kind.ROCK
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


func _boards(crossing: Crossing, players: int) -> Array[float]:
	var values: Array[float] = []
	for peer: int in range(1, players + 1):
		values.append(crossing.boards[peer].value)
	return values


# Puts `body` in the water just beside its own board's right edge.
func _beside_own_board(crossing: Crossing, peer: int, gap_px: float) -> void:
	var board := crossing.deck_rect_of(peer)
	crossing.body_of(peer).global_position = Vector2(board.end.x + gap_px, board.get_center().y)


# --- Per-rider boards -----------------------------------------------------------------------------

func test_solo_rider_on_one_board() -> void:
	var crossing := CrossingRig.make(self, &"test_board", 1, 0.0, 90.0)
	assert_true(crossing.is_board_route())
	assert_eq(crossing.boards.size(), 1)
	assert_eq(crossing.boards[1].value, 60.0)
	assert_eq(crossing.boards[1].maximum, 60.0)
	assert_eq(crossing.rider_state(1), Crossing.Rider.ABOARD)
	assert_false(crossing.integrity.has_integrity(), "no shared vessel")
	assert_true(crossing.deck_rect_of(1).has_point(crossing.body_of(1).global_position), "standing on the board")
	assert_eq(crossing.deck_rect_of(1).size, Vector2(16.0, 32.0), "a 1x2-tile board")
	assert_eq(crossing.vessel_of(1), crossing.boards[1])
	crossing.tie(1)
	assert_eq(crossing.rider_state(1), Crossing.Rider.ABOARD, "no lashing to tie down to")
	for child: Node in crossing.get_children():
		if child is RescuePoint:
			assert_ne((child as RescuePoint).kind, RescuePoint.Kind.LASH, "no lashing point")
	CrossingRig.run(crossing, 1.0)
	assert_eq(crossing.rider_state(1), Crossing.Rider.ABOARD, "the board holds its rider")


func test_boards_sit_apart_in_a_row() -> void:
	var crossing := CrossingRig.make(self, &"test_board", 4, 0.0, 90.0)
	var sea := crossing.sea_rect()
	for peer: int in range(1, 5):
		var board := crossing.deck_rect_of(peer)
		assert_true(sea.encloses(board), "board %d inside the sea" % peer)
		assert_eq(crossing.sea.terrain_at(Vector2i((board.get_center() / Crossing.TILE_PX).floor())), DataEnums.Terrain.BEACH, "board %d stands" % peer)
		if peer > 1:
			assert_eq(board.position.x - crossing.deck_rect_of(peer - 1).position.x, 48.0, "3 tiles apart")
		assert_eq(crossing.rider_state(peer), Crossing.Rider.ABOARD)


func test_a_squall_on_three_boards() -> void:
	var crossing := CrossingRig.make(self, &"test_board", 3, 0.0, 90.0, _beats([[1.0, SQUALL]]))
	CrossingRig.run(crossing, 1.1)
	assert_eq(_boards(crossing, 3), [30.0, 30.0, 30.0] as Array[float])
	for peer: int in range(1, 4):
		assert_eq(crossing.rider_state(peer), Crossing.Rider.IN_WATER, "rider %d in the water" % peer)


func test_solo_board_breaks_and_cannot_be_climbed() -> void:
	var crossing := CrossingRig.make(self, &"test_board", 1, 0.0, 90.0, _beats([[1.0, ROCK], [2.0, SHARK]]))
	CrossingRig.run(crossing, 2.1)
	assert_eq(crossing.boards[1].value, 0.0)
	assert_true(crossing.boards[1].broken)
	assert_eq(crossing.rider_state(1), Crossing.Rider.IN_WATER)
	var body := crossing.body_of(1)
	_beside_own_board(crossing, 1, 4.0)
	CrossingRig.hold(crossing, body, 3.5)
	assert_eq(crossing.rider_state(1), Crossing.Rider.IN_WATER, "a broken board cannot be climbed")


func test_one_board_breaks_and_the_other_rides_on() -> void:
	var crossing := CrossingRig.make(self, &"test_board", 2, 0.0, 90.0, _beats([[1.0, ROCK]]))
	crossing.boards[1].value = 40.0
	CrossingRig.run(crossing, 1.1)
	assert_true(crossing.boards[1].broken)
	assert_eq(crossing.rider_state(1), Crossing.Rider.IN_WATER)
	assert_eq(crossing.boards[2].value, 60.0)
	assert_eq(crossing.rider_state(2), Crossing.Rider.ABOARD)
	CrossingRig.run(crossing, 1.0)
	assert_eq(crossing.rider_state(2), Crossing.Rider.ABOARD, "the other board's cells still stand")
	var sunk := Vector2i((crossing.deck_rect_of(1).get_center() / Crossing.TILE_PX).floor())
	assert_eq(crossing.sea.terrain_at(sunk), DataEnums.Terrain.DEEP, "the broken board sank")


# --- Board hits -----------------------------------------------------------------------------------

func test_hits_go_round_the_boards() -> void:
	var crossing := CrossingRig.make(self, &"test_board", 3, 0.0, 90.0, _beats([[1.0, ROCK], [2.0, SHARK]]))
	CrossingRig.run(crossing, 2.1)
	assert_eq(_boards(crossing, 3), [20.0, 40.0, 60.0] as Array[float])


func test_a_broken_board_is_skipped() -> void:
	var crossing := CrossingRig.make(self, &"test_board", 2, 0.0, 90.0, _beats([[1.0, ROCK]]))
	crossing.boards[1].hit(60.0)
	var swimmer := crossing.body_of(1)
	swimmer.meters.energy = 50.0
	assert_eq(crossing.rider_state(1), Crossing.Rider.IN_WATER)
	CrossingRig.run(crossing, 1.1)
	assert_eq(crossing.boards[2].value, 20.0)
	assert_eq(swimmer.meters.health, 100.0, "the swimmer is untouched")
	assert_false(swimmer.meters.has_status(DataEnums.Status.BLEEDING))


func test_with_no_board_left_a_hit_hits_nothing() -> void:
	var crossing := CrossingRig.make(self, &"test_board", 1, 0.0, 90.0)
	crossing.boards[1].hit(60.0)
	assert_eq(crossing.hit_vessel(20.0), crossing.deck_center())
	assert_eq(crossing.boards[1].value, 0.0)


func test_hit_vessel_returns_the_hit_boards_centre() -> void:
	var crossing := CrossingRig.make(self, &"test_board", 2, 0.0, 90.0)
	assert_eq(crossing.hit_vessel(10.0), crossing.deck_rect_of(1).get_center())
	assert_eq(crossing.hit_vessel(10.0), crossing.deck_rect_of(2).get_center())


# --- Shark dumps on a board -----------------------------------------------------------------------

func test_solo_rider_dumped_by_a_shark_climbs_back() -> void:
	var crossing := CrossingRig.make(self, &"test_board", 1, 0.0, 90.0, _beats([[1.0, SHARK]]))
	var body := crossing.body_of(1)
	body.meters.energy = 80.0
	CrossingRig.run(crossing, 1.0)
	assert_eq(crossing.boards[1].value, 40.0)
	assert_eq(crossing.rider_state(1), Crossing.Rider.IN_WATER)
	assert_almost_eq(body.meters.energy, 70.0, 0.5, "fell in for 10")
	assert_false(crossing.deck_rect_of(1).has_point(body.global_position), "pushed off the board")
	CrossingRig.hold(crossing, body, 3.0)
	assert_eq(crossing.rider_state(1), Crossing.Rider.ABOARD, "back aboard with no teammate")
	assert_true(crossing.deck_rect_of(1).has_point(body.global_position))


func test_a_shark_dumps_only_the_hit_boards_rider() -> void:
	var crossing := CrossingRig.make(self, &"test_board", 2, 0.0, 90.0, _beats([[1.0, SHARK]]))
	CrossingRig.run(crossing, 1.1)
	assert_eq(crossing.rider_state(1), Crossing.Rider.IN_WATER)
	assert_eq(crossing.rider_state(2), Crossing.Rider.ABOARD)


# --- Board rescue ---------------------------------------------------------------------------------

func test_releasing_early_does_not_climb_a_board() -> void:
	var crossing := CrossingRig.make(self, &"test_board", 1, 0.0, 90.0)
	var body := crossing.body_of(1)
	crossing.boards[1].value = 40.0
	crossing.throw_in(1)
	_beside_own_board(crossing, 1, 8.0)
	CrossingRig.hold(crossing, body, 2.0)
	CrossingRig.release(crossing, body)
	assert_eq(crossing.rider_state(1), Crossing.Rider.IN_WATER)
	CrossingRig.hold(crossing, body, 3.0)
	assert_eq(crossing.rider_state(1), Crossing.Rider.ABOARD)


func test_a_teammate_pulls_a_rider_onto_their_own_board() -> void:
	var crossing := CrossingRig.make(self, &"test_board", 2, 0.0, 90.0)
	crossing.throw_in(2)
	var puller := crossing.body_of(1)
	crossing.body_of(2).global_position = puller.global_position + Vector2(14.0, 0.0)
	CrossingRig.hold(crossing, puller, 1.9)
	assert_eq(crossing.rider_state(2), Crossing.Rider.IN_WATER)
	CrossingRig.hold(crossing, puller, 0.1)
	assert_eq(crossing.rider_state(2), Crossing.Rider.ABOARD)
	assert_true(crossing.deck_rect_of(2).has_point(crossing.body_of(2).global_position), "on their own board")
	assert_eq(crossing.rider_state(1), Crossing.Rider.ABOARD)
	assert_true(crossing.deck_rect_of(1).has_point(puller.global_position), "the puller is still on theirs")


func test_no_pull_onto_a_broken_board() -> void:
	var crossing := CrossingRig.make(self, &"test_board", 2, 0.0, 90.0)
	crossing.boards[2].hit(60.0)
	var puller := crossing.body_of(1)
	crossing.body_of(2).global_position = puller.global_position + Vector2(14.0, 0.0)
	CrossingRig.hold(crossing, puller, 2.5)
	assert_eq(crossing.rider_state(2), Crossing.Rider.IN_WATER)


func test_a_swimmer_cannot_climb_a_teammates_board() -> void:
	var crossing := CrossingRig.make(self, &"test_board", 2, 0.0, 90.0)
	crossing.boards[2].hit(60.0)
	var swimmer := crossing.body_of(2)
	var other := crossing.deck_rect_of(1)
	swimmer.global_position = Vector2(other.end.x + 2.0, other.get_center().y)
	CrossingRig.hold(crossing, swimmer, 3.5)
	assert_eq(crossing.rider_state(2), Crossing.Rider.IN_WATER)


func test_a_swimmer_cannot_walk_onto_any_board() -> void:
	var crossing := CrossingRig.make(self, &"test_board", 2, 0.0, 90.0)
	crossing.throw_in(2)
	var swimmer := crossing.body_of(2)
	swimmer.global_position = crossing.deck_rect_of(1).get_center()
	CrossingRig.run(crossing, 0.1)
	assert_false(crossing.deck_rect_of(1).has_point(swimmer.global_position))
	assert_eq(crossing.rider_state(2), Crossing.Rider.IN_WATER)


func test_a_rejoined_rider_keeps_their_board() -> void:
	var crossing := CrossingRig.make(self, &"test_board", 2, 0.0, 90.0)
	crossing.hit_vessel(20.0)
	crossing.hit_vessel(20.0)
	var board := crossing.boards[2]
	var spot := crossing.deck_rect_of(2)
	crossing.session()._rebind_body(2, 7)
	assert_false(crossing.boards.has(2))
	assert_eq(crossing.boards[7], board)
	assert_eq(crossing.boards[7].value, 40.0)
	assert_eq(crossing.deck_rect_of(7), spot, "the same board, the same place")
	assert_eq(crossing.rider_state(7), Crossing.Rider.ABOARD)
	crossing.boards[7].hit(40.0)
	assert_eq(crossing.boards[7].value, 0.0)
	var sunk := Vector2i((spot.get_center() / Crossing.TILE_PX).floor())
	assert_eq(crossing.sea.terrain_at(sunk), DataEnums.Terrain.DEEP, "the rejoined rider's board sinks where it was")
