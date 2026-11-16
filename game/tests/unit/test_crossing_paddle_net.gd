extends GutTest
## crossing "Paddling" and "Crossing play state on every peer" over ENet on localhost (NetHarness):
## the host applies a client's paddling, every peer shows the host's lateral position, a peer that
## joins mid-crossing gets it in the snapshot, a snapshot without it is refused, and a solo crossing
## sends nothing.

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


# The host's rider stands on the paddle of `side` and holds interact.
func _hold_paddle(crossing: Crossing, side: int) -> void:
	var deck := crossing.deck_rect()
	var x: float = deck.end.x - 4.0 if side == CrossingSteer.EAST else deck.position.x + 4.0
	crossing.body_of(1).global_position = Vector2(x, deck.get_center().y)
	crossing.body_of(1).intent = MoveIntent.create(Vector2.ZERO, false, false, true)


func _east_edge(crossing: Crossing) -> Vector2:
	var deck := crossing.deck_rect()
	return Vector2(deck.end.x - 4.0, deck.get_center().y)


func test_a_client_paddles_and_both_peers_show_it() -> void:
	var pair := await _pair()
	var client_id: int = net.peer_id(pair[1])
	var host_crossing := _raft_for_both(pair[0])
	var theirs := await _crossing_on(pair[1])
	if host_crossing == null or theirs == null:
		fail_test("no crossing")
		return
	host_crossing.body_of(client_id).global_position = _east_edge(host_crossing)
	theirs.body_of(client_id).global_position = _east_edge(theirs)
	await wait_physics_frames(10)
	theirs.body_of(client_id).intent = MoveIntent.create(Vector2.ZERO, false, false, true)
	var moved := func() -> bool: return host_crossing.steer.position >= 2.5
	assert_true(await wait_until(moved, TIMEOUT_S), "the host moves the raft east for the client's paddling")
	theirs.body_of(client_id).intent = MoveIntent.new()
	assert_gt(host_crossing.steer.position, 0.0)
	var shown := func() -> bool: return absf(theirs.steer.position - host_crossing.steer.position) < 0.5 and theirs.steer.position > 1.0
	assert_true(await wait_until(shown, TIMEOUT_S), "the client shows the raft east of the line where the host has it")


func test_the_client_sees_the_host_paddle_and_drift_back() -> void:
	var pair := await _pair()
	var host_crossing := _raft_for_both(pair[0])
	var theirs := await _crossing_on(pair[1])
	if host_crossing == null or theirs == null:
		fail_test("no crossing")
		return
	_hold_paddle(host_crossing, CrossingSteer.WEST)
	var paddled := func() -> bool: return host_crossing.steer.position <= -3.0
	assert_true(await wait_until(paddled, TIMEOUT_S))
	host_crossing.body_of(1).intent = MoveIntent.new()
	var seen := func() -> bool: return theirs.steer.position < -2.0
	assert_true(await wait_until(seen, TIMEOUT_S), "the client shows the raft west of the line")
	var back := func() -> bool: return absf(theirs.steer.position) < 0.01
	assert_true(await wait_until(back, 15.0), "and drifting back to the line with the host")


func test_a_joiner_mid_paddle_shows_the_hosts_position() -> void:
	var pair := await _pair()
	var host_crossing := _raft_for_both(pair[0])
	if host_crossing == null:
		fail_test("no crossing")
		return
	_hold_paddle(host_crossing, CrossingSteer.EAST)
	var at_limit := func() -> bool: return host_crossing.steer.position >= host_crossing.tuning.max_offset_tiles
	assert_true(await wait_until(at_limit, TIMEOUT_S), "the host holds the raft 6 tiles east")
	var late := await net.join(_setup)
	assert_not_null(late)
	if late == null:
		return
	var theirs := await _crossing_on(late)
	assert_not_null(theirs, "the joiner builds the crossing")
	if theirs == null:
		return
	assert_almost_eq(theirs.steer.position, host_crossing.steer.position, 0.5, "the joiner shows the host's position")


func test_a_client_dropped_mid_paddle_stops_paddling() -> void:
	var pair := await _pair()
	var client_id: int = net.peer_id(pair[1])
	var host_crossing := _raft_for_both(pair[0])
	var theirs := await _crossing_on(pair[1])
	if host_crossing == null or theirs == null:
		fail_test("no crossing")
		return
	host_crossing.body_of(client_id).global_position = _east_edge(host_crossing)
	theirs.body_of(client_id).global_position = _east_edge(theirs)
	await wait_physics_frames(10)
	theirs.body_of(client_id).intent = MoveIntent.create(Vector2.ZERO, false, false, true)
	var moving := func() -> bool: return host_crossing.steer.position >= 1.5
	assert_true(await wait_until(moving, TIMEOUT_S), "the client paddles")
	net.drop(pair[1])
	var back := func() -> bool: return host_crossing.steer.position == 0.0
	assert_true(await wait_until(back, 15.0), "with the client gone the current takes the raft back to the line")


func test_a_snapshot_without_the_steer_is_refused() -> void:
	NetManager.start_solo()
	var crossing := CrossingRig.make(self, &"raft", 1, 100.0, 60.0)
	var data := CrossingSnapshot.of(crossing).to_dict()
	assert_not_null(CrossingSnapshot.from_dict(data), "a whole snapshot is taken")
	data.erase("steer")
	assert_null(CrossingSnapshot.from_dict(data), "one without the steer is refused")
	var bad := CrossingSnapshot.of(crossing).to_dict()
	bad["steer"] = [INF, 0.0]
	assert_null(CrossingSnapshot.from_dict(bad), "and one with a number that is not finite")
	NetManager.leave()


func test_solo_paddling_sends_nothing() -> void:
	NetManager.start_solo()
	var crossing := CrossingRig.make(self, &"raft", 1, 100.0, 30.0)
	var body := crossing.body_of(1)
	body.global_position = _east_edge(crossing)
	body.intent = MoveIntent.create(Vector2.ZERO, false, false, true)
	CrossingRig.run(crossing, 2.0)
	assert_gt(crossing.steer.position, 2.5, "the solo raft moved")
	assert_eq(crossing.recipients(), [] as Array[int], "nobody to tell")
	NetManager.leave()
