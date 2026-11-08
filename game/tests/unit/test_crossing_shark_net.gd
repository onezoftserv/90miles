extends GutTest
## crossing-shark-sync over ENet on localhost (NetHarness): the crossing's reef shark is a host-run
## creature, so a client in the crossing and a client that joins during its circle both see it
## beside the bitten swimmer, and it leaves both when the host's circle ends. A client's copy has
## no lifetime of its own, so the tests tell the crossing's shark from the island's by where it is:
## in the crossing's sea, far from the island.

const ISLAND_SCENE: PackedScene = preload("res://scenes/levels/sandbar_island.tscn")
const SHARK := CrossingBeat.Kind.SHARK_PASS
const TIMEOUT_S: float = 6.0
const BESIDE_PX: float = 32.0

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
	island.furnish(session)


# The reef sharks `session` shows inside `sea` (the crossing's, not the island's).
func _sharks_in(session: CoopSession, sea: Rect2) -> Array[Creature]:
	var found: Array[Creature] = []
	for child: Node in session.entities.get_children():
		var creature := child as Creature
		if creature != null and creature.data.id == &"reef_shark" and not creature.is_queued_for_deletion() and sea.has_point(creature.position):
			found.append(creature)
	return found


func test_a_client_and_a_late_joiner_see_the_crossing_shark() -> void:
	var host := net.add_host(_setup)
	var client := await net.join(_setup)
	assert_not_null(client)
	if client == null:
		return
	assert_true(await net.settle())
	net.silence_input()
	var client_id: int = net.peer_id(client)
	var route := GameState.content.get_entry(&"routes", &"raft") as RouteData
	var riders: Array[int] = host.peer_ids()
	Crossing.launch(client, route, riders, 100.0, DataEnums.DistanceBand.COAST, rng)
	var crossing := Crossing.launch(host, route, riders, 100.0, DataEnums.DistanceBand.COAST, rng)
	crossing.plan = CrossingPlan.create(600.0)
	var sea := crossing.sea_rect()
	crossing.throw_in(client_id)
	var swimmer := crossing.body_of(client_id)
	swimmer.meters.energy = 15.0
	CrossingRig.put_beside_deck(crossing, swimmer, 20.0)
	crossing.threats.resolve(CrossingBeat.create(1.0, SHARK), crossing)
	var host_sharks := _sharks_in(host, sea)
	assert_eq(host_sharks.size(), 1, "the host spawned the crossing's shark")
	if host_sharks.is_empty():
		return
	var seen := func() -> bool: return _sharks_in(client, sea).size() == 1
	assert_true(await wait_until(seen, TIMEOUT_S), "the bitten client sees the shark")
	if _sharks_in(client, sea).is_empty():
		return
	var theirs: Creature = _sharks_in(client, sea)[0]
	assert_lt(theirs.position.distance_to(swimmer.global_position), BESIDE_PX, "beside the client's player")
	var late := await net.join(_setup)
	assert_not_null(late)
	if late == null:
		return
	var late_sees := func() -> bool: return _sharks_in(late, sea).size() == 1
	assert_true(await wait_until(late_sees, TIMEOUT_S), "a client that joins during the circle sees it too")
	host_sharks[0].advance(10.0)
	var gone := func() -> bool: return _sharks_in(client, sea).is_empty() and _sharks_in(late, sea).is_empty()
	assert_true(await wait_until(gone, TIMEOUT_S), "the circle ends on every screen")
