extends GutTest
## creatures-ai: the furnished sandbar starts its creatures unless a test turns them off.

const ISLAND_SCENE: PackedScene = preload("res://scenes/levels/sandbar_island.tscn")
const SESSION_SCENE: PackedScene = preload("res://scenes/net/coop_session.tscn")

var island: SandbarIsland
var session: CoopSession


func before_each() -> void:
	NetManager.start_solo()
	WeatherManager.stop()
	WeatherManager.sky.start_at(0.0)


func after_each() -> void:
	WeatherManager.stop()
	NetManager.leave()


func _furnish(with_creatures: bool) -> CreatureSpawner:
	island = ISLAND_SCENE.instantiate() as SandbarIsland
	add_child_autofree(island)
	session = SESSION_SCENE.instantiate() as CoopSession
	session.terrain = island.terrain
	session.spawn_points = island.spawn_points(true)
	add_child_autofree(session)
	island.with_creatures = with_creatures
	island.furnish(session)
	session.start()
	await get_tree().process_frame
	return session.get_node_or_null(NodePath(SandbarIsland.CREATURES_NAME)) as CreatureSpawner


func test_a_furnished_island_spawns_gulls_and_the_offshore_shark() -> void:
	var spawner := await _furnish(true)
	assert_not_null(spawner)
	assert_gt(spawner.creatures(&"seagull").size(), 0)
	assert_eq(spawner.creatures(&"reef_shark").size(), 1)


func test_an_island_without_creatures_spawns_none() -> void:
	var spawner := await _furnish(false)
	assert_null(spawner)
	assert_eq(session.entities.get_child_count(), 0)
