extends GutTest
## crossing "Leaks" and "Crossing play state on every peer" over ENet on localhost (NetHarness): the
## host plugs a leak for a client's hold and both peers show it plugged, a peer that joins
## mid-crossing sees an open leak drain as on the host, a snapshot without the leaks is refused, and
## a solo crossing sends nothing.

const ISLAND_SCENE: PackedScene = preload("res://scenes/levels/sandbar_island.tscn")
const TIMEOUT_S: float = 6.0

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
	var routes := session.get_node("Routes") as IslandRoutes
	routes.route_started.connect(func(id: StringName, peers: Array[int]) -> void:
		var route := GameState.content.get_entry(&"routes", id) as RouteData
		Crossing.launch(session, route, peers, float(route.vessel_integrity), DataEnums.DistanceBand.COAST, rng))


func _pair() -> Array[CoopSession]:
	var host := net.add_host(_setup)
	var client := await net.join(_setup)
	assert_not_null(client)
	assert_true(await net.settle())
	net.silence_input()
	var pair: Array[CoopSession] = [host, client]
	return pair


func _crossing_on(session: CoopSession) -> Crossing:
	var path := NodePath(Crossing.node_name_for(0))
	var built := func() -> bool:
		var found := session.get_node_or_null(path) as Crossing
		return found != null and found.plan != null
	if not await wait_until(built, TIMEOUT_S):
		return null
	return session.get_node(path) as Crossing


# Both players build the raft and the host launches it; the host's crossing gets a 600 s plan.
func _raft_for_both(host: CoopSession) -> Crossing:
	var site := host.get_node("RaftSite") as BuildSite
	for id: int in host.peer_ids():
		host.body(id).global_position = site.global_position
	var builder := host.body(1)
	builder.inventory.add(&"driftwood", 6)
	builder.inventory.add(&"inner_tube", 2)
	builder.inventory.add(&"rope", 3)
	site.deposit(builder)
	site.work(1.0)
	assert_true(host.start_route_for(1, &"raft"), "the raft leaves with both")
	var crossing := host.get_node_or_null("Crossing0") as Crossing
	if crossing != null:
		crossing.plan = CrossingPlan.create(600.0)
	return crossing


func _east_edge(crossing: Crossing) -> Vector2:
	var deck := crossing.deck_rect()
	return Vector2(deck.end.x - 4.0, deck.get_center().y)


const K := CrossingBeat.Kind


func test_a_client_plugs_a_leak_and_both_show_it() -> void:
	var pair := await _pair()
	var client_id: int = net.peer_id(pair[1])
	var host_crossing := _raft_for_both(pair[0])
	var theirs := await _crossing_on(pair[1])
	if host_crossing == null or theirs == null:
		fail_test("no crossing")
		return
	host_crossing.hole_vessel(CrossingBeat.create(1.0, K.DEBRIS, 1))
	var shown := func() -> bool: return theirs.leaks.list.size() == 1
	assert_true(await wait_until(shown, TIMEOUT_S), "the client shows the leak")
	var spot: Vector2 = host_crossing.leak_position(host_crossing.leaks.list[0])
	host_crossing.body_of(client_id).global_position = spot
	theirs.body_of(client_id).global_position = spot
	await wait_physics_frames(10)
	theirs.body_of(client_id).intent = MoveIntent.create(Vector2.ZERO, false, false, true)
	var plugged := func() -> bool: return host_crossing.leaks.list.is_empty()
	assert_true(await wait_until(plugged, TIMEOUT_S), "the host plugs it for the client's 2 s hold")
	theirs.body_of(client_id).intent = MoveIntent.new()
	var gone := func() -> bool: return theirs.leaks.list.is_empty()
	assert_true(await wait_until(gone, TIMEOUT_S), "and the client shows it plugged")


func test_a_joiner_sees_an_open_leak_drain() -> void:
	var pair := await _pair()
	var host_crossing := _raft_for_both(pair[0])
	if host_crossing == null:
		fail_test("no crossing")
		return
	host_crossing.hole_vessel(CrossingBeat.create(1.0, K.DEBRIS, -2))
	var late := await net.join(_setup)
	assert_not_null(late)
	if late == null:
		return
	var theirs := await _crossing_on(late)
	assert_not_null(theirs, "the joiner builds the crossing")
	if theirs == null:
		return
	assert_eq(theirs.leaks.list.size(), 1, "with the open leak")
	assert_lt(float(theirs.leaks.list[0]["x"]), 0.0, "on the west half, where the host has it")
	var first: float = theirs.integrity.value
	var drained := func() -> bool: return theirs.integrity.value < first - 0.4
	assert_true(await wait_until(drained, TIMEOUT_S), "the raft keeps losing integrity there as on the host")


func test_a_snapshot_without_the_leaks_is_refused() -> void:
	NetManager.start_solo()
	var crossing := CrossingRig.make(self, &"raft", 1, 100.0, 60.0)
	crossing.hole_vessel(CrossingBeat.create(1.0, K.DEBRIS, 0))
	var data := CrossingSnapshot.of(crossing).to_dict()
	var whole := CrossingSnapshot.from_dict(data)
	assert_not_null(whole)
	assert_eq((whole.play["leaks"] as Array).size(), 1, "the leak travels")
	data.erase("leaks")
	assert_null(CrossingSnapshot.from_dict(data), "one without the leaks is refused")
	NetManager.leave()


func test_solo_plugging_sends_nothing() -> void:
	NetManager.start_solo()
	var crossing := CrossingRig.make(self, &"raft", 1, 100.0, 30.0, [CrossingBeat.create(2.0, K.DEBRIS, 0)])
	var body := crossing.body_of(1)
	CrossingRig.run(crossing, 2.5)
	body.global_position = crossing.leak_position(crossing.leaks.list[0])
	CrossingRig.hold(crossing, body, 2.1)
	CrossingRig.release(crossing, body)
	assert_true(crossing.leaks.list.is_empty(), "the solo rider plugged it")
	assert_eq(crossing.recipients(), [] as Array[int], "nobody to tell")
	NetManager.leave()
