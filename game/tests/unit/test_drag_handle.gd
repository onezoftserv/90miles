extends GutTest
## player-movement: PlayerBody interaction and dragging a downed teammate (DragHandle).

const PLAYER_SCENE: PackedScene = preload("res://scenes/player/player.tscn")
const TILE: float = 16.0
const DT: float = 1.0 / 60.0


func _spawn(at: Vector2) -> PlayerBody:
	var body := PLAYER_SCENE.instantiate() as PlayerBody
	body.position = at
	add_child_autofree(body)
	return body


# Steps dragger first, then the downed body, like the scene tree order.
func _step(bodies: Array[PlayerBody], seconds: float) -> void:
	for i: int in roundi(seconds / DT):
		for body: PlayerBody in bodies:
			body._physics_process(DT)


func _both(a: PlayerBody, b: PlayerBody) -> Array[PlayerBody]:
	return [a, b]


func test_handle_is_enabled_only_while_downed() -> void:
	var body := _spawn(Vector2.ZERO)
	assert_false(body.drag_handle.enabled)
	body.set_downed(true)
	assert_true(body.downed)
	assert_true(body.drag_handle.enabled)
	body.set_downed(false)
	assert_false(body.drag_handle.enabled)


func test_drag_handle_is_an_instant_interactable() -> void:
	var body := _spawn(Vector2.ZERO)
	assert_eq(body.drag_handle.hold_time_s, 0.0)
	assert_true(body.drag_handle.is_in_group(Interactable.GROUP))


func test_held_drag_moves_the_downed_player_at_2_tiles_per_second() -> void:
	var helper := _spawn(Vector2(12.0, 0.0))
	var downed := _spawn(Vector2.ZERO)
	downed.set_downed(true)
	# The helper walks east (4 tiles/s) while holding interact, so the gap stays wide.
	helper.intent = MoveIntent.create(Vector2.RIGHT, false, false, true)
	_step(_both(helper, downed), 1.0)
	assert_almost_eq(downed.position.x / TILE, 2.0, 0.02, "2 tiles in 1 s")
	assert_almost_eq(helper.position.x / TILE, 0.75 + 4.0, 0.02)
	assert_eq(downed.movement_state, MovementStep.Move.DRAGGED)


func test_dragging_stops_when_interact_is_released() -> void:
	var helper := _spawn(Vector2(12.0, 0.0))
	var downed := _spawn(Vector2.ZERO)
	downed.set_downed(true)
	helper.intent = MoveIntent.create(Vector2.RIGHT, false, false, true)
	_step(_both(helper, downed), 0.5)
	var stopped_at := downed.position
	helper.intent = MoveIntent.create(Vector2.RIGHT, false, false, false)
	_step(_both(helper, downed), 0.5)
	assert_gt(stopped_at.x, 0.0)
	assert_eq(downed.position, stopped_at, "released: the downed player stays put")
	assert_null(downed.drag_handle.dragger)


func test_downed_player_follows_but_never_overshoots_the_dragger() -> void:
	var helper := _spawn(Vector2(12.0, 0.0))
	var downed := _spawn(Vector2.ZERO)
	downed.set_downed(true)
	helper.intent = MoveIntent.create(Vector2.ZERO, false, false, true)
	_step(_both(helper, downed), 2.0)
	assert_lt(downed.position.distance_to(helper.position), 12.0)
	assert_gt(downed.position.distance_to(helper.position), 0.0, "stops beside the dragger")
	assert_lt(downed.position.x, helper.position.x)


func test_standing_players_cannot_be_dragged() -> void:
	var helper := _spawn(Vector2(12.0, 0.0))
	var other := _spawn(Vector2.ZERO)
	helper.intent = MoveIntent.create(Vector2.RIGHT, false, false, true)
	_step(_both(helper, other), 1.0)
	assert_eq(other.position, Vector2.ZERO)


func test_downed_player_ignores_its_own_intent() -> void:
	var downed := _spawn(Vector2.ZERO)
	downed.set_downed(true)
	downed.intent = MoveIntent.create(Vector2.RIGHT, true)
	_step([downed] as Array[PlayerBody], 1.0)
	assert_eq(downed.position, Vector2.ZERO)
	assert_eq(downed.meters.energy, 100.0)


func test_getting_up_ends_the_drag() -> void:
	var helper := _spawn(Vector2(12.0, 0.0))
	var downed := _spawn(Vector2.ZERO)
	downed.set_downed(true)
	helper.intent = MoveIntent.create(Vector2.RIGHT, false, false, true)
	_step(_both(helper, downed), 0.2)
	downed.set_downed(false)
	assert_null(downed.drag_handle.dragger)


func test_player_uses_the_nearest_interactable_in_reach() -> void:
	var player := _spawn(Vector2.ZERO)
	var coconut := Interactable.new()
	coconut.hold_time_s = 0.0
	coconut.position = Vector2(8.0, 0.0)
	add_child_autofree(coconut)
	var crate := Interactable.new()
	crate.hold_time_s = 0.0
	crate.position = Vector2(14.4, 0.0)
	add_child_autofree(crate)
	watch_signals(coconut)
	watch_signals(crate)
	player.intent = MoveIntent.create(Vector2.ZERO, false, false, true)
	_step([player] as Array[PlayerBody], 0.1)
	assert_signal_emit_count(coconut, "interacted", 1)
	assert_signal_not_emitted(crate, "interacted")


func test_player_needs_a_2_second_hold_for_a_timed_interactable() -> void:
	var player := _spawn(Vector2.ZERO)
	var net := Interactable.new()
	net.position = Vector2(8.0, 0.0)
	add_child_autofree(net)
	watch_signals(net)
	player.intent = MoveIntent.create(Vector2.ZERO, false, false, true)
	_step([player] as Array[PlayerBody], 1.5)
	player.intent = MoveIntent.create()
	_step([player] as Array[PlayerBody], 0.1)
	assert_signal_not_emitted(net, "interacted")
	player.intent = MoveIntent.create(Vector2.ZERO, false, false, true)
	_step([player] as Array[PlayerBody], 1.5)
	assert_signal_not_emitted(net, "interacted", "holding again starts from 0 s")
	_step([player] as Array[PlayerBody], 0.6)
	assert_signal_emit_count(net, "interacted", 1)
