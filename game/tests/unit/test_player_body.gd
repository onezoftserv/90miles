extends GutTest
## player-movement: PlayerBody applies the MovementModel with 16 px tiles, driven by intents.

const PLAYER_SCENE: PackedScene = preload("res://scenes/player/player.tscn")
const TILE: float = 16.0
const DT: float = 1.0 / 60.0
const T := DataEnums.Terrain


func _spawn() -> PlayerBody:
	var body := PLAYER_SCENE.instantiate() as PlayerBody
	add_child_autofree(body)
	return body


func _step(body: PlayerBody, seconds: float) -> void:
	for i: int in roundi(seconds / DT):
		body._physics_process(DT)


func test_running_on_sand_for_10_s_ends_60_tiles_away_with_45_energy() -> void:
	var body := _spawn()
	body.meters.energy = 50.0
	body.intent = MoveIntent.create(Vector2.RIGHT, true)
	_step(body, 10.0)
	assert_almost_eq(body.position.x / TILE, 60.0, 0.05)
	assert_almost_eq(body.position.y, 0.0, 0.001)
	assert_almost_eq(body.meters.energy, 45.0, 0.01)


func test_same_intent_on_two_bodies_gives_identical_results() -> void:
	var a := _spawn()
	var b := _spawn()
	for body: PlayerBody in [a, b]:
		body.meters.energy = 50.0
		body.intent = MoveIntent.create(Vector2.RIGHT, true)
		_step(body, 2.0)
	assert_almost_eq(a.position.x / TILE, 12.0, 0.02)
	assert_almost_eq(50.0 - a.meters.energy, 1.0, 0.01)
	assert_eq(a.position, b.position)
	assert_eq(a.meters.energy, b.meters.energy)


func test_swimming_moves_3_tiles_per_second_and_spends_energy() -> void:
	var body := _spawn()
	var grid := GridTerrain.new()
	grid.default_terrain = T.DEEP
	body.terrain = grid
	body.intent = MoveIntent.create(Vector2.DOWN)
	_step(body, 1.0)
	assert_almost_eq(body.position.y / TILE, 3.0, 0.02)
	assert_almost_eq(body.meters.energy, 97.0, 0.01)
	assert_eq(body.movement_state, MovementStep.Move.SWIM)


func test_exhausted_swimmer_drifts_with_the_current() -> void:
	var body := _spawn()
	var grid := GridTerrain.new()
	grid.default_terrain = T.DEEP
	body.terrain = grid
	body.meters.energy = 0.0
	body.intent = MoveIntent.create(Vector2.LEFT)
	_step(body, 2.0)
	assert_almost_eq(body.position.x / TILE, 2.0, 0.02)
	assert_eq(body.movement_state, MovementStep.Move.FLOAT)


func test_crouching_in_scrub_reports_hidden() -> void:
	var body := _spawn()
	var grid := GridTerrain.new()
	grid.default_terrain = T.SCRUB
	body.terrain = grid
	body.intent = MoveIntent.create(Vector2.RIGHT, false, true)
	_step(body, 1.0)
	assert_almost_eq(body.position.x / TILE, 2.0, 0.02)
	assert_eq(body.stealth_state, MovementStep.Stealth.HIDDEN)


func test_cell_uses_16_pixel_tiles_and_floors_negatives() -> void:
	var body := _spawn()
	body.position = Vector2(17.0, 31.0)
	assert_eq(body.cell(), Vector2i(1, 1))
	body.position = Vector2(-1.0, -16.0)
	assert_eq(body.cell(), Vector2i(-1, -1))


func test_terrain_is_looked_up_at_the_bodys_cell() -> void:
	var body := _spawn()
	var grid := GridTerrain.new()
	grid.fill_rect(Rect2i(2, 0, 10, 1), T.DEEP)
	body.terrain = grid
	body.position = Vector2(2.0 * TILE + 1.0, 4.0)
	body.intent = MoveIntent.create(Vector2.RIGHT)
	_step(body, 0.1)
	assert_eq(body.movement_state, MovementStep.Move.SWIM)


func test_idle_body_does_not_move_or_spend() -> void:
	var body := _spawn()
	_step(body, 1.0)
	assert_eq(body.position, Vector2.ZERO)
	assert_eq(body.meters.energy, 100.0)


func test_a_new_body_has_an_idle_intent() -> void:
	var body := _spawn()
	assert_not_null(body.intent)
	assert_eq(body.intent.direction, Vector2.ZERO)
