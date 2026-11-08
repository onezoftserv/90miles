extends GutTest
## escape-routes over ENet on localhost (NetHarness): the host applies a client's start request,
## picks the riders, and the players who stay keep the island and its routes.

const ISLAND_SCENE: PackedScene = preload("res://scenes/levels/sandbar_island.tscn")
const TIMEOUT_S: float = 5.0

var net: NetHarness
var islands: Array[SandbarIsland] = []
var started: Array = []


func before_each() -> void:
	net = NetHarness.new(self)
	WeatherManager.stop()
	WeatherManager.sky.start_at(0.0)
	started.clear()


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


# A host and a client, both spawned and settled.
func _pair() -> Array[CoopSession]:
	var host := net.add_host(_setup)
	(host.get_node("Routes") as IslandRoutes).route_started.connect(func(id: StringName, peers: Array[int]) -> void: started.append([id, peers]))
	var client := await net.join(_setup)
	assert_true(await net.settle())
	net.silence_input()
	var pair: Array[CoopSession] = [host, client]
	return pair


func _gather(host: CoopSession) -> void:
	var site := host.get_node("RaftSite") as Node2D
	for id: int in host.peer_ids():
		host.body(id).global_position = site.global_position


func _feed(host: CoopSession, work: float) -> void:
	var site := host.get_node("RaftSite") as BuildSite
	var body := host.body(1)
	body.inventory.add(&"driftwood", 6)
	body.inventory.add(&"inner_tube", 2)
	body.inventory.add(&"rope", 3)
	site.deposit(body)
	site.work(work)


func test_a_clients_start_request_is_applied_by_the_host() -> void:
	var pair := await _pair()
	var host := pair[0]
	var client := pair[1]
	_gather(host)
	_feed(host, 1.0)
	client.start_route(&"raft")
	assert_true(await wait_until(func() -> bool: return started.size() == 1, TIMEOUT_S))
	assert_eq(started[0][0], &"raft")
	assert_eq(started[0][1].size(), 2)
	var hidden := func() -> bool:
		return not net.own_body(client).visible
	assert_true(await wait_until(hidden, TIMEOUT_S), "the client hides its player too")


func test_the_host_picks_riders_from_the_sender() -> void:
	var pair := await _pair()
	var host := pair[0]
	var client_id: int = net.peer_id(pair[1])
	WeatherManager.sky.weather.apply(&"calm", 100.0, &"", -1.0)
	_gather(host)
	for id: int in host.peer_ids():
		host.body(id).inventory.add(&"binoculars", 1)
	host.body(client_id).meters.energy = 100.0
	host.body(1).meters.energy = 99.0
	assert_true(host.start_route_for(client_id, &"binoculars_swim"))
	assert_eq(started[0][1], [client_id])
	assert_true(host.body(1).visible, "the host stays on the island")


func test_a_client_cannot_start_an_unoffered_or_undiscovered_route() -> void:
	var pair := await _pair()
	var host := pair[0]
	var client_id: int = net.peer_id(pair[1])
	host.body(client_id).inventory.add(&"binoculars", 1)
	host.body(client_id).meters.energy = 100.0
	WeatherManager.sky.weather.apply(&"squall", 100.0, &"", -1.0)
	assert_false(host.start_route_for(client_id, &"turtle"))
	assert_false(host.start_route_for(client_id, &"binoculars_swim"))
	assert_eq(started.size(), 0)


func test_players_who_stay_keep_the_island_and_its_routes() -> void:
	var pair := await _pair()
	var host := pair[0]
	var client_id: int = net.peer_id(pair[1])
	WeatherManager.sky.weather.apply(&"calm", 100.0, &"", -1.0)
	_gather(host)
	host.body(client_id).inventory.add(&"binoculars", 1)
	host.body(client_id).meters.energy = 100.0
	host.body(1).meters.energy = 99.0
	assert_true(host.start_route_for(client_id, &"binoculars_swim"))
	var routes := host.get_node("Routes") as IslandRoutes
	assert_eq(routes.offered.size(), 2)
	assert_false(routes.has_left(1))
	assert_false(host.start_route_for(client_id, &"raft"), "a departed player starts nothing")
	_feed(host, 1.0)
	(host.get_node("Raft") as Raft).interactable.interacted.emit(host.body(1))
	assert_eq(started.size(), 2)
	assert_eq(started[1][1], [1])


func test_a_launched_raft_is_replaced_by_a_fresh_site() -> void:
	var pair := await _pair()
	var host := pair[0]
	_gather(host)
	_feed(host, 1.0)
	(host.get_node("Raft") as Raft).interactable.interacted.emit(host.body(1))
	await wait_frames(2)
	var site := host.get_node_or_null("RaftSite") as BuildSite
	assert_not_null(site)
	assert_false(site.inputs_complete())
	assert_null(host.get_node_or_null("Raft"))


func test_raft_progress_reaches_the_client() -> void:
	var pair := await _pair()
	var host := pair[0]
	var client := pair[1]
	_gather(host)
	_feed(host, 0.5)
	var site := host.get_node("RaftSite") as BuildSite
	var seen := func() -> bool:
		var theirs := client.get_node_or_null("RaftSite") as BuildSite
		return theirs != null and absf(theirs.progress() - site.progress()) < 0.05 and theirs.inputs_complete()
	assert_true(await wait_until(seen, TIMEOUT_S))
