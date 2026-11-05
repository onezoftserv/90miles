extends GutTest
## coop-networking "Per-peer rate limits", through the session's intent path with the session
## clock replaced by a test clock. A solo session stands in for the host; peer 7 is a client
## added by hand (its intents are fed to the handler as if they came from peer 7).

const SESSION_SCENE: PackedScene = preload("res://scenes/net/coop_session.tscn")
const TILE: float = 16.0
const DT: float = 1.0 / 60.0
const CLIENT: int = 7

var now_s: float = 0.0


func before_each() -> void:
	now_s = 0.0


func _session_with_client() -> CoopSession:
	var session := SESSION_SCENE.instantiate() as CoopSession
	add_child_autofree(session)
	session.clock = func() -> float: return now_s
	session.start()
	session._add_player(CLIENT)
	for id: int in session.peer_ids():
		session.body(id).player_input.enabled = false
	return session


func test_limits_are_the_specified_numbers() -> void:
	assert_eq(PeerLimits.INTENT_BURST, 30.0)
	assert_eq(PeerLimits.INTENTS_PER_S, 90.0)
	assert_eq(PeerLimits.SIM_TIME_SLACK_S, 0.25)
	assert_eq(PeerLimits.SIM_TIME_PER_S, 1.0)
	assert_eq(PeerLimits.MIN_INTENT_COST_S, 1.0 / 60.0)
	assert_eq(PeerLimits.QUICK_CHAT_BURST, 3.0)
	assert_eq(PeerLimits.QUICK_CHAT_PER_S, 0.5)
	assert_eq(CoopSession.MAX_INTENT_DELTA_S, 0.1)


func test_client_claims_extra_time() -> void:
	var session := _session_with_client()
	var accepted_s: float = 0.0
	for i: int in 60:
		now_s = float(i) / 60.0
		if session.accept_intent(CLIENT, 0.1):
			accepted_s += 0.1
	assert_lt(accepted_s * MovementModel.WALK_SPEED, 5.0 + 0.000001, "at most 5 tiles of walking")
	assert_gt(accepted_s, 1.0, "the honest second still gets through")


func test_intents_over_the_time_budget_never_move_the_player() -> void:
	var session := _session_with_client()
	var body := session.body(CLIENT)
	var start := body.position
	for seq: int in range(1, 61):
		session._receive_intent(CLIENT, seq, Vector2.RIGHT, false, false, false, 0.1)
	for i: int in 20:
		body.net._physics_process(DT)
	assert_almost_eq((body.position.x - start.x) / TILE, 2.0 * 0.1 * MovementModel.WALK_SPEED, 0.00001, "only the 0.25 s of slack: 2 intents")


func test_a_tiny_time_step_still_costs_a_frame() -> void:
	var session := _session_with_client()
	var accepted: int = 0
	for i: int in 40:
		if session.accept_intent(CLIENT, 0.001):
			accepted += 1
	assert_eq(accepted, 15, "0.25 s of slack is 15 frames, however small the claimed step")
	now_s = 0.02
	assert_true(session.accept_intent(CLIENT, 0.001), "a frame's worth back after 20 ms")
	assert_false(session.accept_intent(CLIENT, 0.001))


func test_the_intent_count_burst_is_30() -> void:
	var limits := PeerLimits.new()
	var accepted: int = 0
	for i: int in 40:
		if limits.intents.try_take(1.0, 0.0):
			accepted += 1
	assert_eq(accepted, 30)


func test_the_hosts_own_player_is_never_rate_limited() -> void:
	var session := _session_with_client()
	for i: int in 200:
		assert_true(session.accept_intent(CoopSession.HOST_ID, 0.1), "intent %d" % i)


func test_an_intent_longer_than_a_slow_frame_is_refused() -> void:
	var session := _session_with_client()
	var body := session.body(CLIENT)
	var start := body.position
	session._receive_intent(CLIENT, 1, Vector2.RIGHT, false, false, false, 0.5)
	body.net._physics_process(DT)
	assert_eq(body.position, start)


func test_an_unknown_peer_has_no_allowance() -> void:
	var session := _session_with_client()
	assert_false(session.accept_intent(42, 0.01))


func test_the_session_clock_defaults_to_real_time() -> void:
	var session := SESSION_SCENE.instantiate() as CoopSession
	add_child_autofree(session)
	var first: float = session.clock.call()
	assert_gt(first, 0.0)
	assert_true(session.clock.call() >= first)
