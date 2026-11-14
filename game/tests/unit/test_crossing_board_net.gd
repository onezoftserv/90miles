extends GutTest
## crossing "Board crossing state" and "Board rescue" over ENet on localhost (NetHarness), on the
## `test_board` fixture route: the client shows every board at the host's integrity, the host
## applies the client's climb onto its own board, and a peer that joins during the crossing sees a
## broken board as gone. Every session gets the sandbar, offers the fixture and launches a crossing
## on `route_started`, as the shell does.

const ISLAND_SCENE: PackedScene = preload("res://scenes/levels/sandbar_island.tscn")
const TIMEOUT_S: float = 6.0
const TILE_PX: float = 16.0

var net: NetHarness
var islands: Array[SandbarIsland] = []
var rng := RandomNumberGenerator.new()


func before_each() -> void:
	FixtureRoutes.put_in()
	net = NetHarness.new(self)
	WeatherManager.stop()
	WeatherManager.sky.start_at(0.0)


func after_each() -> void:
	net.teardown()
	for island: SandbarIsland in islands:
		island.free()
	islands.clear()
	FixtureRoutes.take_out()


# The sandbar in `session`, offering the board, with a crossing launched on every route start.
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
	routes.offered.append(GameState.content.get_entry(&"routes", &"test_board") as RouteData)
	routes.discovered[&"test_board"] = true
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


# The crossing numbered 0 on `session` once it exists and has a plan, or null.
func _crossing_on(session: CoopSession) -> Crossing:
	var path := NodePath(Crossing.node_name_for(0))
	var built := func() -> bool:
		var found := session.get_node_or_null(path) as Crossing
		return found != null and found.plan != null
	if not await wait_until(built, TIMEOUT_S):
		return null
	return session.get_node(path) as Crossing


# Both players carry a rigged board (a tarp) in trade wind and the host starts the board route;
# the host's crossing gets a 600 s plan with nothing in it.
func _boards_for_both(host: CoopSession) -> Crossing:
	var ids := host.peer_ids()
	for index: int in ids.size():
		host.body(ids[index]).global_position = host.body(1).global_position + Vector2(4.0 * index, 0.0)
		host.body(ids[index]).inventory.add(&"tarp", 1)
	host.climate.weather_id = &"trade_wind"
	assert_true(host.start_route_for(1, &"test_board"), "both leave on their boards")
	var crossing := host.get_node_or_null("Crossing0") as Crossing
	if crossing != null:
		crossing.plan = CrossingPlan.create(600.0)
	return crossing


func _hold(client_crossing: Crossing, client_id: int, held: bool) -> void:
	client_crossing.body_of(client_id).intent = MoveIntent.create(Vector2.ZERO, false, false, held)


func test_the_client_shows_every_board() -> void:
	var pair := await _pair()
	var client_id: int = net.peer_id(pair[1])
	var host_crossing := _boards_for_both(pair[0])
	assert_not_null(host_crossing)
	var theirs := await _crossing_on(pair[1])
	assert_not_null(theirs)
	if host_crossing == null or theirs == null:
		return
	assert_eq(host_crossing.peers(), [1, client_id] as Array[int])
	assert_eq(host_crossing.boards.size(), 2, "one board each")
	assert_eq(pair[0].body(client_id).inventory.count_id(&"tarp"), 0, "the client's board was spent on the host")
	host_crossing.hit_vessel(40.0)
	var shown := func() -> bool: return theirs.boards[1].value == 20.0
	assert_true(await wait_until(shown, TIMEOUT_S), "the client shows the host's board at 20")
	assert_eq(theirs.boards[client_id].value, 60.0, "and its own at 60")
	assert_eq(theirs.rider_state(client_id), Crossing.Rider.ABOARD)


func test_the_client_climbs_onto_its_own_board() -> void:
	var pair := await _pair()
	var client_id: int = net.peer_id(pair[1])
	var host_crossing := _boards_for_both(pair[0])
	var theirs := await _crossing_on(pair[1])
	if host_crossing == null or theirs == null:
		fail_test("no crossing")
		return
	host_crossing.throw_in(client_id)
	var board := host_crossing.deck_rect_of(client_id)
	host_crossing.body_of(client_id).global_position = Vector2(board.end.x + 6.0, board.get_center().y)
	var in_water := func() -> bool: return theirs.rider_state(client_id) == Crossing.Rider.IN_WATER
	assert_true(await wait_until(in_water, TIMEOUT_S), "the client sees the fall")
	await wait_physics_frames(10)
	_hold(theirs, client_id, true)
	var aboard := func() -> bool: return host_crossing.rider_state(client_id) == Crossing.Rider.ABOARD
	assert_true(await wait_until(aboard, TIMEOUT_S), "3 s of the client's intents bring them aboard")
	_hold(theirs, client_id, false)
	assert_true(host_crossing.deck_rect_of(client_id).has_point(host_crossing.body_of(client_id).global_position), "onto their own board")
	var shown := func() -> bool: return theirs.rider_state(client_id) == Crossing.Rider.ABOARD
	assert_true(await wait_until(shown, TIMEOUT_S), "the client shows it")


func test_a_joiner_sees_a_broken_board_as_gone() -> void:
	var pair := await _pair()
	var client_id: int = net.peer_id(pair[1])
	var host_crossing := _boards_for_both(pair[0])
	if host_crossing == null:
		fail_test("no crossing")
		return
	host_crossing.hit_vessel(30.0)
	host_crossing.boards[client_id].hit(60.0)
	assert_eq(host_crossing.rider_state(client_id), Crossing.Rider.IN_WATER)
	var spot := host_crossing.deck_rect_of(client_id).get_center() + Vector2(0.0, 3.0 * TILE_PX)
	host_crossing.body_of(client_id).global_position = spot
	var late := await net.join(_setup)
	assert_not_null(late)
	if late == null:
		return
	var theirs := await _crossing_on(late)
	assert_not_null(theirs, "the joiner builds the crossing")
	if theirs == null:
		return
	assert_true(theirs.is_board_route())
	assert_eq(theirs.boards[1].value, host_crossing.boards[1].value, "the host's board at the host's integrity")
	assert_true(theirs.boards[client_id].broken, "no board for the client")
	var sunk := Vector2i((theirs.deck_rect_of(client_id).get_center() / TILE_PX).floor())
	assert_eq(theirs.sea.terrain_at(sunk), DataEnums.Terrain.DEEP)
	assert_eq(theirs.rider_state(client_id), Crossing.Rider.IN_WATER)
	assert_lt(theirs.body_of(client_id).global_position.distance_to(host_crossing.body_of(client_id).global_position), TILE_PX, "where the host has them")
