extends GutTest
## guardacostas-stealth, group 3 (design.md decision 5): the spot meter fills 1 s per second while
## lit and not hidden, drains 0.5 s per second otherwise, never below 0, spots at the spot time
## plus the Stealth bonus (1 s a level, capped at 3) and goes back to 0 on a spot. Pure: whole
## seconds are stepped as 1/60 s ticks summed, as test_movement_model.gd does.

const TICK: float = 1.0 / 60.0
const TOLERANCE: float = 0.000001

var meter: SpotMeter


func before_each() -> void:
	meter = SpotMeter.from_patrol((GameState.content.get_entry(&"creatures", &"patrol_boat") as CreatureData).patrol)


# Steps `seconds` of 1/60 s ticks and returns the tick (1-based) at which the meter spotted, or 0.
func _run(seconds: float, lit: bool, hidden: bool = false, bonus: float = 0.0) -> int:
	var ticks: int = roundi(seconds * 60.0)
	for tick: int in ticks:
		if meter.step(lit, hidden, TICK, bonus):
			return tick + 1
	return 0


func test_it_reads_the_patrol_data() -> void:
	assert_almost_eq(meter.fill_per_s, 1.0, TOLERANCE)
	assert_almost_eq(meter.drain_per_s, 0.5, TOLERANCE)
	assert_almost_eq(meter.spot_time_s, 2.0, TOLERANCE)
	assert_eq(meter.value, 0.0)


func test_two_seconds_lit_spots_the_player_and_resets_the_meter() -> void:
	assert_eq(_run(1.95, true), 0)
	assert_eq(_run(0.2, true), 3, "spotted on the first tick at or past 2 s (117 + 3)")
	assert_eq(meter.value, 0.0, "reset on a spot")


func test_out_of_the_light_in_time() -> void:
	assert_eq(_run(1.5, true), 0)
	assert_almost_eq(meter.value, 1.5, 0.0001)
	assert_eq(_run(3.0, false), 0)
	assert_almost_eq(meter.value, 0.0, 0.0001, "1.5 s drains to 0 over 3 s")
	assert_eq(_run(2.0, false), 0)
	assert_eq(meter.value, 0.0, "never below 0")


func test_two_sweeps_catch_a_still_player() -> void:
	assert_eq(_run(1.5, true), 0)
	assert_eq(_run(1.0, false), 0)
	assert_almost_eq(meter.value, 1.0, 0.0001, "held 1 s when the cone came back")
	var spotted_at: int = _run(2.0, true)
	assert_between(spotted_at, 59, 61, "spotted 1 s later")


func test_stealth_level_2_is_spotted_at_4_s_and_not_at_3_5_s() -> void:
	var bonus: float = SpotMeter.stealth_bonus_s(2)
	assert_almost_eq(bonus, 2.0, TOLERANCE)
	assert_eq(_run(3.5, true, false, bonus), 0)
	assert_between(_run(1.0, true, false, bonus), 29, 31, "the 4 s mark is at tick 240, i.e. 30 ticks after 3.5 s")


func test_stealth_level_5_is_capped_at_5_s() -> void:
	assert_almost_eq(SpotMeter.stealth_bonus_s(5), 3.0, TOLERANCE)
	assert_eq(_run(4.9, true, false, SpotMeter.stealth_bonus_s(5)), 0)
	assert_between(_run(0.5, true, false, SpotMeter.stealth_bonus_s(5)), 1, 8, "spotted at 5 s")


func test_no_stealth_adds_nothing() -> void:
	assert_eq(SpotMeter.stealth_bonus_s(0), 0.0)
	assert_eq(SpotMeter.stealth_bonus_s(-3), 0.0)
	assert_eq(SpotMeter.stealth_level_of(null), 0, "the seam gives 0 until the Stealth skill exists")


func test_a_patrol_spot_time_modifier_adds_to_the_bonus() -> void:
	var modifier := ModifierData.new()
	modifier.stat = ModifierData.Stat.PATROL_SPOT_TIME
	modifier.op = ModifierData.Op.ADD
	modifier.value = 1.0
	var other := ModifierData.new()
	other.stat = ModifierData.Stat.HEAT_GAIN
	other.op = ModifierData.Op.ADD
	other.value = 9.0
	assert_almost_eq(SpotMeter.stealth_bonus_s(1, [modifier, other] as Array[ModifierData]), 2.0, TOLERANCE)


func test_a_hidden_player_never_fills() -> void:
	assert_eq(_run(10.0, true, true), 0)
	assert_eq(meter.value, 0.0)


func test_hiding_mid_fill_drains_the_meter() -> void:
	assert_eq(_run(1.0, true), 0)
	assert_eq(_run(1.0, true, true), 0)
	assert_almost_eq(meter.value, 0.5, 0.0001)


func test_the_meter_resets_after_a_spot_and_can_spot_again() -> void:
	assert_gt(_run(2.5, true), 0)
	assert_eq(meter.value, 0.0)
	assert_gt(_run(2.5, true), 0, "a still lit player is spotted again 2 s later")


func test_a_dead_or_dropped_player_is_cleared() -> void:
	assert_eq(_run(1.5, true), 0)
	meter.clear()
	assert_eq(meter.value, 0.0)
	assert_eq(meter.fraction(0.0), 0.0)


func test_the_fraction_is_the_meter_over_the_spot_time() -> void:
	assert_eq(_run(1.0, true), 0)
	assert_almost_eq(meter.fraction(0.0), 0.5, 0.0001)
	assert_almost_eq(meter.fraction(2.0), 0.25, 0.0001)
	assert_eq(_run(0.9, true), 0)
	assert_lte(meter.fraction(0.0), 1.0)


func test_a_zero_step_changes_nothing() -> void:
	assert_false(meter.step(true, false, 0.0))
	assert_eq(meter.value, 0.0)
