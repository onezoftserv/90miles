extends GutTest
## Solo is first-class (CLAUDE.md; coop-networking "Host and join", scenario "Solo session"):
## a run that neither hosts nor joins runs offline on the same session code, with the solo
## player as the host. Nothing waits for a second peer, and the solo player's movement is
## never predicted, corrected or rate-limited. "No network objects" here means no transport:
## the peer is Godot's offline peer, so no socket or port exists (the spawner and synchronizer
## nodes are part of the shared code path and do nothing offline).

const SESSION_SCENE: PackedScene = preload("res://scenes/net/coop_session.tscn")
const PLAYER_SCENE: PackedScene = preload("res://scenes/player/player.tscn")
const TILE: float = 16.0
const DT: float = 1.0 / 60.0
const START := Vector2(32.0, 48.0)


func before_each() -> void:
	NetManager.start_solo()


func _solo() -> CoopSession:
	var session := SESSION_SCENE.instantiate() as CoopSession
	add_child_autofree(session)
	session.spawn_points = [START] as Array[Vector2]
	session.start()
	session.body(1).player_input.enabled = false
	return session


func _frames(body: PlayerBody, count: int) -> void:
	for i: int in count:
		body.net._physics_process(DT)


func test_a_solo_run_is_offline_with_no_peers_and_no_port() -> void:
	var session := _solo()
	assert_true(session.multiplayer.multiplayer_peer is OfflineMultiplayerPeer, "no transport, so no socket or port")
	assert_eq(session.multiplayer.get_peers(), PackedInt32Array(), "no second peer")
	assert_true(session.multiplayer.is_server(), "the solo player is the host")
	assert_false(NetManager.is_online())


func test_the_solo_player_spawns_at_once_without_waiting_for_anyone() -> void:
	var session := _solo()
	assert_eq(session.peer_ids(), [1] as Array[int])
	var body := session.body(1)
	assert_eq(body.position, START)
	assert_true(body.is_multiplayer_authority(), "the solo player is the local player")
	assert_true(body.camera.enabled)


func test_the_solo_player_runs_by_the_player_movement_numbers() -> void:
	var body := _solo().body(1)
	body.meters.energy = 50.0
	body.intent = MoveIntent.create(Vector2.RIGHT, true)
	_frames(body, 600)
	assert_almost_eq((body.position.x - START.x) / TILE, 60.0, 0.05, "10 s of running is 60 tiles")
	assert_almost_eq(body.meters.energy, 45.0, 0.01, "and costs 5 energy")


func test_the_solo_player_moves_exactly_like_a_body_without_networking() -> void:
	var body := _solo().body(1)
	var plain := PLAYER_SCENE.instantiate() as PlayerBody
	plain.position = START
	add_child_autofree(plain)
	plain.player_input.enabled = false
	var intent := MoveIntent.create(Vector2(0.8, 0.6), true)
	body.intent = intent
	plain.intent = intent
	for i: int in 120:
		body.net._physics_process(DT)
		plain.advance(DT)
	assert_eq(body.position, plain.position, "no added latency, no difference")
	assert_eq(body.meters.energy, plain.meters.energy)


func test_the_solo_player_is_never_predicted_or_corrected() -> void:
	var body := _solo().body(1)
	body.intent = MoveIntent.create(Vector2.RIGHT)
	_frames(body, 30)
	assert_eq(body.net.role, PlayerNet.Role.HOST)
	assert_eq(body.net.buffer.size(), 0, "nothing waits for an acknowledgement")
	var before := body.position
	body.net.net_position = Vector2(999.0, 999.0)
	body.net.apply_host_state()
	assert_eq(body.position, before, "host states never move the host's own player")


func test_the_solo_players_own_intents_are_never_rate_limited() -> void:
	var body := _solo().body(1)
	body.intent = MoveIntent.create(Vector2.RIGHT)
	# Far more than one real second's worth of frames, all at once (a long hitch).
	_frames(body, 120)
	assert_almost_eq((body.position.x - START.x) / TILE, 120.0 * 4.0 * DT, 0.0001)
	assert_eq(body.net.net_ack_seq, 120)


func test_the_solo_player_interacts() -> void:
	var body := _solo().body(1)
	var coconut := Interactable.new()
	coconut.hold_time_s = 0.0
	coconut.position = START + Vector2(0.5 * TILE, 0.0)
	add_child_autofree(coconut)
	watch_signals(coconut)
	body.intent = MoveIntent.create(Vector2.ZERO, false, false, true)
	body.net._physics_process(DT)
	assert_signal_emitted_with_parameters(coconut, "interacted", [body])
