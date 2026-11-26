extends GutTest
## island-stop, escape-routes "Raft fittings" and "The raft's state on every peer" (solo offline),
## with exactly 1 player, offline: the clavazón raises the maximum and the integrity by 20, the
## toldo and the defensas go on and leave the integrity as it was, a fitting goes on once, the four
## raft recipes load from data with no content errors, the launch carries the fitted raft to the
## departure, and nothing is sent to anyone.

const ISLAND_SCENE: PackedScene = preload("res://scenes/levels/sandbar_island.tscn")
const SESSION_SCENE: PackedScene = preload("res://scenes/net/coop_session.tscn")
const COAST_CAY: IslandLayoutData = preload("res://resources/islands/coast_cay.tres")
const SANDBAR: IslandLayoutData = preload("res://resources/islands/sandbar.tres")
const CLAVAZON: StringName = &"raft_clavazon"
const DEFENSAS: StringName = &"raft_defensas"
const TOLDO: StringName = &"raft_toldo"

var island: SandbarIsland
var session: CoopSession
var raft: Raft
var body: PlayerBody


func after_each() -> void:
	WeatherManager.stop()
	NetManager.leave()


# A solo run on `layout` whose raft lies on its build site at `at` of 100, the player at its work point.
func _start(layout: IslandLayoutData, at: float) -> void:
	NetManager.start_solo()
	WeatherManager.stop()
	WeatherManager.sky.start_at(0.0)
	island = ISLAND_SCENE.instantiate() as SandbarIsland
	island.layout = layout
	add_child_autofree(island)
	session = SESSION_SCENE.instantiate() as CoopSession
	session.terrain = island.terrain
	session.climate = island.climate
	session.spawn_points = island.spawn_points(true)
	add_child_autofree(session)
	island.with_creatures = false
	island.furnish(session)
	session.start()
	island.beach_raft(RaftRecord.bare(at))
	raft = session.get_node("Raft") as Raft
	body = session.body(1)
	body.player_input.enabled = false
	body.global_position = raft.work_point.global_position


# The player opens `id` at the raft, deposits what they carry and works it for `seconds`.
func _fit(id: StringName, seconds: float) -> bool:
	if not session.craft_for(CoopSession.HOST_ID, id, session.get_path_to(raft)):
		return false
	var job := raft.job
	job.deposit(body)
	if not body.crafter.start_work(job):
		return false
	body.crafter.advance(seconds)
	return true


func _recipe(id: StringName) -> RecipeData:
	return GameState.content.get_entry(&"recipes", id) as RecipeData


func test_fittings_from_data() -> void:
	for id: StringName in [&"raft_mend", CLAVAZON, DEFENSAS, TOLDO]:
		var recipe := _recipe(id)
		assert_not_null(recipe, "%s loads" % id)
		assert_false(recipe.name_es.is_empty(), "%s has a Spanish name" % id)
		assert_false(recipe.name_en.is_empty(), "%s has an English name" % id)
		assert_eq(recipe.station, RecipeData.Station.NONE, "%s is worked on the raft" % id)
		assert_false(recipe.build_site)
		assert_true(Raft.is_job_recipe(recipe))
		assert_eq(ContentValidator._check_vessel_recipe(String(id), recipe).size(), 0, "%s has no content errors" % id)
	assert_eq(_recipe(CLAVAZON).inputs, {&"nails": 4} as Dictionary[StringName, int])
	assert_eq(_recipe(CLAVAZON).time_s, 20.0)
	assert_eq(_recipe(CLAVAZON).integrity_delta, 20.0)
	assert_eq(_recipe(CLAVAZON).vessel_modifiers.size(), 0, "the maximum is the integrity_delta, no VESSEL_MAX_INTEGRITY")
	assert_eq(_recipe(DEFENSAS).inputs, {&"inner_tube": 1, &"rope": 1} as Dictionary[StringName, int])
	assert_eq(_recipe(DEFENSAS).time_s, 10.0)
	assert_eq(_recipe(TOLDO).inputs, {&"tarp": 1, &"driftwood": 2} as Dictionary[StringName, int])
	assert_eq(_recipe(TOLDO).time_s, 15.0)
	assert_false(CraftList.offers(_recipe(TOLDO)), "never on the bench's list")


func test_the_whole_catalog_has_no_content_errors() -> void:
	assert_eq(ContentValidator.validate(GameState.content), PackedStringArray(), "the content check reports no errors")


func test_solo_nails_the_raft_on_the_coast_cay() -> void:
	_start(COAST_CAY, 70.0)
	body.inventory.add(&"nails", 4)
	assert_true(_fit(CLAVAZON, 20.0), "one player opens, feeds and works the clavazón")
	assert_eq(raft.integrity, 90.0)
	assert_eq(raft.max_integrity, 120.0)
	assert_eq(raft.fittings, [CLAVAZON] as Array[StringName])
	assert_eq(body.inventory.count_id(&"nails"), 0, "the nails left their inventory")
	assert_null(raft.job)


func test_the_clavazon_is_not_done_before_its_20_s() -> void:
	_start(COAST_CAY, 70.0)
	body.inventory.add(&"nails", 4)
	assert_true(_fit(CLAVAZON, 19.0))
	assert_eq(raft.max_integrity, 100.0, "19 s of 20")
	body.crafter.advance(1.0)
	assert_eq(raft.max_integrity, 120.0)


func test_solo_puts_a_toldo_on_the_sandbar_raft() -> void:
	_start(SANDBAR, 100.0)
	body.inventory.add(&"tarp", 1)
	body.inventory.add(&"driftwood", 2)
	assert_true(_fit(TOLDO, 15.0))
	assert_eq(raft.fittings, [TOLDO] as Array[StringName])
	assert_eq(raft.integrity, 100.0, "still at 100")
	assert_eq(raft.max_integrity, 100.0, "of 100")
	assert_eq(body.inventory.count_id(&"tarp"), 0)


func test_solo_fits_the_defensas() -> void:
	_start(COAST_CAY, 80.0)
	body.inventory.add(&"inner_tube", 1)
	body.inventory.add(&"rope", 1)
	assert_true(_fit(DEFENSAS, 10.0))
	assert_eq(raft.fittings, [DEFENSAS] as Array[StringName])
	assert_eq(raft.integrity, 80.0)
	assert_eq(raft.max_integrity, 100.0)


func test_a_fitting_only_once() -> void:
	_start(COAST_CAY, 70.0)
	body.inventory.add(&"nails", 8)
	assert_true(_fit(CLAVAZON, 20.0))
	assert_false(session.craft_for(CoopSession.HOST_ID, CLAVAZON, session.get_path_to(raft)), "no job starts")
	assert_null(raft.job)
	assert_eq(body.inventory.count_id(&"nails"), 4, "the nails stay in their inventory")
	assert_eq(raft.refusal(_recipe(CLAVAZON)), &"raft_has_it")
	assert_eq(raft.max_integrity, 120.0, "the maximum is raised once")


func test_all_three_fittings_and_a_mend() -> void:
	_start(COAST_CAY, 70.0)
	body.inventory.add(&"nails", 4)
	body.inventory.add(&"inner_tube", 1)
	body.inventory.add(&"rope", 2)
	body.inventory.add(&"tarp", 1)
	body.inventory.add(&"driftwood", 3)
	assert_true(_fit(CLAVAZON, 20.0))
	assert_true(_fit(DEFENSAS, 10.0))
	assert_true(_fit(TOLDO, 15.0))
	assert_true(_fit(&"raft_mend", 10.0))
	assert_eq(raft.fittings, [CLAVAZON, DEFENSAS, TOLDO] as Array[StringName], "in the order they were done")
	assert_eq(raft.integrity, 110.0, "70 + 20 + 20")
	assert_eq(raft.max_integrity, 120.0)


func test_solo_fits_offline_and_the_launch_carries_the_fittings() -> void:
	_start(SANDBAR, 100.0)
	body.inventory.add(&"tarp", 1)
	body.inventory.add(&"driftwood", 2)
	assert_true(_fit(TOLDO, 15.0))
	assert_true(session.multiplayer.get_peers().is_empty(), "nobody to send to")
	body.global_position = raft.global_position
	assert_true(session.start_route_for(CoopSession.HOST_ID, &"raft"))
	var routes := session.get_node("Routes") as IslandRoutes
	var left: RaftRecord = routes.departure_raft[&"raft"]
	assert_eq(left.integrity, 100.0)
	assert_eq(left.maximum, 100.0)
	assert_eq(left.fittings, [TOLDO] as Array[StringName])
	assert_true(left.deck_shaded())


func test_the_beached_look_follows_the_maximum() -> void:
	assert_eq(StructureArt.vessel_frame(70.0, 100.0), StructureArt.RAFT_WHOLE)
	assert_eq(StructureArt.vessel_frame(70.0, 120.0), StructureArt.RAFT_WORN, "70 of 120 is under two thirds")


func test_the_beached_raft_draws_its_fittings() -> void:
	_start(COAST_CAY, 70.0)
	var look := raft.get_node("Look") as StructureLook
	look.step()
	var fittings := RaftFittingsLook.of(look.sprite)
	assert_false(fittings.visible, "a bare raft draws no fittings")
	body.inventory.add(&"nails", 4)
	body.inventory.add(&"tarp", 1)
	body.inventory.add(&"driftwood", 2)
	assert_true(_fit(CLAVAZON, 20.0))
	assert_true(_fit(TOLDO, 15.0))
	look.step()
	var data := StructureArtData.standard()
	assert_true(fittings.visible)
	assert_eq(fittings.shown(), [data.raft_fittings[CLAVAZON], data.raft_fittings[TOLDO]] as Array[Texture2D], "the nails, then the toldo on top")
	var layer := fittings.get_child(0) as Sprite2D
	assert_eq(layer.offset, look.sprite.offset, "standing where the raft stands")
	assert_eq(layer.texture.get_size(), Vector2(64.0, 32.0), "the raft frame's size")
