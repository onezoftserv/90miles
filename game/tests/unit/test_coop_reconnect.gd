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

var net: NetHarness
var papo: PlayerIdentity


func before_each() -> void:
	net = NetHarness.new(self)
	papo = PlayerIdentity.create()


func after_each() -> void:
	net.teardown()


func _island(session: CoopSession) -> void:
	session.spawn_points = SPAWNS.duplicate()


# A client from Papo's install (or any identity), named "Papo".
func _as(identity: PlayerIdentity, player_name: String = "Papo") -> Callable:
	return func(session: CoopSession) -> void:
		session.local_identity = identity
		session.local_name = player_name


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


func test_an_id_in_use_joins_as_a_new_player() -> void:
	var host := net.add_host(_island)
	var first := await net.join(_as(papo))
	assert_not_null(first)
	if first == null:
		return
	var papo_id: int = net.peer_id(first)
	var papo_body := host.body(papo_id)
	var twin := await net.join(_as(papo))
	assert_not_null(twin, "the same install joins twice")
	if twin == null:
		return
	assert_not_same(host.body(net.peer_id(twin)), papo_body, "as a new player")
	assert_same(host.body(papo_id), papo_body, "and Papo keeps his")
	assert_false(host.is_dropped(papo_id))


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
