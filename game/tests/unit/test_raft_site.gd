extends GutTest
## escape-routes "Raft build site": the shared site on the sandbar takes 6 driftwood, 2 tubes
## and 3 rope from any player and advances only while someone works it.

const ISLAND_SCENE: PackedScene = preload("res://scenes/levels/sandbar_island.tscn")
const SESSION_SCENE: PackedScene = preload("res://scenes/net/coop_session.tscn")
const PLAYER_SCENE: PackedScene = preload("res://scenes/player/player.tscn")

var island: SandbarIsland
var session: CoopSession
var site: BuildSite


func before_each() -> void:
	NetManager.start_solo()
	WeatherManager.stop()
	WeatherManager.sky.start_at(0.0)
	island = ISLAND_SCENE.instantiate() as SandbarIsland
	add_child_autofree(island)
	session = SESSION_SCENE.instantiate() as CoopSession
	session.terrain = island.terrain
	session.climate = island.climate
	session.spawn_points = island.spawn_points(true)
	add_child_autofree(session)
	island.furnish(session)
	session.start()
	site = session.get_node("RaftSite") as BuildSite
	session.body(1).player_input.enabled = false


func after_each() -> void:
	WeatherManager.stop()
	NetManager.leave()


func _helper() -> PlayerBody:
	var body := PLAYER_SCENE.instantiate() as PlayerBody
	add_child_autofree(body)
	body.global_position = site.global_position
	return body


func _filled() -> PlayerBody:
	var body := session.body(1)
	body.global_position = site.global_position
	body.inventory.add(&"driftwood", 6)
	body.inventory.add(&"inner_tube", 2)
	body.inventory.add(&"rope", 3)
	site.deposit(body)
	return body


func test_the_site_stands_on_the_marked_beach_cell() -> void:
	assert_not_null(site)
	assert_eq(site.recipe.id, &"raft")
	assert_eq(site.position, IslandLayout.cell_center(island.built.raft_site))


func test_the_site_takes_6_2_3_from_any_player() -> void:
	var a := session.body(1)
	var b := _helper()
	a.inventory.add(&"driftwood", 8)
	a.inventory.add(&"inner_tube", 1)
	b.inventory.add(&"inner_tube", 1)
	b.inventory.add(&"rope", 4)
	site.deposit(a)
	site.deposit(b)
	assert_eq(site.deposited, {&"driftwood": 6, &"inner_tube": 2, &"rope": 3})
	assert_true(site.inputs_complete())
	assert_eq(a.inventory.count_id(&"driftwood"), 2)
	assert_eq(b.inventory.count_id(&"rope"), 1)


func test_progress_advances_only_while_someone_works() -> void:
	var body := _filled()
	body.crafter.advance(10.0)
	assert_eq(site.progress(), 0.0, "nobody works it")
	assert_true(body.crafter.start_work(site))
	body.crafter.advance(30.0)
	assert_almost_eq(site.progress(), 0.5, 0.001)
	body.global_position += Vector2(10 * PlayerBody.TILE_SIZE, 0)
	body.crafter.advance(10.0)
	assert_almost_eq(site.progress(), 0.5, 0.001, "out of reach, no work")


func test_60_seconds_of_work_make_a_raft() -> void:
	var body := _filled()
	body.crafter.start_work(site)
	body.crafter.advance(60.0)
	var raft := session.get_node_or_null("Raft") as Raft
	assert_not_null(raft)
	assert_eq(raft.position, IslandLayout.cell_center(island.built.raft_site))
	assert_eq(raft.recipe_id, &"raft")
