extends GutTest
## crossing "Crossing length" and "Threat plan": rolled on the host from the route and the sky.

var tuning: CrossingTuning
var sky: WorldSky


func before_each() -> void:
	WeatherManager.stop()
	WeatherManager.sky.start_at(0.0)
	sky = WeatherManager.sky
	tuning = CrossingTuning.standard()


func _route(id: StringName, length: Vector2 = Vector2.ZERO) -> RouteData:
	var route := (GameState.content.get_entry(&"routes", id) as RouteData).duplicate() as RouteData
	if length != Vector2.ZERO:
		route.duration_s = length
	return route


func _roll(route: RouteData, seed_value: int) -> CrossingPlan:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return CrossingPlan.roll(route, DataEnums.DistanceBand.COAST, sky, rng, tuning)


func test_length_within_route_duration() -> void:
	var route := _route(&"raft")
	assert_eq(route.duration_s, Vector2(60, 90), "the raft's coast crossing")
	for seed_value: int in 50:
		var length: float = _roll(route, seed_value).length_s
		assert_between(length, 60.0, 90.0)
	assert_eq(_roll(_route(&"raft", Vector2(75, 75)), 1).length_s, 75.0)
	assert_eq(_roll(_route(&"binoculars_swim"), 1).length_s, 60.0)


func test_warned_squall_follows_riders() -> void:
	sky.weather.apply(&"calm", 100.0, &"squall", 40.0)
	var plan := _roll(_route(&"raft", Vector2(90, 90)), 3)
	var squalls: Array[RefCounted] = plan.events.filter(func(e: RefCounted) -> bool: return (e as CrossingBeat).kind == CrossingBeat.Kind.SQUALL)
	assert_eq(squalls.size(), 1)
	assert_eq((squalls[0] as CrossingBeat).time_s, 40.0)


func test_running_squall_hits_10s_in() -> void:
	sky.weather.apply(&"squall", 100.0, &"", -1.0)
	var plan := _roll(_route(&"raft", Vector2(60, 60)), 3)
	var squalls: Array[RefCounted] = plan.events.filter(func(e: RefCounted) -> bool: return (e as CrossingBeat).kind == CrossingBeat.Kind.SQUALL)
	assert_eq((squalls[0] as CrossingBeat).time_s, 10.0)


func test_same_seed_same_plan() -> void:
	var route := _route(&"raft")
	for seed_value: int in 20:
		assert_eq(_roll(route, seed_value).to_array(), _roll(route, seed_value).to_array())


func test_a_60s_crossing_never_rolls_its_own_squall() -> void:
	var route := _route(&"raft", Vector2(60, 60))
	for seed_value: int in 50:
		for item: RefCounted in _roll(route, seed_value).events:
			assert_ne((item as CrossingBeat).kind, CrossingBeat.Kind.SQUALL_WARN)


func test_events_are_in_time_order_and_survive_the_wire() -> void:
	var route := _route(&"raft", Vector2(90, 90))
	for seed_value: int in 30:
		var plan := _roll(route, seed_value)
		var previous: float = 0.0
		for item: RefCounted in plan.events:
			assert_gte((item as CrossingBeat).time_s, previous)
			previous = (item as CrossingBeat).time_s
		assert_eq(CrossingPlan.from_array(plan.to_array()).to_array(), plan.to_array())
	assert_null(CrossingPlan.from_array([60.0, [[1.0, 99]]]), "an unknown kind")
	assert_null(CrossingPlan.from_array("nope"))
