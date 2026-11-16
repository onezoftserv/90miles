extends GutTest
## crossing "Paddling", "Jobs aboard", "Coast drift", "Steering and current" (the blow) with 1 and 2
## riders, offline: holding a paddle slides the vessel toward its side, the current pulls it back to
## the line, two paddlers are faster, both sides cancel, it stops at 6 tiles, a tied rider and a
## swimmer cannot paddle, the squall's blow halves it, and it never counts as drift.

const K := CrossingBeat.Kind
const EPS: float = 0.25


func after_each() -> void:
	FixtureRoutes.take_out()
	WeatherManager.stop()
	NetManager.leave()
	if FileAccess.file_exists("user://test_crossing_paddle_settings.cfg"):
		DirAccess.remove_absolute(ProjectSettings.globalize_path("user://test_crossing_paddle_settings.cfg"))


# `body` stands at the `side` edge of the shared deck, on its paddle.
func _to_edge(crossing: Crossing, body: PlayerBody, side: int) -> void:
	var deck := crossing.deck_rect()
	var x: float = deck.end.x - 4.0 if side == CrossingSteer.EAST else deck.position.x + 4.0
	body.global_position = Vector2(x, deck.get_center().y)


func _paddle(crossing: Crossing, bodies: Array[PlayerBody], seconds: float) -> void:
	for body: PlayerBody in bodies:
		body.intent = MoveIntent.create(Vector2.ZERO, false, false, true)
	# One step more: the press lands in the bodies' step, after the crossing's first one.
	CrossingRig.run(crossing, seconds + CrossingRig.STEP_S)
	for body: PlayerBody in bodies:
		body.intent = MoveIntent.new()


func test_solo_paddles_off_the_line_and_drifts_back() -> void:
	var crossing := CrossingRig.make(self, &"raft", 1, 100.0, 60.0)
	var body := crossing.body_of(1)
	_to_edge(crossing, body, CrossingSteer.EAST)
	_paddle(crossing, [body], 2.0)
	assert_almost_eq(crossing.steer.position, 3.0, EPS, "3 tiles east when they let go")
	CrossingRig.run(crossing, 2.0)
	assert_almost_eq(crossing.steer.position, 2.0, EPS, "2 tiles east 2 s later")
	CrossingRig.run(crossing, 6.0)
	assert_eq(crossing.steer.position, 0.0, "back on the line, and no further")


func test_two_paddlers_on_one_side() -> void:
	var crossing := CrossingRig.make(self, &"raft", 2, 100.0, 60.0)
	var bodies: Array[PlayerBody] = [crossing.body_of(1), crossing.body_of(2)]
	for body: PlayerBody in bodies:
		_to_edge(crossing, body, CrossingSteer.WEST)
	_paddle(crossing, bodies, 2.0)
	assert_almost_eq(crossing.steer.position, -4.5, EPS)


func test_paddles_on_both_sides_cancel() -> void:
	var crossing := CrossingRig.make(self, &"raft", 2, 100.0, 60.0)
	_to_edge(crossing, crossing.body_of(1), CrossingSteer.WEST)
	_to_edge(crossing, crossing.body_of(2), CrossingSteer.EAST)
	_paddle(crossing, [crossing.body_of(1), crossing.body_of(2)], 2.0)
	assert_eq(crossing.steer.position, 0.0, "still on the line")


func test_solo_paddles_to_the_limit() -> void:
	var crossing := CrossingRig.make(self, &"raft", 1, 100.0, 60.0)
	_to_edge(crossing, crossing.body_of(1), CrossingSteer.EAST)
	_paddle(crossing, [crossing.body_of(1)], 5.0)
	assert_eq(crossing.steer.position, 6.0)


func test_a_tied_rider_cannot_paddle() -> void:
	var crossing := CrossingRig.make(self, &"raft", 1, 100.0, 60.0)
	var body := crossing.body_of(1)
	CrossingRig.hold(crossing, body, 1.0)
	CrossingRig.release(crossing, body)
	assert_eq(crossing.rider_state(1), Crossing.Rider.TIED)
	_to_edge(crossing, body, CrossingSteer.EAST)
	_paddle(crossing, [body], 2.0)
	assert_eq(crossing.steer.position, 0.0, "a tied rider keeps only untying")


func test_a_swimmer_cannot_paddle() -> void:
	var crossing := CrossingRig.make(self, &"raft", 1, 100.0, 60.0)
	var body := crossing.body_of(1)
	crossing.throw_in(1)
	CrossingRig.put_beside_deck(crossing, body, 4.0)
	_paddle(crossing, [body], 2.0)
	assert_eq(crossing.steer.position, 0.0)


func test_solo_paddles_slowly_in_the_blow() -> void:
	var crossing := CrossingRig.make(self, &"raft", 1, 100.0, 60.0, [CrossingRig.beat(40.0, K.SQUALL)])
	var body := crossing.body_of(1)
	CrossingRig.hold(crossing, body, 1.0)
	CrossingRig.release(crossing, body)
	CrossingRig.run(crossing, 40.5 - crossing.elapsed_s)
	assert_eq(crossing.rider_state(1), Crossing.Rider.TIED, "tied when the squall hit")
	CrossingRig.hold(crossing, body, 1.0)
	CrossingRig.release(crossing, body)
	CrossingRig.run(crossing, 43.0 - crossing.elapsed_s)
	_to_edge(crossing, body, CrossingSteer.EAST)
	_paddle(crossing, [body], 2.0)
	assert_almost_eq(crossing.steer.position, 1.5, EPS, "half what calm water gives")


func test_solo_paddling_records_no_drift() -> void:
	var launched := _shell_launch()
	var shell := launched[0] as GameShell
	var crossing := launched[1] as Crossing
	var body := crossing.body_of(1)
	_to_edge(crossing, body, CrossingSteer.EAST)
	body.intent = MoveIntent.create(Vector2.ZERO, false, false, true)
	CrossingRig.run(crossing, 60.0)
	body.intent = MoveIntent.new()
	assert_eq(shell.crossing_results.size(), 1)
	assert_eq((shell.crossing_results[0] as CrossingResult).drift_offset_tiles, 0.0, "paddling is not drift")


func test_the_row_of_boards_paddles_as_one() -> void:
	FixtureRoutes.put_in()
	var crossing := CrossingRig.make(self, &"test_board", 2, 60.0, 60.0)
	var first := crossing.body_of(1)
	var board := crossing.deck_rect_of(1)
	first.global_position = board.get_center() + Vector2(5.0, 0.0)
	var gap_before: float = crossing.deck_rect_of(2).get_center().x - board.get_center().x
	_paddle(crossing, [first], 2.0)
	assert_almost_eq(crossing.steer.position, 3.0, EPS, "both boards 3 tiles east of the line")
	assert_eq(crossing.deck_rect_of(2).get_center().x - crossing.deck_rect_of(1).get_center().x, gap_before, "still 3 tiles apart")


func test_a_board_rider_cannot_paddle_another_board() -> void:
	FixtureRoutes.put_in()
	var crossing := CrossingRig.make(self, &"test_board", 2, 60.0, 60.0)
	var paddles: Array[RescuePoint] = []
	for child: Node in crossing.get_children():
		var point := child as RescuePoint
		if point != null and point.kind == RescuePoint.Kind.PADDLE:
			paddles.append(point)
	assert_eq(paddles.size(), 4, "two paddles per board")
	for paddle: RescuePoint in paddles:
		var owner_body := crossing.body_of(paddle.swimmer)
		var other := crossing.body_of(3 - paddle.swimmer)
		assert_true(paddle.usable_by(owner_body))
		assert_false(paddle.usable_by(other), "another rider's board paddle")


func test_a_press_on_the_deck_middle_still_ties_down() -> void:
	# crossing "Which job a press takes": a rider on their spot reaches the lashing before a paddle.
	var crossing := CrossingRig.make(self, &"raft", 1, 100.0, 60.0)
	var body := crossing.body_of(1)
	CrossingRig.hold(crossing, body, 1.0)
	CrossingRig.release(crossing, body)
	assert_eq(crossing.rider_state(1), Crossing.Rider.TIED)
	assert_eq(crossing.steer.position, 0.0)


# A solo shell run with the sandbar's raft launched on a calm 60 s crossing with no beats.
func _shell_launch() -> Array:
	NetManager.start_solo()
	WeatherManager.stop()
	WeatherManager.sky.start_at(0.0)
	var shell := (preload("res://scenes/shell/game_shell.tscn") as PackedScene).instantiate() as GameShell
	shell.settings_path = "user://test_crossing_paddle_settings.cfg"
	add_child_autofree(shell)
	(shell.screen as TitleScreen).solo_requested.emit()
	var body := shell.session.body(1)
	body.player_input.enabled = false
	var site := shell.session.get_node("RaftSite") as BuildSite
	body.global_position = site.global_position
	body.inventory.add(&"driftwood", 6)
	body.inventory.add(&"inner_tube", 2)
	body.inventory.add(&"rope", 3)
	site.deposit(body)
	site.work(1.0)
	(shell.session.get_node("Raft") as Raft).interactable.interacted.emit(body)
	var crossing := shell.crossings[0] as Crossing
	crossing.plan = CrossingPlan.create(60.0, [])
	return [shell, crossing]
