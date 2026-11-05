extends GutTest
## coop-networking with survival-meters: the host ticks every player's meters once per host
## frame (never once per intent, and also while a client's intents stall), and clients show the
## host's meter values (survival-meters "Client shows host values").

const PLAYER_SCENE: PackedScene = preload("res://scenes/player/player.tscn")
const SESSION_SCENE: PackedScene = preload("res://scenes/net/coop_session.tscn")
const DT: float = 1.0 / 60.0
const TIMEOUT_S: float = 5.0

var net: NetHarness


func after_each() -> void:
	if net != null:
		net.teardown()
		net = null


func _plain() -> PlayerBody:
	var body := PLAYER_SCENE.instantiate() as PlayerBody
	add_child_autofree(body)
	body.player_input.enabled = false
	return body


func _host_copy(owner_peer: int) -> PlayerBody:
	var body := PLAYER_SCENE.instantiate() as PlayerBody
	(body.get_node(^"PlayerNet") as PlayerNet).attach(owner_peer, PlayerNet.Role.HOST, func(_s: int, _i: MoveIntent, _d: float) -> void: pass)
	add_child_autofree(body)
	body.player_input.enabled = false
	return body


func test_a_clients_meters_tick_every_host_frame_even_without_intents() -> void:
	var reference := _plain()
	var copy := _host_copy(7)
	for i: int in 60:
		reference._physics_process(DT)
		copy.net._physics_process(DT)
		copy._physics_process(DT)
	assert_lt(copy.meters.thirst, SurvivalMeters.MAX_VALUE, "a stalled client still gets thirsty")
	assert_eq(copy.meters.thirst, reference.meters.thirst)
	assert_eq(copy.meters.hunger, reference.meters.hunger)


func test_many_intents_in_one_frame_tick_the_meters_once() -> void:
	var reference := _plain()
	var copy := _host_copy(7)
	for seq: int in range(1, 9):
		copy.net.enqueue(seq, MoveIntent.new(), DT)
	copy.net._physics_process(DT)
	copy._physics_process(DT)
	reference._physics_process(DT)
	assert_eq(copy.net.net_ack_seq, 8)
	assert_eq(copy.meters.thirst, reference.meters.thirst, "one host frame is one meters tick")


func test_the_solo_players_meters_tick_once_per_frame() -> void:
	NetManager.start_solo()
	var session := SESSION_SCENE.instantiate() as CoopSession
	add_child_autofree(session)
	session.start()
	var body := session.body(1)
	body.player_input.enabled = false
	var reference := _plain()
	for i: int in 60:
		body.net._physics_process(DT)
		body._physics_process(DT)
		reference._physics_process(DT)
	assert_lt(body.meters.thirst, SurvivalMeters.MAX_VALUE)
	assert_eq(body.meters.thirst, reference.meters.thirst)


func test_a_dead_player_does_not_count_for_difficulty() -> void:
	NetManager.start_solo()
	var session := SESSION_SCENE.instantiate() as CoopSession
	add_child_autofree(session)
	session.start()
	session._add_player(7)
	session.body(7).meters.dead = true
	assert_false(CoopSession.is_alive(session.body(7)))
	assert_eq(session.island_difficulty().players, 1)


func test_client_shows_host_values() -> void:
	net = NetHarness.new(self)
	var host := net.add_host()
	var a := await net.join()
	var b := await net.join()
	assert_not_null(a)
	assert_not_null(b)
	if a == null or b == null:
		return
	assert_true(await net.settle())
	var a_id: int = net.peer_id(a)
	var on_host := host.body(a_id).meters
	on_host.thirst = 40.0
	on_host.health = 20.0
	on_host.sunstroke = true
	var shown := func(session: CoopSession) -> bool:
		var meters := session.body(a_id).meters
		return absf(meters.thirst - on_host.thirst) < 0.5 and absf(meters.health - on_host.health) < 0.5 and meters.sunstroke
	assert_true(await wait_until(func() -> bool: return shown.call(a) and shown.call(b), TIMEOUT_S), "A and B show the host's values for A")
	assert_lt(a.body(a_id).meters.thirst, 40.5)
