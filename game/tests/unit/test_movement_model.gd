extends GutTest
## player-movement: every number of the spec, proven against the pure MovementModel.

const EAST := Vector2.RIGHT
const T := DataEnums.Terrain
const CURRENT := TerrainQuery.DEFAULT_CURRENT

var model: MovementModel


func before_each() -> void:
	model = MovementModel.new()


func _run(terrain: DataEnums.Terrain, energy: float, intent: MoveIntent, seconds: float) -> Dictionary:
	return MovementSim.run(model, terrain, energy, intent, seconds)


func _tiles(r: Dictionary) -> Vector2:
	return r["tiles"] as Vector2


func _last(r: Dictionary) -> MovementStep:
	return r["last"] as MovementStep


# --- walk, run, crouch -------------------------------------------------------------------

func test_walks_4_tiles_per_second() -> void:
	var r := _run(T.BEACH, 50.0, MoveIntent.create(EAST), 1.0)
	assert_almost_eq(_tiles(r).x, 4.0, 0.001)
	assert_eq(_last(r).movement, MovementStep.Move.WALK)
	assert_almost_eq(r["energy"] as float, 50.0, 0.0001, "walking is free")


func test_runs_6_tiles_per_second() -> void:
	var r := _run(T.BEACH, 50.0, MoveIntent.create(EAST, true), 1.0)
	assert_almost_eq(_tiles(r).x, 6.0, 0.001)
	assert_eq(_last(r).movement, MovementStep.Move.RUN)


func test_crouches_2_tiles_per_second() -> void:
	var r := _run(T.BEACH, 50.0, MoveIntent.create(EAST, false, true), 1.0)
	assert_almost_eq(_tiles(r).x, 2.0, 0.001)
	assert_eq(_last(r).movement, MovementStep.Move.CROUCH)


func test_running_on_sand_for_10_s_moves_60_tiles_and_costs_5_energy() -> void:
	var r := _run(T.BEACH, 50.0, MoveIntent.create(EAST, true), 10.0)
	assert_almost_eq(_tiles(r).x, 60.0, 0.01)
	assert_almost_eq(r["energy"] as float, 45.0, 0.001)


func test_running_without_a_direction_costs_nothing() -> void:
	var r := _run(T.BEACH, 50.0, MoveIntent.create(Vector2.ZERO, true), 2.0)
	assert_almost_eq(r["energy"] as float, 50.0, 0.0001)
	assert_eq(_tiles(r), Vector2.ZERO)


func test_direction_longer_than_one_is_clamped() -> void:
	var intent := MoveIntent.new()
	intent.direction = Vector2(5.0, 0.0)
	assert_almost_eq(intent.direction.length(), 1.0, 0.0001)
	var r := _run(T.BEACH, 50.0, intent, 1.0)
	assert_almost_eq(_tiles(r).x, 4.0, 0.001)


func test_half_stick_walks_half_speed() -> void:
	var r := _run(T.BEACH, 50.0, MoveIntent.create(EAST * 0.5), 1.0)
	assert_almost_eq(_tiles(r).x, 2.0, 0.001)


func test_diagonal_is_not_faster_than_straight() -> void:
	var r := _run(T.BEACH, 50.0, MoveIntent.create(Vector2(1.0, 1.0)), 1.0)
	assert_almost_eq(_tiles(r).length(), 4.0, 0.001)


# --- stealth on brush --------------------------------------------------------------------

func test_crouching_in_scrub_is_hidden_at_2_tiles_per_second() -> void:
	var r := _run(T.SCRUB, 50.0, MoveIntent.create(EAST, false, true), 1.0)
	assert_almost_eq(_tiles(r).x, 2.0, 0.001)
	assert_eq(_last(r).stealth, MovementStep.Stealth.HIDDEN)


func test_crouching_in_mangrove_is_hidden() -> void:
	var r := _run(T.MANGROVE, 50.0, MoveIntent.create(EAST, false, true), 1.0)
	assert_eq(_last(r).stealth, MovementStep.Stealth.HIDDEN)


func test_standing_in_brush_is_visible() -> void:
	var r := _run(T.SCRUB, 50.0, MoveIntent.create(EAST), 1.0)
	assert_eq(_last(r).stealth, MovementStep.Stealth.VISIBLE)


func test_crouching_on_sand_is_visible() -> void:
	var r := _run(T.BEACH, 50.0, MoveIntent.create(EAST, false, true), 1.0)
	assert_eq(_last(r).stealth, MovementStep.Stealth.VISIBLE)


func test_crouching_still_in_brush_is_hidden() -> void:
	var r := _run(T.SCRUB, 50.0, MoveIntent.create(Vector2.ZERO, false, true), 1.0)
	assert_eq(_last(r).stealth, MovementStep.Stealth.HIDDEN)


# --- crawl at zero energy ----------------------------------------------------------------

func test_crawls_at_zero_energy_ignoring_run() -> void:
	var r := _run(T.BEACH, 0.0, MoveIntent.create(EAST, true), 4.0)
	assert_almost_eq(_tiles(r).x, 4.0, 0.01)
	assert_almost_eq(r["energy"] as float, 0.0, 0.0001)
	assert_eq(_last(r).movement, MovementStep.Move.CRAWL)


func test_crawl_speed_constant_is_one_tile_per_second() -> void:
	assert_eq(MovementModel.CRAWL_SPEED, 1.0)


# --- swimming ----------------------------------------------------------------------------

func test_swims_3_tiles_per_second_and_3_energy_per_second_in_every_water() -> void:
	for terrain: DataEnums.Terrain in [T.SHALLOWS, T.DEEP, T.BRACKISH]:
		model = MovementModel.new()
		var r := _run(terrain, 50.0, MoveIntent.create(EAST), 1.0)
		assert_almost_eq(_tiles(r).x, 3.0, 0.001, "tiles in %s" % terrain)
		assert_almost_eq(r["energy"] as float, 47.0, 0.001, "energy in %s" % terrain)
		assert_eq(_last(r).movement, MovementStep.Move.SWIM)


func test_run_is_ignored_while_swimming() -> void:
	var r := _run(T.DEEP, 50.0, MoveIntent.create(EAST, true), 1.0)
	assert_almost_eq(_tiles(r).x, 3.0, 0.001)


func test_treading_water_costs_nothing_without_a_direction() -> void:
	var r := _run(T.DEEP, 50.0, MoveIntent.create(Vector2.ZERO), 2.0)
	assert_almost_eq(r["energy"] as float, 50.0, 0.0001)


func test_exhausted_swimmer_floats_with_the_current() -> void:
	# Pushing west against a current of 1 tile/s east: no speed of their own, drift east.
	var r := _run(T.DEEP, 0.0, MoveIntent.create(Vector2.LEFT), 1.0)
	assert_almost_eq(_tiles(r).x, 1.0, 0.001)
	assert_almost_eq(r["energy"] as float, 0.0, 0.0001)
	assert_eq(_last(r).movement, MovementStep.Move.FLOAT)


func test_float_follows_any_current() -> void:
	var r := MovementSim.run(model, T.SHALLOWS, 0.0, MoveIntent.create(EAST), 2.0, Vector2(0.0, -2.0))
	assert_almost_eq(_tiles(r).y, -4.0, 0.001)
	assert_almost_eq(_tiles(r).x, 0.0, 0.001)


func test_swimmer_runs_out_of_energy_and_then_floats() -> void:
	# 3 energy = 1 s of swimming, then FLOAT.
	var r := _run(T.DEEP, 3.0, MoveIntent.create(EAST), 3.0)
	assert_eq(_last(r).movement, MovementStep.Move.FLOAT)
	assert_almost_eq(r["energy"] as float, 0.0, 0.0001)


func test_energy_spent_never_exceeds_energy_left() -> void:
	var step := model.step(T.DEEP, CURRENT, 0.01, MoveIntent.create(EAST), 1.0)
	assert_almost_eq(step.energy_spent, 0.01, 0.00001)


# --- diving ------------------------------------------------------------------------------

func test_dive_is_submerged_and_costs_10_energy_once() -> void:
	var r := _run(T.DEEP, 50.0, MoveIntent.create(Vector2.ZERO, false, true), 5.0)
	assert_eq(_last(r).movement, MovementStep.Move.DIVE)
	assert_eq(_last(r).stealth, MovementStep.Stealth.SUBMERGED)
	assert_almost_eq(r["energy"] as float, 40.0, 0.001, "10 once, not per second")


func test_dive_stealth_lasts_5_seconds_then_ends() -> void:
	var intent := MoveIntent.create(Vector2.ZERO, false, true)
	var last: MovementStep = null
	for i: int in 10:
		last = model.step(T.DEEP, CURRENT, 50.0, intent, 0.5)
	assert_eq(last.stealth, MovementStep.Stealth.SUBMERGED, "still hidden at exactly 5 s")
	last = model.step(T.DEEP, CURRENT, 50.0, intent, 0.5)
	assert_eq(last.stealth, MovementStep.Stealth.VISIBLE, "visible after 5 s")
	assert_ne(last.movement, MovementStep.Move.DIVE)
	assert_eq(last.energy_spent, 0.0, "holding crouch longer does not charge again")


func test_a_new_dive_needs_a_release_and_costs_again() -> void:
	var down := MoveIntent.create(Vector2.ZERO, false, true)
	var up := MoveIntent.create(Vector2.ZERO)
	var first := model.step(T.DEEP, CURRENT, 50.0, down, 0.1)
	assert_eq(first.energy_spent, 10.0)
	var surfaced := model.step(T.DEEP, CURRENT, 40.0, up, 0.1)
	assert_eq(surfaced.stealth, MovementStep.Stealth.VISIBLE)
	assert_eq(surfaced.energy_spent, 0.0)
	var second := model.step(T.DEEP, CURRENT, 40.0, down, 0.1)
	assert_eq(second.energy_spent, 10.0)
	assert_eq(second.stealth, MovementStep.Stealth.SUBMERGED)


func test_cannot_dive_with_less_than_10_energy() -> void:
	var step := model.step(T.DEEP, CURRENT, 9.0, MoveIntent.create(Vector2.ZERO, false, true), 0.1)
	assert_eq(step.stealth, MovementStep.Stealth.VISIBLE)
	assert_eq(step.energy_spent, 0.0)


func test_diving_swimmer_still_swims_at_3_tiles_per_second() -> void:
	var r := _run(T.DEEP, 50.0, MoveIntent.create(EAST, false, true), 1.0)
	assert_almost_eq(_tiles(r).x, 3.0, 0.001)
	assert_almost_eq(r["energy"] as float, 50.0 - 10.0 - 3.0, 0.001)


func test_crouching_on_land_is_not_a_dive() -> void:
	var step := model.step(T.BEACH, CURRENT, 50.0, MoveIntent.create(Vector2.ZERO, false, true), 0.1)
	assert_ne(step.movement, MovementStep.Move.DIVE)
	assert_eq(step.energy_spent, 0.0)


func test_dive_ends_when_the_swimmer_reaches_land() -> void:
	var down := MoveIntent.create(Vector2.ZERO, false, true)
	model.step(T.DEEP, CURRENT, 50.0, down, 0.1)
	model.step(T.BEACH, CURRENT, 40.0, down, 0.1)
	var again := model.step(T.DEEP, CURRENT, 40.0, down, 0.1)
	assert_eq(again.energy_spent, 10.0, "a fresh dive after touching land")


# --- intents -----------------------------------------------------------------------------

func test_same_intent_same_result_on_two_models() -> void:
	var intent := MoveIntent.create(EAST, true)
	var a := _run(T.BEACH, 50.0, intent, 2.0)
	var b := MovementSim.run(MovementModel.new(), T.BEACH, 50.0, intent, 2.0)
	assert_almost_eq(_tiles(a).x, 12.0, 0.01)
	assert_almost_eq(50.0 - (a["energy"] as float), 1.0, 0.001)
	assert_eq(a["tiles"], b["tiles"])
	assert_eq(a["energy"], b["energy"])


func test_intent_defaults_are_idle() -> void:
	var intent := MoveIntent.new()
	assert_eq(intent.direction, Vector2.ZERO)
	assert_false(intent.run)
	assert_false(intent.crouch)
	assert_false(intent.interact_held)


# --- dragged -----------------------------------------------------------------------------

func test_dragged_body_moves_2_tiles_per_second_toward_the_dragger() -> void:
	var step := model.drag_step(Vector2(10.0, 0.0), 1.0)
	assert_eq(step.velocity, Vector2(2.0, 0.0))
	assert_eq(step.movement, MovementStep.Move.DRAGGED)


func test_dragged_body_stops_next_to_the_dragger_without_overshooting() -> void:
	var step := model.drag_step(Vector2(0.6, 0.0), 1.0)
	assert_almost_eq(step.velocity.x, 0.6 - MovementModel.DRAG_STOP_DISTANCE, 0.0001)
	var close := model.drag_step(Vector2(0.2, 0.0), 1.0)
	assert_eq(close.velocity, Vector2.ZERO)


func test_energy_3_swimmer_floats_after_exactly_1_second() -> void:
	var r := _run(T.DEEP, 3.0, MoveIntent.create(EAST), 1.0)
	assert_almost_eq(r["energy"] as float, 0.0, 0.0000001)
	var next := model.step(T.DEEP, CURRENT, r["energy"] as float, MoveIntent.create(EAST), MovementSim.DT)
	assert_eq(next.movement, MovementStep.Move.FLOAT)
	assert_eq(next.velocity, CURRENT)


func test_cannot_dive_with_exactly_10_energy() -> void:
	var r := _run(T.DEEP, 10.0, MoveIntent.create(Vector2.ZERO, false, true), 1.0)
	assert_ne(_last(r).stealth, MovementStep.Stealth.SUBMERGED)
	assert_almost_eq(r["energy"] as float, 10.0, 0.0001, "a refused dive costs nothing")


func test_reset_ends_a_dive_in_progress() -> void:
	var crouch := MoveIntent.create(Vector2.ZERO, false, true)
	var r := _run(T.DEEP, 50.0, crouch, 1.0)
	assert_eq(_last(r).stealth, MovementStep.Stealth.SUBMERGED)
	model.reset()
	var again := model.step(T.DEEP, CURRENT, 40.0, crouch, MovementSim.DT)
	assert_almost_eq(again.energy_spent, MovementModel.DIVE_ENERGY_COST, 0.0001, "a fresh dive is paid for")
