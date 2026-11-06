extends GutTest
## escape-routes "Riders by capacity": who a started route takes.

const PLAYER_SCENE: PackedScene = preload("res://scenes/player/player.tscn")
const TILE: float = PlayerBody.TILE_SIZE


func _body(at_tiles: float = 0.0) -> PlayerBody:
	var body := PLAYER_SCENE.instantiate() as PlayerBody
	add_child_autofree(body)
	body.global_position = Vector2(at_tiles * TILE, 0.0)
	return body


func _route(mode: RouteData.CapacityMode) -> RouteData:
	var route := RouteData.new()
	route.capacity_mode = mode
	return route


func _swim() -> RouteData:
	return GameState.content.get_entry(&"routes", &"binoculars_swim") as RouteData


func _list(bodies: Array) -> Array[PlayerBody]:
	var list: Array[PlayerBody] = []
	for body: PlayerBody in bodies:
		list.append(body)
	return list


func test_all_takes_everyone_within_5_tiles_sender_first() -> void:
	var a := _body(0.0)
	var b := _body(2.0)
	var c := _body(4.0)
	var far := _body(8.0)
	var riders := RouteLauncher.riders(_route(RouteData.CapacityMode.ALL), b, _list([a, b, c, far]), Vector2.ZERO)
	assert_eq(riders.size(), 3)
	assert_eq(riders[0], b, "the sender first")
	assert_false(riders.has(far))


func test_one_player_alone_is_the_rider() -> void:
	var a := _body()
	var riders := RouteLauncher.riders(_route(RouteData.CapacityMode.ALL), a, _list([a]), Vector2.ZERO)
	assert_eq(riders, _list([a]))


func test_per_swimmer_leaves_the_tired_and_the_bleeding_behind() -> void:
	var sender := _body(0.0)
	var tired := _body(1.0)
	var cut := _body(1.0)
	var fit := _body(1.0)
	for body: PlayerBody in [sender, cut, fit]:
		body.meters.energy = 100.0
	tired.meters.energy = 99.0
	cut.meters.set_status(DataEnums.Status.BLEEDING, true)
	var riders := RouteLauncher.riders(_swim(), sender, _list([sender, tired, cut, fit]), sender.global_position)
	assert_eq(riders, _list([sender, fit]))
	fit.meters.energy = 99.0
	assert_eq(RouteLauncher.riders(_swim(), sender, _list([sender, tired, cut, fit]), sender.global_position), _list([sender]))


func test_fixed_takes_the_sender_then_the_nearest() -> void:
	var route := _route(RouteData.CapacityMode.FIXED)
	route.capacity = 2
	var sender := _body(0.0)
	var near := _body(1.0)
	var mid := _body(3.0)
	var riders := RouteLauncher.riders(route, sender, _list([mid, near, sender]), Vector2.ZERO)
	assert_eq(riders, _list([sender, near]))


func test_a_sender_who_fails_the_rider_requirements_starts_nothing() -> void:
	var sender := _body()
	var other := _body(1.0)
	sender.meters.energy = 50.0
	other.meters.energy = 100.0
	assert_eq(RouteLauncher.riders(_swim(), sender, _list([sender, other]), Vector2.ZERO).size(), 0)


func test_downed_or_dead_players_never_ride() -> void:
	var sender := _body()
	var downed := _body(1.0)
	var dead := _body(1.0)
	downed.meters.downed = true
	dead.meters.dead = true
	var riders := RouteLauncher.riders(_route(RouteData.CapacityMode.ALL), sender, _list([sender, downed, dead]), Vector2.ZERO)
	assert_eq(riders, _list([sender]))
