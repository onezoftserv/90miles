extends GutTest
## player-movement: the manual-test playground scene loads, has the terrain the spec needs and
## two players, and needs no textures of its own.

const PLAYGROUND_PATH := "res://scenes/dev/movement_playground.tscn"
const T := DataEnums.Terrain

var playground: MovementPlayground


func before_each() -> void:
	playground = (load(PLAYGROUND_PATH) as PackedScene).instantiate() as MovementPlayground
	add_child_autofree(playground)


func _players() -> Array[PlayerBody]:
	var found: Array[PlayerBody] = []
	for child: Node in playground.get_children():
		var body := child as PlayerBody
		if body != null:
			found.append(body)
	return found


func _has_terrain(terrain: DataEnums.Terrain) -> bool:
	return playground.terrain.cells.values().has(terrain)


func test_has_land_brush_shallow_and_deep_water() -> void:
	for terrain: DataEnums.Terrain in [T.BEACH, T.SCRUB, T.MANGROVE, T.SHALLOWS, T.DEEP, T.BRACKISH]:
		assert_true(_has_terrain(terrain), "terrain %s" % terrain)


func test_has_two_players_and_only_one_is_local() -> void:
	var players := _players()
	assert_eq(players.size(), 2)
	var cameras: int = 0
	for body: PlayerBody in players:
		if body.camera.enabled:
			cameras += 1
	assert_eq(cameras, 1)


func test_players_use_the_playground_terrain_and_start_on_land() -> void:
	for body: PlayerBody in _players():
		assert_eq(body.terrain, playground.terrain)
		assert_false(TerrainQuery.is_water(playground.terrain.terrain_at(body.cell())))


func test_has_one_enabled_interactable_in_reach_of_the_start() -> void:
	var items: Array[Interactable] = []
	for child: Node in playground.get_children():
		var item := child as Interactable
		if item != null:
			items.append(item)
	assert_eq(items.size(), 1)
	assert_true(items[0].enabled)
	var first := _players()[0]
	assert_not_null(InteractionPicker.pick(first.global_position, items, first))


func test_a_player_can_walk_from_land_into_the_water() -> void:
	var swimmer := _players()[0]
	swimmer.intent = MoveIntent.create(Vector2.RIGHT, true)
	for i: int in 600:
		swimmer._physics_process(1.0 / 60.0)
	assert_eq(swimmer.movement_state, MovementStep.Move.SWIM)
	assert_lt(swimmer.meters.energy, 100.0)


func test_hud_shows_the_local_players_meters() -> void:
	var hud := playground.get_node("Hud/MetersHud") as MetersHud
	assert_not_null(hud)
	var local := _players()[0]
	assert_true(local.local_player)
	local.meters.thirst = 40.0
	assert_eq(hud.bar_for(DataEnums.Meter.THIRST).bar.value, 40.0)
	_players()[1].meters.thirst = 10.0
	assert_eq(hud.bar_for(DataEnums.Meter.THIRST).bar.value, 40.0, "not the teammate's")


func test_has_a_shaded_hut_on_land() -> void:
	assert_false(playground.terrain.shaded.is_empty())
	for cell: Vector2i in playground.terrain.shaded:
		assert_false(TerrainQuery.is_water(playground.terrain.terrain_at(cell)), "hut cell %s" % cell)


func test_players_share_a_midday_climate() -> void:
	assert_eq(playground.climate.phase, DataEnums.DayPhase.DAY)
	assert_true(playground.climate.midday)
	for body: PlayerBody in _players():
		assert_eq(body.climate, playground.climate)


func test_scene_draws_without_textures() -> void:
	for dependency: String in ResourceLoader.get_dependencies(PLAYGROUND_PATH):
		assert_false(dependency.get_extension() in ["png", "jpg", "webp", "svg"], dependency)


func test_the_playground_has_a_day_night_tint() -> void:
	var found: Array[Node] = playground.find_children("*", "DayNightTint", false, false)
	assert_eq(found.size(), 1)
	assert_true(found[0] is CanvasModulate)


func test_the_playground_starts_at_1000_on_the_one_clock() -> void:
	assert_eq(WeatherManager.hour(), 10)
	assert_true(playground.climate == WeatherManager.sky.climate)
