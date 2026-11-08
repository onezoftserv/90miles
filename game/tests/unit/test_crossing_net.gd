extends GutTest
## crossing over ENet on localhost (NetHarness): the host applies a client's tie-down and climb from
## the intents it sends, the client only shows what the host says, and the plan is never rolled by
## a client.

const TIMEOUT_S: float = 6.0

const ISLAND_SCENE: PackedScene = preload("res://scenes/levels/sandbar_island.tscn")

var net: NetHarness
var islands: Array[SandbarIsland] = []
var rng := RandomNumberGenerator.new()


func before_each() -> void:
	net = NetHarness.new(self)
	WeatherManager.stop()
	WeatherManager.sky.start_at(0.0)


func after_each() -> void:
	net.teardown()
	for island: SandbarIsland in islands:
		island.free()
	islands.clear()


func _setup(session: CoopSession) -> void:
	var island := ISLAND_SCENE.instantiate() as SandbarIsland
	add_child(island)
	islands.append(island)
	session.terrain = island.terrain
	session.climate = island.climate
	session.spawn_points = island.spawn_points(false)
	island.with_creatures = false
	island.furnish(session)


func _route(id: StringName) -> RouteData:
	return GameState.content.get_entry(&"routes", id) as RouteData


# A host and a client with a crossing for both, built the way the shell does: the client's node
# first, so the host's plan finds it.
func _crossings(route_id: StringName, riders: Array[int] = []) -> Array[Crossing]:
	var host := net.add_host(_setup)
	var client := await net.join(_setup)
	assert_true(await net.settle())
	net.silence_input()
	var peers: Array[int] = riders if not riders.is_empty() else host.peer_ids()
	var made: Array[Crossing] = []
	made.append(Crossing.launch(client, _route(route_id), peers, 100.0, DataEnums.DistanceBand.COAST, rng))
	made.append(Crossing.launch(host, _route(route_id), peers, 100.0, DataEnums.DistanceBand.COAST, rng))
	made[1].plan = CrossingPlan.create(600.0)
	await wait_until(func() -> bool: return made[0].plan != null, TIMEOUT_S)
	return made


func _hold(client_crossing: Crossing, client_id: int, held: bool) -> void:
	client_crossing.body_of(client_id).intent = MoveIntent.create(Vector2.ZERO, false, false, held)


func test_client_tie_down_applied_by_host() -> void:
	var pair := await _crossings(&"raft")
	var client_id: int = net.peer_id(net.sessions[1])
	_hold(pair[0], client_id, true)
	var tied := func() -> bool: return pair[1].rider_state(client_id) == Crossing.Rider.TIED
	assert_true(await wait_until(tied, TIMEOUT_S), "the host ties the sender down")
	_hold(pair[0], client_id, false)
	var shown := func() -> bool: return pair[0].rider_state(client_id) == Crossing.Rider.TIED
	assert_true(await wait_until(shown, TIMEOUT_S), "the client shows it")
	assert_true(pair[0].body_of(client_id).pinned)


func test_client_climb_applied_by_host() -> void:
	var pair := await _crossings(&"raft")
	var client_id: int = net.peer_id(net.sessions[1])
	var host_crossing: Crossing = pair[1]
	host_crossing.hit_vessel(40.0)
	assert_eq(host_crossing.integrity.value, 60.0)
	host_crossing.throw_in(client_id)
	CrossingRig.put_beside_deck(host_crossing, host_crossing.body_of(client_id), 6.0)
	var in_water := func() -> bool: return pair[0].rider_state(client_id) == Crossing.Rider.IN_WATER
	assert_true(await wait_until(in_water, TIMEOUT_S), "the client sees the fall")
	await wait_physics_frames(10)
	_hold(pair[0], client_id, true)
	var aboard := func() -> bool: return host_crossing.rider_state(client_id) == Crossing.Rider.ABOARD
	assert_true(await wait_until(aboard, TIMEOUT_S), "3 s of the client's intents bring them aboard")
	_hold(pair[0], client_id, false)
	var shown := func() -> bool: return pair[0].rider_state(client_id) == Crossing.Rider.ABOARD
	assert_true(await wait_until(shown, TIMEOUT_S), "the client shows it")


func test_client_never_rolls_plan() -> void:
	var pair := await _crossings(&"raft")
	var client_crossing: Crossing = pair[0]
	assert_not_null(client_crossing.plan, "the host's plan arrived")
	var fresh := Crossing.SCENE.instantiate() as Crossing
	autofree(fresh)
	assert_null(fresh.plan, "a crossing built on a client starts without one")
	var before: Array = client_crossing.plan.to_array()
	client_crossing.receive_plan([5.0, []], 1.0)
	assert_eq(client_crossing.plan.to_array(), before, "a second plan is ignored")
	client_crossing.receive_state({1: Crossing.Rider.DEAD}, 1.0, 5.0)
	assert_ne(client_crossing.rider_state(1), Crossing.Rider.DEAD, "no sender, no host: ignored")


func test_one_crosses_one_stays() -> void:
	var host := net.add_host(_setup)
	var client := await net.join(_setup)
	assert_true(await net.settle())
	net.silence_input()
	var client_id: int = net.peer_id(client)
	var crossings: Array[Crossing] = []
	for session: CoopSession in [client, host]:
		(session.get_node("Routes") as IslandRoutes).route_started.connect(
			func(id: StringName, peers: Array[int]) -> void:
				crossings.append(Crossing.launch(session, _route(id), peers, 100.0, DataEnums.DistanceBand.COAST, rng)))
	WeatherManager.sky.weather.apply(&"calm", 100.0, &"", -1.0)
	host.body(client_id).inventory.add(&"binoculars", 1)
	host.body(client_id).meters.energy = 100.0
	host.body(1).meters.energy = 99.0
	assert_true(host.start_route_for(client_id, &"binoculars_swim"))
	assert_true(await wait_until(func() -> bool: return crossings.size() == 2, TIMEOUT_S))
	for crossing: Crossing in crossings:
		assert_eq(crossing.peers(), [client_id])
		assert_eq(crossing.rider_state(client_id), Crossing.Rider.IN_WATER)
	assert_false((host.get_node("Routes") as IslandRoutes).has_left(1), "the host stays on the island")
	assert_ne(crossings[1].body_of(1).terrain, crossings[1].sea, "the host body keeps the island ground")
