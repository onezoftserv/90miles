extends GutTest
## island-pressure group 2, 1 player, offline: the sandbar's raft site is built in four stages
## (crafting-inventory "Build stages"), worked only while interact is held ("Held work on staged
## builds"), and each second of work costs 1 energy and 0.25 thirst ("Work costs"); a fire site keeps
## the old rules. The body is stepped frame by frame from its intent, as the host steps it.

const ISLAND_SCENE: PackedScene = preload("res://scenes/levels/sandbar_island.tscn")
const SESSION_SCENE: PackedScene = preload("res://scenes/net/coop_session.tscn")
const STEP_S: float = 0.1
const RAFT_TIME_S: float = 120.0

var island: SandbarIsland
var session: CoopSession
var site: BuildSite
var body: PlayerBody


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
	island.with_creatures = false
	island.furnish(session)
	session.start()
	site = session.get_node("RaftSite") as BuildSite
	body = session.body(1)
	body.player_input.enabled = false
	body.auto_advance = false
	body.global_position = site.global_position
	# Dawn, out of the sun: thirst drains at its 0.1/s rest rate.
	island.climate.phase = DataEnums.DayPhase.DAWN
	island.climate.midday = false


func after_each() -> void:
	WeatherManager.stop()
	NetManager.leave()


# Steps the body `seconds` from an intent that holds interact (or not), as the host does each frame.
func _step(seconds: float, held: bool) -> void:
	body.intent = MoveIntent.create(Vector2.ZERO, false, false, held)
	for i: int in roundi(seconds / STEP_S):
		body.advance(STEP_S)
		body._tick_meters(STEP_S)


func _hold(seconds: float) -> void:
	_step(seconds, true)


func _carry(driftwood: int, tubes: int, rope: int) -> void:
	if driftwood > 0:
		body.inventory.add(&"driftwood", driftwood)
	if tubes > 0:
		body.inventory.add(&"inner_tube", tubes)
	if rope > 0:
		body.inventory.add(&"rope", rope)


func _work_s() -> float:
	return site.progress() * RAFT_TIME_S


func _raft() -> Raft:
	return session.get_node_or_null("Raft") as Raft


func _slot_of(id: StringName) -> int:
	for i: int in body.inventory.slots.size():
		var slot: InventorySlot = body.inventory.slots[i]
		if slot != null and slot.item_id == id:
			return i
	return -1


func _stage_name() -> String:
	return site.recipe.stages[site.stage_index()].name_es


# --- Build stages ----------------------------------------------------------------------------

func test_solo_raft_waits_at_a_stage() -> void:
	_carry(0, 2, 3)
	_hold(40.0)
	assert_eq(site.deposited, {&"inner_tube": 2, &"rope": 3} as Dictionary[StringName, int], "the press deposited everything")
	assert_almost_eq(_work_s(), 30.0, 0.01, "the first stage is done and work stops there")
	assert_eq(site.stage_index(), 1)
	assert_eq(_stage_name(), "Armar el piso")
	assert_eq(site.stage_missing_items(), {&"driftwood": 4} as Dictionary[StringName, int])
	assert_almost_eq(body.meters.energy, 70.0, 0.01, "waiting at the stage costs nothing")
	assert_false(site.inputs_complete(), "the whole recipe still needs driftwood")


func test_everything_in_at_once() -> void:
	_carry(6, 2, 3)
	_hold(60.0)
	assert_almost_eq(_work_s(), 60.0, 0.01)
	assert_eq(site.stage_index(), 2)
	assert_eq(_stage_name(), "Amarrar la baranda")
	assert_almost_eq(site.stage_progress(), 0.0, 0.001)
	assert_eq(site.stage_missing_items(), {} as Dictionary[StringName, int])


func test_the_stage_comes_from_the_progress() -> void:
	_carry(6, 2, 3)
	_hold(45.0)
	assert_eq(site.stage_count(), 4)
	assert_eq(site.stage_index(), 1)
	assert_almost_eq(site.stage_progress(), 0.5, 0.001)
	assert_almost_eq(site.work_limit(), 1.0, 0.0001, "every input is in")


func test_a_recipe_without_stages() -> void:
	var fire := GameState.content.get_entry(&"recipes", &"fire") as RecipeData
	var fire_site := body.crafter.place_site(fire, body.global_position + Vector2(-2.0 * PlayerBody.TILE_SIZE, 0.0), session)
	body.global_position = fire_site.global_position
	body.inventory.add(&"driftwood", 3)
	body.inventory.add(&"dry_grass", 1)
	fire_site.deposit(body)
	assert_eq(fire_site.stage_count(), 0)
	assert_true(body.crafter.start_work(fire_site))
	_step(30.0, false)
	assert_true(fire_site.built, "a fire site is worked by standing in reach, as before")
	assert_almost_eq(body.meters.energy, 100.0, 0.001, "a free fire")


# --- Held work --------------------------------------------------------------------------------

func test_letting_go_keeps_the_work() -> void:
	_carry(6, 2, 3)
	_hold(10.0)
	_step(1.0, false)
	body.global_position += Vector2(8.0 * PlayerBody.TILE_SIZE, 0.0)
	_step(19.0, false)
	assert_almost_eq(_work_s(), 10.0, 0.01, "nothing moved while let go")
	assert_false(body.crafter.is_crafting(), "letting go ended the work")
	body.global_position = site.global_position
	_step(STEP_S, false)
	_hold(20.0)
	assert_almost_eq(_work_s(), 30.0, 0.05)
	assert_eq(site.stage_index(), 1, "the first stage is done")


func test_standing_in_reach_without_holding_does_not_work_a_staged_site() -> void:
	_carry(6, 2, 3)
	site.deposit(body)
	assert_true(body.crafter.start_work(site))
	_step(10.0, false)
	assert_eq(site.progress(), 0.0)
	assert_false(body.crafter.is_crafting(), "no hold, no work")


func test_a_downed_player_does_not_work() -> void:
	_carry(6, 2, 3)
	_hold(5.0)
	body.meters.solo = true
	body.meters.health = 0.0
	body.meters.tick(0.0, MeterContext.new())
	assert_true(body.downed, "a solo last stand lies down")
	var before: float = _work_s()
	body.intent = MoveIntent.create(Vector2.ZERO, false, false, true)
	for i: int in 60:
		body.crafter.advance(STEP_S)
	assert_almost_eq(_work_s(), before, 0.0001)


# --- Work costs -------------------------------------------------------------------------------

func test_solo_stage_at_dawn() -> void:
	body.meters.thirst = 80.0
	_carry(0, 2, 1)
	_hold(30.0)
	assert_eq(site.stage_index(), 1, "the first stage is done")
	assert_almost_eq(body.meters.energy, 70.0, 0.01)
	assert_almost_eq(body.meters.thirst, 69.5, 0.01)


# owner Q4 (a): at 0 energy the work goes on at a quarter speed and costs thirst only.
func test_out_of_strength() -> void:
	_carry(6, 2, 3)
	site.deposit(body)
	body.meters.energy = 5.0
	body.meters.thirst = 80.0
	_hold(10.0)
	assert_almost_eq(_work_s(), 6.25, 0.03, "5 s, then 5 s at a quarter speed")
	assert_almost_eq(body.meters.energy, 0.0, 0.0001)
	assert_almost_eq(body.meters.thirst, 76.5, 0.03, "the thirst of every second held, and the rest drain")
	assert_true(site.needs_strength(body), "the prompt asks for food")


func test_the_slow_work_factor_is_data() -> void:
	assert_eq(site.recipe.exhausted_work_factor, 0.25)
	var fire := GameState.content.get_entry(&"recipes", &"fire") as RecipeData
	assert_eq(fire.exhausted_work_factor, 0.0, "a recipe without a work cost has none")


# crafting-inventory "No food left": a player who reaches 0 energy with no food still finishes the
# raft on island 1, and launches it at night.
func test_no_food_left_still_finishes_and_launches() -> void:
	_carry(6, 2, 3)
	site.deposit(body)
	site.work(100.0 / RAFT_TIME_S)
	body.meters.energy = 0.0
	assert_eq(body.inventory.held_food(), &"", "no food")
	_hold(79.0)
	assert_null(_raft(), "not yet: 19.75 of the last 20 s")
	_hold(1.2)
	var raft := _raft()
	assert_not_null(raft, "the raft is built at a quarter speed")
	assert_almost_eq(body.meters.energy, 0.0, 0.0001, "no energy was needed")
	assert_false(body.meters.dead)
	island.climate.phase = DataEnums.DayPhase.NIGHT
	var routes := session.get_node("Routes") as IslandRoutes
	raft.global_position = body.global_position
	assert_true(routes.start_for(1, &"raft"), "launched at night")


func test_building_the_raft_in_the_sun() -> void:
	island.climate.phase = DataEnums.DayPhase.DAY
	var cell := body.cell()
	assert_false(body.terrain.is_shaded(cell), "the raft site is in the open")
	body.meters.thirst = 80.0
	_carry(6, 2, 3)
	_hold(20.0)
	assert_almost_eq(body.meters.thirst, 71.0, 0.01, "0.2/s in the sun and 0.25/s of work")


func test_a_raft_stage_costs_30_energy() -> void:
	_carry(0, 2, 1)
	_hold(30.0)
	assert_almost_eq(body.meters.energy, 70.0, 0.01)


# escape-routes "Solo raft".
func test_solo_raft() -> void:
	_carry(6, 2, 3)
	body.inventory.add(&"coco", 2)
	body.inventory.add(&"knife", 1)
	_hold(100.0)
	assert_almost_eq(_work_s(), 100.0, 0.05, "100 energy buys 100 s of work")
	assert_eq(site.stage_index(), 3, "in the fourth stage")
	assert_almost_eq(body.meters.energy, 0.0, 0.0001)
	_step(STEP_S, false)
	for i: int in 2:
		var slot: int = _slot_of(&"coco")
		assert_true(ItemUser.use(body, slot, 0), "eats a coconut")
	assert_almost_eq(body.meters.energy, 20.0, 0.01, "two meals")
	_step(STEP_S, false)
	_hold(21.0)
	var raft := _raft()
	assert_not_null(raft, "the raft is built")
	island.climate.phase = DataEnums.DayPhase.NIGHT
	var routes := session.get_node("Routes") as IslandRoutes
	raft.global_position = body.global_position
	assert_true(routes.start_for(1, &"raft"), "launched at night")
	assert_eq(routes.route_left_by(1), &"raft")


# escape-routes "A solo Mecánico": no shipped background has the Building skill yet, so the raft's
# recipe is given the Maestro's skill here; the rule is the same.
func test_a_solo_mecanico() -> void:
	var recipe := site.recipe.duplicate() as RecipeData
	recipe.skill = DataEnums.Skill.NAVIGATION
	site.recipe = recipe
	body.background_id = &"maestro"
	_carry(6, 2, 3)
	_hold(60.0)
	assert_true(site.built, "60 s at 2x")
	assert_almost_eq(body.meters.energy, 40.0, 0.05, "pays per second worked")
