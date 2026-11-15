extends GutTest
## art-pass "Look slots in a rematch" (design D6): the host keeps each connected player's look slot
## from the run that ended, by peer id (nobody reconnects), whatever order their join requests come
## in; a player new to the party takes the lowest slot nobody holds or keeps for a connected peer;
## a kept slot of a peer that is not connected is free. `look_slots()` is what the host hands over.
## 1 player, offline: nothing kept, slot 0.

const SPAWNS: Array[Vector2] = [Vector2(32.0, 48.0), Vector2(48.0, 48.0), Vector2(64.0, 48.0), Vector2(80.0, 48.0)]
const SESSION_SCENE: PackedScene = preload("res://scenes/net/coop_session.tscn")
const TIMEOUT_S: float = 5.0

var net: NetHarness


func before_each() -> void:
	net = NetHarness.new(self)


func after_each() -> void:
	net.teardown()
	NetManager.leave()


func _offline_session() -> CoopSession:
	NetManager.start_solo()
	var session := SESSION_SCENE.instantiate() as CoopSession
	add_child_autofree(session)
	return session


func _slot(session: CoopSession, peer_id: int) -> int:
	var found: PlayerBody = session.body(peer_id)
	return found.look_slot if found != null else -1


func _lobby(player_name: String) -> Callable:
	return func(session: CoopSession) -> void:
		session.spawn_points = SPAWNS.duplicate()
		session.local_name = player_name


func test_solo_keeps_nothing_and_is_slot_0() -> void:
	var session := _offline_session()
	session.start()
	assert_true(session.carried_looks.is_empty())
	assert_eq(_slot(session, CoopSession.HOST_ID), 0)


func test_a_kept_slot_is_given_whatever_the_spawn_order() -> void:
	var session := _offline_session()
	session.carried_looks = {7: 2, 8: 1} as Dictionary[int, int]
	session.start(true)
	session._add_player(7)
	session._add_player(8)
	assert_eq(_slot(session, 7), 2, "peer 7 spawned first and still gets its slot 2")
	assert_eq(_slot(session, 8), 1)


func test_a_held_slot_is_not_given_twice() -> void:
	var session := _offline_session()
	session.carried_looks = {7: 0} as Dictionary[int, int]
	session.start()
	assert_eq(_slot(session, CoopSession.HOST_ID), 0, "the host took slot 0 first")
	session._add_player(7)
	assert_eq(_slot(session, 7), 1, "slot 0 is held, so the lowest free one")


func test_a_kept_slot_of_a_peer_not_connected_is_free() -> void:
	var session := _offline_session()
	session.carried_looks = {1: 0, 999: 1} as Dictionary[int, int]
	session.start()
	session._add_player(8)
	assert_eq(_slot(session, 8), 1, "peer 999 is not connected, so its slot 1 is free")


func test_a_newcomer_skips_a_slot_kept_for_a_connected_peer() -> void:
	var host := net.add_host(_lobby("Yuni"), true, true)
	var newcomer := await net.join_lobby("Nuevo")
	var papo := await net.join_lobby("Papo")
	assert_not_null(newcomer)
	assert_not_null(papo)
	if newcomer == null or papo == null:
		return
	var papo_id: int = net.peer_id(papo)
	var newcomer_id: int = net.peer_id(newcomer)
	host.carried_looks = {CoopSession.HOST_ID: 0, papo_id: 1} as Dictionary[int, int]
	assert_true(host.begin_run())
	assert_eq(_slot(host, CoopSession.HOST_ID), 0)
	assert_eq(_slot(host, newcomer_id), 2, "the newcomer spawned before Papo and skipped Papo's slot 1")
	assert_eq(_slot(host, papo_id), 1, "Papo keeps slot 1")
	assert_true(await net.settle())
	var drawn := func() -> bool:
		return _slot(papo, papo_id) == 1 and _slot(papo, newcomer_id) == 2 and _slot(newcomer, papo_id) == 1
	assert_true(await wait_until(drawn, TIMEOUT_S), "every peer draws the same slots")


func test_look_slots_maps_the_host_and_every_connected_player() -> void:
	var host := net.add_host(_lobby("Yuni"))
	var papo := await net.join(_lobby("Papo"))
	var dayana := await net.join(_lobby("Dayana"))
	assert_not_null(papo)
	assert_not_null(dayana)
	if papo == null or dayana == null:
		return
	var papo_id: int = net.peer_id(papo)
	var dayana_id: int = net.peer_id(dayana)
	net.drop(dayana)
	assert_true(await wait_until(func() -> bool: return host.is_dropped(dayana_id), TIMEOUT_S))
	var expected: Dictionary[int, int] = {CoopSession.HOST_ID: 0, papo_id: 1}
	assert_eq(host.look_slots(), expected, "a dropped player keeps nothing: they are not connected")
	assert_true(papo.look_slots().is_empty(), "a client hands over nothing")
