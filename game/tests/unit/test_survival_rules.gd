extends GutTest
## survival-meters: thirst, hunger, heat, energy and morale scenarios, stepped by hand through
## SurvivalMeters.tick with a MeterContext. Numbers come from the shipped tuning (provisional).

const M := DataEnums.Meter
const P := DataEnums.DayPhase
const STEP: float = 0.25
const TOLERANCE: float = 0.01

var meters: SurvivalMeters


func before_each() -> void:
	meters = SurvivalMeters.new()
	add_child_autofree(meters)


func _run(seconds: float, context: MeterContext) -> void:
	for i: int in roundi(seconds / STEP):
		meters.tick(STEP, context)


func _context(phase: DataEnums.DayPhase, shaded: bool = false) -> MeterContext:
	var context := MeterContext.new()
	context.phase = phase
	context.shaded = shaded
	return context


func _midday_sun() -> MeterContext:
	var context := _context(P.DAY)
	context.midday = true
	return context


func _swimming(phase: DataEnums.DayPhase) -> MeterContext:
	var context := _context(phase)
	context.in_water = true
	context.swimming = true
	return context


# --- Thirst ---------------------------------------------------------------------------------

func test_working_in_the_sun_drains_12_thirst_per_minute() -> void:
	meters.thirst = 80.0
	_run(60.0, _context(P.DAY))
	assert_almost_eq(meters.thirst, 68.0, TOLERANCE)


func test_swimming_in_the_midday_sun_is_x3_not_x6() -> void:
	meters.thirst = 80.0
	var context := _swimming(P.DAY)
	context.midday = true
	_run(60.0, context)
	assert_almost_eq(meters.thirst, 62.0, TOLERANCE)


func test_swimming_at_night_is_x3_times_x0_5() -> void:
	meters.thirst = 80.0
	_run(60.0, _swimming(P.NIGHT))
	assert_almost_eq(meters.thirst, 71.0, TOLERANCE)


func test_shade_or_dusk_drains_the_base_6_per_minute() -> void:
	meters.thirst = 80.0
	_run(60.0, _context(P.DAY, true))
	assert_almost_eq(meters.thirst, 74.0, TOLERANCE, "shade in the day phase")
	_run(60.0, _context(P.DUSK))
	assert_almost_eq(meters.thirst, 68.0, TOLERANCE, "no direct sun at dusk")


func test_a_day_in_the_shade_costs_57_thirst() -> void:
	_run(60.0, _context(P.DAWN, true))
	_run(300.0, _context(P.DAY, true))
	_run(60.0, _context(P.DUSK, true))
	_run(300.0, _context(P.NIGHT, true))
	assert_almost_eq(meters.thirst, 43.0, TOLERANCE)


func test_empty_thirst_drains_2_health_per_second() -> void:
	meters.thirst = 0.0
	_run(10.0, _context(P.DAWN))
	assert_almost_eq(meters.health, 80.0, TOLERANCE)


func test_seawater_gives_10_then_takes_30_over_120_s() -> void:
	var night_shade := _context(P.NIGHT, true)
	meters.thirst = 50.0
	meters.add(M.THIRST, 10.0)
	meters.add_over_time(M.THIRST, -30.0, 120.0)
	assert_almost_eq(meters.thirst, 60.0, TOLERANCE, "immediately")
	_run(60.0, night_shade)
	assert_almost_eq(meters.thirst, 42.0, TOLERANCE, "half the seawater and 3 of night drain")
	_run(60.0, night_shade)
	assert_almost_eq(meters.thirst, 24.0, TOLERANCE, "after 120 s")
	_run(60.0, night_shade)
	assert_almost_eq(meters.thirst, 21.0, TOLERANCE, "the timed change is over")


# --- Hunger ---------------------------------------------------------------------------------

func test_hunger_drains_3_per_minute_at_rest() -> void:
	meters.hunger = 50.0
	_run(60.0, _context(P.DAY))
	assert_almost_eq(meters.hunger, 47.0, TOLERANCE)


func test_crafting_doubles_hunger() -> void:
	meters.hunger = 50.0
	var context := _context(P.DAY)
	context.crafting = true
	_run(60.0, context)
	assert_almost_eq(meters.hunger, 44.0, TOLERANCE)


func test_swimming_doubles_hunger() -> void:
	meters.hunger = 50.0
	_run(60.0, _swimming(P.DAY))
	assert_almost_eq(meters.hunger, 44.0, TOLERANCE)


func test_starving_caps_energy_at_50() -> void:
	meters.energy = 80.0
	meters.hunger = 0.5
	_run(10.0, _context(P.DAWN))
	assert_eq(meters.hunger, 0.0, "float crumbs snap to empty")
	assert_eq(meters.energy, 50.0)
	meters.gain_energy(20.0)
	assert_eq(meters.energy, 50.0, "cannot rise past the cap")


func test_eating_lifts_the_starving_cap() -> void:
	meters.hunger = 0.0
	meters.energy = 50.0
	meters.tick(0.0, _context(P.DAWN))
	meters.eat(20.0)
	assert_eq(meters.hunger, 20.0)
	assert_eq(meters.energy, 60.0, "the meal's 10 energy goes past 50 once hunger is back")


# --- Heat -----------------------------------------------------------------------------------

func test_midday_sun_raises_heat_to_90_in_120_s() -> void:
	_run(120.0, _midday_sun())
	assert_almost_eq(meters.heat, 90.0, TOLERANCE)
	assert_false(meters.sunstroke)


func test_scorching_calm_brings_sunstroke_in_70_s() -> void:
	var context := _midday_sun()
	context.heat_factor = 2.0
	_run(70.0, context)
	assert_eq(meters.heat, 100.0)
	assert_true(meters.sunstroke)


func test_sunstroke_lingers_until_heat_drops_below_60() -> void:
	meters.heat = 100.0
	meters.tick(0.0, _midday_sun())
	assert_true(meters.sunstroke, "starts at 100")
	assert_almost_eq(meters.speed_factor(), 0.6, 1e-6)
	var shade := _midday_sun()
	shade.shaded = true
	_run(40.0, shade)
	assert_almost_eq(meters.heat, 70.0, TOLERANCE)
	assert_true(meters.sunstroke, "still on at 70")
	_run(13.0, shade)
	assert_true(meters.sunstroke, "still on at 60.25")
	_run(1.0, shade)
	assert_false(meters.sunstroke, "off below 60")
	assert_eq(meters.speed_factor(), 1.0)


func test_night_resets_heat() -> void:
	meters.heat = 50.0
	meters.tick(STEP, _context(P.NIGHT))
	assert_eq(meters.heat, 0.0)


func test_heat_falls_in_the_sun_outside_the_midday_window() -> void:
	meters.heat = 50.0
	_run(20.0, _context(P.DAY))
	assert_almost_eq(meters.heat, 35.0, TOLERANCE)


func test_heat_falls_in_water_at_midday() -> void:
	meters.heat = 50.0
	var context := _swimming(P.DAY)
	context.midday = true
	_run(20.0, context)
	assert_almost_eq(meters.heat, 35.0, TOLERANCE)


# --- Energy ---------------------------------------------------------------------------------

func test_a_meal_gives_10_energy() -> void:
	meters.energy = 40.0
	meters.hunger = 50.0
	meters.eat(20.0)
	assert_eq(meters.hunger, 70.0)
	assert_eq(meters.energy, 50.0)


func test_eating_nothing_is_not_a_meal() -> void:
	meters.energy = 40.0
	meters.eat(0.0)
	assert_eq(meters.energy, 40.0)


func test_a_nights_sleep_gives_50_energy() -> void:
	meters.energy = 20.0
	meters.sleep_night()
	assert_eq(meters.energy, 70.0)


func test_energy_does_not_regenerate_at_rest() -> void:
	meters.energy = 40.0
	_run(60.0, _context(P.DAY, true))
	assert_eq(meters.energy, 40.0)


# --- Morale ---------------------------------------------------------------------------------

func test_an_allys_death_costs_30_and_starts_hallucinations() -> void:
	meters.morale = 45.0
	meters.morale_event(SurvivalMeters.MoraleEvent.ALLY_DIED)
	assert_eq(meters.morale, 15.0)
	assert_true(meters.hallucinating)


func test_alone_at_night_costs_5_per_minute() -> void:
	meters.morale = 50.0
	_run(60.0, _context(P.NIGHT))
	assert_almost_eq(meters.morale, 45.0, TOLERANCE)


func test_alone_in_the_day_costs_nothing() -> void:
	meters.morale = 50.0
	_run(60.0, _context(P.DAY))
	assert_eq(meters.morale, 50.0)


func test_company_restores_2_per_minute_day_or_night() -> void:
	meters.morale = 50.0
	var day := _context(P.DAY)
	day.teammate_nearby = true
	_run(60.0, day)
	assert_almost_eq(meters.morale, 52.0, TOLERANCE, "day")
	var night := _context(P.NIGHT)
	night.teammate_nearby = true
	_run(60.0, night)
	assert_almost_eq(meters.morale, 54.0, TOLERANCE, "night, not alone")


func test_a_fire_ends_the_hallucinations() -> void:
	meters.morale = 45.0
	meters.morale_event(SurvivalMeters.MoraleEvent.ALLY_DIED)
	meters.morale_event(SurvivalMeters.MoraleEvent.FIRE_LIT)
	assert_eq(meters.morale, 20.0)
	assert_false(meters.hallucinating)


func test_squall_song_and_found_text_amounts() -> void:
	meters.morale = 50.0
	meters.morale_event(SurvivalMeters.MoraleEvent.SQUALL)
	assert_eq(meters.morale, 40.0, "squall")
	meters.morale_event(SurvivalMeters.MoraleEvent.SONG)
	assert_eq(meters.morale, 55.0, "song")
	meters.morale_event(SurvivalMeters.MoraleEvent.TEXT_READ)
	assert_eq(meters.morale, 65.0, "found text")


func test_hallucinating_emits_its_signal() -> void:
	watch_signals(meters)
	meters.morale = 25.0
	meters.add(M.MORALE, -10.0)
	assert_signal_emitted_with_parameters(meters, "hallucinating_changed", [true])
