extends GutTest
## ui-shell "Lobby" and the coop-networking "Host and join" lobby phase, over ENet on
## localhost (NetHarness): names arrive once per peer, nobody spawns until the host starts the
## run, and a joiner during the run spawns at once.

const SPAWNS: Array[Vector2] = [Vector2(32.0, 48.0), Vector2(48.0, 48.0), Vector2(64.0, 48.0), Vector2(80.0, 48.0)]
const TIMEOUT_S: float = 5.0

var net: NetHarness


func before_each() -> void:
	net = NetHarness.new(self)


func after_each() -> void:
	net.teardown()


func _lobby_host() -> CoopSession:
	var setup := func(session: CoopSession) -> void:
		session.spawn_points = SPAWNS.duplicate()
		session.local_name = "Yuni"
	return net.add_host(setup, true, true)


func test_a_lobby_session_spawns_nobody() -> void:
	var host := _lobby_host()
	assert_eq(host.phase, CoopSession.Phase.LOBBY)
	assert_eq(host.peer_ids().size(), 0)
	assert_eq(host.roster, {1: "Yuni"} as Dictionary[int, String])


func test_two_players_meet() -> void:
	var host := _lobby_host()
	var papo := await net.join_lobby("Papo")
	assert_not_null(papo)
	if papo == null:
		return
	var papo_id: int = net.peer_id(papo)
	var expected: Dictionary[int, String] = {1: "Yuni", papo_id: "Papo"}
	assert_true(await wait_until(func() -> bool: return papo.roster == expected, TIMEOUT_S), "the client has the roster")
	assert_eq(host.roster, expected)
	assert_eq(papo.peer_ids().size(), 0, "nobody spawned in the lobby")


func test_players_spawn_when_the_run_starts() -> void:
	var host := _lobby_host()
	var papo := await net.join_lobby("Papo")
	var dayana := await net.join_lobby("Dayana")
	assert_not_null(papo)
	assert_not_null(dayana)
	if papo == null or dayana == null:
		return
	watch_signals(papo)
	for session: CoopSession in [host, papo, dayana]:
		assert_eq(session.peer_ids().size(), 0)
	assert_true(host.begin_run())
	var everyone := func() -> bool:
		return host.peer_ids().size() == 3 and papo.peer_ids().size() == 3 and dayana.peer_ids().size() == 3
	assert_true(await wait_until(everyone, TIMEOUT_S), "all three spawn on every peer")
	assert_eq(host.phase, CoopSession.Phase.RUN)
	assert_eq(host.body(1).position, SPAWNS[0], "the host first")
	assert_eq(host.body(net.peer_id(papo)).position, SPAWNS[1], "then in join order")
	assert_eq(host.body(net.peer_id(dayana)).position, SPAWNS[2])
	assert_signal_emitted(papo, "run_started")


func test_a_join_during_the_run_spawns_at_once() -> void:
	var host := _lobby_host()
	assert_true(host.begin_run())
	var late := net.add_client(func(session: CoopSession) -> void: session.local_name = "Chino")
	watch_signals(late)
	var spawned := func() -> bool: return net._connected(late) and host.body(net.peer_id(late)) != null
	assert_true(await wait_until(spawned, TIMEOUT_S))
	assert_true(await wait_until(func() -> bool: return late.roster.size() == 2, TIMEOUT_S))
	assert_signal_emitted_with_parameters(late, "lobby_received", [true])
	assert_eq(host.player_name(net.peer_id(late)), "Chino")


func test_client_renames_itself_over_and_over() -> void:
	var host := _lobby_host()
	var papo := await net.join_lobby("Papo")
	var dayana := await net.join_lobby("Dayana")
	assert_not_null(papo)
	assert_not_null(dayana)
	if papo == null or dayana == null:
		return
	assert_true(await wait_until(func() -> bool: return dayana.roster.size() == 3, TIMEOUT_S))
	watch_signals(dayana)
	for i: int in 50:
		papo.request_join.rpc_id(1, "Otro %d" % i)
	await wait_seconds(0.3)
	assert_eq(host.player_name(net.peer_id(papo)), "Papo")
	assert_signal_not_emitted(dayana, "roster_updated", "no roster update for ignored requests")


func test_names_are_cleaned_by_the_host() -> void:
	var host := _lobby_host()
	var messy := await net.join_lobby("  \u0001Pa\npo  ")
	assert_not_null(messy)
	if messy == null:
		return
	assert_eq(host.player_name(net.peer_id(messy)), "Papo")
	var blank := await net.join_lobby("")
	assert_not_null(blank)
	if blank != null:
		assert_eq(host.player_name(net.peer_id(blank)), "Balsero 3")


func test_leaving_the_lobby_drops_the_name() -> void:
	var host := _lobby_host()
	var papo := await net.join_lobby("Papo")
	assert_not_null(papo)
	if papo == null:
		return
	var papo_id: int = net.peer_id(papo)
	net.drop(papo)
	assert_true(await wait_until(func() -> bool: return not host.roster.has(papo_id), TIMEOUT_S))
	assert_eq(host.peer_ids().size(), 0, "nobody to leave downed in a lobby")


func test_only_the_host_can_start() -> void:
	var host := _lobby_host()
	var papo := await net.join_lobby("Papo")
	assert_not_null(papo)
	if papo == null:
		return
	assert_false(papo.begin_run(), "a client cannot start the run")
	assert_eq(host.phase, CoopSession.Phase.LOBBY)


func test_a_malformed_roster_is_cleaned() -> void:
	var cleaned := CoopSession.clean_roster({1: "Yuni", "x": "Papo", 2: 7, 3: "\u0001Dayana"})
	assert_eq(cleaned, {1: "Yuni", 3: "Dayana"} as Dictionary[int, String])
