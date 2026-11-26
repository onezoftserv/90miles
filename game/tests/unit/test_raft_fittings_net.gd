extends GutTest
## island-stop over ENet on localhost (NetHarness), crossing "Fittings ride with the raft": a host
## and a client launch a raft at 90 of 120 with the clavazón and a toldo; the client's crossing
## starts at 90 of 120 with the toldo's shade, and a third player who joins mid-crossing builds the
## same raft from the snapshot. A forged departure record is cleaned. The 1-player, offline cases
## are in test_raft_fittings.gd and test_raft_fittings_sea.gd.

const ISLAND_SCENE: PackedScene = preload("res://scenes/levels/sandbar_island.tscn")
const TIMEOUT_S: float = 6.0
const CLAVAZON: StringName = &"raft_clavazon"
const TOLDO: StringName = &"raft_toldo"

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
	routes.route_started.connect(func(id: StringName, peers: Array[int]) -> void:
		var route := GameState.content.get_entry(&"routes", id) as RouteData
		var raft: RaftRecord = routes.departure_raft.get(id)
		var integrity: float = raft.integrity if raft != null else float(route.vessel_integrity)
		Crossing.launch(session, route, peers, integrity, DataEnums.DistanceBand.COAST, rng, raft))


func _crossing_on(session: CoopSession) -> Crossing:
	var path := NodePath(Crossing.node_name_for(0))
	var built := func() -> bool:
		var found := session.get_node_or_null(path) as Crossing
		return found != null and found.plan != null
	if not await wait_until(built, TIMEOUT_S):
		return null
	return session.get_node(path) as Crossing


# Both players build the raft; the host fits it to 90 of 120 with the clavazón and a toldo and
# launches it with both aboard. The host's crossing gets a 600 s plan.
func _fitted_launch(host: CoopSession) -> Crossing:
	var site := host.get_node("RaftSite") as BuildSite
	for id: int in host.peer_ids():
		host.body(id).global_position = site.global_position
	var builder := host.body(1)
	builder.inventory.add(&"driftwood", 6)
	builder.inventory.add(&"inner_tube", 2)
	builder.inventory.add(&"rope", 3)
	site.deposit(builder)
	site.work(1.0)
	var raft := host.get_node("Raft") as Raft
	raft.fittings = [CLAVAZON, TOLDO] as Array[StringName]
	raft.max_integrity = 120.0
	raft.integrity = 90.0
	assert_true(host.start_route_for(1, &"raft"), "the raft leaves with both")
	var crossing := host.get_node_or_null("Crossing0") as Crossing
	if crossing != null:
		crossing.plan = CrossingPlan.create(600.0)
	return crossing


func _assert_fitted(crossing: Crossing, who: String) -> void:
	assert_eq(crossing.integrity.value, 90.0, "%s: at 90" % who)
	assert_eq(crossing.integrity.maximum, 120.0, "%s: of 120" % who)
	assert_not_null(crossing.fitted, "%s: the raft's record" % who)
	if crossing.fitted == null:
		return
	assert_eq(crossing.fitted.fittings, [CLAVAZON, TOLDO] as Array[StringName], "%s: both fittings" % who)
	var deck := crossing.deck_rect().get_center()
	assert_true(crossing.sea.is_shaded(Vector2i((deck / Crossing.TILE_PX).floor())), "%s: the toldo shades the deck" % who)


func test_the_client_and_a_joiner_see_the_fittings_mid_crossing() -> void:
	var host := net.add_host(_setup)
	var client := await net.join(_setup)
	assert_not_null(client)
	if client == null:
		return
	assert_true(await net.settle())
	net.silence_input()
	var host_crossing := _fitted_launch(host)
	assert_not_null(host_crossing)
	if host_crossing == null:
		return
	_assert_fitted(host_crossing, "host")
	var theirs := await _crossing_on(client)
	assert_not_null(theirs, "the client builds the crossing")
	if theirs == null:
		return
	_assert_fitted(theirs, "client")
	host_crossing.advance(20.0)
	var late := await net.join(_setup)
	assert_not_null(late)
	if late == null:
		return
	var joined := await _crossing_on(late)
	assert_not_null(joined, "the joiner builds the crossing")
	if joined == null:
		return
	_assert_fitted(joined, "joiner")
	await wait_frames(2)
	assert_eq((joined.get_node("Deck") as CrossingDeck).frame_name, StructureArt.RAFT_WHOLE, "90 of 120 (75 %) draws whole on the joiner")
	var drawn := RaftFittingsLook.of(joined.get_node("Deck") as CrossingDeck)
	var data := StructureArtData.standard()
	assert_eq(drawn.shown(), [data.raft_fittings[CLAVAZON], data.raft_fittings[TOLDO]] as Array[Texture2D], "the joiner draws the toldo")
	host_crossing.advance(host_crossing.plan.length_s)
	assert_true(await wait_until(func() -> bool: return theirs.finished, TIMEOUT_S), "the end reaches the client")
	assert_eq(theirs.result.maximum, 120.0)
	assert_eq(theirs.result.fittings, [CLAVAZON, TOLDO] as Array[StringName], "the client's result holds the fittings")


func test_a_snapshot_without_a_raft_is_refused() -> void:
	var raft := RaftRecord.bare(90.0, 120.0)
	raft.fittings = [TOLDO] as Array[StringName]
	var crossing := CrossingRig.make(self, &"raft", 1, 90.0, 60.0, [], raft)
	var data := CrossingSnapshot.of(crossing).to_dict()
	var back := CrossingSnapshot.from_dict(bytes_to_var(var_to_bytes(data)))
	assert_not_null(back)
	assert_eq(back.raft.fittings, [TOLDO] as Array[StringName], "the raft travels in the snapshot")
	assert_eq(back.raft.maximum, 120.0)
	var bad := data.duplicate()
	bad["raft"] = {"integrity": 90.0}
	assert_null(CrossingSnapshot.from_dict(bad), "a malformed raft")
	data.erase("raft")
	assert_null(CrossingSnapshot.from_dict(data), "no raft key")


func test_a_swim_snapshot_has_no_raft() -> void:
	var crossing := CrossingRig.make(self, &"binoculars_swim", 1, 0.0, 60.0)
	var back := CrossingSnapshot.from_dict(CrossingSnapshot.of(crossing).to_dict())
	assert_not_null(back)
	assert_null(back.raft)
