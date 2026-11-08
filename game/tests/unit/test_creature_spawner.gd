extends GutTest
## creatures-ai spawning on the sandbar: crabs at night by the ISLANDS count, the fire halving,
## party scaling, gulls at their nest palms and the offshore shark. Solo is the default party.

const SESSION_SCENE: PackedScene = preload("res://scenes/net/coop_session.tscn")
const FIRE_SCENE: PackedScene = preload("res://scenes/structures/fire.tscn")
const SANDBAR: IslandLayoutData = preload("res://resources/islands/sandbar.tres")
const TEMP_ROOT: String = "user://test_creature_spawner"

var session: CoopSession
var spawner: CreatureSpawner


func before_each() -> void:
	NetManager.start_solo()
	WeatherManager.stop()
	WeatherManager.sky.start_at(0.0)


func after_each() -> void:
	NetManager.leave()
	FsHelpers.remove_tree(TEMP_ROOT)


func _spawner(party: int = 1, catalog: ContentCatalog = null) -> CreatureSpawner:
	session = SESSION_SCENE.instantiate() as CoopSession
	add_child_autofree(session)
	session.start()
	spawner = CreatureSpawner.new()
	spawner.party_size = party
	session.add_child(spawner)
	spawner.setup(session, SANDBAR, catalog)
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
	FsHelpers.save_content(TEMP_ROOT, "creatures", "tiburon_prueba", data)
	_spawner(1, ContentCatalog.new(TEMP_ROOT))
	var made := spawner.creatures(&"tiburon_prueba")
	assert_eq(made.size(), 1)
	assert_true((made[0] as Creature).brain is PatrolCircleStrike)
	assert_gte(spawner.nav.land_distance((made[0] as Creature).cell()), 2)
