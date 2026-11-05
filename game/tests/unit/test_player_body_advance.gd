extends GutTest
## coop-networking: the network steps a body through advance(); interactions run only where
## the world is authoritative.

const PLAYER_SCENE: PackedScene = preload("res://scenes/player/player.tscn")
const TILE: float = 16.0
const DT: float = 1.0 / 60.0


func _spawn() -> PlayerBody:
	var body := PLAYER_SCENE.instantiate() as PlayerBody
	add_child_autofree(body)
	body.player_input.enabled = false
	return body


func _coconut(at: Vector2) -> Interactable:
	var node := Interactable.new()
	node.hold_time_s = 0.0
	node.position = at
	add_child_autofree(node)
	return node


func test_physics_process_does_nothing_while_auto_advance_is_off() -> void:
	var body := _spawn()
	body.auto_advance = false
	body.intent = MoveIntent.create(Vector2.RIGHT)
	for i: int in 10:
		body._physics_process(DT)
	assert_eq(body.position, Vector2.ZERO)


func test_advance_moves_exactly_like_a_physics_frame() -> void:
	var stepped := _spawn()
	var advanced := _spawn()
	for body: PlayerBody in [stepped, advanced]:
		body.intent = MoveIntent.create(Vector2(1.0, 0.5), true)
	for i: int in 30:
		stepped._physics_process(DT)
		advanced.advance(DT)
	assert_eq(advanced.position, stepped.position)
	assert_eq(advanced.meters.energy, stepped.meters.energy)
	assert_almost_eq(advanced.position.length() / TILE, 6.0 * 30.0 * DT, 0.001)


func test_advance_without_interaction_uses_nothing() -> void:
	var body := _spawn()
	var coconut := _coconut(Vector2(0.5 * TILE, 0.0))
	watch_signals(coconut)
	body.intent = MoveIntent.create(Vector2.ZERO, false, false, true)
	body.advance(DT, false)
	assert_signal_not_emitted(coconut, "interacted")


func test_advance_with_interaction_uses_the_nearest() -> void:
	var body := _spawn()
	var coconut := _coconut(Vector2(0.5 * TILE, 0.0))
	watch_signals(coconut)
	body.intent = MoveIntent.create(Vector2.ZERO, false, false, true)
	body.advance(DT)
	assert_signal_emitted_with_parameters(coconut, "interacted", [body])
