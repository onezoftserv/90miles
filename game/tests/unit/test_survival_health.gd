extends GutTest
## survival-meters "Health and downed state": poison, the 90 s downed timer, solo death and
## revive. A cup's revive is item data (crafting-inventory); here it is revive() plus the cup's
## +25 thirst.

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


func _go_down() -> void:
	meters.add(M.HEALTH, -meters.health)


func test_poison_takes_20_health_over_30_s() -> void:
	meters.add_over_time(M.HEALTH, -20.0, 30.0)
	_run(15.0)
	assert_almost_eq(meters.health, 90.0, 0.01)
	_run(15.0)
	assert_almost_eq(meters.health, 80.0, 0.01)
	_run(15.0)
	assert_almost_eq(meters.health, 80.0, 0.01, "poison is over")


func test_co_op_player_at_0_health_is_downed_for_90_s() -> void:
	watch_signals(meters)
	_go_down()
	assert_true(meters.downed)
	assert_false(meters.dead)
	assert_eq(meters.downed_time_left_s, 90.0)
	assert_signal_emitted_with_parameters(meters, "downed_changed", [true])


func test_nobody_comes_and_the_player_dies_after_90_s() -> void:
	watch_signals(meters)
	_go_down()
	_run(89.0)
	assert_false(meters.dead, "1 s left")
	_run(1.0)
	assert_true(meters.dead)
	assert_signal_emitted(meters, "died")


func test_solo_player_dies_at_once() -> void:
	meters.solo = true
	watch_signals(meters)
	_go_down()
	assert_true(meters.dead)
	assert_false(meters.downed, "no downed timer")
	assert_signal_emitted(meters, "died")
	assert_signal_not_emitted(meters, "downed_changed")


func test_empty_thirst_eventually_downs_the_player() -> void:
	meters.thirst = 0.0
	meters.health = 10.0
	_run(5.0)
	assert_eq(meters.health, 0.0)
	assert_true(meters.downed)


func test_revive_with_a_rain_cup_stands_up_at_30_health_and_plus_25_thirst() -> void:
	meters.thirst = 30.0
	_go_down()
	_run(50.0)
	assert_eq(meters.downed_time_left_s, 40.0)
	var thirst_before: float = meters.thirst
	watch_signals(meters)
	assert_true(meters.revive())
	meters.add(M.THIRST, 25.0)
	assert_false(meters.downed)
	assert_eq(meters.health, 30.0)
	assert_almost_eq(meters.thirst, thirst_before + 25.0, 0.001)
	assert_signal_emitted_with_parameters(meters, "downed_changed", [false])


func test_revive_is_refused_when_not_downed() -> void:
	meters.health = 70.0
	assert_false(meters.revive())
	assert_eq(meters.health, 70.0)


func test_revive_is_refused_once_dead() -> void:
	meters.solo = true
	_go_down()
	assert_false(meters.revive())
	assert_eq(meters.health, 0.0)


func test_thirst_and_hunger_keep_draining_while_downed() -> void:
	_go_down()
	_run(60.0)
	assert_almost_eq(meters.thirst, 94.0, 0.01)
	assert_almost_eq(meters.hunger, 97.0, 0.01)


func test_going_down_again_restarts_the_timer() -> void:
	_go_down()
	_run(80.0)
	meters.revive()
	_go_down()
	assert_eq(meters.downed_time_left_s, 90.0)


func test_dead_meters_stop_changing() -> void:
	meters.solo = true
	_go_down()
	_run(60.0)
	meters.add(M.THIRST, -50.0)
	meters.eat(20.0)
	assert_eq(meters.thirst, 100.0)
	assert_eq(meters.hunger, 100.0)
