extends GutTest
## survival-meters wired into PlayerBody: the host ticks each body's meters with a context built
## from the terrain, the movement state, nearby teammates and the climate; sunstroke slows the
## body; the meters own the downed state the body follows.

const PLAYER_SCENE: PackedScene = preload("res://scenes/player/player.tscn")
const TILE: float = 16.0
const DT: float = 1.0 / 60.0
## Long runs step coarser; every rate is linear.
const LONG_DT: float = 0.25
const M := DataEnums.Meter
const P := DataEnums.DayPhase
const T := DataEnums.Terrain


func _spawn(at: Vector2 = Vector2.ZERO) -> PlayerBody:
	var body := PLAYER_SCENE.instantiate() as PlayerBody
	body.position = at
	add_child_autofree(body)
	return body


func _step(bodies: Array[PlayerBody], seconds: float, dt: float = DT) -> void:
	for i: int in roundi(seconds / dt):
		for body: PlayerBody in bodies:
			body._physics_process(dt)


func _climate(phase: DataEnums.DayPhase, midday: bool = false) -> ClimateState:
	var climate := ClimateState.new()
	climate.phase = phase
	climate.midday = midday
	return climate


func test_body_in_the_midday_sun_loses_thirst_at_0_2_per_second() -> void:
	var body := _spawn()
	body.climate = _climate(P.DAY, true)
	_step([body], 10.0)
	assert_almost_eq(body.meters.thirst, 98.0, 0.01)
	assert_almost_eq(body.meters.heat, 7.5, 0.01, "heat rises in the midday sun")


func test_swimming_body_loses_thirst_at_x3() -> void:
	var body := _spawn()
	var grid := GridTerrain.new()
	grid.default_terrain = T.DEEP
	body.terrain = grid
	body.climate = _climate(P.DAY, true)
	body.intent = MoveIntent.create(Vector2.DOWN)
	_step([body], 10.0)
	assert_eq(body.movement_state, MovementStep.Move.SWIM)
	assert_almost_eq(body.meters.thirst, 97.0, 0.01)
	assert_eq(body.meters.heat, 0.0, "water keeps heat down")


func test_body_on_a_shaded_cell_gets_no_sun() -> void:
	var body := _spawn(Vector2(8.0, 8.0))
	var grid := GridTerrain.new()
	grid.set_shaded(Rect2i(0, 0, 1, 1))
	body.terrain = grid
	body.climate = _climate(P.DAY, true)
	_step([body], 10.0)
	assert_true(grid.is_shaded(Vector2i(0, 0)))
	assert_false(grid.is_shaded(Vector2i(1, 0)))
	assert_almost_eq(body.meters.thirst, 99.0, 0.01, "base rate in the shade")
	assert_eq(body.meters.heat, 0.0)


func test_teammate_within_5_tiles_restores_morale_at_night() -> void:
	var a := _spawn(Vector2.ZERO)
	var b := _spawn(Vector2(4.0 * TILE, 0.0))
	for body: PlayerBody in [a, b]:
		body.meters.morale = 50.0
		body.climate = _climate(P.NIGHT)
	_step([a, b], 60.0, LONG_DT)
	assert_almost_eq(a.meters.morale, 52.0, 0.01)
	assert_almost_eq(b.meters.morale, 52.0, 0.01)


func test_teammate_6_tiles_away_is_not_company() -> void:
	var a := _spawn(Vector2.ZERO)
	var b := _spawn(Vector2(6.0 * TILE, 0.0))
	a.meters.morale = 50.0
	a.climate = _climate(P.NIGHT)
	b.climate = _climate(P.NIGHT)
	_step([a, b], 60.0, LONG_DT)
	assert_almost_eq(a.meters.morale, 45.0, 0.01, "alone at night")


func test_dead_teammate_is_not_company() -> void:
	var a := _spawn(Vector2.ZERO)
	var b := _spawn(Vector2(2.0 * TILE, 0.0))
	b.meters.dead = true
	a.meters.morale = 50.0
	a.climate = _climate(P.NIGHT)
	_step([a], 60.0, LONG_DT)
	assert_almost_eq(a.meters.morale, 45.0, 0.01)


func test_sunstroke_slows_walking_to_2_4_tiles_per_second() -> void:
	var body := _spawn()
	body.meters.heat = 100.0
	body.meters.tick(0.0, MeterContext.new())
	assert_true(body.meters.sunstroke)
	body.intent = MoveIntent.create(Vector2.RIGHT)
	_step([body], 1.0)
	assert_almost_eq(body.position.x / TILE, 2.4, 0.02)


func test_running_out_of_energy_leaves_the_body_crawling() -> void:
	var body := _spawn()
	body.meters.energy = 5.0
	body.intent = MoveIntent.create(Vector2.RIGHT, true)
	# 10 s of running spends the 5; the frame after that is the first one without energy.
	_step([body], 11.0)
	assert_eq(body.meters.energy, 0.0)
	assert_eq(body.movement_state, MovementStep.Move.CRAWL)


func test_meters_going_down_put_the_body_down_and_revive_stands_it_up() -> void:
	var body := _spawn()
	body.meters.add(M.HEALTH, -100.0)
	assert_true(body.downed)
	assert_true(body.drag_handle.enabled)
	body.meters.revive()
	assert_false(body.downed)
	assert_false(body.drag_handle.enabled)


func test_dead_body_stays_down_and_cannot_be_dragged() -> void:
	var body := _spawn()
	body.meters.add(M.HEALTH, -100.0)
	_step([body], 90.0, LONG_DT)
	assert_true(body.meters.dead)
	assert_true(body.downed)
	assert_false(body.drag_handle.enabled)


func test_downed_body_keeps_losing_thirst() -> void:
	var body := _spawn()
	body.climate = _climate(P.DAWN)
	body.meters.add(M.HEALTH, -100.0)
	_step([body], 10.0, LONG_DT)
	assert_almost_eq(body.meters.thirst, 99.0, 0.01)


func test_body_that_is_not_the_host_does_not_advance_its_meters() -> void:
	var body := _spawn()
	body.climate = _climate(P.DAY, true)
	var client := ENetMultiplayerPeer.new()
	assert_eq(client.create_client("127.0.0.1", 47_391), OK)
	var api := SceneMultiplayer.new()
	api.multiplayer_peer = client
	get_tree().set_multiplayer(api, body.get_path())
	assert_false(body.multiplayer.is_server(), "the body now lives on a client")
	_step([body], 10.0)
	var thirst_on_client: float = body.meters.thirst
	get_tree().set_multiplayer(null, body.get_path())
	client.close()
	assert_eq(thirst_on_client, 100.0, "only the host simulates")
