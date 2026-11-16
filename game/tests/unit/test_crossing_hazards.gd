extends GutTest
## crossing "Scrolling hazards", "Hazards and swimmers" and "Board hits" with exactly 1 player
## (and a row of 3 boards): a rock in line hits an idle raft as before, paddling clear dodges it, a
## rock out of line passes, debris takes 5, a swimmer under a rock is cut and bleeds, a swimmer
## who swims clear is not, and a row of boards is hit only where it overlaps.

const K := CrossingBeat.Kind
const EPS: float = 0.2


func after_each() -> void:
	FixtureRoutes.take_out()


func _east_edge(crossing: Crossing, body: PlayerBody) -> void:
	var deck := crossing.deck_rect()
	body.global_position = Vector2(deck.end.x - 4.0, deck.get_center().y)


func test_solo_leaves_a_rock_in_line_alone_and_takes_it() -> void:
	var crossing := CrossingRig.make(self, &"raft", 1, 100.0, 60.0, [CrossingRig.beat(30.0, K.ROCK)])
	CrossingRig.run(crossing, 30.0)
	assert_eq(crossing.integrity.value, 60.0)


func test_solo_dodges_a_rock() -> void:
	var crossing := CrossingRig.make(self, &"raft", 1, 100.0, 60.0, [CrossingBeat.create(30.0, K.ROCK, 0)])
	var body := crossing.body_of(1)
	CrossingRig.run(crossing, 27.0)
	_east_edge(crossing, body)
	body.intent = MoveIntent.create(Vector2.ZERO, false, false, true)
	CrossingRig.run(crossing, 3.1)
	assert_gt(crossing.steer.position, 3.0, "the raft is clear of the rock's lane")
	assert_eq(crossing.integrity.value, 100.0, "the rock passes it")


func test_the_rock_is_seen_coming() -> void:
	var crossing := CrossingRig.make(self, &"raft", 1, 100.0, 60.0, [CrossingBeat.create(30.0, K.ROCK, 2)])
	CrossingRig.run(crossing, 25.0)
	var beat := crossing.plan.events[0] as CrossingBeat
	var at := crossing.beat_center(beat)
	assert_almost_eq(at.y, crossing.sea_rect().position.y, 1.0, "at the sea's north edge 5 s before")
	assert_almost_eq(at.x, crossing.deck_center().x + 2.0 * Crossing.TILE_PX, 0.01, "2 tiles east of the line")
	assert_true(crossing.beat_on_sea(beat))


func test_a_rock_out_of_line_passes_by() -> void:
	var crossing := CrossingRig.make(self, &"raft", 1, 100.0, 60.0, [CrossingBeat.create(30.0, K.ROCK, 4)])
	CrossingRig.run(crossing, 31.0)
	assert_eq(crossing.integrity.value, 100.0)


func test_debris_holes_the_raft() -> void:
	var crossing := CrossingRig.make(self, &"raft", 1, 100.0, 60.0, [CrossingBeat.create(20.0, K.DEBRIS, 1)])
	CrossingRig.run(crossing, 20.0)
	assert_eq(crossing.integrity.value, 95.0)


func test_debris_out_of_line_misses() -> void:
	var crossing := CrossingRig.make(self, &"raft", 1, 100.0, 60.0, [CrossingBeat.create(20.0, K.DEBRIS, 3)])
	CrossingRig.run(crossing, 21.0)
	assert_eq(crossing.integrity.value, 100.0, "half the raft (2) plus half the debris (0.5) is under 3")


func test_solo_swimmer_cut_by_a_rock() -> void:
	var crossing := CrossingRig.make(self, &"binoculars_swim", 1, 0.0, 60.0, [CrossingBeat.create(30.0, K.ROCK, 0)])
	var body := crossing.body_of(1)
	CrossingRig.run(crossing, 25.0)
	body.global_position = crossing.deck_center()
	var health: float = body.meters.health
	CrossingRig.run(crossing, 6.0)
	assert_eq(body.meters.health, health - 15.0, "cut once by the rock passing over")
	assert_true(body.meters.has_status(DataEnums.Status.BLEEDING), "and bleeding")


func test_solo_swimmer_swims_clear() -> void:
	var crossing := CrossingRig.make(self, &"binoculars_swim", 1, 0.0, 60.0, [CrossingBeat.create(30.0, K.ROCK, 0)])
	var body := crossing.body_of(1)
	CrossingRig.run(crossing, 25.0)
	body.global_position = crossing.deck_center() + Vector2(3.0 * Crossing.TILE_PX, 0.0)
	var health: float = body.meters.health
	CrossingRig.run(crossing, 6.0)
	assert_eq(body.meters.health, health)
	assert_false(body.meters.has_status(DataEnums.Status.BLEEDING))


func test_debris_cuts_a_swimmer_less() -> void:
	var crossing := CrossingRig.make(self, &"binoculars_swim", 1, 0.0, 60.0, [CrossingBeat.create(30.0, K.DEBRIS, 0)])
	var body := crossing.body_of(1)
	CrossingRig.run(crossing, 25.0)
	body.global_position = crossing.deck_center()
	var health: float = body.meters.health
	CrossingRig.run(crossing, 6.0)
	assert_eq(body.meters.health, health - 5.0)
	assert_false(body.meters.has_status(DataEnums.Status.BLEEDING))


func test_a_rock_beside_the_row_misses_every_board() -> void:
	FixtureRoutes.put_in()
	var crossing := CrossingRig.make(self, &"test_board", 3, 60.0, 60.0, [CrossingBeat.create(30.0, K.ROCK, 6)])
	CrossingRig.run(crossing, 31.0)
	for peer: int in [1, 2, 3]:
		assert_eq(crossing.boards[peer].value, 60.0)


func test_a_rock_on_the_row_goes_round_the_boards() -> void:
	FixtureRoutes.put_in()
	var crossing := CrossingRig.make(self, &"test_board", 3, 60.0, 60.0, [CrossingBeat.create(30.0, K.ROCK, 0), CrossingBeat.create(40.0, K.ROCK, -2)])
	CrossingRig.run(crossing, 41.0)
	assert_eq(crossing.boards[1].value, 20.0, "the first rock takes the first board")
	assert_eq(crossing.boards[2].value, 20.0, "the second takes the next")
	assert_eq(crossing.boards[3].value, 60.0)


func test_the_reef_line_with_its_gap_east() -> void:
	# crossing "Crossing pacing": solo steers through the reef line, while a raft left alone takes it.
	var reef: Array[RefCounted] = [CrossingBeat.create(56.0, K.ROCK, -2), CrossingBeat.create(56.0, K.ROCK, 8)]
	var idle := CrossingRig.make(self, &"raft", 1, 100.0, 60.0, reef)
	CrossingRig.run(idle, 57.0)
	assert_eq(idle.integrity.value, 60.0, "left on the line it takes the west rock")
	var reef2: Array[RefCounted] = [CrossingBeat.create(56.0, K.ROCK, -2), CrossingBeat.create(56.0, K.ROCK, 8)]
	var steered := CrossingRig.make(self, &"raft", 1, 100.0, 60.0, reef2)
	var body := steered.body_of(1)
	CrossingRig.run(steered, 52.0)
	_east_edge(steered, body)
	body.intent = MoveIntent.create(Vector2.ZERO, false, false, true)
	CrossingRig.run(steered, 2.0)
	body.intent = MoveIntent.new()
	CrossingRig.run(steered, 2.0)
	assert_almost_eq(steered.steer.position, 2.0, 0.4, "near the gap at lane 3")
	assert_eq(steered.integrity.value, 100.0, "both reef rocks pass")


func test_the_hazards_node_draws_the_rock_coming() -> void:
	var crossing := CrossingRig.make(self, &"raft", 1, 100.0, 60.0, [CrossingBeat.create(30.0, K.ROCK, 2)])
	var hazards := crossing.get_node_or_null("Hazards") as CrossingHazards
	assert_not_null(hazards, "the crossing scene has its hazards drawing")
	CrossingRig.run(crossing, 20.0)
	assert_eq(hazards.shown_beats().size(), 0, "nothing on the sea 10 s before")
	CrossingRig.run(crossing, 5.0)
	var shown := hazards.shown_beats()
	assert_eq(shown.size(), 1, "the rock shows 5 s before")
	var at: Vector2 = shown[0][1]
	assert_almost_eq(at.y, crossing.sea_rect().position.y, 1.0, "at the north edge")
	assert_almost_eq(at.x, crossing.deck_center().x + 32.0, 0.01, "in lane 2")
	assert_eq(hazards.z_index, -30, "over the sea, under the deck")
