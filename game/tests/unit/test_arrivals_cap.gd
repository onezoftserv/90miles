extends GutTest
## dropped-teammate-state design D5: an arrivals message and the world state's `waiting` list are
## sanity bounds on a host message, not the player cap. Dropped bodies do not hold a place in the
## cap, so four connected players and a dropped waiting rider are five arrivals, and the landing
## must not wait for the dropped one's removal.

const ISLAND_SCENE: PackedScene = preload("res://scenes/levels/sandbar_island.tscn")
const TIMEOUT_S: float = 6.0
const COAST: StringName = &"coast_cay"
const SANDBAR: StringName = &"sandbar"

var net: NetHarness


func before_each() -> void:
	net = NetHarness.new(self)
	WeatherManager.stop()
	WeatherManager.sky.start_at(0.0)


func after_each() -> void:
	net.teardown()


func _arrivals(count: int) -> Dictionary:
	var arrivals: Dictionary = {}
	for peer: int in range(1, count + 1):
		arrivals[peer] = {"health": 100.0, "energy": 100.0}
	return arrivals


func test_an_arrivals_message_holds_up_to_eight_players() -> void:
	assert_eq(CoopSession.MAX_ARRIVALS, 2 * CoopSession.MAX_PLAYERS)
	assert_not_null(CoopSession.checked_arrivals(_arrivals(5)), "four connected and one dropped")
	assert_not_null(CoopSession.checked_arrivals(_arrivals(8)))
	assert_null(CoopSession.checked_arrivals(_arrivals(9)), "still a bound")


func test_the_waiting_list_holds_five() -> void:
	var waiting: Array = [1, 2, 3, 4, 5]
	var clean := CoopSession.checked_world_state({"waiting": waiting})
	assert_eq(clean.get("waiting"), [1, 2, 3, 4, 5] as Array[int])


# --- over ENet ---------------------------------------------------------------------------------

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


func _travel(session: CoopSession) -> IslandTravel:
	return session.get_node("Travel") as IslandTravel


# `peer`'s crossing ends: the host's meters hold the numbers and every peer with the body holds it.
func _end_crossing(host: CoopSession, peer: int) -> void:
	var result := CrossingResult.new()
	result.route_id = &"raft"
	result.riders[peer] = {"health": 90.0, "energy": 50.0, "aboard": true, "dead": false}
	for session: CoopSession in net.sessions:
		if is_instance_valid(session) and session.body(peer) != null:
			_travel(session).crossing_ended(result)


func test_four_connected_and_a_dropped_waiting_rider_land_at_once() -> void:
	var host := net.add_host(_setup)
	_travel(host).island.place_pickups(host)
	var clients: Array[CoopSession] = []
	for i: int in 3:
		var client := await net.join(_setup)
		assert_not_null(client)
		if client == null:
			return
		clients.append(client)
	assert_true(await net.settle())
	net.silence_input()
	# The third client's crossing ends and it drops while waiting on the cay's shore.
	var dropped_id: int = net.peer_id(clients[2])
	_end_crossing(host, dropped_id)
	net.drop(clients[2])
	assert_true(await wait_until(func() -> bool: return host.is_dropped(dropped_id), TIMEOUT_S))
	# A fourth player joins in the dropped one's place: five bodies, four connected.
	var fourth := await net.join(_setup)
	assert_not_null(fourth, "the freed place takes a new player")
	if fourth == null:
		return
	assert_eq(host.peer_ids().size(), 5)
	for peer: int in [1, net.peer_id(clients[0]), net.peer_id(clients[1]), net.peer_id(fourth)]:
		_end_crossing(host, peer)
	assert_true(await wait_until(func() -> bool: return _travel(host).island.layout.id == COAST, TIMEOUT_S), "the coast cay loads at once, not after the removal")
	assert_true(host.is_dropped(dropped_id), "the dropped rider was not removed first")
	assert_false(host.body(dropped_id).left_island, "and lands with the rest")
	assert_true(await wait_until(func() -> bool: return _travel(fourth).island.layout.id == COAST, TIMEOUT_S), "every client follows")


# Before this change a refused landing re-queued itself within the same deferred flush, forever:
# the host hung sending travel calls, then crashed. A refused landing now waits for the next change.
func test_a_refused_landing_does_not_spin_the_host() -> void:
	var host := net.add_host(_setup)
	var travel := _travel(host)
	var layout := travel.island.layout.duplicate() as IslandLayoutData
	layout.next_island = &"no_such_island"
	travel.island.layout = layout
	_end_crossing(host, 1)
	await wait_frames(5)
	assert_eq(travel.island.layout.id, SANDBAR, "the refused landing changed nothing")
	assert_false(travel._travel_queued, "and nothing is left queued")
	assert_eq(travel.check(), IslandTravel.Outcome.TRAVEL, "it is tried again on the next change")
	await wait_frames(5)
	assert_eq(travel.island.layout.id, SANDBAR)
