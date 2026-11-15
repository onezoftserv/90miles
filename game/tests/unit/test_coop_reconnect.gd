extends GutTest
## coop-reconnect over ENet on localhost (NetHarness): the join request carries the player id
## and secret; players spawn on it, not on connect; a silent peer times out; a dropped player
## who joins again within 90 s with the same identity takes back the same body; someone else's
## id, or an id in use, joins as a new player; late joiners see a reclaimed body under its new
## owner. Solo spawns at once and stays closed.

const TILE: float = 16.0
const SPAWNS: Array[Vector2] = [Vector2(32.0, 48.0), Vector2(48.0, 48.0), Vector2(64.0, 48.0), Vector2(80.0, 48.0)]
const TIMEOUT_S: float = 5.0
const SESSION_SCENE: PackedScene = preload("res://scenes/net/coop_session.tscn")
## Intent messages a frame from an old copy that keeps sending (the takeover case).
const STALE_BURST: int = 4

var net: NetHarness
var papo: PlayerIdentity
var _burst: Callable = Callable()


func before_each() -> void:
	net = NetHarness.new(self)
	papo = PlayerIdentity.create()


func after_each() -> void:
	_stop_sending()
	net.teardown()


func _island(session: CoopSession) -> void:
	session.spawn_points = SPAWNS.duplicate()


# A client from Papo's install (or any identity), named "Papo".
func _as(identity: PlayerIdentity, player_name: String = "Papo") -> Callable:
	return func(session: CoopSession) -> void:
		session.local_identity = identity
		session.local_name = player_name


func _connected(session: CoopSession) -> bool:
	var peer := session.multiplayer.multiplayer_peer
	return peer != null and peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED


# Papo plays, then drops; returns his body on the host, downed and waiting.
func _papo_drops(host: CoopSession) -> PlayerBody:
	var client := await net.join(_as(papo))
	assert_not_null(client)
	if client == null:
		return null
	var papo_id: int = net.peer_id(client)
	var papo_body := host.body(papo_id)
	net.drop(client)
	var downed := func() -> bool: return host.is_dropped(papo_id)
	assert_true(await wait_until(downed, TIMEOUT_S), "Papo's body waits, downed")
	return papo_body


# An old copy of a game that is still connected keeps sending: STALE_BURST intent messages every
# process frame until it loses its connection, so some always share the host's poll with a later
# join request. Each holds one standing-still intent numbered 1, which the body has already
# queued, so the host skips it and nothing moves.
func _keep_sending(stale: CoopSession) -> void:
	_burst = func() -> void:
		if not is_instance_valid(stale) or not _connected(stale):
			return
		var standing: Array[PendingIntent] = [PendingIntent.create(1, MoveIntent.new(), 1.0 / Engine.physics_ticks_per_second)]
		for i: int in STALE_BURST:
			stale.send_intents(standing)
	get_tree().process_frame.connect(_burst)


func _stop_sending() -> void:
	if _burst.is_valid() and get_tree().process_frame.is_connected(_burst):
		get_tree().process_frame.disconnect(_burst)
	_burst = Callable()


# Waits until the host has closed the old copy's connection and the old copy has lost it.
func _old_copy_closed(host: CoopSession, stale: CoopSession, stale_id: int) -> void:
	var closed := func() -> bool: return not host.multiplayer.get_peers().has(stale_id)
	assert_true(await wait_until(closed, TIMEOUT_S), "the host closed the old connection")
	var told := func() -> bool: return not _connected(stale)
	assert_true(await wait_until(told, TIMEOUT_S), "the old copy loses its connection")
	_stop_sending()


# Waits until `session` is connected and listed in the host's roster.
func _listed(host: CoopSession, session: CoopSession) -> bool:
	var listed := func() -> bool:
		return _connected(session) and host.roster.has(session.multiplayer.get_unique_id())
	return await wait_until(listed, TIMEOUT_S)


# --- join request ----------------------------------------------------------------------------

func test_a_joiner_spawns_on_its_join_request_not_on_connect() -> void:
	var host := net.add_host(_island)
	var silent := net.add_silent_client()
	assert_true(await net.wait_connected(silent))
	var id: int = net.peer_id(silent)
	assert_true(await wait_until(func() -> bool: return host.multiplayer.get_peers().has(id), TIMEOUT_S))
	await wait_process_frames(10)
	assert_null(host.body(id), "no player before the join request")
	silent.start()
	assert_true(await wait_until(func() -> bool: return host.body(id) != null, TIMEOUT_S), "spawned once it asked")


func test_a_peer_that_never_asks_to_join_is_disconnected() -> void:
	var host := net.add_host(_island)
	var silent := net.add_silent_client()
	assert_true(await net.wait_connected(silent))
	var id: int = net.peer_id(silent)
	assert_true(await wait_until(func() -> bool: return host.multiplayer.get_peers().has(id), TIMEOUT_S))
	host._physics_process(CoopSession.JOIN_TIMEOUT_S - 0.5)
	assert_true(host.multiplayer.get_peers().has(id), "still waiting just before 10 s")
	host._physics_process(1.0)
	var gone := func() -> bool: return not host.multiplayer.get_peers().has(id)
	assert_true(await wait_until(gone, TIMEOUT_S), "disconnected after 10 s")
	assert_null(host.body(id), "no player spawned for it")
	assert_eq(host.peer_ids(), [1] as Array[int])


func test_the_join_timeout_is_10_s() -> void:
	assert_eq(CoopSession.JOIN_TIMEOUT_S, 10.0)


func test_solo_spawns_at_once_and_stays_closed() -> void:
	NetManager.start_solo()
	var session := SESSION_SCENE.instantiate() as CoopSession
	add_child_autofree(session)
	session.start()
	assert_not_null(session.body(CoopSession.HOST_ID), "the one player spawns at once, no join request")
	assert_true(session.multiplayer.multiplayer_peer is OfflineMultiplayerPeer, "no port: nobody can join")
	session._physics_process(CoopSession.JOIN_TIMEOUT_S + 1.0)
	assert_eq(session.peer_ids(), [CoopSession.HOST_ID] as Array[int], "and nothing times out")
	NetManager.leave()


func test_solo_has_nobody_to_take_over() -> void:
	NetManager.start_solo()
	var session := SESSION_SCENE.instantiate() as CoopSession
	session.local_identity = papo
	add_child_autofree(session)
	session.start()
	var mine := session.body(CoopSession.HOST_ID)
	watch_signals(session)
	session.request_join("Papo", papo.id, papo.secret)
	await wait_process_frames(2)
	assert_signal_not_emitted(session, "player_rebound", "nothing is taken over")
	assert_signal_not_emitted(session, "player_disconnected", "nobody is dropped")
	assert_same(session.body(CoopSession.HOST_ID), mine, "the one player keeps their body")
	assert_eq(session.peer_ids(), [CoopSession.HOST_ID] as Array[int])
	assert_true(session.multiplayer.multiplayer_peer is OfflineMultiplayerPeer, "still offline")
	NetManager.leave()


# --- reclaim -----------------------------------------------------------------------------------

func test_rejoin_within_90_s_gets_the_same_body_back() -> void:
	var host := net.add_host(_island)
	var dayana := await net.join(_as(PlayerIdentity.create(), "Dayana"))
	assert_not_null(dayana)
	var client := await net.join(_as(papo))
	assert_not_null(client)
	if dayana == null or client == null:
		return
	var old_id: int = net.peer_id(client)
	var papo_body := host.body(old_id)
	papo_body.meters.health = 60.0
	papo_body.meters.thirst = 40.0
	var seen_by_dayana := dayana.body(old_id)
	net.drop(client)
	assert_true(await wait_until(func() -> bool: return host.is_dropped(old_id), TIMEOUT_S))
	var lay_at := papo_body.position
	var back := await net.join(_as(papo))
	assert_not_null(back, "Papo joins again")
	if back == null:
		return
	var new_id: int = net.peer_id(back)
	assert_ne(new_id, old_id, "a new peer id")
	assert_same(host.body(new_id), papo_body, "the same body on the host")
	assert_null(host.body(old_id))
	assert_false(host.is_dropped(old_id), "no longer counting down")
	assert_false(papo_body.downed, "standing again")
	assert_almost_eq(papo_body.meters.health, 60.0, 1.0)
	assert_almost_eq(papo_body.meters.thirst, 40.0, 1.0)
	assert_eq(papo_body.position, lay_at, "where it lay")
	assert_eq(host.player_name(new_id), "Papo")
	var mine := net.own_body(back)
	assert_not_null(mine, "Papo's client has its body")
	if mine != null:
		assert_eq(mine.net.role, PlayerNet.Role.PREDICTED, "and predicts it")
		assert_true(mine.camera.enabled, "its camera follows it")
	var dayana_sees := func() -> bool: return dayana.body(new_id) == seen_by_dayana and dayana.body(old_id) == null
	assert_true(await wait_until(dayana_sees, TIMEOUT_S), "Dayana sees the same body come back as Papo's")
	assert_eq(dayana.player_name(new_id), "Papo")


func test_a_reclaimed_body_takes_the_new_clients_intents() -> void:
	var host := net.add_host(_island)
	var papo_body := await _papo_drops(host)
	if papo_body == null:
		return
	var back := await net.join(_as(papo))
	assert_not_null(back)
	if back == null:
		return
	var start_x: float = papo_body.position.x
	var mine := net.own_body(back)
	mine.intent = MoveIntent.create(Vector2.RIGHT)
	await wait_physics_frames(30)
	mine.intent = MoveIntent.new()
	var moved := func() -> bool: return papo_body.position.x > start_x + TILE
	assert_true(await wait_until(moved, TIMEOUT_S), "the host steps the rejoined client's intents")


func test_someone_elses_id_cannot_take_the_body() -> void:
	var host := net.add_host(_island)
	var papo_body := await _papo_drops(host)
	if papo_body == null:
		return
	var impostor := await net.join(_as(PlayerIdentity.from(papo.id, PlayerIdentity.create().secret), "Chino"))
	assert_not_null(impostor)
	if impostor == null:
		return
	var impostor_id: int = net.peer_id(impostor)
	assert_not_same(host.body(impostor_id), papo_body, "a new player")
	assert_true(papo_body.downed, "Papo's body stays downed")
	assert_true(is_instance_valid(papo_body) and host.peer_ids().size() == 3, "and waits for Papo")


func test_back_before_the_host_noticed_takes_over() -> void:
	# Papo's client crashed; the host still holds the dead connection when he joins again.
	var host := net.add_host(_island)
	var stale := await net.join(_as(papo))
	assert_not_null(stale)
	if stale == null:
		return
	var stale_id: int = net.peer_id(stale)
	var papo_body := host.body(stale_id)
	net.freeze(stale)
	await wait_process_frames(5)
	assert_true(host.multiplayer.get_peers().has(stale_id), "the host still holds the dead connection")
	var back := await net.join(_as(papo))
	assert_not_null(back, "Papo joins again while his old connection is open")
	if back == null:
		return
	assert_same(host.body(net.peer_id(back)), papo_body, "he takes back the same body")
	assert_null(host.body(stale_id))
	assert_false(papo_body.downed)
	var closed := func() -> bool: return not host.multiplayer.get_peers().has(stale_id)
	assert_true(await wait_until(closed, TIMEOUT_S), "the host closed the old connection")
	assert_eq(host.peer_ids().size(), 2, "still two players: the host and Papo")


func test_a_takeover_while_the_old_copy_still_sends_is_clean() -> void:
	# A second copy of Papo's game joins while the first is still connected and sending. The host
	# can read the old copy's packets behind the join request in one poll; none may log an engine
	# error (GUT fails the test on one).
	var host := net.add_host(_island)
	var stale := await net.join(_as(papo))
	assert_not_null(stale)
	if stale == null:
		return
	var stale_id: int = net.peer_id(stale)
	var papo_body := host.body(stale_id)
	_keep_sending(stale)
	var back := await net.join(_as(papo))
	assert_not_null(back, "the second copy joins while the first still sends")
	if back == null:
		return
	assert_same(host.body(net.peer_id(back)), papo_body, "it takes back the same body")
	assert_null(host.body(stale_id))
	await _old_copy_closed(host, stale, stale_id)
	assert_eq(host.peer_ids().size(), 2, "still two players: the host and Papo")
	assert_eq(host.player_name(net.peer_id(back)), "Papo")


func test_a_takeover_in_the_lobby_while_the_old_copy_still_sends_is_clean() -> void:
	var host := net.add_host(_island, true, true)
	var stale := net.add_client(_as(papo))
	assert_true(await _listed(host, stale), "Papo is in the lobby")
	var stale_id: int = net.peer_id(stale)
	_keep_sending(stale)
	var back := net.add_client(_as(papo))
	assert_true(await _listed(host, back), "the second copy joins the lobby")
	await _old_copy_closed(host, stale, stale_id)
	assert_false(host.roster.has(stale_id), "the old copy leaves the roster")
	assert_eq(host.roster.size(), 2, "the host and Papo, once")
	assert_eq(host.player_name(net.peer_id(back)), "Papo")


func test_a_repeated_join_request_during_a_takeover_is_ignored() -> void:
	var host := net.add_host(_island)
	var stale := await net.join(_as(papo))
	assert_not_null(stale)
	if stale == null:
		return
	var stale_id: int = net.peer_id(stale)
	var papo_body := host.body(stale_id)
	_keep_sending(stale)
	var back := net.add_silent_client(_as(papo))
	assert_true(await net.wait_connected(back))
	var back_id: int = net.peer_id(back)
	# Both requests leave in one frame, so the host reads them in one poll.
	back.start()
	back._request_join()
	var taken := func() -> bool: return host.body(back_id) == papo_body
	assert_true(await wait_until(taken, TIMEOUT_S), "the second copy takes back the body")
	await _old_copy_closed(host, stale, stale_id)
	await wait_process_frames(10)
	assert_true(_connected(back), "and stays connected")
	assert_true(host.multiplayer.get_peers().has(back_id))
	assert_same(host.body(back_id), papo_body, "it still holds the body")
	assert_false(host.is_dropped(back_id))
	assert_eq(host.peer_ids().size(), 2, "the host and Papo")


func test_a_client_with_the_hosts_id_joins_as_a_new_player() -> void:
	# A host and a client started from one install share the id.
	var same_install := func(session: CoopSession) -> void:
		_island(session)
		session.local_identity = papo
	var host := net.add_host(same_install)
	var host_body := host.body(CoopSession.HOST_ID)
	var client := await net.join(_as(papo, "Yuni"))
	assert_not_null(client)
	if client == null:
		return
	assert_not_same(host.body(net.peer_id(client)), host_body, "a new player")
	assert_same(host.body(CoopSession.HOST_ID), host_body, "the host keeps its own")
	assert_eq(host.peer_ids().size(), 2)


func test_a_body_reclaimed_twice_keeps_its_owner_for_late_joiners() -> void:
	var host := net.add_host(_island)
	var papo_body := await _papo_drops(host)
	if papo_body == null:
		return
	var second := await net.join(_as(papo))
	assert_not_null(second)
	if second == null:
		return
	var second_id: int = net.peer_id(second)
	net.drop(second)
	assert_true(await wait_until(func() -> bool: return host.is_dropped(second_id), TIMEOUT_S))
	var third := await net.join(_as(papo))
	assert_not_null(third)
	if third == null:
		return
	var third_id: int = net.peer_id(third)
	assert_same(host.body(third_id), papo_body, "the same body after two drops")
	var late := await net.join(_as(PlayerIdentity.create(), "Yuni"))
	assert_not_null(late)
	if late == null:
		return
	assert_true(await net.settle())
	assert_not_null(late.body(third_id), "the late joiner maps it to its current owner")
	net.drop(third)
	assert_true(await wait_until(func() -> bool: return host.is_dropped(third_id), TIMEOUT_S))
	host._physics_process(CoopSession.DISCONNECT_DOWNED_S + 1.0)
	var removed := func() -> bool: return late.body(third_id) == null and late.removed_names() == (["Papo"] as Array[String])
	assert_true(await wait_until(removed, TIMEOUT_S), "and removing it reaches the late joiner")


func test_a_body_downed_by_its_meters_stays_down() -> void:
	var host := net.add_host(_island)
	var client := await net.join(_as(papo))
	assert_not_null(client)
	if client == null:
		return
	var papo_body := host.body(net.peer_id(client))
	papo_body.meters.downed = true
	net.drop(client)
	var dropped := func() -> bool: return host.is_dropped(_peer_of(host, papo_body))
	assert_true(await wait_until(dropped, TIMEOUT_S))
	var back := await net.join(_as(papo))
	assert_not_null(back)
	if back == null:
		return
	assert_same(host.body(net.peer_id(back)), papo_body)
	assert_true(papo_body.downed, "it was down before the drop: it stays down")


func _peer_of(session: CoopSession, player: PlayerBody) -> int:
	for peer_id: int in session.peer_ids():
		if session.body(peer_id) == player:
			return peer_id
	return 0


func test_a_late_joiner_sees_the_reclaimed_body_under_its_new_owner() -> void:
	var host := net.add_host(_island)
	var papo_body := await _papo_drops(host)
	if papo_body == null:
		return
	var back := await net.join(_as(papo))
	assert_not_null(back)
	if back == null:
		return
	var papo_id: int = net.peer_id(back)
	var late := await net.join(_as(PlayerIdentity.create(), "Yuni"))
	assert_not_null(late)
	if late == null:
		return
	assert_true(await net.settle())
	var reclaimed := late.body(papo_id)
	assert_not_null(reclaimed, "the late joiner has Papo's body under Papo's peer")
	if reclaimed != null:
		assert_eq(reclaimed.net.role, PlayerNet.Role.REMOTE)
		assert_eq(reclaimed.net.owner_peer, papo_id)
	assert_eq(late.player_name(papo_id), "Papo")
	assert_eq(late.peer_ids(), host.peer_ids(), "the same players everywhere")


# --- removed players -------------------------------------------------------------------------

func test_a_rejoin_after_removal_is_a_new_player() -> void:
	var host := net.add_host(_island)
	var dayana := await net.join(_as(PlayerIdentity.create(), "Dayana"))
	assert_not_null(dayana)
	if dayana == null:
		return
	var papo_body := await _papo_drops(host)
	if papo_body == null:
		return
	host._physics_process(CoopSession.DISCONNECT_DOWNED_S + 1.0)
	assert_eq(host.removed_names(), ["Papo"] as Array[String], "the host keeps who was removed")
	var told := func() -> bool: return dayana.removed_names() == (["Papo"] as Array[String])
	assert_true(await wait_until(told, TIMEOUT_S), "and so does every client")
	var back := await net.join(_as(papo))
	assert_not_null(back, "Papo joins again")
	if back == null:
		return
	var fresh := host.body(net.peer_id(back))
	assert_not_null(fresh)
	assert_false(is_instance_valid(papo_body) and fresh == papo_body, "a new player, not the removed body")
	assert_true(SPAWNS.has(fresh.position), "at a spawn point")
	assert_eq(host.removed_names(), ["Papo"] as Array[String], "the removed player still counts as dead")


func test_a_late_joiner_learns_who_was_removed() -> void:
	var host := net.add_host(_island)
	var papo_body := await _papo_drops(host)
	if papo_body == null:
		return
	host._physics_process(CoopSession.DISCONNECT_DOWNED_S + 1.0)
	var late := await net.join(_as(PlayerIdentity.create(), "Yuni"))
	assert_not_null(late)
	if late == null:
		return
	var told := func() -> bool: return late.removed_names() == (["Papo"] as Array[String])
	assert_true(await wait_until(told, TIMEOUT_S))


func test_a_reclaimed_client_gets_the_clock_and_weather() -> void:
	# Review M2: the reclaim sends the same world state as a join, sky included.
	var host_sky := WorldSky.from_catalog(GameState.content)
	host_sky.start_at(450.0)
	host_sky.weather.start_weather(&"squall")
	var island_with_sky := func(session: CoopSession) -> void:
		_island(session)
		session.sky = host_sky
	var host := net.add_host(island_with_sky)
	var papo_body := await _papo_drops(host)
	if papo_body == null:
		return
	var client_sky := WorldSky.from_catalog(GameState.content)
	client_sky.weather.rolls_enabled = false
	var papo_with_sky := func(session: CoopSession) -> void:
		_as(papo).call(session)
		session.sky = client_sky
	var back := await net.join(papo_with_sky)
	assert_not_null(back)
	if back == null:
		return
	assert_same(host.body(net.peer_id(back)), papo_body)
	var told := func() -> bool: return client_sky.weather.current.id == &"squall"
	assert_true(await wait_until(told, TIMEOUT_S), "the rejoined client has the host's weather at once")
	assert_eq(client_sky.clock.phase(), DataEnums.DayPhase.NIGHT)
