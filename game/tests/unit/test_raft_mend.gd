extends GutTest
## island-stop, escape-routes "Mending a built raft", "Raft jobs are shared" (one job, nobody
## working), "A launch ends an unfinished job" and "The raft's state on every peer" (solo offline),
## with exactly 1 player, offline, on the real coast cay with a raft beached at 48: the work point
## stands on the land side; a mend takes 1 driftwood and 1 rope and 10 s of work for +20, repeats,
## stops at the maximum and is refused on a whole raft; one job at a time; nobody working keeps the
## progress; a launch hands the deposits back; a fitting (a fixture here: the real ones come with
## the fittings PR) raises the maximum once; a background with the recipe's skill works it twice as
## fast; and nothing is sent to anyone.

const ISLAND_SCENE: PackedScene = preload("res://scenes/levels/sandbar_island.tscn")
const SESSION_SCENE: PackedScene = preload("res://scenes/net/coop_session.tscn")
const COAST_CAY: IslandLayoutData = preload("res://resources/islands/coast_cay.tres")
const MEND: StringName = &"raft_mend"

var island: SandbarIsland
var session: CoopSession
var raft: Raft
var body: PlayerBody


func before_each() -> void:
	NetManager.start_solo()
	WeatherManager.stop()
	WeatherManager.sky.start_at(0.0)
	island = ISLAND_SCENE.instantiate() as SandbarIsland
	island.layout = COAST_CAY
	add_child_autofree(island)
	session = SESSION_SCENE.instantiate() as CoopSession
	session.terrain = island.terrain
	session.climate = island.climate
	session.spawn_points = island.spawn_points(true)
	add_child_autofree(session)
	island.with_creatures = false
	island.furnish(session)
	session.start()
	island.beach_raft(RaftRecord.bare(48.0))
	raft = session.get_node("Raft") as Raft
	body = session.body(1)
	body.player_input.enabled = false
	body.global_position = raft.work_point.global_position


func after_each() -> void:
	WeatherManager.stop()
	NetManager.leave()


func _raft_path() -> NodePath:
	return session.get_path_to(raft)


# The player opens a mend at the raft, deposits what they carry and works it for `seconds`.
func _mend(seconds: float) -> bool:
	if not session.craft_for(CoopSession.HOST_ID, MEND, _raft_path()):
		return false
	var job := raft.job
	job.deposit(body)
	if not body.crafter.start_work(job):
		return false
	body.crafter.advance(seconds)
	return true


func _carry(driftwood: int, rope: int) -> void:
	body.inventory.add(&"driftwood", driftwood)
	body.inventory.add(&"rope", rope)


func _fixture_fitting() -> RecipeData:
	var fitting := RecipeData.new()
	fitting.id = &"fixture_fitting"
	fitting.name_es = "Arreglo de prueba"
	fitting.output_kind = RecipeData.OutputKind.VESSEL_UPGRADE
	fitting.station = RecipeData.Station.NONE
	fitting.integrity_delta = 20.0
	return fitting


func test_the_beached_raft_has_its_integrity_and_the_recipes_maximum() -> void:
	assert_eq(raft.integrity, 48.0)
	assert_eq(raft.max_integrity, 100.0)
	assert_eq(raft.fittings, [] as Array[StringName])
	assert_null(raft.job)


func test_the_work_point_stands_on_land_beside_the_raft() -> void:
	var offset: Vector2 = raft.work_point.position
	assert_eq(offset.length(), float(IslandLayout.TILE), "one tile from the raft")
	var cell := Vector2i((raft.work_point.global_position / float(IslandLayout.TILE)).floor())
	assert_false(TerrainQuery.is_water(island.terrain.terrain_at(cell)), "on land")
	assert_true(raft.work_point.enabled)


func test_solo_mends_on_the_coast_cay() -> void:
	_carry(1, 1)
	assert_true(_mend(10.0), "one player opens, feeds and works the mend")
	assert_eq(raft.integrity, 68.0, "48 + 20")
	assert_eq(raft.max_integrity, 100.0)
	assert_eq(body.inventory.count_id(&"driftwood"), 0)
	assert_eq(body.inventory.count_id(&"rope"), 0)
	assert_null(raft.job, "the job is done and gone")
	assert_true(raft.work_point.enabled, "the work point is back")
	body.global_position = raft.global_position
	assert_true(session.start_route_for(CoopSession.HOST_ID, &"raft"), "the mended raft launches")
	var routes := session.get_node("Routes") as IslandRoutes
	assert_eq(routes.departure_raft[&"raft"].integrity, 68.0, "at 68")


func test_the_mend_is_not_done_before_its_10_s() -> void:
	_carry(1, 1)
	assert_true(_mend(9.0))
	assert_eq(raft.integrity, 48.0, "9 s of 10")
	body.crafter.advance(1.0)
	assert_eq(raft.integrity, 68.0, "done at 10 s")


func test_two_mends_in_a_row() -> void:
	_carry(2, 2)
	assert_true(_mend(10.0))
	assert_true(_mend(10.0), "the mend repeats")
	assert_eq(raft.integrity, 88.0)


func test_a_mend_stops_at_the_maximum() -> void:
	raft.integrity = 90.0
	_carry(1, 1)
	assert_true(_mend(10.0))
	assert_eq(raft.integrity, 100.0)


func test_a_whole_raft_takes_no_mend() -> void:
	raft.integrity = 100.0
	_carry(1, 1)
	assert_false(session.craft_for(CoopSession.HOST_ID, MEND, _raft_path()), "no job starts")
	assert_null(raft.job)
	assert_eq(body.inventory.count_id(&"driftwood"), 1, "nothing is spent")
	assert_eq(body.inventory.count_id(&"rope"), 1)
	assert_eq(raft.refusal(GameState.content.get_entry(&"recipes", MEND) as RecipeData), &"raft_whole")


func test_a_mend_out_of_reach_of_the_work_point_is_refused() -> void:
	body.global_position = raft.work_point.global_position + Vector2(0.0, 3.0 * IslandLayout.TILE)
	assert_false(session.craft_for(CoopSession.HOST_ID, MEND, _raft_path()))
	assert_null(raft.job)


func test_a_mend_the_player_does_not_know_is_refused() -> void:
	var mend := GameState.content.get_entry(&"recipes", MEND) as RecipeData
	var taught := mend.duplicate() as RecipeData
	taught.availability = RecipeData.Availability.TAUGHT_BY_NPC
	body.crafter.register(taught)
	assert_false(session.craft_for(CoopSession.HOST_ID, MEND, _raft_path()), "an NPC teaches it here")
	assert_null(raft.job)
	body.crafter.register(mend)
	assert_true(session.craft_for(CoopSession.HOST_ID, MEND, _raft_path()), "the known one opens")


func test_a_mend_is_never_worked_at_the_bench() -> void:
	var bench := session.get_node("HutWorkbench") as Workbench
	body.global_position = bench.global_position
	_carry(1, 1)
	assert_false(session.craft_for(CoopSession.HOST_ID, MEND, session.get_path_to(bench)), "only at a raft")
	assert_false(body.crafter.is_crafting())
	assert_false(CraftList.offers(GameState.content.get_entry(&"recipes", MEND) as RecipeData), "not on the bench's list")


func test_one_job_at_a_time() -> void:
	assert_true(session.craft_for(CoopSession.HOST_ID, MEND, _raft_path()))
	var first := raft.job
	assert_false(session.craft_for(CoopSession.HOST_ID, MEND, _raft_path()), "a second start is refused")
	assert_same(raft.job, first, "the first job stays")
	assert_false(raft.work_point.enabled, "the work point waits while a job is open")
	assert_eq(raft.refusal(GameState.content.get_entry(&"recipes", MEND) as RecipeData), &"in_progress")


func test_nobody_working_keeps_the_progress() -> void:
	_carry(1, 1)
	assert_true(session.craft_for(CoopSession.HOST_ID, MEND, _raft_path()))
	var job := raft.job
	job.deposit(body)
	assert_true(job.work(0.5))
	body.crafter.advance(30.0)
	assert_eq(job.progress(), 0.5, "nobody works it")
	assert_eq(raft.integrity, 48.0)


func test_solo_launches_in_the_middle_of_a_mend() -> void:
	raft.integrity = 60.0
	_carry(1, 0)
	assert_true(session.craft_for(CoopSession.HOST_ID, MEND, _raft_path()))
	raft.job.deposit(body)
	assert_eq(body.inventory.count_id(&"driftwood"), 0, "the driftwood went in")
	body.global_position = raft.global_position
	assert_true(session.start_route_for(CoopSession.HOST_ID, &"raft"), "a job never stops a launch")
	var routes := session.get_node("Routes") as IslandRoutes
	assert_eq(routes.departure_raft[&"raft"].integrity, 60.0, "the crossing starts at 60")
	assert_eq(body.inventory.count_id(&"driftwood"), 1, "the driftwood is back")


func test_a_launch_drops_what_the_depositor_cannot_carry() -> void:
	_carry(1, 0)
	assert_true(session.craft_for(CoopSession.HOST_ID, MEND, _raft_path()))
	raft.job.deposit(body)
	var at: Vector2 = raft.position
	# Too heavy now to take the driftwood back.
	body.inventory.add(&"rope", 999)
	var full: bool = body.inventory.add(&"driftwood", 1) == 0
	if not full:
		body.inventory.remove_id(&"driftwood", 1)
		pending("the test inventory never fills")
		return
	raft.end_job()
	var dropped: int = 0
	for node: Node in session.get_node("Pickups").get_children():
		var item := node as WorldItem
		if item != null and item.item_id == &"driftwood" and item.position.distance_to(at) < 1.0:
			dropped += item.count
	assert_eq(dropped, 1, "it lies on the raft's cell")


func test_a_fitting_raises_the_maximum_and_comes_once() -> void:
	raft.integrity = 70.0
	var fitting := _fixture_fitting()
	assert_eq(raft.refusal(fitting), &"")
	raft.finish_job(fitting)
	assert_eq(raft.integrity, 90.0)
	assert_eq(raft.max_integrity, 120.0)
	assert_true(raft.fittings.has(&"fixture_fitting"))
	assert_eq(raft.refusal(fitting), &"raft_has_it", "only once")
	raft.finish_job(fitting)
	assert_eq(raft.max_integrity, 120.0, "a second one does nothing")


func test_a_background_with_the_recipes_skill_works_twice_as_fast() -> void:
	var chart := RecipeData.new()
	chart.time_s = 10.0
	chart.skill = DataEnums.Skill.NAVIGATION
	chart.skill_speed_multiplier = 2.0
	var mend := GameState.content.get_entry(&"recipes", MEND) as RecipeData
	assert_eq(body.crafter.recipe_time(chart), 10.0, "no background")
	body.background_id = &"maestro"
	assert_eq(body.crafter.recipe_time(chart), 5.0, "a Maestro has Navigation")
	assert_eq(body.crafter.recipe_time(mend), 10.0, "but not Building")


func test_nothing_is_sent_offline() -> void:
	_carry(1, 1)
	assert_true(_mend(10.0))
	assert_eq(multiplayer.get_peers(), PackedInt32Array(), "no second peer")
	assert_eq(raft.integrity, 68.0)
