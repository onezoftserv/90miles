extends GutTest
## crossing-late-join over ENet on localhost (NetHarness): a player who joins, or rejoins under a
## new peer, while a crossing is under way builds it from the host's snapshot and learns who left
## by which route; the host sends a crossing's messages only to peers that have it. Every session
## gets the sandbar and launches a crossing on `route_started`, as the shell does. Solo, offline,
## sends nothing.

const ISLAND_SCENE: PackedScene = preload("res://scenes/levels/sandbar_island.tscn")
const TIMEOUT_S: float = 6.0
const TILE_PX: float = 16.0

var net: NetHarness
var islands: Array[SandbarIsland] = []
var rng := RandomNumberGenerator.new()
## Session instance id -> how many times its routes emitted route_started.
var starts: Dictionary[int, int] = {}


func before_each() -> void:
	net = NetHarness.new(self)
	WeatherManager.stop()
	WeatherManager.sky.start_at(0.0)
	starts.clear()


func after_each() -> void:
	net.teardown()
	for island: SandbarIsland in islands:
		island.free()
	islands.clear()


# The sandbar in `session`, with a crossing launched on every route start (the shell's job).
func _setup(session: CoopSession) -> void:
	var island := ISLAND_SCENE.instantiate() as SandbarIsland
	add_child(island)
	islands.append(island)
	session.terrain = island.terrain
	session.climate = island.climate
	session.spawn_points = island.spawn_points(false)
	island.furnish(session)
	var routes := session.get_node("Routes") as IslandRoutes
	var key: int = session.get_instance_id()
	starts[key] = 0
	routes.route_started.connect(func(id: StringName, peers: Array[int]) -> void:
		starts[key] += 1
		var route := GameState.content.get_entry(&"routes", id) as RouteData
		var integrity: float = routes.departure_integrity.get(id, float(route.vessel_integrity))
		Crossing.launch(session, route, peers, integrity, DataEnums.DistanceBand.COAST, rng))


func _as(identity: PlayerIdentity) -> Callable:
	return func(session: CoopSession) -> void:
		_setup(session)
		session.local_identity = identity


func _routes(session: CoopSession) -> IslandRoutes:
	return session.get_node("Routes") as IslandRoutes


# A host and a client (with `identity`, if given), spawned and settled.
func _pair(identity: PlayerIdentity = null) -> Array[CoopSession]:
	var host := net.add_host(_setup)
	var client := await net.join(_as(identity) if identity != null else _setup)
	assert_not_null(client)
	assert_true(await net.settle())
	net.silence_input()
	var pair: Array[CoopSession] = [host, client]
	return pair


# The crossing numbered `serial` on `session` once it exists and has a plan, or null.
func _crossing_on(session: CoopSession, serial: int = 0) -> Crossing:
	var path := NodePath(Crossing.node_name_for(serial))
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


# The client swims off with the binoculars; the host stays on the island.
func _client_swims(host: CoopSession, client_id: int) -> Crossing:
	WeatherManager.sky.weather.apply(&"calm", 100.0, &"", -1.0)
	host.body(client_id).inventory.add(&"binoculars", 1)
	host.body(client_id).meters.energy = 100.0
	host.body(1).meters.energy = 99.0
	assert_true(host.start_route_for(client_id, &"binoculars_swim"))
	var crossing := host.get_node_or_null("Crossing0") as Crossing
	if crossing != null:
		crossing.plan = CrossingPlan.create(600.0)
	return crossing


func _assert_camera_on_sea(body: PlayerBody, crossing: Crossing) -> void:
	var rect := crossing.sea_rect()
	assert_eq(body.camera.limit_left, int(rect.position.x))
	assert_eq(body.camera.limit_top, int(rect.position.y))
	assert_eq(body.camera.limit_right, int(rect.end.x))
	assert_eq(body.camera.limit_bottom, int(rect.end.y))


# --- a late joiner ------------------------------------------------------------------------------

func test_a_late_joiner_sees_the_crossing_under_way() -> void:
	var pair := await _pair()
	var host := pair[0]
	var a_id: int = net.peer_id(pair[1])
	var host_crossing := _raft_for_both(host)
	assert_not_null(host_crossing)
	if host_crossing == null:
		return
	host_crossing.advance(20.0)
	host_crossing.hit_vessel(30.0)
	host_crossing.throw_in(a_id)
	CrossingRig.put_beside_deck(host_crossing, host_crossing.body_of(a_id), 24.0)
	var late := await net.join(_setup)
	assert_not_null(late)
	if late == null:
		return
	var theirs := await _crossing_on(late)
	assert_not_null(theirs, "the late joiner builds the crossing")
	if theirs == null:
		return
	assert_eq(theirs.peers(), host_crossing.peers(), "the same riders in the same slots")
	assert_eq(theirs.route.id, &"raft")
	assert_eq(theirs.plan.to_array(), host_crossing.plan.to_array(), "the host's plan")
	assert_almost_eq(theirs.elapsed_s, host_crossing.elapsed_s, 1.0, "the host's clock")
	assert_eq(theirs.integrity.maximum, host_crossing.integrity.maximum)
	assert_eq(theirs.integrity.value, host_crossing.integrity.value)
	assert_eq(theirs.rider_state(1), Crossing.Rider.ABOARD)
	assert_eq(theirs.rider_state(a_id), Crossing.Rider.IN_WATER)
	var swimmer := theirs.body_of(a_id)
	assert_lt(swimmer.global_position.distance_to(host_crossing.body_of(a_id).global_position), TILE_PX, "where the host has the swimmer")
	assert_same(swimmer.terrain, theirs.sea, "the swimmer is in the sea")
	assert_ne(net.own_body(late).terrain, theirs.sea, "the late joiner stays on the island")
	assert_eq(starts[late.get_instance_id()], 0, "learning the crossing starts no route")
	host_crossing.bring_aboard(a_id)
	var aboard := func() -> bool: return theirs.rider_state(a_id) == Crossing.Rider.ABOARD
	assert_true(await wait_until(aboard, TIMEOUT_S), "the host's later states reach the late joiner")
	host_crossing.advance(host_crossing.plan.length_s)
	assert_true(host_crossing.finished)
	assert_true(await wait_until(func() -> bool: return theirs.finished, TIMEOUT_S), "and so does the end")
	assert_eq(theirs.result.route_id, &"raft")
	assert_eq(theirs.result.riders.keys(), host_crossing.result.riders.keys())


func test_a_late_joiner_learns_who_left_and_who_stayed() -> void:
	var pair := await _pair()
	var host := pair[0]
	var a_id: int = net.peer_id(pair[1])
	var swim := _client_swims(host, a_id)
	assert_not_null(swim)
	var late := await net.join(_setup)
	assert_not_null(late)
	if late == null:
		return
	var told := func() -> bool: return _routes(late).has_left(a_id)
	assert_true(await wait_until(told, TIMEOUT_S), "the late joiner learns the departure")
	assert_eq(_routes(late).route_left_by(a_id), &"binoculars_swim")
	assert_false(_routes(late).has_left(1), "the host is still on the island")
	assert_eq(_routes(late).departed, _routes(host).departed)
	assert_eq(starts[late.get_instance_id()], 0, "and no crossing starts because of it")
	var theirs := await _crossing_on(late)
	assert_not_null(theirs, "it sees the swim under way")
	if theirs != null:
		assert_eq(theirs.peers(), [a_id] as Array[int])
		assert_false(theirs.integrity.has_integrity(), "swimmers have no vessel")


func test_the_next_crossing_has_the_same_name_on_a_late_joiner() -> void:
	var pair := await _pair()
	var host := pair[0]
	var a_id: int = net.peer_id(pair[1])
	var swim := _client_swims(host, a_id)
	swim.plan = CrossingPlan.create(0.5)
	swim.advance(0.5)
	assert_true(swim.finished)
	var late := await net.join(_setup)
	assert_not_null(late)
	if late == null:
		return
	var follows := func() -> bool: return Crossing.next_serial(late) == Crossing.next_serial(host)
	assert_true(await wait_until(follows, TIMEOUT_S), "the joiner takes the host's crossing number")
	assert_null(late.get_node_or_null("Crossing0"), "an ended crossing is not built")


# --- a rejoin -----------------------------------------------------------------------------------

func test_a_rider_who_rejoins_mid_crossing_is_back_on_the_raft() -> void:
	var papo := PlayerIdentity.create()
	var pair := await _pair(papo)
	var host := pair[0]
	var old_id: int = net.peer_id(pair[1])
	var host_crossing := _raft_for_both(host)
	assert_not_null(host_crossing)
	if host_crossing == null:
		return
	host_crossing.tie(old_id)
	var slots: Array[int] = host_crossing.peers().duplicate()
	net.drop(pair[1])
	assert_true(await wait_until(func() -> bool: return host.is_dropped(old_id), TIMEOUT_S))
	var back := await net.join(_as(papo))
	assert_not_null(back, "Papo joins again")
	if back == null:
		return
	var new_id: int = net.peer_id(back)
	var expected: Array[int] = slots.duplicate()
	expected[slots.find(old_id)] = new_id
	assert_eq(host_crossing.peers(), expected, "the host keeps Papo in his slot")
	var theirs := await _crossing_on(back)
	assert_not_null(theirs, "the rejoined client builds the crossing")
	if theirs == null:
		return
	assert_eq(theirs.peers(), expected)
	assert_eq(theirs.rider_state(new_id), Crossing.Rider.TIED, "still tied down")
	var own := net.own_body(back)
	assert_same(theirs.body_of(new_id), own, "the rider is Papo's own body")
	assert_same(own.terrain, theirs.sea, "on sea ground")
	assert_true(own.pinned, "tied down")
	assert_true(own.camera.enabled, "the camera follows Papo")
	_assert_camera_on_sea(own, theirs)
	assert_true(theirs.sea_rect().has_point(own.global_position), "in the sea")
	assert_eq(_routes(back).route_left_by(new_id), &"raft", "Papo left by raft, under his new peer")
	assert_false(_routes(back).has_left(old_id))
	assert_eq(starts[back.get_instance_id()], 0)
	host_crossing.untie(new_id)
	var untied := func() -> bool: return theirs.rider_state(new_id) == Crossing.Rider.ABOARD
	assert_true(await wait_until(untied, TIMEOUT_S), "the host's later states reach Papo")


# --- who gets crossing messages -----------------------------------------------------------------

func test_a_peer_still_joining_gets_no_crossing_messages() -> void:
	var pair := await _pair()
	var host := pair[0]
	var host_crossing := _raft_for_both(host)
	assert_not_null(host_crossing)
	if host_crossing == null:
		return
	var waiting := net.add_silent_client()
	assert_true(await net.wait_connected(waiting))
	var waiting_id: int = net.peer_id(waiting)
	assert_true(await wait_until(func() -> bool: return host.multiplayer.get_peers().has(waiting_id), TIMEOUT_S))
	host_crossing.hit_vessel(10.0)
	host_crossing.advance(0.1)
	await wait_physics_frames(10)
	assert_false(host_crossing.recipients().has(waiting_id), "not told of the crossing yet")
	assert_true(host_crossing.recipients().has(net.peer_id(pair[1])))
	assert_null(waiting.get_node_or_null("Crossing0"))


func test_a_peer_that_saw_the_start_while_joining_keeps_one_crossing() -> void:
	var pair := await _pair()
	var host := pair[0]
	var early := net.add_silent_client(_setup)
	assert_true(await net.wait_connected(early))
	var early_id: int = net.peer_id(early)
	assert_true(await wait_until(func() -> bool: return host.multiplayer.get_peers().has(early_id), TIMEOUT_S))
	var host_crossing := _raft_for_both(host)
	assert_not_null(host_crossing)
	var built := func() -> bool: return early.get_node_or_null("Crossing0") != null
	assert_true(await wait_until(built, TIMEOUT_S), "the route start reached it before its join was answered")
	var seen := early.get_node("Crossing0") as Crossing
	await wait_physics_frames(10)
	assert_null(seen.plan, "but no crossing messages until its join is answered")
	assert_false(host_crossing.recipients().has(early_id))
	early.start()
	assert_true(await wait_until(func() -> bool: return seen.plan != null, TIMEOUT_S), "the snapshot brings the plan")
	assert_true(host_crossing.recipients().has(early_id))
	host_crossing.hit_vessel(25.0)
	var refreshed := func() -> bool: return seen.integrity.value == host_crossing.integrity.value
	assert_true(await wait_until(refreshed, TIMEOUT_S))
	var count: int = 0
	for child: Node in early.get_children():
		if child is Crossing:
			count += 1
	assert_eq(count, 1, "one crossing, not two")
	assert_eq(starts[early.get_instance_id()], 1, "started once, by the route start")


# --- 1 player, offline --------------------------------------------------------------------------

func test_solo_launch_sends_nothing() -> void:
	NetManager.start_solo()
	var session := CrossingRig.make_session(self, 1)
	var route := GameState.content.get_entry(&"routes", &"raft") as RouteData
	var crossing := Crossing.launch(session, route, [1] as Array[int], 100.0, DataEnums.DistanceBand.COAST, rng)
	crossing.plan = CrossingPlan.create(5.0)
	assert_eq(crossing.recipients(), [] as Array[int], "nobody to tell")
	CrossingRig.run(crossing, 5.0)
	assert_true(crossing.finished, "the solo crossing ends as before")
	assert_true(crossing.result.riders[1]["aboard"])
	NetManager.leave()
