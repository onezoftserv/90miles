extends GutTest
## crossing "Arrival scatter" over ENet on localhost (NetHarness): two board riders whose crossing
## ended land on the coast cay 10-20 tiles apart, on the cells the host picked, the same cells on
## both peers. Each branch builds the island and the IslandTravel the way the shell does.

const ISLAND_SCENE: PackedScene = preload("res://scenes/levels/sandbar_island.tscn")
const TIMEOUT_S: float = 6.0
const COAST: StringName = &"coast_cay"

var net: NetHarness


func before_each() -> void:
	FixtureRoutes.put_in()
	net = NetHarness.new(self)
	WeatherManager.stop()
	WeatherManager.sky.start_at(0.0)


func after_each() -> void:
	net.teardown()
	FixtureRoutes.take_out()


func _setup(session: CoopSession) -> void:
	var island := ISLAND_SCENE.instantiate() as SandbarIsland
	island.with_creatures = false
	session.get_parent().add_child(island)
	session.terrain = island.terrain
	session.climate = island.climate
	session.spawn_points = island.spawn_points(false)
	island.furnish(session)
	var travel := IslandTravel.new()
	travel.name = "Travel"
	session.add_child(travel)
	travel.setup(session, island)


func _travel(session: CoopSession) -> IslandTravel:
	return session.get_node("Travel") as IslandTravel


func _cell_of(session: CoopSession, peer: int) -> Vector2i:
	return Vector2i((session.body(peer).position / float(IslandLayout.TILE)).floor())


func test_two_board_riders_land_apart_and_the_same_on_both_peers() -> void:
	var host := net.add_host(_setup)
	var client := await net.join(_setup)
	assert_not_null(client)
	if client == null:
		return
	assert_true(await net.settle())
	net.silence_input()
	var client_id: int = net.peer_id(client)
	var result := CrossingResult.new()
	result.route_id = &"test_board"
	for peer: int in [1, client_id]:
		result.riders[peer] = {"health": 100.0, "energy": 70.0, "aboard": true, "dead": false, "board": 40.0, "board_broken": false}
	for session: CoopSession in [host, client]:
		_travel(session).crossing_ended(result)
	var on_cay := func() -> bool:
		return _travel(host).island.layout.id == COAST and _travel(client).island.layout.id == COAST \
				and not host.body(client_id).left_island and not client.body(1).left_island
	assert_true(await wait_until(on_cay, TIMEOUT_S), "the coast cay loads on both peers with both riders on it")
	await wait_process_frames(2)
	var built := _travel(host).island.built
	var host_cells: Array[Vector2i] = [_cell_of(host, 1), _cell_of(host, client_id)]
	assert_eq(host_cells[0], built.landing_cells()[0], "the first rider on the first landing cell")
	assert_eq(built.terrain.cells.get(host_cells[1]), DataEnums.Terrain.BEACH, "the second on the beach")
	assert_between(Vector2(host_cells[0] - host_cells[1]).length(), 10.0, 20.0, "10-20 tiles apart")
	assert_eq(_cell_of(client, 1), host_cells[0], "the client lands the host's rider on the host's cell")
	assert_eq(_cell_of(client, client_id), host_cells[1], "and its own rider on the host's cell")
	assert_eq(host.body(client_id).position, IslandLayout.cell_center(host_cells[1]))
	assert_null(host.get_node_or_null("Raft"), "no raft beached from boards")
