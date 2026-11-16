extends GutTest
## creatures-ai spawning on the sandbar: crabs at night by the ISLANDS count, the fire halving,
## party scaling, gulls at their nest palms and the offshore shark. Solo is the default party.

const SESSION_SCENE: PackedScene = preload("res://scenes/net/coop_session.tscn")
const FIRE_SCENE: PackedScene = preload("res://scenes/structures/fire.tscn")
const SANDBAR: IslandLayoutData = preload("res://resources/islands/sandbar.tres")
const COAST_CAY: IslandLayoutData = preload("res://resources/islands/coast_cay.tres")
var temp_root: String = UserTmp.path("test_creature_spawner")

var session: CoopSession
var spawner: CreatureSpawner


func before_each() -> void:
	NetManager.start_solo()
	WeatherManager.stop()
	WeatherManager.sky.start_at(0.0)


func after_each() -> void:
	NetManager.leave()
	FsHelpers.remove_tree(temp_root)


func _spawner(party: int = 1, catalog: ContentCatalog = null, layout: IslandLayoutData = SANDBAR, run_seed: int = 0) -> CreatureSpawner:
	session = SESSION_SCENE.instantiate() as CoopSession
	add_child_autofree(session)
	session.start()
	session.world_state = {"run_seed": run_seed}
	spawner = CreatureSpawner.new()
	spawner.party_size = party
	session.add_child(spawner)
	spawner.setup(session, layout, catalog)
	spawner.spawn_permanent()
	return spawner


func _light_fire(cell: Vector2i) -> Fire:
	var lit := FIRE_SCENE.instantiate() as Fire
	lit.position = IslandLayout.cell_center(cell)
	session.add_child(lit)
	lit.light()
	return lit


func test_solo_night_brings_six_crabs_on_beach_cells_and_dawn_takes_them() -> void:
	_spawner()
	spawner.apply_phase(DataEnums.DayPhase.DAY)
	assert_eq(spawner.creatures(&"land_crab").size(), 0)
	spawner.apply_phase(DataEnums.DayPhase.NIGHT)
	var crabs := spawner.creatures(&"land_crab")
	assert_eq(crabs.size(), 6)
	for crab: Creature in crabs:
		assert_eq(spawner.built.terrain.terrain_at(crab.cell()), DataEnums.Terrain.BEACH)
	spawner.apply_phase(DataEnums.DayPhase.DAWN)
	assert_eq(spawner.creatures(&"land_crab").size(), 0)


func test_solo_fire_at_dusk_halves_the_crabs_and_none_stands_in_the_light() -> void:
	_spawner()
	var lit := _light_fire(spawner.built.solo_spawn + Vector2i(0, 2))
	spawner.apply_phase(DataEnums.DayPhase.NIGHT)
	var crabs := spawner.creatures(&"land_crab")
	assert_eq(crabs.size(), 3)
	for crab: Creature in crabs:
		assert_gte(crab.position.distance_to(lit.position), 5.0 * 16.0)


func test_a_fire_lit_during_the_night_sends_half_the_crabs_away() -> void:
	_spawner()
	spawner.apply_phase(DataEnums.DayPhase.NIGHT)
	assert_eq(spawner.creatures(&"land_crab").size(), 6)
	_light_fire(spawner.built.solo_spawn)
	spawner.check_fires()
	assert_eq(spawner.creatures(&"land_crab").size(), 3)


func test_party_scaling_gives_6_7_8_10_crabs() -> void:
	var expected: Array[int] = [6, 7, 8, 10]
	for players: int in range(1, 5):
		_spawner(players)
		spawner.apply_phase(DataEnums.DayPhase.NIGHT)
		assert_eq(spawner.creatures(&"land_crab").size(), expected[players - 1], "%d players" % players)
		session.queue_free()
		await get_tree().process_frame


func test_solo_gulls_nest_two_per_palm_by_day_and_stay_at_night() -> void:
	_spawner()
	spawner.apply_phase(DataEnums.DayPhase.DAY)
	var gulls := spawner.creatures(&"seagull")
	assert_eq(gulls.size(), 4)
	for index: int in SANDBAR.nest_palms:
		var nest := IslandLayout.cell_center(spawner.built.palms[index])
		var here: int = 0
		for gull: Creature in gulls:
			if gull.nest == nest:
				here += 1
		assert_eq(here, 2)
	spawner.apply_phase(DataEnums.DayPhase.NIGHT)
	assert_eq(spawner.creatures(&"seagull").size(), 4)


func test_one_reef_shark_waits_offshore_in_deep_water() -> void:
	_spawner()
	var sharks := spawner.creatures(&"reef_shark")
	assert_eq(sharks.size(), 1)
	var cell: Vector2i = (sharks[0] as Creature).cell()
	assert_gte(spawner.nav.land_distance(cell), 2)
	assert_true(TerrainQuery.is_water(spawner.built.terrain.terrain_at(cell)))


func test_a_new_shark_file_spawns_with_no_script_edited() -> void:
	var data := (GameState.content.get_entry(&"creatures", &"reef_shark") as CreatureData).duplicate() as CreatureData
	data.id = &"tiburon_prueba"
	FsHelpers.save_content(temp_root, "creatures", "tiburon_prueba", data)
	_spawner(1, ContentCatalog.new(temp_root))
	var made := spawner.creatures(&"tiburon_prueba")
	assert_eq(made.size(), 1)
	assert_true((made[0] as Creature).brain is PatrolCircleStrike)
	assert_gte(spawner.nav.land_distance((made[0] as Creature).cell()), 2)


# --- guardacostas-stealth: the patrol boats ----------------------------------------------------------

func _boats() -> Array[Creature]:
	return spawner.creatures(&"patrol_boat")


# The clocks of the boats, sorted, as whole seconds.
func _clocks() -> Array[int]:
	var found: Array[int] = []
	for boat: Creature in _boats():
		found.append(roundi((boat.brain as PatrolRoute).clock_s))
	found.sort()
	return found


func test_the_sandbar_gets_one_patrol_for_one_player_and_two_for_two_or_three() -> void:
	var expected: Array[int] = [1, 2, 2, 3]
	for players: int in range(1, 5):
		_spawner(players)
		assert_eq(_boats().size(), expected[players - 1], "%d players" % players)
		session.queue_free()
		await get_tree().process_frame


func test_the_boats_run_the_patrol_brain_and_stand_on_the_loop() -> void:
	_spawner()
	var boat := _boats()[0]
	assert_true(boat.brain is PatrolRoute)
	var loop := PatrolLoop.build(spawner.built.terrain, spawner.built.size, boat.data.patrol.route_lap_s, boat.data.patrol.route_offshore_tiles)
	assert_eq(boat.position, loop.pose_px(0.0), "placed at once, on the loop's start")


func test_the_reef_shark_crab_and_gull_counts_do_not_change_with_the_patrol() -> void:
	_spawner()
	assert_eq(spawner.creatures(&"reef_shark").size(), 1)
	spawner.apply_phase(DataEnums.DayPhase.DAY)
	assert_eq(spawner.creatures(&"seagull").size(), 4)
	spawner.apply_phase(DataEnums.DayPhase.NIGHT)
	assert_eq(spawner.creatures(&"land_crab").size(), 6)
	assert_eq(_boats().size(), 1)


# How many boats the coast cay gets under `run_seed`.
func _coast_boats(run_seed: int, players: int = 1) -> int:
	_spawner(players, null, COAST_CAY, run_seed)
	var found: int = _boats().size()
	session.queue_free()
	await get_tree().process_frame
	return found


func test_the_coast_cays_second_boat_is_rolled_from_the_run_seed_and_stable_for_one_seed() -> void:
	var seen: Dictionary[int, bool] = {}
	for run_seed: int in range(1, 13):
		var first: int = await _coast_boats(run_seed)
		assert_between(first, 1, 2, "seed %d" % run_seed)
		seen[first] = true
		var again: int = await _coast_boats(run_seed)
		assert_eq(again, first, "seed %d gives the same boats every time" % run_seed)
	assert_true(seen.has(1) and seen.has(2), "different run seeds give both outcomes")


func test_four_players_on_a_two_boat_coast_cay_get_four_boats_45_s_apart() -> void:
	var seed_with_two: int = -1
	for run_seed: int in range(1, 40):
		if await _coast_boats(run_seed) == 2:
			seed_with_two = run_seed
			break
	assert_gt(seed_with_two, 0, "some seed rolls the second boat")
	_spawner(4, null, COAST_CAY, seed_with_two)
	assert_eq(_boats().size(), 4)
	var clocks := _clocks()
	assert_eq(clocks, [0, 45, 90, 135] as Array[int], "each boat's warning starts 45 s after the one before")


func test_one_boat_alone_starts_its_horizon_at_once() -> void:
	_spawner()
	assert_eq((_boats()[0].brain as PatrolRoute).clock_s, 0.0)
