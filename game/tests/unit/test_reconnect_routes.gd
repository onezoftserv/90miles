extends GutTest
## coop-reconnect with escape-routes: a reclaimed body keeps the node name of the peer it first
## spawned under, so the route code must take a rider's peer from the session, not the name. A
## player who rejoined and then leaves by a route is recorded under their current peer. Offline.

const ISLAND_SCENE: PackedScene = preload("res://scenes/levels/sandbar_island.tscn")
const SESSION_SCENE: PackedScene = preload("res://scenes/net/coop_session.tscn")

var session: CoopSession
var routes: IslandRoutes
var started: Array = []


func before_each() -> void:
	NetManager.start_solo()
	WeatherManager.stop()
	WeatherManager.sky.start_at(0.0)
	started.clear()


func after_each() -> void:
	WeatherManager.stop()
	NetManager.leave()


# The sandbar run with a second player who spawned as peer 7 and came back as peer 9.
func _rejoined_player() -> PlayerBody:
	var island := ISLAND_SCENE.instantiate() as SandbarIsland
	add_child_autofree(island)
	session = SESSION_SCENE.instantiate() as CoopSession
	session.terrain = island.terrain
	session.climate = island.climate
	session.spawn_points = island.spawn_points(false)
	add_child_autofree(session)
	island.furnish(session)
	session.start()
	routes = session.get_node("Routes") as IslandRoutes
	routes.route_started.connect(func(id: StringName, peers: Array[int]) -> void: started.append([id, peers]))
	session._add_player(7)
	session._rebind_body(7, 9)
	for peer_id: int in session.peer_ids():
		session.body(peer_id).player_input.enabled = false
	return session.body(9)


func test_the_session_names_a_bodys_current_peer() -> void:
	var rejoined := _rejoined_player()
	assert_not_null(rejoined)
	assert_eq(session.peer_of(rejoined), 9)
	assert_eq(String(rejoined.name), "7", "the node keeps its first name")
	var stray := PlayerBody.new()
	assert_eq(session.peer_of(stray), 0, "a body outside the session has no peer")
	stray.free()


func test_a_rejoined_player_swims_away_under_their_current_peer() -> void:
	var rejoined := _rejoined_player()
	WeatherManager.sky.weather.apply(&"calm", 100.0, &"", -1.0)
	rejoined.inventory.add(&"binoculars", 1)
	rejoined.meters.energy = 100.0
	for i: int in rejoined.inventory.slots.size():
		var slot := rejoined.inventory.slots[i]
		if not slot.is_empty() and slot.item_id == &"binoculars":
			ItemUser.use(rejoined, i, 0)
			break
	assert_eq(started.size(), 1, "the swim starts")
	if started.size() == 1:
		assert_eq(started[0][1], [9])
	assert_true(routes.has_left(9), "recorded under the current peer")
	assert_false(routes.has_left(7))


func test_a_rejoined_player_starts_a_route_by_peer_lookup() -> void:
	var rejoined := _rejoined_player()
	WeatherManager.sky.weather.apply(&"calm", 100.0, &"", -1.0)
	rejoined.inventory.add(&"binoculars", 1)
	rejoined.meters.energy = 100.0
	assert_true(routes.start_for(9, &"binoculars_swim"))
	assert_eq(routes.route_left_by(9), &"binoculars_swim")
