extends GutTest
## island-stop escape-routes "Raft fittings", the island's half of crossing "Fittings ride with the
## raft", and the four recipes as data, with exactly 1 player, offline:
## - the clavazón takes 4 nails and 20 s, and makes a worn raft 90 of 120;
## - the defensas take a tube and a rope and 10 s;
## - the toldo takes the sandbar's tarp and 2 driftwood and 15 s;
## - each fitting comes once, and a mend then reaches the raised maximum;
## - through the shell, a toldo crosses from the sandbar to the coast cay on the raft;
## - a broken raft leaves nothing, and a raft built after it is bare;
## - of two rafts, the sturdiest comes ashore with its own fittings.

const ISLAND_SCENE: PackedScene = preload("res://scenes/levels/sandbar_island.tscn")
const SESSION_SCENE: PackedScene = preload("res://scenes/net/coop_session.tscn")
const SHELL_SCENE: PackedScene = preload("res://scenes/shell/game_shell.tscn")
const COAST_CAY: IslandLayoutData = preload("res://resources/islands/coast_cay.tres")
const SANDBAR: IslandLayoutData = preload("res://resources/islands/sandbar.tres")
const CLAVAZON: StringName = &"raft_clavazon"
const DEFENSAS: StringName = &"raft_defensas"
const TOLDO: StringName = &"raft_toldo"

var settings_path: String = UserTmp.path("test_raft_fittings_settings.cfg")
var island: SandbarIsland
var session: CoopSession
var raft: Raft
var body: PlayerBody


func before_each() -> void:
	NetManager.start_solo()
	WeatherManager.stop()
	WeatherManager.sky.start_at(0.0)


func after_each() -> void:
	WeatherManager.stop()
	NetManager.leave()
	if FileAccess.file_exists(settings_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(settings_path))


# The island `layout` with a raft beached at `integrity`, the player at its work point.
func _island(layout: IslandLayoutData, integrity: float) -> void:
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
	island.beach_raft(integrity)
	raft = session.get_node("Raft") as Raft
	body = session.body(1)
	body.player_input.enabled = false
	body.global_position = raft.work_point.global_position


func _fit(ids: Array) -> Array[StringName]:
	var fitted: Array[StringName] = []
	fitted.assign(ids)
	return fitted


# The player opens `recipe_id` at the raft, deposits what they carry and works it `seconds`.
func _work(recipe_id: StringName, seconds: float) -> bool:
	if not session.craft_for(CoopSession.HOST_ID, recipe_id, session.get_path_to(raft)):
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
		if recipe == null:
			continue
		assert_false(recipe.name_es.is_empty() or recipe.name_en.is_empty(), "%s has both names" % id)
		assert_eq(ContentValidator._check_vessel_recipe("recipes/%s" % id, recipe), PackedStringArray(), "%s checks" % id)
	assert_eq(ContentValidator.validate(GameState.content), PackedStringArray(), "the whole catalog checks")
	assert_eq(_recipe(CLAVAZON).inputs, {&"nails": 4} as Dictionary[StringName, int])
	assert_eq(_recipe(CLAVAZON).time_s, 20.0)
	assert_eq(_recipe(CLAVAZON).integrity_delta, 20.0)
	assert_eq(_recipe(DEFENSAS).inputs, {&"inner_tube": 1, &"rope": 1} as Dictionary[StringName, int])
	assert_eq(_recipe(DEFENSAS).time_s, 10.0)
	assert_eq(VesselFittings.factor(_fit([DEFENSAS]), ModifierData.Stat.VESSEL_HAZARD_DAMAGE), 0.75)
	assert_eq(_recipe(TOLDO).inputs, {&"driftwood": 2, &"tarp": 1} as Dictionary[StringName, int])
	assert_eq(_recipe(TOLDO).time_s, 15.0)
	assert_true(VesselFittings.has_flag(_fit([TOLDO]), ModifierData.Stat.VESSEL_DECK_SHADE))
	assert_false(VesselFittings.has_flag(_fit([CLAVAZON, DEFENSAS]), ModifierData.Stat.VESSEL_DECK_SHADE))
	for id: StringName in [CLAVAZON, DEFENSAS, TOLDO]:
		assert_false(CraftList.offers(_recipe(id)), "%s is never on the bench's list" % id)


func test_solo_nails_the_raft_on_the_coast_cay() -> void:
	_island(COAST_CAY, 70.0)
	body.inventory.add(&"nails", 4)
	assert_true(_work(CLAVAZON, 20.0))
	assert_eq(raft.integrity, 90.0)
	assert_eq(raft.max_integrity, 120.0)
	assert_eq(raft.fittings, _fit([CLAVAZON]))
	assert_eq(body.inventory.count_id(&"nails"), 0, "the observation post's 4 nails are spent")


func test_the_clavazon_is_not_done_before_its_20_s() -> void:
	_island(COAST_CAY, 70.0)
	body.inventory.add(&"nails", 4)
	assert_true(_work(CLAVAZON, 19.0))
	assert_eq(raft.max_integrity, 100.0)
	body.crafter.advance(1.0)
	assert_eq(raft.max_integrity, 120.0)


func test_solo_fits_the_defensas() -> void:
	_island(COAST_CAY, 70.0)
	body.inventory.add(&"inner_tube", 1)
	body.inventory.add(&"rope", 1)
	assert_true(_work(DEFENSAS, 10.0))
	assert_eq(raft.fittings, _fit([DEFENSAS]))
	assert_eq(raft.integrity, 70.0, "the defensas mend nothing")
	assert_eq(raft.max_integrity, 100.0)


func test_solo_puts_a_toldo_on_the_sandbar_raft() -> void:
	_island(SANDBAR, 100.0)
	body.inventory.add(&"tarp", 1)
	body.inventory.add(&"driftwood", 2)
	assert_true(_work(TOLDO, 15.0))
	assert_eq(raft.fittings, _fit([TOLDO]))
	assert_eq(raft.integrity, 100.0)
	assert_eq(raft.max_integrity, 100.0)


func test_a_fitting_only_once() -> void:
	_island(COAST_CAY, 70.0)
	body.inventory.add(&"nails", 8)
	assert_true(_work(CLAVAZON, 20.0))
	assert_false(session.craft_for(CoopSession.HOST_ID, CLAVAZON, session.get_path_to(raft)), "a second clavazón is refused")
	assert_null(raft.job)
	assert_eq(body.inventory.count_id(&"nails"), 4, "the other 4 nails stay")


func test_a_mend_reaches_the_raised_maximum() -> void:
	_island(COAST_CAY, 70.0)
	body.inventory.add(&"nails", 4)
	assert_true(_work(CLAVAZON, 20.0))
	body.inventory.add(&"driftwood", 2)
	body.inventory.add(&"rope", 2)
	assert_true(_work(&"raft_mend", 10.0))
	assert_eq(raft.integrity, 110.0, "90 + 20, past the old 100")
	assert_true(_work(&"raft_mend", 10.0))
	assert_eq(raft.integrity, 120.0, "and no higher than 120")


func test_a_launch_takes_the_fittings_aboard() -> void:
	_island(COAST_CAY, 70.0)
	raft.fittings = _fit([DEFENSAS, TOLDO])
	body.global_position = raft.global_position
	assert_true(session.start_route_for(CoopSession.HOST_ID, &"raft"))
	var routes := session.get_node("Routes") as IslandRoutes
	assert_eq(routes.departure_integrity[&"raft"], 70.0)
	assert_eq(routes.departure_fittings[&"raft"], [DEFENSAS, TOLDO])


# --- through the shell: the fittings ride with the raft ---------------------------------------------

func _shell() -> GameShell:
	var shell := SHELL_SCENE.instantiate() as GameShell
	shell.settings_path = settings_path
	add_child_autofree(shell)
	(shell.screen as TitleScreen).solo_requested.emit()
	shell.session.body(1).player_input.enabled = false
	return shell


# The sandbar's raft site built at once, as if the player had built it.
func _build_sandbar_raft(shell: GameShell) -> Raft:
	var site := shell.session.get_node("RaftSite") as BuildSite
	for id: StringName in site.recipe.inputs:
		site.deposited[id] = site.recipe.inputs[id]
	site.work(1.0)
	return shell.session.get_node_or_null("Raft") as Raft


func _cross(shell: GameShell, at_end: float, broken: bool = false) -> void:
	var crossing := shell.crossings[0] as Crossing
	crossing.plan = CrossingPlan.create(20.0, [] as Array[RefCounted])
	crossing.tie(1)
	if broken:
		crossing.integrity.hit(crossing.integrity.value)
	else:
		crossing.integrity.value = at_end
	CrossingRig.run(crossing, 20.0)


func test_solo_carries_a_toldo_to_the_coast_cay() -> void:
	var shell := _shell()
	var built := _build_sandbar_raft(shell)
	assert_not_null(built, "the sandbar's raft is built")
	if built == null:
		return
	built.fittings = _fit([TOLDO])
	var player := shell.session.body(1)
	player.global_position = built.global_position
	assert_true(shell.session.start_route_for(1, &"raft"))
	var crossing := shell.crossings[0] as Crossing
	assert_eq(crossing.fittings, _fit([TOLDO]), "the toldo is aboard")
	assert_true(crossing.deck_shaded())
	_cross(shell, 70.0)
	await wait_process_frames(2)
	assert_eq(shell.island.layout.id, &"coast_cay")
	var beached := shell.session.get_node_or_null("Raft") as Raft
	assert_not_null(beached, "a raft stands at the coast cay's raft site")
	if beached == null:
		return
	assert_eq(beached.integrity, 70.0)
	assert_eq(beached.max_integrity, 100.0)
	assert_eq(beached.fittings, _fit([TOLDO]), "with the toldo")


func test_a_nailed_raft_keeps_its_maximum_ashore() -> void:
	var shell := _shell()
	var built := _build_sandbar_raft(shell)
	if built == null:
		fail_test("no raft")
		return
	built.fittings = _fit([CLAVAZON])
	built.max_integrity = 120.0
	built.integrity = 120.0
	shell.session.body(1).global_position = built.global_position
	assert_true(shell.session.start_route_for(1, &"raft"))
	var crossing := shell.crossings[0] as Crossing
	assert_eq(crossing.integrity.maximum, 120.0)
	assert_eq(crossing.integrity.value, 120.0)
	_cross(shell, 110.0)
	await wait_process_frames(2)
	var beached := shell.session.get_node_or_null("Raft") as Raft
	assert_not_null(beached)
	if beached != null:
		assert_eq(beached.integrity, 110.0, "110 of 120 survives the beaching")
		assert_eq(beached.max_integrity, 120.0)


func test_a_broken_raft_loses_its_fittings() -> void:
	var shell := _shell()
	var built := _build_sandbar_raft(shell)
	if built == null:
		fail_test("no raft")
		return
	built.fittings = _fit([CLAVAZON])
	shell.session.body(1).global_position = built.global_position
	assert_true(shell.session.start_route_for(1, &"raft"))
	_cross(shell, 0.0, true)
	await wait_process_frames(2)
	assert_eq(shell.island.layout.id, &"coast_cay")
	assert_null(shell.session.get_node_or_null("Raft"), "nothing beached")
	var site := shell.session.get_node_or_null("RaftSite") as BuildSite
	assert_not_null(site, "the raft build site is empty")
	if site == null:
		return
	for id: StringName in site.recipe.inputs:
		site.deposited[id] = site.recipe.inputs[id]
	site.work(1.0)
	var fresh := shell.session.get_node_or_null("Raft") as Raft
	assert_not_null(fresh)
	if fresh != null:
		assert_eq(fresh.integrity, 100.0)
		assert_eq(fresh.max_integrity, 100.0)
		assert_eq(fresh.fittings, _fit([]), "built bare")


func test_the_sturdiest_raft_keeps_its_own_fittings() -> void:
	var travel := IslandTravel.new()
	autofree(travel)
	var toldo := CrossingResult.new()
	toldo.route_id = &"raft"
	toldo.integrity = 80.0
	toldo.maximum = 100.0
	toldo.fittings = _fit([TOLDO])
	var nailed := CrossingResult.new()
	nailed.route_id = &"raft"
	nailed.integrity = 60.0
	nailed.maximum = 120.0
	nailed.fittings = _fit([CLAVAZON])
	travel._results = [nailed, toldo] as Array[CrossingResult]
	assert_eq(travel._beached_integrity(), 80.0)
	assert_eq(travel._beached_fittings(), _fit([TOLDO]), "the toldo's raft, without the clavazón")
	nailed.broken = true
	toldo.broken = true
	assert_eq(travel._beached_fittings(), _fit([]), "nothing when both broke")


# --- the look (drawing only) ---------------------------------------------------------------------

func test_the_fittings_are_drawn_on_the_beached_raft() -> void:
	_island(COAST_CAY, 70.0)
	var look := raft.get_node_or_null(NodePath(RaftFittingsLook.NODE_NAME)) as RaftFittingsLook
	assert_not_null(look)
	if look == null:
		return
	look.step()
	assert_eq(look.sprite_count(), 0, "a bare raft shows none")
	raft.fittings = _fit([CLAVAZON, DEFENSAS, TOLDO])
	look.step()
	assert_eq(look.sprite_count(), 5, "two nail icons, two tubes and the tarp")
	var raft_look := raft.get_node_or_null(^"Look") as StructureLook
	if raft_look != null:
		raft_look.step()
		var frame_size: Vector2 = raft_look.sprite.sprite_frames.get_frame_texture(raft_look.sprite.animation, 0).get_size()
		var lean: Vector2 = raft_look.sprite.offset - StructureArt.frame_offset(frame_size)
		assert_eq(look.position, RaftFittingsLook.ISLAND_CENTER + lean, "the icons lean toward land with the raft (C14)")
	assert_eq(raft.integrity, 70.0, "drawing changes nothing")
	assert_eq(raft.fittings, _fit([CLAVAZON, DEFENSAS, TOLDO]))


func test_the_fittings_are_drawn_on_the_deck_at_sea() -> void:
	var crossing := CrossingRig.make(self, &"raft", 1, 100.0, 60.0, [], _fit([TOLDO]))
	var look := crossing.get_node_or_null(NodePath(RaftFittingsLook.NODE_NAME)) as RaftFittingsLook
	assert_not_null(look)
	if look == null:
		return
	look.step()
	assert_eq(look.sprite_count(), 1, "the toldo's tarp")
	assert_eq(look.position, crossing.deck_center())
	crossing.integrity.hit(100.0)
	look.step()
	assert_eq(look.sprite_count(), 0, "nothing once the raft sank")
