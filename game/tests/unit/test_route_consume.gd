extends GutTest
## escape-routes "Route items spent at the start" (vessel-car-board): a route requirement of kind
## HAS_ITEM marked consume is taken from the starter, a rider requirement from each rider, only
## once the route starts. A refused start spends nothing. Solo first, then a party in one process.
## The fixture routes stand in for content-batch-11's: `tarp` for the rigged board, `plastic_jug`
## for the fuel jug.

const ISLAND_SCENE: PackedScene = preload("res://scenes/levels/sandbar_island.tscn")
const SESSION_SCENE: PackedScene = preload("res://scenes/net/coop_session.tscn")

var session: CoopSession
var routes: IslandRoutes
var fixtures: Dictionary[StringName, RouteData] = {}
var started: Array = []


func before_each() -> void:
	NetManager.start_solo()
	WeatherManager.stop()
	fixtures = FixtureRoutes.put_in()
	started.clear()


func after_each() -> void:
	WeatherManager.stop()
	NetManager.leave()
	FixtureRoutes.take_out()


# A sandbar run with `players` idle bodies (peer ids 1, 2, ...) standing side by side, offering
# the fixture routes as discovered, in calm weather.
func _run(players: int) -> Array[PlayerBody]:
	var island := ISLAND_SCENE.instantiate() as SandbarIsland
	add_child_autofree(island)
	session = SESSION_SCENE.instantiate() as CoopSession
	session.terrain = island.terrain
	session.climate = island.climate
	session.spawn_points = island.spawn_points(true)
	add_child_autofree(session)
	island.with_creatures = false
	island.furnish(session)
	session.start()
	for id: int in range(2, players + 1):
		var extra := CoopSession.PLAYER_SCENE.instantiate() as PlayerBody
		extra.name = str(id)
		extra.climate = session.climate
		extra.terrain = session.terrain
		session.players.add_child(extra)
		session._bodies[id] = extra
	routes = session.get_node("Routes") as IslandRoutes
	for id: StringName in fixtures:
		routes.offered.append(fixtures[id])
		routes.discovered[id] = true
	routes.route_started.connect(func(id: StringName, peers: Array[int]) -> void: started.append([id, peers]))
	session.climate.weather_id = &"calm"
	var bodies: Array[PlayerBody] = []
	var origin := session.body(1).global_position
	for peer: int in session.peer_ids():
		var body := session.body(peer)
		body.player_input.enabled = false
		body.global_position = origin + Vector2(8.0 * (peer - 1), 0.0)
		bodies.append(body)
	return bodies


func test_solo_board_refused_in_calm_then_started_in_trade_wind() -> void:
	var body := _run(1)[0]
	body.inventory.add(&"tarp", 1)
	assert_false(routes.start_for(1, &"test_board"), "calm refuses the board")
	assert_eq(body.inventory.count_id(&"tarp"), 1, "a refused start spends nothing")
	assert_false(routes.has_left(1))
	session.climate.weather_id = &"trade_wind"
	assert_true(routes.start_for(1, &"test_board"))
	assert_eq(body.inventory.count_id(&"tarp"), 0, "the solo rider spent their board")
	assert_eq(started, [[&"test_board", [1] as Array[int]]])


func test_solo_without_the_item_starts_nothing() -> void:
	var body := _run(1)[0]
	session.climate.weather_id = &"trade_wind"
	assert_false(routes.start_for(1, &"test_board"))
	assert_eq(body.inventory.count_id(&"tarp"), 0)
	assert_true(started.is_empty())


func test_each_rider_spends_their_own() -> void:
	var bodies := _run(3)
	session.climate.weather_id = &"trade_wind"
	bodies[0].inventory.add(&"tarp", 1)
	bodies[2].inventory.add(&"tarp", 2)
	assert_true(routes.start_for(1, &"test_board"))
	assert_eq(started, [[&"test_board", [1, 3] as Array[int]]], "the two carriers ride")
	assert_eq(bodies[0].inventory.count_id(&"tarp"), 0)
	assert_eq(bodies[2].inventory.count_id(&"tarp"), 1, "each rider spends one, their own")
	assert_false(routes.has_left(2), "the third stays")
	assert_eq(bodies[1].inventory.count_id(&"tarp"), 0)


func test_solo_starter_spends_one_fuel_jug() -> void:
	var body := _run(1)[0]
	body.inventory.add(&"plastic_jug", 2)
	assert_true(routes.start_for(1, &"test_car"))
	assert_eq(body.inventory.count_id(&"plastic_jug"), 1)


func test_a_party_on_the_car_spends_only_the_starters_jug() -> void:
	var bodies := _run(2)
	bodies[0].inventory.add(&"plastic_jug", 1)
	bodies[1].inventory.add(&"plastic_jug", 1)
	assert_true(routes.start_for(1, &"test_car"))
	assert_eq(started, [[&"test_car", [1, 2] as Array[int]]])
	assert_eq(bodies[0].inventory.count_id(&"plastic_jug"), 0)
	assert_eq(bodies[1].inventory.count_id(&"plastic_jug"), 1, "a starter requirement is the starter's alone")


func test_negated_and_nested_conditions_spend_nothing() -> void:
	var body := _run(1)[0]
	var car := fixtures[&"test_car"]
	var nested := ConditionData.new()
	nested.kind = ConditionData.Kind.ANY_OF
	var jug := ConditionData.new()
	jug.kind = ConditionData.Kind.HAS_ITEM
	jug.ref_id = &"plastic_jug"
	jug.consume = true
	nested.children = [jug] as Array[DataPart]
	var no_tarp := ConditionData.new()
	no_tarp.kind = ConditionData.Kind.HAS_ITEM
	no_tarp.ref_id = &"tarp"
	no_tarp.negate = true
	no_tarp.consume = true
	car.requirements = [nested, no_tarp] as Array[ConditionData]
	body.inventory.add(&"plastic_jug", 1)
	assert_true(routes.start_for(1, &"test_car"))
	assert_eq(body.inventory.count_id(&"plastic_jug"), 1, "a nested condition is not spent")
	assert_eq(body.inventory.count_id(&"tarp"), 0)


func test_spend_takes_the_amount_asked() -> void:
	var body := _run(1)[0]
	var car := fixtures[&"test_car"]
	car.requirements[0].amount = 2.0
	body.inventory.add(&"plastic_jug", 3)
	RouteLauncher.spend(car, body, [body] as Array[PlayerBody])
	assert_eq(body.inventory.count_id(&"plastic_jug"), 1)
