extends GutTest
## crossing "Shooing the shark" and creatures-ai "Every peer sees the crossing shark" over ENet on
## localhost (NetHarness): the host shoos the shark for a client's 1 s hold and it leaves both
## screens before its strike, a peer that joins during the circle knows the fin, a snapshot without
## the shooed passes is refused, and a solo crossing sends nothing.

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


func _sharks(session: CoopSession) -> Array[Creature]:
	var found: Array[Creature] = []
	for child: Node in session.entities.get_children():
		var creature := child as Creature
		if creature != null and creature.data != null and creature.data.id == CreatureThreats.SHARK_ID and not creature.is_queued_for_deletion():
			found.append(creature)
	return found


func test_a_client_shoos_the_shark_off_both_screens() -> void:
	var pair := await _pair()
	var client_id: int = net.peer_id(pair[1])
	var host_crossing := _raft_for_both(pair[0])
	var theirs := await _crossing_on(pair[1])
	if host_crossing == null or theirs == null:
		fail_test("no crossing")
		return
	var strike_s: float = host_crossing.elapsed_s + 4.0
	var beats: Array[RefCounted] = [CrossingBeat.create(strike_s, K.SHARK_PASS, 0, CrossingBeat.Side.EAST)]
	host_crossing.plan = CrossingPlan.create(600.0, beats)
	var deck := host_crossing.deck_rect()
	var edge := Vector2(deck.end.x - 1.0, deck.get_center().y)
	host_crossing.body_of(client_id).global_position = edge
	theirs.body_of(client_id).global_position = edge
	var warned := func() -> bool: return theirs.fins.size() == 1 and _sharks(pair[1]).size() == 1
	assert_true(await wait_until(warned, TIMEOUT_S), "the client sees the fin and the shark")
	await wait_physics_frames(5)
	theirs.body_of(client_id).intent = MoveIntent.create(Vector2.ZERO, false, false, true)
	var shooed := func() -> bool: return host_crossing.shooed.has(0)
	assert_true(await wait_until(shooed, TIMEOUT_S), "the host shoos it for the client's 1 s hold")
	theirs.body_of(client_id).intent = MoveIntent.new()
	var gone := func() -> bool: return _sharks(pair[1]).is_empty() and _sharks(pair[0]).is_empty()
	assert_true(await wait_until(gone, TIMEOUT_S), "the shark is gone from both screens")
	assert_lt(host_crossing.elapsed_s, strike_s, "before its strike")
	var past := func() -> bool: return host_crossing.elapsed_s > strike_s + 0.5
	assert_true(await wait_until(past, TIMEOUT_S))
	assert_eq(host_crossing.integrity.value, 100.0, "the raft untouched")


func test_a_joiner_during_the_circle_sees_the_fin() -> void:
	var pair := await _pair()
	var host_crossing := _raft_for_both(pair[0])
	if host_crossing == null:
		fail_test("no crossing")
		return
	var beats: Array[RefCounted] = [CrossingBeat.create(host_crossing.elapsed_s + 5.5, K.SHARK_PASS, 0, CrossingBeat.Side.WEST)]
	host_crossing.plan = CrossingPlan.create(600.0, beats)
	var warned := func() -> bool: return host_crossing.fins.size() == 1
	assert_true(await wait_until(warned, TIMEOUT_S))
	var late := await net.join(_setup)
	assert_not_null(late)
	if late == null:
		return
	var theirs := await _crossing_on(late)
	assert_not_null(theirs)
	if theirs == null:
		return
	assert_true(theirs.fins.has(0), "the joiner knows the fin")
	assert_eq(theirs.fins[0], host_crossing.fins[0], "where the host has it")


func test_a_clients_shoo_prompt_goes_off_after_a_strike() -> void:
	var pair := await _pair()
	var host_crossing := _raft_for_both(pair[0])
	var theirs := await _crossing_on(pair[1])
	if host_crossing == null or theirs == null:
		fail_test("no crossing")
		return
	var strike_s: float = host_crossing.elapsed_s + 3.0
	var beats: Array[RefCounted] = [CrossingBeat.create(strike_s, K.SHARK_PASS, 0, CrossingBeat.Side.WEST)]
	host_crossing.plan = CrossingPlan.create(600.0, beats)
	var copy: Array[RefCounted] = [CrossingBeat.create(strike_s, K.SHARK_PASS, 0, CrossingBeat.Side.WEST)]
	theirs.plan = CrossingPlan.create(600.0, copy)
	var on := func() -> bool: return theirs._shoo_points.has(0) and theirs._shoo_points[0].enabled
	assert_true(await wait_until(on, TIMEOUT_S), "the client's shoo point is on while the fin circles")
	var struck := func() -> bool: return host_crossing.elapsed_s > strike_s + 0.5
	assert_true(await wait_until(struck, TIMEOUT_S))
	var off := func() -> bool: return not theirs._shoo_points[0].enabled
	assert_true(await wait_until(off, TIMEOUT_S), "and off once the shark struck, unshooed")


func test_a_snapshot_without_the_shooed_passes_is_refused() -> void:
	NetManager.start_solo()
	var crossing := CrossingRig.make(self, &"raft", 1, 100.0, 60.0, [CrossingBeat.create(30.0, K.SHARK_PASS)])
	CrossingRig.run(crossing, 26.0)
	assert_true(crossing.shoo_shark(0))
	var data := CrossingSnapshot.of(crossing).to_dict()
	assert_eq(CrossingSnapshot.from_dict(data).play["shooed"], [0], "the shooed pass travels")
	data.erase("shooed")
	assert_null(CrossingSnapshot.from_dict(data), "one without it is refused")
	NetManager.leave()


func test_solo_shooing_sends_nothing() -> void:
	NetManager.start_solo()
	var crossing := CrossingRig.make(self, &"raft", 1, 100.0, 30.0, [CrossingBeat.create(10.0, K.SHARK_PASS)])
	CrossingRig.run(crossing, 6.0)
	assert_true(crossing.shoo_shark(0))
	CrossingRig.run(crossing, 5.0)
	assert_eq(crossing.integrity.value, 100.0)
	assert_eq(crossing.recipients(), [] as Array[int], "nobody to tell")
	NetManager.leave()
