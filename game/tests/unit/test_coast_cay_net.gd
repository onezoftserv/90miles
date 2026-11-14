extends GutTest
## escape-routes "Split parties" and crossing "Arrival" over ENet on localhost (NetHarness): riders
## whose crossing ended wait out of play, the host loads the coast cay for every peer once nobody
## is left on the sandbar, a client never loads it on its own, and the wait survives a drop and a
## rejoin. Each branch builds the island and the IslandTravel the way the shell does.

const ISLAND_SCENE: PackedScene = preload("res://scenes/levels/sandbar_island.tscn")
const TIMEOUT_S: float = 6.0
const COAST: StringName = &"coast_cay"
const SANDBAR: StringName = &"sandbar"

var net: NetHarness
var papo: PlayerIdentity


func before_each() -> void:
	net = NetHarness.new(self)
	papo = PlayerIdentity.create()
	WeatherManager.stop()
	WeatherManager.sky.start_at(0.0)


func after_each() -> void:
	net.teardown()


# The shell's order: the island beside the session, the session's ground and spawn points,
# furnish, then the travel keeper. The harness calls this before start().
func _setup(session: CoopSession) -> void:
	var island := ISLAND_SCENE.instantiate() as SandbarIsland
	island.with_creatures = false
	session.get_parent().add_child(island)
	session.terrain = island.terrain
	session.climate = island.climate
	session.spawn_points = island.spawn_points(false)
	island.furnish(session)
	var travel := IslandTravel.new()
	travel.name = "Travel"
	session.add_child(travel)
	travel.setup(session, island)


func _as(identity: PlayerIdentity, player_name: String) -> Callable:
	return func(session: CoopSession) -> void:
		_setup(session)
		session.local_identity = identity
		session.local_name = player_name


func _travel(session: CoopSession) -> IslandTravel:
	return session.get_node("Travel") as IslandTravel


func _island_id(session: CoopSession) -> StringName:
	return _travel(session).island.layout.id


# A host and one client on the sandbar, both bodies on both peers.
func _pair() -> Array[CoopSession]:
	var host := net.add_host(_setup)
	_travel(host).island.place_pickups(host)
	var client := await net.join(_setup)
	assert_not_null(client)
	assert_true(await net.settle())
	net.silence_input()
	return [host, client] as Array[CoopSession]


func _result(peer: int, health: float, energy: float, integrity: float, broken: bool = false) -> CrossingResult:
	var result := CrossingResult.new()
	result.route_id = &"raft"
	result.integrity = integrity
	result.broken = broken
	result.riders[peer] = {"health": health, "energy": energy, "aboard": not broken, "dead": false}
	return result


# `peer`'s crossing ends with these numbers: the host's meters say them and every peer's travel
# hears the result, as the shell's Crossing.ended handler tells it.
func _end_crossing(host: CoopSession, peer: int, health: float, energy: float, integrity: float) -> void:
	var meters := host.body(peer).meters
	meters.health = health
	meters.energy = energy
	var result := _result(peer, health, energy, integrity)
	for session: CoopSession in net.sessions:
		if is_instance_valid(session) and session.body(peer) != null:
			_travel(session).crossing_ended(result)


func _landing(session: CoopSession, index: int) -> Vector2:
	return IslandLayout.cell_center(_travel(session).island.built.landing_cells()[index])


func _on_both(sessions: Array[CoopSession], island_id: StringName) -> Callable:
	return func() -> bool:
		for session: CoopSession in sessions:
			if _island_id(session) != island_id:
				return false
		return true


func test_the_one_who_stayed_dies() -> void:
	var pair := await _pair()
	var host := pair[0]
	var client := pair[1]
	var client_id: int = net.peer_id(client)
	_end_crossing(host, 1, 90.0, 40.0, 70.0)
	for session: CoopSession in pair:
		assert_true(session.body(1).left_island, "the rider waits out of play")
		assert_false(session.body(1).visible)
		assert_eq(_island_id(session), SANDBAR, "the sandbar stays the live island")
	await wait_frames(5)
	assert_eq(_island_id(host), SANDBAR, "the second player is still on it")
	host.body(client_id).meters.dead = true
	host.body(client_id).meters.died.emit()
	assert_true(await wait_until(_on_both(pair, COAST), TIMEOUT_S), "the coast cay loads on both peers")
	for session: CoopSession in pair:
		var rider := session.body(1)
		assert_false(rider.left_island)
		assert_true(rider.visible)
		assert_eq(rider.position, _landing(session, 0), "the first player on the landing")
		assert_eq(rider.terrain, _travel(session).island.terrain)
	assert_eq(host.body(1).meters.health, 90.0)
	assert_eq(host.body(1).meters.energy, 40.0)


func test_both_cross_and_land_together() -> void:
	var pair := await _pair()
	var host := pair[0]
	var client := pair[1]
	var client_id: int = net.peer_id(client)
	_end_crossing(host, 1, 90.0, 40.0, 60.0)
	await wait_frames(5)
	assert_eq(_island_id(host), SANDBAR, "the other rider is still crossing")
	_end_crossing(host, client_id, 70.0, 55.0, 80.0)
	assert_true(await wait_until(_on_both(pair, COAST), TIMEOUT_S))
	for session: CoopSession in pair:
		var a := session.body(1)
		var b := session.body(client_id)
		assert_eq(a.position, _landing(session, 0))
		assert_eq(b.position, _landing(session, 1))
		assert_lte(a.position.distance_to(b.position), 80.0, "within 5 tiles")
		var raft := session.get_node_or_null("Raft") as Raft
		assert_not_null(raft, "one raft is beached")
		assert_eq(raft.integrity, 80.0, "the sturdier of the two")
	assert_eq(host.body(client_id).meters.health, 70.0)
	assert_eq(host.body(client_id).meters.energy, 55.0)


# A rider in a crossing is not held until it ends (the shell holds riders in Crossing.ended), so a
# player who has not arrived keeps the sandbar open whether they stand on it or are still crossing.
func test_a_player_who_has_not_arrived_holds_the_load() -> void:
	var pair := await _pair()
	var host := pair[0]
	var client_id: int = net.peer_id(pair[1])
	_end_crossing(host, 1, 90.0, 40.0, 0.0)
	assert_eq(_travel(host).check(), IslandTravel.Outcome.PLAYING, "the other player is not done")
	await wait_frames(5)
	assert_eq(_island_id(host), SANDBAR)
	_end_crossing(host, client_id, 80.0, 50.0, 0.0)
	assert_eq(_travel(host).check(), IslandTravel.Outcome.TRAVEL)
	assert_true(await wait_until(_on_both(pair, COAST), TIMEOUT_S))
	assert_null(host.get_node_or_null("Raft"), "no vessel from a swim: nothing beached")


func test_a_clients_arrival_is_driven_by_the_host() -> void:
	var pair := await _pair()
	var host := pair[0]
	var client := pair[1]
	var arrivals: Dictionary = {
		1: {"health": 100.0, "energy": 100.0},
		net.peer_id(client): {"health": 100.0, "energy": 100.0},
	}
	# A client cannot load an island on its own, and the host ignores what makes no sense.
	client.travel_to(String(COAST), arrivals, 0.0)
	host.travel_to("no_such_island", arrivals, 0.0)
	host.travel_to(String(COAST), {"x": 1}, 0.0)
	host.travel_to(String(COAST), arrivals, NAN)
	await wait_frames(5)
	assert_eq(_island_id(client), SANDBAR, "the client stays where the host is")
	assert_eq(_island_id(host), SANDBAR)
	_travel(host).travel(COAST)
	assert_true(await wait_until(_on_both(pair, COAST), TIMEOUT_S), "the client loads it after the host's call")
	var on_client: Vector2 = client.body(1).position
	assert_eq(on_client, host.body(1).position, "the same spot on both peers")
	assert_eq(client.body(net.peer_id(client)).position, host.body(net.peer_id(client)).position)


func test_a_late_joiner_lands_on_the_coast_cay() -> void:
	var host := net.add_host(_setup)
	_travel(host).island.place_pickups(host)
	_travel(host).travel(COAST)
	var joiner := await net.join(_setup)
	assert_not_null(joiner)
	if joiner == null:
		return
	assert_true(await net.settle())
	var id: int = net.peer_id(joiner)
	assert_true(await wait_until(func() -> bool: return _island_id(joiner) == COAST, TIMEOUT_S), "the joiner follows the host's island")
	var own := joiner.body(id)
	assert_eq(own.position, host.body(id).position)
	assert_eq(own.terrain, _travel(joiner).island.terrain)
	assert_true(IslandLayout.cell_center(_travel(host).island.built.landing_cells()[1]) == host.body(id).position, "at a landing cell")


func test_a_joiner_on_the_coast_cay_counts_two_islands() -> void:
	var host := net.add_host(_setup)
	_travel(host).island.place_pickups(host)
	_travel(host).travel(COAST)
	assert_eq(_travel(host).islands_reached, 2, "the sandbar and the cay")
	var joiner := await net.join(_setup)
	assert_not_null(joiner)
	if joiner == null:
		return
	assert_true(await wait_until(func() -> bool: return _island_id(joiner) == COAST, TIMEOUT_S))
	assert_eq(_travel(joiner).islands_reached, 2, "the host's count, not 1")


func test_a_waiting_rider_who_drops_and_rejoins_stays_a_waiting_rider() -> void:
	var host := net.add_host(_setup)
	var client := await net.join(_as(papo, "Papo"))
	assert_not_null(client)
	assert_true(await net.settle())
	net.silence_input()
	var old_id: int = net.peer_id(client)
	_end_crossing(host, old_id, 75.0, 45.0, 0.0)
	assert_true(host.body(old_id).left_island)
	net.drop(client)
	assert_true(await wait_until(func() -> bool: return host.is_dropped(old_id), TIMEOUT_S))
	assert_eq(_island_id(host), SANDBAR, "a dropped rider does not open or close anything")
	var back := await net.join(_as(papo, "Papo"))
	assert_not_null(back)
	if back == null:
		return
	var new_id: int = net.peer_id(back)
	assert_ne(new_id, old_id)
	assert_true(host.body(new_id).left_island, "still waiting under the new peer")
	var held := func() -> bool: return back.body(new_id) != null and back.body(new_id).left_island
	assert_true(await wait_until(held, TIMEOUT_S), "and the rejoined client shows it too")
	# The host's own player was the one still playing: when they die, the waiting rider lands.
	host.body(1).meters.dead = true
	host.body(1).meters.died.emit()
	var sessions: Array[CoopSession] = [host, back]
	assert_true(await wait_until(_on_both(sessions, COAST), TIMEOUT_S))
	assert_eq(host.body(new_id).position, _landing(host, 1), "the rejoined rider lands with the rest")
	assert_false(host.body(new_id).left_island)
	assert_eq(host.body(new_id).meters.health, 75.0)


func test_a_removed_player_counts_as_dead_for_the_load() -> void:
	var host := net.add_host(_setup)
	var client := await net.join(_as(papo, "Papo"))
	assert_not_null(client)
	assert_true(await net.settle())
	net.silence_input()
	var client_id: int = net.peer_id(client)
	_end_crossing(host, 1, 88.0, 42.0, 55.0)
	net.drop(client)
	assert_true(await wait_until(func() -> bool: return host.is_dropped(client_id), TIMEOUT_S))
	# dropped-teammate-state: the dropped body alone keeps the waiting rider from landing, so its
	# time is cut to the short hold.
	assert_lte(host.disconnect_time_left(client_id), IslandTravel.DROPPED_HOLD_S, "cut to the short hold")
	assert_eq(IslandTravel.DROPPED_HOLD_S, 30.0)
	host._physics_process(IslandTravel.DROPPED_HOLD_S - 5.0)
	await wait_frames(5)
	assert_eq(_island_id(host), SANDBAR, "a dropped player may come back: the sandbar stays open")
	host._physics_process(6.0)
	assert_true(await wait_until(func() -> bool: return _island_id(host) == COAST, TIMEOUT_S), "removed after 30 s: nobody living is left on the sandbar")
	assert_eq(host.removed_names(), ["Papo"] as Array[String])
	assert_eq(host.body(1).position, _landing(host, 0))
	assert_eq(host.body(1).meters.health, 88.0)


# --- dropped-teammate-state: the short hold ---------------------------------------------------

func test_a_dropped_player_back_within_the_short_hold_plays_on() -> void:
	var host := net.add_host(_setup)
	var client := await net.join(_as(papo, "Papo"))
	assert_not_null(client)
	assert_true(await net.settle())
	net.silence_input()
	var old_id: int = net.peer_id(client)
	var papo_body := host.body(old_id)
	_end_crossing(host, 1, 88.0, 42.0, 55.0)
	net.drop(client)
	assert_true(await wait_until(func() -> bool: return host.is_dropped(old_id), TIMEOUT_S))
	host._physics_process(20.0)
	assert_true(host.is_dropped(old_id), "10 s of the hold left")
	var back := await net.join(_as(papo, "Papo"))
	assert_not_null(back, "Papo joins again 20 s after the drop")
	if back == null:
		return
	var new_id: int = net.peer_id(back)
	assert_same(host.body(new_id), papo_body, "his own body")
	assert_false(papo_body.downed, "standing again")
	assert_false(papo_body.left_island, "on the sandbar, playing")
	host._physics_process(IslandTravel.DROPPED_HOLD_S)
	await wait_frames(5)
	assert_eq(_island_id(host), SANDBAR, "the sandbar stays the live island")
	assert_true(host.body(1).left_island, "the host still waits")
	assert_eq(_travel(host).check(), IslandTravel.Outcome.PLAYING)
	assert_eq(host.removed_names(), [] as Array[String], "nobody removed")


func test_a_dropped_rider_in_a_crossing_holds_the_load() -> void:
	var pair := await _pair()
	var host := pair[0]
	var client_id: int = net.peer_id(pair[1])
	_end_crossing(host, 1, 90.0, 40.0, 60.0)
	# The client set off by a route and is still crossing (left, not yet held).
	(host.get_node("Routes") as IslandRoutes).departed[client_id] = &"raft"
	net.drop(pair[1])
	assert_true(await wait_until(func() -> bool: return host.is_dropped(client_id), TIMEOUT_S))
	assert_gt(host.disconnect_time_left(client_id), IslandTravel.DROPPED_HOLD_S, "a crossing rider's hold is not cut")
	host._physics_process(IslandTravel.DROPPED_HOLD_S + 1.0)
	await wait_frames(5)
	assert_eq(_island_id(host), SANDBAR, "the crossing still runs: the sandbar stays live")
	assert_eq(_travel(host).check(), IslandTravel.Outcome.PLAYING)
	_end_crossing(host, client_id, 70.0, 55.0, 80.0)
	assert_true(await wait_until(func() -> bool: return _island_id(host) == COAST, TIMEOUT_S), "the crossing ended: the party lands")
	assert_eq(host.body(1).position, _landing(host, 0))
	assert_eq(host.body(client_id).position, _landing(host, 1), "the dropped rider lands with the rest")


func test_nobody_waiting_keeps_the_full_hold() -> void:
	var pair := await _pair()
	var host := pair[0]
	var client := pair[1]
	var client_id: int = net.peer_id(client)
	host.body(1).meters.dead = true
	host.body(1).meters.died.emit()
	assert_eq(_travel(host).check(), IslandTravel.Outcome.PLAYING, "the client still plays")
	net.drop(client)
	assert_true(await wait_until(func() -> bool: return host.is_dropped(client_id), TIMEOUT_S))
	assert_gt(host.disconnect_time_left(client_id), IslandTravel.DROPPED_HOLD_S, "nobody waits: the full 90 s")
	host._physics_process(CoopSession.DISCONNECT_DOWNED_S - 5.0)
	await wait_frames(5)
	assert_eq(_travel(host).check(), IslandTravel.Outcome.PLAYING, "a drop never ends the run early")
	assert_eq(host.removed_names(), [] as Array[String])
	assert_eq(_island_id(host), SANDBAR)


func test_the_waiting_line_marks_a_dropped_teammate() -> void:
	var host := net.add_host(_setup)
	var dayana := await net.join(_as(PlayerIdentity.create(), "Dayana"))
	var client := await net.join(_as(papo, "Papo"))
	assert_not_null(dayana)
	assert_not_null(client)
	if dayana == null or client == null:
		return
	assert_true(await net.settle())
	net.silence_input()
	var papo_id: int = net.peer_id(client)
	_end_crossing(host, 1, 90.0, 40.0, 60.0)
	_end_crossing(host, net.peer_id(dayana), 80.0, 50.0, 0.0)
	assert_eq(GameShell.waiting_text(dayana), "En la orilla. Esperando a: Papo", "Papo still plays")
	net.drop(client)
	var marked := func() -> bool: return GameShell.waiting_text(dayana) == "En la orilla. Esperando a: Papo (desconectado)"
	assert_true(await wait_until(marked, TIMEOUT_S), "Dayana's line: %s" % GameShell.waiting_text(dayana))
	assert_eq(GameShell.waiting_text(host), "En la orilla. Esperando a: Papo (desconectado)", "and the host's")
	assert_true(host.is_dropped(papo_id))


# On an island that names no next one (the coast cay), the riders wait for the run's end: a dropped
# body alone holding them is cut to the short hold too, and its removal ends the run.
func test_on_the_last_island_the_short_hold_ends_the_run() -> void:
	var pair := await _pair()
	var host := pair[0]
	var client := pair[1]
	var client_id: int = net.peer_id(client)
	_travel(host).travel(COAST)
	assert_true(await wait_until(_on_both(pair, COAST), TIMEOUT_S))
	assert_true(_travel(host).island.layout.next_island.is_empty(), "the coast cay names no next island")
	_end_crossing(host, 1, 90.0, 40.0, 60.0)
	net.drop(client)
	assert_true(await wait_until(func() -> bool: return host.is_dropped(client_id), TIMEOUT_S))
	assert_lte(host.disconnect_time_left(client_id), IslandTravel.DROPPED_HOLD_S, "cut to the short hold")
	assert_eq(_travel(host).check(), IslandTravel.Outcome.PLAYING, "the run stays open meanwhile")
	host._physics_process(IslandTravel.DROPPED_HOLD_S + 1.0)
	assert_true(await wait_until(func() -> bool: return not host.removed_names().is_empty(), TIMEOUT_S), "removed after 30 s")
	assert_eq(_travel(host).check(), IslandTravel.Outcome.OVER, "and the run is over")
