extends GutTest
## island-stop crossing "Fittings ride with the raft" over ENet on localhost (NetHarness): a client's
## crossing is built, as the shell builds it, with no fittings of its own, and learns the fitted
## raft's maximum and fittings from the host's plan, its deck shaded under a toldo; the host's hits
## take the defensas' three quarters and the client shows the result.

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


func _fit(ids: Array) -> Array[StringName]:
	var fitted: Array[StringName] = []
	fitted.assign(ids)
	return fitted


func test_a_client_learns_the_rafts_maximum_and_fittings() -> void:
	var host := net.add_host(_setup)
	var client := await net.join(_setup)
	assert_not_null(client)
	if client == null:
		return
	assert_true(await net.settle())
	net.silence_input()
	var route := GameState.content.get_entry(&"routes", &"raft") as RouteData
	var peers: Array[int] = host.peer_ids()
	# The client's node first, with what a client's routes know: no fittings, the route's 100.
	var theirs := Crossing.launch(client, route, peers, 100.0, DataEnums.DistanceBand.COAST, rng)
	var mine := Crossing.launch(host, route, peers, 90.0, DataEnums.DistanceBand.COAST, rng, _fit([&"raft_clavazon", &"raft_defensas", &"raft_toldo"]))
	assert_eq(mine.integrity.maximum, 120.0)
	assert_true(await wait_until(func() -> bool: return theirs.plan != null, TIMEOUT_S), "the plan arrives")
	assert_eq(theirs.fittings, _fit([&"raft_clavazon", &"raft_defensas", &"raft_toldo"]), "the client has the fittings")
	assert_eq(theirs.integrity.maximum, 120.0, "and the raised maximum")
	assert_eq(theirs.integrity.value, 90.0)
	assert_true(theirs.deck_shaded(), "its deck is shaded")
	mine.hit_vessel(mine.tuning.rock_hit * mine.hazard_factor())
	assert_eq(mine.integrity.value, 60.0, "the host's rock takes three quarters of 40")
	assert_true(await wait_until(func() -> bool: return is_equal_approx(theirs.integrity.value, 60.0), TIMEOUT_S), "the client shows 60")
	await wait_physics_frames(10)
	assert_eq(get_errors().size(), 0)


func test_a_bare_raft_sends_no_fittings() -> void:
	var host := net.add_host(_setup)
	var client := await net.join(_setup)
	assert_not_null(client)
	if client == null:
		return
	assert_true(await net.settle())
	net.silence_input()
	var route := GameState.content.get_entry(&"routes", &"raft") as RouteData
	var peers: Array[int] = host.peer_ids()
	var theirs := Crossing.launch(client, route, peers, 100.0, DataEnums.DistanceBand.COAST, rng)
	Crossing.launch(host, route, peers, 70.0, DataEnums.DistanceBand.COAST, rng)
	assert_true(await wait_until(func() -> bool: return theirs.plan != null, TIMEOUT_S))
	assert_eq(theirs.fittings, _fit([]))
	assert_eq(theirs.integrity.maximum, 100.0)
	assert_eq(theirs.integrity.value, 70.0)
	assert_false(theirs.deck_shaded())
