extends GutTest
## coop-networking "Per-peer rate limits", through the session's intent handler with the
## session clock replaced by a test clock (solo session: the sender is peer 1).

const SESSION_SCENE: PackedScene = preload("res://scenes/net/coop_session.tscn")
const TILE: float = 16.0
const DT: float = 1.0 / 60.0

var now_s: float = 0.0


func before_each() -> void:
	now_s = 0.0


func _solo() -> CoopSession:
	var session := SESSION_SCENE.instantiate() as CoopSession
	add_child_autofree(session)
	session.clock = func() -> float: return now_s
	session.start()
	session.body(1).player_input.enabled = false
	return session


func test_limits_are_the_specified_numbers() -> void:
	assert_eq(PeerLimits.INTENT_BURST, 30.0)
	assert_eq(PeerLimits.INTENTS_PER_S, 90.0)
	assert_eq(PeerLimits.SIM_TIME_SLACK_S, 0.25)
	assert_eq(PeerLimits.SIM_TIME_PER_S, 1.0)
	assert_eq(PeerLimits.QUICK_CHAT_BURST, 3.0)
	assert_eq(PeerLimits.QUICK_CHAT_PER_S, 0.5)
	assert_eq(CoopSession.MAX_INTENT_DELTA_S, 0.1)


func test_client_claims_extra_time() -> void:
	var session := _solo()
	var accepted_s: float = 0.0
	for i: int in 60:
		now_s = float(i) / 60.0
		if session.accept_intent(1, 0.1):
			accepted_s += 0.1
	assert_lt(accepted_s * MovementModel.WALK_SPEED, 5.0 + 0.000001, "at most 5 tiles of walking")
	assert_gt(accepted_s, 1.0, "the honest second still gets through")


func test_intents_over_the_time_budget_never_move_the_player() -> void:
	var session := _solo()
	var body := session.body(1)
	for seq: int in range(1, 61):
		session.submit_intent.rpc_id(1, 1000 + seq, Vector2.RIGHT, false, false, false, 0.1)
	for i: int in 20:
		body.net._physics_process(DT)
	assert_almost_eq(body.position.x / TILE, 2.0 * 0.1 * MovementModel.WALK_SPEED, 0.00001, "only the 0.25 s of slack: 2 intents")


func test_an_intent_flood_is_cut_to_the_burst() -> void:
	var session := _solo()
	var accepted: int = 0
	for i: int in 40:
		if session.accept_intent(1, 0.001):
			accepted += 1
	assert_eq(accepted, 30)
	now_s = 0.02
	assert_true(session.accept_intent(1, 0.001), "1.8 tokens back after 20 ms")
	assert_false(session.accept_intent(1, 0.001))


func test_an_intent_longer_than_a_slow_frame_is_refused() -> void:
	var session := _solo()
	var body := session.body(1)
	session.submit_intent.rpc_id(1, 1001, Vector2.RIGHT, false, false, false, 0.5)
	body.net._physics_process(DT)
	assert_eq(body.position, Vector2.ZERO)


func test_an_unknown_peer_has_no_allowance() -> void:
	var session := _solo()
	assert_false(session.accept_intent(42, 0.01))


func test_the_session_clock_defaults_to_real_time() -> void:
	var session := SESSION_SCENE.instantiate() as CoopSession
	add_child_autofree(session)
	var first: float = session.clock.call()
	assert_gt(first, 0.0)
	assert_true(session.clock.call() >= first)
