extends GutTest
## coop-networking "Host authority": the three roles of a player's net component, driven by
## hand (no network): the host steps queued intents, the owning client predicts and reconciles,
## other clients interpolate.

const PLAYER_SCENE: PackedScene = preload("res://scenes/player/player.tscn")
const TILE: float = 16.0
const DT: float = 1.0 / 60.0
const EAST := Vector2.RIGHT
const Role := PlayerNet.Role

var sent: Array[Dictionary] = []
var now_s: float = 0.0


func before_each() -> void:
	sent = []
	now_s = 0.0


func _record(seq: int, intent: MoveIntent, delta: float) -> void:
	sent.append({"seq": seq, "intent": intent.copy(), "delta": delta})


func _spawn(owner_peer: int, role: PlayerNet.Role, at: Vector2 = Vector2.ZERO) -> PlayerBody:
	var body := PLAYER_SCENE.instantiate() as PlayerBody
	body.position = at
	var net := body.get_node(^"PlayerNet") as PlayerNet
	net.attach(owner_peer, role, _record)
	net.clock = func() -> float: return now_s
	add_child_autofree(body)
	body.player_input.enabled = false
	return body


func _plain(at: Vector2) -> PlayerBody:
	var body := PLAYER_SCENE.instantiate() as PlayerBody
	body.position = at
	add_child_autofree(body)
	body.player_input.enabled = false
	return body


func _host_state(body: PlayerBody, position: Vector2, ack: int, energy: float = SurvivalMeters.MAX_ENERGY, downed: bool = false) -> void:
	var net := body.net
	net.net_position = position
	net.net_ack_seq = ack
	net.net_energy = energy
	net.net_model_state = MovementModel.new().get_state()
	net.net_downed = downed
	net.apply_host_state()


func _frames(body: PlayerBody, count: int) -> void:
	for i: int in count:
		body.net._physics_process(DT)


# --- roles -------------------------------------------------------------------------------

func test_role_table() -> void:
	assert_eq(PlayerNet.role_for(true, 1, 1), Role.HOST)
	assert_eq(PlayerNet.role_for(true, 1, 7), Role.HOST)
	assert_eq(PlayerNet.role_for(false, 7, 7), Role.PREDICTED)
	assert_eq(PlayerNet.role_for(false, 7, 1), Role.REMOTE)
	assert_eq(PlayerNet.role_for(false, 7, 9), Role.REMOTE)


func test_an_unattached_body_runs_on_its_own() -> void:
	var body := _plain(Vector2.ZERO)
	assert_eq(body.net.role, Role.INACTIVE)
	assert_true(body.auto_advance)


func test_attaching_hands_the_stepping_to_the_net_component() -> void:
	var body := _spawn(7, Role.HOST)
	assert_false(body.auto_advance)
	assert_eq(body.net.owner_peer, 7)


# --- host --------------------------------------------------------------------------------

func test_host_steps_each_queued_intent_with_its_own_delta() -> void:
	var body := _spawn(7, Role.HOST)
	for seq: int in [1, 2, 3]:
		assert_true(body.net.enqueue(seq, MoveIntent.create(EAST), DT))
	body.net._physics_process(DT)
	assert_almost_eq(body.position.x / TILE, 3.0 * 4.0 * DT, 0.00001)
	assert_eq(body.net.net_ack_seq, 3)
	assert_eq(body.net.net_position, body.position)


func test_host_uses_the_intents_time_step_not_its_own() -> void:
	var body := _spawn(7, Role.HOST)
	body.net.enqueue(1, MoveIntent.create(EAST), 0.05)
	body.net._physics_process(DT)
	assert_almost_eq(body.position.x / TILE, 0.2, 0.00001)


func test_host_does_not_move_a_body_without_intents() -> void:
	var body := _spawn(7, Role.HOST)
	body.intent = MoveIntent.create(EAST)
	_frames(body, 10)
	assert_eq(body.position, Vector2.ZERO)
	assert_eq(body.net.net_ack_seq, 0)


func test_host_steps_at_most_8_intents_per_frame() -> void:
	var body := _spawn(7, Role.HOST)
	for seq: int in range(1, 11):
		body.net.enqueue(seq, MoveIntent.create(EAST), DT)
	body.net._physics_process(DT)
	assert_eq(body.net.net_ack_seq, PlayerNet.MAX_STEPS_PER_FRAME)
	body.net._physics_process(DT)
	assert_eq(body.net.net_ack_seq, 10)


func test_host_refuses_stale_or_repeated_seq() -> void:
	var body := _spawn(7, Role.HOST)
	assert_true(body.net.enqueue(5, MoveIntent.create(EAST), DT))
	assert_false(body.net.enqueue(5, MoveIntent.create(EAST), DT))
	assert_false(body.net.enqueue(4, MoveIntent.create(EAST), DT))
	assert_true(body.net.enqueue(6, MoveIntent.create(EAST), DT))


func test_host_writes_the_shadow_fields() -> void:
	var body := _spawn(7, Role.HOST)
	for seq: int in range(1, 31):
		body.net.enqueue(seq, MoveIntent.create(EAST, true), DT)
	_frames(body, 4)
	var net := body.net
	assert_eq(net.net_position, body.position)
	assert_eq(net.net_energy, body.meters.energy)
	assert_lt(net.net_energy, SurvivalMeters.MAX_ENERGY, "running spent energy")
	assert_eq(net.net_movement, int(MovementStep.Move.RUN))
	assert_eq(net.net_stealth, int(MovementStep.Stealth.VISIBLE))
	assert_eq(net.net_model_state, body.model.get_state())
	assert_false(net.net_downed)


func test_host_acknowledges_but_ignores_intents_of_a_downed_body() -> void:
	var body := _spawn(7, Role.HOST)
	body.set_downed(true)
	body.net.enqueue(1, MoveIntent.create(EAST), DT)
	body.net.enqueue(2, MoveIntent.create(EAST), DT)
	body.net._physics_process(DT)
	assert_eq(body.position, Vector2.ZERO)
	assert_eq(body.net.net_ack_seq, 2)
	assert_true(body.net.net_downed)


func test_host_still_drags_a_downed_body_without_intents() -> void:
	var body := _spawn(7, Role.HOST)
	var dragger := Node2D.new()
	dragger.position = Vector2(4.0 * TILE, 0.0)
	add_child_autofree(dragger)
	body.set_downed(true)
	body.drag_handle.dragger = dragger
	_frames(body, 30)
	assert_almost_eq(body.position.x / TILE, 2.0 * 30.0 * DT, 0.001, "dragged at 2 tiles/s")


func test_hosts_own_body_sends_its_input_through_the_session() -> void:
	var body := _spawn(1, Role.HOST)
	body.intent = MoveIntent.create(EAST, true)
	_frames(body, 2)
	assert_eq(sent.size(), 2)
	assert_eq([sent[0].seq, sent[1].seq], [1, 2])
	assert_true((sent[0].intent as MoveIntent).run)
	assert_eq(sent[0].delta, DT)


func test_host_sends_nothing_for_bodies_it_does_not_own() -> void:
	var body := _spawn(7, Role.HOST)
	body.intent = MoveIntent.create(EAST)
	_frames(body, 3)
	assert_eq(sent.size(), 0)


# --- predicted (the client's own player) -------------------------------------------------

func test_own_player_responds_at_once() -> void:
	var body := _spawn(7, Role.PREDICTED)
	body.intent = MoveIntent.create(EAST)
	body.net._physics_process(DT)
	assert_almost_eq(body.position.x / TILE, 4.0 * DT, 0.00001, "moved before any host answer")
	assert_eq(sent.size(), 1)
	assert_eq(sent[0].seq, 1)
	assert_eq((sent[0].intent as MoveIntent).direction, EAST)


func test_prediction_never_runs_interactions() -> void:
	var body := _spawn(7, Role.PREDICTED)
	var coconut := Interactable.new()
	coconut.hold_time_s = 0.0
	coconut.position = Vector2(0.5 * TILE, 0.0)
	add_child_autofree(coconut)
	watch_signals(coconut)
	body.intent = MoveIntent.create(Vector2.ZERO, false, false, true)
	_frames(body, 3)
	assert_signal_not_emitted(coconut, "interacted")


func test_correction_from_the_host_replays_unacknowledged_intents() -> void:
	var body := _spawn(7, Role.PREDICTED)
	body.intent = MoveIntent.create(EAST)
	_frames(body, 9)
	var host_position := Vector2(100.0, 40.0)
	var reference := _plain(host_position)
	reference.intent = MoveIntent.create(EAST)
	for i: int in 6:
		reference.advance(DT, false)
	_host_state(body, host_position, 3)
	assert_eq(body.position, reference.position, "host state plus the 6 unacknowledged intents")
	assert_eq(body.net.buffer.size(), 6)
	_host_state(body, Vector2(120.0, 40.0), 9)
	assert_eq(body.position, Vector2(120.0, 40.0), "exactly the host's position once all are processed")
	assert_eq(body.net.buffer.size(), 0)


func test_correction_takes_the_hosts_energy_and_replays_its_cost() -> void:
	var body := _spawn(7, Role.PREDICTED)
	body.intent = MoveIntent.create(EAST, true)
	_frames(body, 9)
	_host_state(body, Vector2.ZERO, 3, 60.0)
	assert_almost_eq(body.meters.energy, 60.0 - 6.0 * 0.5 * DT, 0.000000001)


func test_a_correction_keeps_the_current_intent() -> void:
	var body := _spawn(7, Role.PREDICTED)
	body.intent = MoveIntent.create(EAST)
	_frames(body, 3)
	var latest := MoveIntent.create(Vector2.UP, true)
	body.intent = latest
	_host_state(body, Vector2.ZERO, 1)
	assert_eq(body.intent, latest)


func test_downed_player_is_not_predicted() -> void:
	var body := _spawn(7, Role.PREDICTED)
	now_s = 0.0
	_host_state(body, Vector2(0.0, 0.0), 0, SurvivalMeters.MAX_ENERGY, true)
	assert_true(body.downed)
	now_s = 0.05
	_host_state(body, Vector2(16.0, 0.0), 0, SurvivalMeters.MAX_ENERGY, true)
	body.intent = MoveIntent.create(EAST, true)
	body.net._physics_process(DT)
	assert_eq(sent.size(), 0, "no movement intents while downed")
	body.net.update_drawn_position(0.125)
	assert_almost_eq(body.position.x, 8.0, 0.0001, "drawn where the host's states put it")


func test_a_revived_player_is_predicted_again() -> void:
	var body := _spawn(7, Role.PREDICTED)
	_host_state(body, Vector2(32.0, 0.0), 0, SurvivalMeters.MAX_ENERGY, true)
	_host_state(body, Vector2(32.0, 0.0), 0, SurvivalMeters.MAX_ENERGY, false)
	assert_false(body.downed)
	body.intent = MoveIntent.create(EAST)
	body.net._physics_process(DT)
	assert_eq(sent.size(), 1)
	assert_almost_eq(body.position.x, 32.0 + 4.0 * DT * TILE, 0.00001)


func test_going_down_forgets_unacknowledged_intents() -> void:
	var body := _spawn(7, Role.PREDICTED)
	body.intent = MoveIntent.create(EAST)
	_frames(body, 3)
	_host_state(body, Vector2(16.0, 0.0), 0, SurvivalMeters.MAX_ENERGY, true)
	assert_eq(body.net.buffer.size(), 0, "nothing is left to replay on revive")
	_host_state(body, Vector2(64.0, 0.0), 0, SurvivalMeters.MAX_ENERGY, false)
	assert_eq(body.position, Vector2(64.0, 0.0), "revived exactly where the host has it")


func test_a_non_finite_host_state_is_ignored_by_the_owner() -> void:
	var body := _spawn(7, Role.PREDICTED, Vector2(10.0, 20.0))
	_host_state(body, Vector2(NAN, 0.0), 0)
	assert_eq(body.position, Vector2(10.0, 20.0))
	_host_state(body, Vector2(30.0, 20.0), 0, INF)
	assert_eq(body.position, Vector2(10.0, 20.0))
	assert_eq(body.meters.energy, SurvivalMeters.MAX_ENERGY)


func test_a_non_finite_host_state_is_ignored_for_teammates() -> void:
	var body := _spawn(1, Role.REMOTE)
	_host_state(body, Vector2(INF, 0.0), 0)
	assert_eq(body.net.interpolator.size(), 0)


# --- remote (other clients' view) --------------------------------------------------------

func test_remote_player_is_drawn_between_host_states() -> void:
	var body := _spawn(1, Role.REMOTE)
	now_s = 0.0
	_host_state(body, Vector2(0.0, 0.0), 0)
	now_s = 0.05
	_host_state(body, Vector2(1.0 * TILE, 0.0), 0)
	body.net.update_drawn_position(0.125)
	assert_almost_eq(body.position.x / TILE, 0.5, 0.0001)


func test_remote_player_never_simulates_or_sends() -> void:
	var body := _spawn(1, Role.REMOTE)
	body.intent = MoveIntent.create(EAST, true)
	_frames(body, 5)
	assert_eq(body.position, Vector2.ZERO)
	assert_eq(sent.size(), 0)


func test_remote_player_takes_states_from_the_host() -> void:
	var body := _spawn(1, Role.REMOTE)
	body.net.net_movement = int(MovementStep.Move.SWIM)
	body.net.net_stealth = int(MovementStep.Stealth.SUBMERGED)
	_host_state(body, Vector2.ZERO, 0, 42.0, true)
	assert_eq(body.movement_state, MovementStep.Move.SWIM)
	assert_eq(body.stealth_state, MovementStep.Stealth.SUBMERGED)
	assert_eq(body.meters.energy, 42.0)
	assert_true(body.downed)
