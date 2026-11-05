extends GutTest
## survival-meters "Solo play": one player can hold every meter up alone. A lit fire keeps a lone
## player company at night, and the sandbar's coconuts carry one player through 3 days.

const M := DataEnums.Meter
const P := DataEnums.DayPhase
const STEP: float = 0.25
const COCONUT_THIRST: float = 15.0
const COCONUT_HUNGER: float = 5.0
const DRINK_BELOW: float = 15.0

var meters: SurvivalMeters
var coconuts_left: int = 10
var lowest: Dictionary[DataEnums.Meter, float] = {}
var hallucinated: bool = false


func before_each() -> void:
	meters = SurvivalMeters.new()
	meters.solo = true
	add_child_autofree(meters)
	coconuts_left = 10
	lowest = {M.THIRST: 100.0, M.HUNGER: 100.0, M.MORALE: 100.0}
	hallucinated = false


func _context(phase: DataEnums.DayPhase, shaded: bool = false, near_fire: bool = false) -> MeterContext:
	var context := MeterContext.new()
	context.phase = phase
	context.shaded = shaded
	context.near_fire = near_fire
	return context


## Steps `seconds`, drinking a coconut whenever thirst drops below DRINK_BELOW, and records lows.
func _live(seconds: float, context: MeterContext) -> void:
	for i: int in roundi(seconds / STEP):
		meters.tick(STEP, context)
		if meters.thirst < DRINK_BELOW and coconuts_left > 0:
			coconuts_left -= 1
			meters.add(M.THIRST, COCONUT_THIRST)
			meters.eat(COCONUT_HUNGER)
		for meter: DataEnums.Meter in lowest:
			lowest[meter] = minf(lowest[meter], meters.value(meter))
		hallucinated = hallucinated or meters.hallucinating


## One 12-minute day from dawn: half the day phase in the sun, a fire lit at dusk, the night by it.
func _live_one_day() -> void:
	_live(60.0, _context(P.DAWN))
	_live(150.0, _context(P.DAY))
	_live(150.0, _context(P.DAY, true))
	meters.morale_event(SurvivalMeters.MoraleEvent.FIRE_LIT)
	_live(60.0, _context(P.DUSK, false, true))
	_live(300.0, _context(P.NIGHT, false, true))


func test_a_fire_keeps_a_lone_player_company_at_night() -> void:
	meters.morale = 50.0
	_live(60.0, _context(P.NIGHT, false, true))
	assert_eq(meters.morale, 50.0)


func test_without_a_fire_a_lone_player_still_loses_5_per_minute() -> void:
	meters.morale = 50.0
	_live(60.0, _context(P.NIGHT))
	assert_almost_eq(meters.morale, 45.0, 0.01)


func test_a_night_alone_by_the_fire_never_hallucinates() -> void:
	meters.morale = 40.0
	meters.morale_event(SurvivalMeters.MoraleEvent.FIRE_LIT)
	_live(300.0, _context(P.NIGHT, false, true))
	assert_eq(meters.morale, 45.0, "at dawn")
	assert_false(hallucinated)


func test_three_solo_days_on_the_sandbar_on_coconuts() -> void:
	for day: int in 3:
		_live_one_day()
	assert_gt(lowest[M.THIRST], 0.0, "thirst never runs out")
	assert_gt(lowest[M.HUNGER], 0.0, "hunger never runs out")
	assert_gte(coconuts_left, 0, "at most the sandbar's 10 coconuts")
	assert_eq(coconuts_left, 1, "9 coconuts at the provisional rates")
	assert_gte(lowest[M.MORALE], 20.0)
	assert_false(hallucinated)
	assert_false(meters.dead)


func test_a_solo_week_with_a_fire_each_night_and_a_squall_each_day_keeps_morale() -> void:
	for day: int in 7:
		meters.morale_event(SurvivalMeters.MoraleEvent.SQUALL)
		meters.morale_event(SurvivalMeters.MoraleEvent.FIRE_LIT)
		_live(300.0, _context(P.NIGHT, false, true))
	assert_eq(meters.morale, 65.0)
	assert_false(hallucinated)
