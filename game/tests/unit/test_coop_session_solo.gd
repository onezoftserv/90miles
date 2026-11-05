extends GutTest
## coop-networking "Host and join", scenario "Solo session": solo runs the session on the
## offline peer; the host's own player goes through the same intent path as in co-op.

const SESSION_SCENE: PackedScene = preload("res://scenes/net/coop_session.tscn")
const TILE: float = 16.0
const DT: float = 1.0 / 60.0
const START := Vector2(32.0, 48.0)


func _solo() -> CoopSession:
	var session := SESSION_SCENE.instantiate() as CoopSession
	add_child_autofree(session)
	session.spawn_points = [START] as Array[Vector2]
	session.start()
	return session


func test_solo_session_has_one_player_on_the_host_path_and_no_port() -> void:
	var session := _solo()
	assert_true(multiplayer.multiplayer_peer is OfflineMultiplayerPeer, "no network port")
	assert_eq(session.peer_ids(), [1] as Array[int])
	var body := session.body(1)
	assert_not_null(body)
	assert_eq(body.net.role, PlayerNet.Role.HOST)
	assert_eq(body.position, START)
	assert_true(body.camera.enabled, "the solo player is the local player")


func test_solo_player_moves_through_the_intent_path() -> void:
	var session := _solo()
	var body := session.body(1)
	body.player_input.enabled = false
	body.intent = MoveIntent.create(Vector2.RIGHT)
	body.net._physics_process(DT)
	assert_almost_eq(body.position.x, START.x + 4.0 * DT * TILE, 0.00001)
	assert_eq(body.net.net_ack_seq, 1, "the host acknowledged its own intent")


func test_bodies_are_named_after_their_peer() -> void:
	var session := _solo()
	assert_eq(String(session.body(1).name), "1")
	assert_eq(session.body(1).get_parent(), session.players)


func test_a_session_without_spawn_points_spawns_at_the_origin() -> void:
	var session := SESSION_SCENE.instantiate() as CoopSession
	add_child_autofree(session)
	session.spawn_points = [] as Array[Vector2]
	session.start()
	assert_eq(session.body(1).position, Vector2.ZERO)


func test_unknown_peers_have_no_body() -> void:
	var session := _solo()
	assert_null(session.body(42))


func test_a_direct_call_outside_an_rpc_has_no_sender_and_is_ignored() -> void:
	# The handler acts for the RPC's sender; called directly there is none (id 0).
	var session := _solo()
	var body := session.body(1)
	session.submit_intent(1, Vector2.RIGHT, false, false, false, DT)
	assert_eq(body.net.net_ack_seq, 0)
