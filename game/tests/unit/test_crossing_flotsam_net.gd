extends GutTest
## crossing "Flotsam" and "Crossing play state on every peer" over ENet on localhost (NetHarness): the
## host gives a client the coconut its hold took and both peers stop drawing it, a peer that joins
## after does not see it, a snapshot without the taken pieces is refused, and solo sends nothing.

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


func _coco() -> int:
	return CrossingTuning.standard().flotsam_items.find(&"coco")


# The host's plan becomes one with a coconut in lane 3 at `at_s`, and the client's the same.
func _coconut_plan(host_crossing: Crossing, client_crossing: Crossing, at_s: float) -> void:
	var beats: Array[RefCounted] = [CrossingBeat.create(at_s, K.FLOTSAM, 3, _coco())]
	host_crossing.plan = CrossingPlan.create(600.0, beats)
	if client_crossing != null:
		var copy: Array[RefCounted] = [CrossingBeat.create(at_s, K.FLOTSAM, 3, _coco())]
		client_crossing.plan = CrossingPlan.create(600.0, copy)


func test_a_client_grabs_a_coconut() -> void:
	var pair := await _pair()
	var client_id: int = net.peer_id(pair[1])
	var host_crossing := _raft_for_both(pair[0])
	var theirs := await _crossing_on(pair[1])
	if host_crossing == null or theirs == null:
		fail_test("no crossing")
		return
	var deck := host_crossing.deck_rect()
	var edge := Vector2(deck.end.x - 1.0, deck.get_center().y)
	host_crossing.body_of(client_id).global_position = edge
	theirs.body_of(client_id).global_position = edge
	var arrives_s: float = host_crossing.elapsed_s + 3.0
	_coconut_plan(host_crossing, theirs, arrives_s)
	var before: int = pair[0].body(client_id).inventory.count_id(&"coco")
	# A press locks what it reaches when it starts, so the client presses as the coconut comes alongside.
	var alongside := func() -> bool: return host_crossing.elapsed_s >= arrives_s - 0.3
	assert_true(await wait_until(alongside, TIMEOUT_S))
	theirs.body_of(client_id).intent = MoveIntent.create(Vector2.ZERO, false, false, true)
	var got := func() -> bool: return host_crossing.taken.has(0)
	assert_true(await wait_until(got, TIMEOUT_S), "the host gives the client the coconut")
	theirs.body_of(client_id).intent = MoveIntent.new()
	assert_eq(host_crossing.taken.get(0), client_id)
	assert_eq(pair[0].body(client_id).inventory.count_id(&"coco"), before + 1, "in the client's inventory on the host")
	var shown := func() -> bool: return theirs.taken.has(0) and not theirs.beat_shown(theirs.plan.beat_at(0))
	assert_true(await wait_until(shown, TIMEOUT_S), "the client stops drawing it")


func test_a_joiner_does_not_see_a_taken_coconut() -> void:
	var pair := await _pair()
	var host_crossing := _raft_for_both(pair[0])
	if host_crossing == null:
		fail_test("no crossing")
		return
	_coconut_plan(host_crossing, null, host_crossing.elapsed_s + 20.0)
	assert_true(host_crossing.take_flotsam(0, 1), "the host took it")
	var late := await net.join(_setup)
	assert_not_null(late)
	if late == null:
		return
	var theirs := await _crossing_on(late)
	assert_not_null(theirs)
	if theirs == null:
		return
	assert_true(theirs.taken.has(0), "the joiner knows it was taken")
	assert_false(theirs.beat_shown(theirs.plan.beat_at(0)), "and does not draw it")


func test_a_snapshot_without_the_taken_pieces_is_refused() -> void:
	NetManager.start_solo()
	var crossing := CrossingRig.make(self, &"raft", 1, 100.0, 60.0, [CrossingBeat.create(40.0, K.FLOTSAM, 3, _coco())])
	assert_true(crossing.take_flotsam(0, 1))
	var data := CrossingSnapshot.of(crossing).to_dict()
	assert_eq((CrossingSnapshot.from_dict(data).play["taken"] as Dictionary).get(0), 1, "who took it travels")
	data.erase("taken")
	assert_null(CrossingSnapshot.from_dict(data), "one without the taken pieces is refused")
	var bad := CrossingSnapshot.of(crossing).to_dict()
	bad["taken"] = {99: 1}
	assert_null(CrossingSnapshot.from_dict(bad), "and one naming a beat the plan does not have")
	NetManager.leave()


func test_solo_grabbing_sends_nothing() -> void:
	NetManager.start_solo()
	var crossing := CrossingRig.make(self, &"raft", 1, 100.0, 30.0, [CrossingBeat.create(10.0, K.FLOTSAM, 3, _coco())])
	var body := crossing.body_of(1)
	var deck := crossing.deck_rect()
	body.global_position = Vector2(deck.end.x - 1.0, deck.get_center().y)
	CrossingRig.run(crossing, 9.8)
	CrossingRig.hold(crossing, body, 0.5)
	CrossingRig.release(crossing, body)
	assert_true(crossing.taken.has(0), "the solo rider took the coconut")
	assert_eq(crossing.recipients(), [] as Array[int], "nobody to tell")
	NetManager.leave()
