extends GutTest
## crossing "Vessel look on the crossing" (vessel-car-board, design.md D4 and D9): the deck draws
## the car on a car route by its share of the route's 160, a board route draws one board under each
## rider by its share of 60 and nothing for a broken one, a host and a client draw the same boards,
## and freeing the boards' look changes nothing the crossing does. Solo cases on the crossing rig,
## offline; the host-and-client case over ENet on localhost (NetHarness).

const ISLAND_SCENE: PackedScene = preload("res://scenes/levels/sandbar_island.tscn")
const DECK_Z: int = -20
const TIMEOUT_S: float = 6.0
const SQUALL := CrossingBeat.Kind.SQUALL
const SHARK := CrossingBeat.Kind.SHARK_PASS
const ROCK := CrossingBeat.Kind.ROCK

var net: NetHarness
var islands: Array[SandbarIsland] = []
var rng := RandomNumberGenerator.new()
var _solo: bool = false


func before_each() -> void:
	WeatherManager.stop()
	WeatherManager.sky.start_at(0.0)
	FixtureRoutes.put_in()


func after_each() -> void:
	if net != null:
		net.teardown()
		net = null
	for island: SandbarIsland in islands:
		island.free()
	islands.clear()
	if _solo:
		NetManager.leave()
		_solo = false
	FixtureRoutes.take_out()


func _start_solo() -> void:
	NetManager.start_solo()
	WeatherManager.stop()
	WeatherManager.sky.start_at(0.0)
	_solo = true


func _beats(list: Array) -> Array[RefCounted]:
	var beats: Array[RefCounted] = []
	for pair: Array in list:
		beats.append(CrossingRig.beat(pair[0], pair[1]))
	return beats


func _deck_of(crossing: Crossing) -> Sprite2D:
	return crossing.get_node_or_null(^"Deck") as Sprite2D


func _boards_of(crossing: Crossing) -> CrossingBoards:
	return crossing.get_node_or_null(^"Boards") as CrossingBoards


func _car(frame: StringName) -> Texture2D:
	return StructureArtData.standard().car.get_frame_texture(frame, 0)


func _board(frame: StringName) -> Texture2D:
	return StructureArtData.standard().board.get_frame_texture(frame, 0)


# --- the frame rule -----------------------------------------------------------------------------

func test_vessel_frames_go_by_the_share_left() -> void:
	assert_eq(StructureArt.vessel_frame(95.0, 160.0), StructureArt.RAFT_WORN, "a car at 95 of 160")
	assert_eq(StructureArt.vessel_frame(60.0, 60.0), StructureArt.RAFT_WHOLE, "a new board")
	assert_eq(StructureArt.vessel_frame(30.0, 60.0), StructureArt.RAFT_WORN)
	assert_eq(StructureArt.vessel_frame(19.0, 60.0), StructureArt.RAFT_BREAKING)
	assert_eq(StructureArt.vessel_frame(0.0, 60.0), StructureArt.NO_FRAME)
	assert_eq(StructureArt.vessel_frame(10.0, 0.0), StructureArt.NO_FRAME, "no vessel, nothing drawn")
	for value: float in [100.0, 67.0, 66.0, 50.0, 34.0, 33.0, 20.0, 1.0, 0.0]:
		assert_eq(StructureArt.vessel_frame(value, 100.0), StructureArt.raft_frame(value), "a raft at %d as before" % value)


func test_the_art_holds_the_car_and_the_board() -> void:
	var art := StructureArtData.standard()
	for frames: SpriteFrames in [art.car, art.board]:
		assert_not_null(frames)
		if frames == null:
			continue
		for frame: StringName in [StructureArt.RAFT_WHOLE, StructureArt.RAFT_WORN, StructureArt.RAFT_BREAKING]:
			assert_true(frames.has_animation(frame), "%s" % frame)
	assert_eq(_car(StructureArt.RAFT_WHOLE).get_size(), Vector2(64.0, 32.0), "the car covers the 4x2 deck")
	assert_eq(_board(StructureArt.RAFT_WHOLE).get_size(), Vector2(16.0, 32.0), "a board covers its 1x2 tiles")


# --- solo ---------------------------------------------------------------------------------------

func test_a_solo_car_is_drawn_worn_at_95_of_160() -> void:
	_start_solo()
	var crossing := CrossingRig.make(self, &"test_car", 1, 0.0, 90.0, _beats([[1.0, SQUALL], [2.0, SHARK]]))
	crossing.tie(1)
	CrossingRig.run(crossing, 2.1)
	assert_eq(crossing.integrity.value, 95.0)
	await wait_process_frames(2)
	var deck := _deck_of(crossing)
	assert_not_null(deck)
	if deck == null:
		return
	assert_true(deck.visible)
	assert_eq(deck.texture, _car(StructureArt.RAFT_WORN), "the worn car, not the raft")
	assert_eq(deck.position, crossing.deck_center(), "over the deck")
	assert_null(_boards_of(crossing).sprite_for(1), "no board on a car")


func test_a_new_solo_board_is_drawn_whole_under_its_rider() -> void:
	_start_solo()
	var crossing := CrossingRig.make(self, &"test_board", 1, 0.0, 90.0)
	await wait_process_frames(2)
	assert_false(_deck_of(crossing).visible, "no shared deck")
	var sprite := _boards_of(crossing).sprite_for(1)
	assert_not_null(sprite, "the board is drawn")
	if sprite == null:
		return
	assert_eq(sprite.texture, _board(StructureArt.RAFT_WHOLE), "whole at 60 of 60")
	assert_eq(sprite.global_position, crossing.deck_rect_of(1).get_center(), "on the rider's board")
	assert_eq(DrawOrder.absolute_z(sprite), DECK_Z)
	assert_true(DrawOrder.drawn_after(crossing.body_of(1), sprite), "the rider over the board")


func test_each_board_shows_its_share_and_a_broken_one_is_gone() -> void:
	_start_solo()
	var crossing := CrossingRig.make(self, &"test_board", 3, 0.0, 90.0)
	crossing.boards[2].value = 30.0
	crossing.boards[3].hit(60.0)
	await wait_process_frames(2)
	var boards := _boards_of(crossing)
	assert_eq(boards.sprite_for(1).texture, _board(StructureArt.RAFT_WHOLE))
	assert_eq(boards.sprite_for(2).texture, _board(StructureArt.RAFT_WORN))
	assert_null(boards.sprite_for(3), "a broken board is not drawn")


func test_freeing_the_boards_changes_nothing_the_crossing_does() -> void:
	_start_solo()
	var crossing := CrossingRig.make(self, &"test_board", 2, 0.0, 90.0, _beats([[1.0, ROCK], [2.0, SHARK]]))
	_boards_of(crossing).free()
	CrossingRig.run(crossing, 2.1)
	await wait_process_frames(2)
	assert_eq(crossing.boards[1].value, 20.0)
	assert_eq(crossing.boards[2].value, 40.0)
	assert_eq(crossing.rider_state(1), Crossing.Rider.ABOARD)
	assert_eq(crossing.rider_state(2), Crossing.Rider.IN_WATER)


# --- host and client --------------------------------------------------------------------------

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


func _crossing_on(session: CoopSession) -> Crossing:
	var path := NodePath(Crossing.node_name_for(0))
	var built := func() -> bool:
		var found := session.get_node_or_null(path) as Crossing
		return found != null and found.plan != null
	if not await wait_until(built, TIMEOUT_S):
		return null
	return session.get_node(path) as Crossing


func test_host_and_client_draw_the_hosts_board_and_not_the_clients_broken_one() -> void:
	net = NetHarness.new(self)
	var host := net.add_host(_setup)
	var client := await net.join(_setup)
	assert_not_null(client)
	if client == null:
		return
	assert_true(await net.settle())
	net.silence_input()
	var client_id: int = net.peer_id(client)
	var ids := host.peer_ids()
	for index: int in ids.size():
		host.body(ids[index]).global_position = host.body(1).global_position + Vector2(4.0 * index, 0.0)
		host.body(ids[index]).inventory.add(&"tarp", 1)
	host.climate.weather_id = &"trade_wind"
	assert_true(host.start_route_for(1, &"test_board"))
	var host_crossing := host.get_node_or_null(^"Crossing0") as Crossing
	var client_crossing := await _crossing_on(client)
	assert_not_null(host_crossing)
	assert_not_null(client_crossing)
	if host_crossing == null or client_crossing == null:
		return
	host_crossing.plan = CrossingPlan.create(600.0)
	host_crossing.boards[client_id].hit(60.0)
	var broke := func() -> bool: return client_crossing.boards[client_id].broken
	assert_true(await wait_until(broke, TIMEOUT_S), "the client hears the break")
	await wait_process_frames(3)
	for side: Array in [["host", host_crossing], ["client", client_crossing]]:
		var peer: String = side[0]
		var crossing: Crossing = side[1]
		var boards := _boards_of(crossing)
		var own := boards.sprite_for(1)
		assert_not_null(own, "%s: the host's board is drawn" % peer)
		if own != null:
			assert_eq(own.texture, _board(StructureArt.RAFT_WHOLE), "%s: whole at 60" % peer)
			assert_eq(own.global_position, crossing.deck_rect_of(1).get_center(), "%s: under the host" % peer)
		assert_null(boards.sprite_for(client_id), "%s: no board for the client" % peer)
