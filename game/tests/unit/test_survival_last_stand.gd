extends GutTest
## survival-meters "Solo last stand" and "Free revive" (user decisions, 2026-11-05; island-pressure,
## 2026-11-23): a solo player at 0 health gets 12 s on land plus their downed-timer bonuses, and the
## bonuses alone at sea; the Medalla's free revive stands its holder
## at 30 once per run, solo or not. Bonus values come from endings-progression; tests set them.

const M := DataEnums.Meter
const STEP: float = 0.25

var meters: SurvivalMeters
var rest: MeterContext


func before_each() -> void:
	meters = SurvivalMeters.new()
	add_child_autofree(meters)
	rest = MeterContext.new()


func _run(seconds: float) -> void:
	for i: int in roundi(seconds / STEP):
		meters.tick(STEP, rest)


func _hit_zero() -> void:
	meters.add(M.HEALTH, -meters.health)


func test_solo_on_run_1_with_no_bonus_gets_12_s_on_land() -> void:
	meters.solo = true
	meters.downed_bonus_s = 0.0
	_hit_zero()
	assert_true(meters.last_stand)
	assert_false(meters.downed)
	assert_eq(meters.downed_time_left_s, 12.0)
	_run(11.75)
	assert_false(meters.dead)
	_run(0.25)
	assert_true(meters.dead)


func test_solo_on_run_1_at_sea_dies_at_once() -> void:
	meters.solo = true
	var sea := MeterContext.new()
	sea.at_sea = true
	meters.tick(0.0, sea)
	_hit_zero()
	assert_true(meters.dead)
	assert_false(meters.last_stand)
	assert_false(meters.downed)


func test_last_stand_lasts_the_experiencia_bonus() -> void:
	meters.solo = true
	meters.downed_bonus_s = 15.0
	watch_signals(meters)
	_hit_zero()
	assert_true(meters.last_stand)
	assert_false(meters.downed, "a last stand is not downed")
	assert_false(meters.dead)
	assert_eq(meters.downed_time_left_s, 27.0, "12 s on land and the 15 s bonus")
	assert_signal_emitted_with_parameters(meters, "last_stand_changed", [true])
	_run(26.0)
	assert_false(meters.dead, "1 s left")
	_run(1.0)
	assert_true(meters.dead)


func test_the_10_s_point_boost_adds_10_s_to_the_last_stand() -> void:
	meters.solo = true
	meters.downed_bonus_s = 10.0
	_hit_zero()
	_run(21.75)
	assert_false(meters.dead, "12 s on land and the 10 s boost")
	_run(0.25)
	assert_true(meters.dead)


func test_saving_yourself_with_a_rain_cup_in_the_last_stand() -> void:
	meters.solo = true
	meters.downed_bonus_s = 10.0
	meters.thirst = 30.0
	_hit_zero()
	_run(5.0)
	var thirst_before: float = meters.thirst
	watch_signals(meters)
	assert_true(meters.revive())
	meters.add(M.THIRST, 25.0)
	assert_false(meters.last_stand)
	assert_eq(meters.health, 30.0)
	assert_almost_eq(meters.thirst, thirst_before + 25.0, 0.001)
	assert_signal_emitted_with_parameters(meters, "last_stand_changed", [false])


func test_the_last_stand_keeps_draining_thirst() -> void:
	meters.solo = true
	meters.downed_bonus_s = 20.0
	_hit_zero()
	_run(10.0)
	assert_almost_eq(meters.thirst, 99.0, 0.01)


func test_downed_timer_bonus_lengthens_the_co_op_downed_timer() -> void:
	meters.solo = false
	meters.downed_bonus_s = 10.0
	_hit_zero()
	assert_true(meters.downed)
	assert_false(meters.last_stand)
	assert_eq(meters.downed_time_left_s, 100.0)


func test_the_medalla_saves_a_solo_player_once() -> void:
	meters.solo = true
	meters.free_revives = 1
	watch_signals(meters)
	_hit_zero()
	assert_false(meters.dead)
	assert_false(meters.last_stand)
	assert_eq(meters.health, 30.0)
	assert_eq(meters.free_revives, 0, "the revive is used up")
	assert_signal_emitted(meters, "free_revive_used")
	_hit_zero()
	assert_true(meters.last_stand, "the second time, a 12 s last stand")
	assert_eq(meters.downed_time_left_s, 12.0)


func test_the_medalla_comes_before_the_last_stand() -> void:
	meters.solo = true
	meters.downed_bonus_s = 15.0
	meters.free_revives = 1
	_hit_zero()
	assert_eq(meters.health, 30.0)
	assert_false(meters.last_stand)


func test_the_medalla_in_co_op_stands_the_holder_up_instead_of_going_down() -> void:
	meters.solo = false
	meters.free_revives = 1
	_hit_zero()
	assert_false(meters.downed)
	assert_eq(meters.health, 30.0)
	assert_eq(meters.free_revives, 0)
