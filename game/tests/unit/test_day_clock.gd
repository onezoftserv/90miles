extends GutTest
## weather-daynight "Day cycle": a 720 s day (dawn 60, day 300, dusk 60, night 300), one hour
## per 30 s, the clock reads 06:00 at dawn, phase_changed on each transition.

const P := DataEnums.DayPhase

var clock: DayClock


func before_each() -> void:
	clock = DayClock.new()
	watch_signals(clock)


func _run(seconds: float, step: float) -> void:
	var left: float = seconds
	while left > 0.0001:
		var dt: float = minf(step, left)
		clock.advance(dt)
		left -= dt


func test_a_new_day_starts_at_dawn_at_0600() -> void:
	assert_eq(clock.time_of_day_s, 0.0)
	assert_eq(clock.hour(), 6)
	assert_eq(clock.minute(), 0)
	assert_eq(clock.phase(), P.DAWN)
	assert_eq(clock.day, 1)


func test_after_150_s_the_clock_reads_1100_in_the_day_phase() -> void:
	_run(150.0, 0.5)
	assert_eq(clock.hour(), 11)
	assert_eq(clock.minute(), 0)
	assert_eq(clock.phase(), P.DAY)


func test_after_360_s_the_phase_is_dusk_and_phase_changed_fired() -> void:
	_run(360.0, 1.0 / 60.0)
	assert_eq(clock.phase(), P.DUSK)
	assert_signal_emit_count(clock, "phase_changed", 2)
	assert_signal_emitted_with_parameters(clock, "phase_changed", [P.DUSK])


func test_one_big_step_emits_every_crossed_phase_in_order() -> void:
	clock.advance(360.0)
	assert_signal_emit_count(clock, "phase_changed", 2)
	assert_eq(get_signal_parameters(clock, "phase_changed", 0), [P.DAY])
	assert_eq(get_signal_parameters(clock, "phase_changed", 1), [P.DUSK])


func test_phase_boundaries() -> void:
	assert_eq(DayClock.phase_at(59.9), P.DAWN)
	assert_eq(DayClock.phase_at(60.0), P.DAY)
	assert_eq(DayClock.phase_at(359.9), P.DAY)
	assert_eq(DayClock.phase_at(360.0), P.DUSK)
	assert_eq(DayClock.phase_at(419.9), P.DUSK)
	assert_eq(DayClock.phase_at(420.0), P.NIGHT)
	assert_eq(DayClock.phase_at(719.9), P.NIGHT)
	clock.set_time(719.9, 1)
	assert_eq(clock.hour(), 5)
	assert_eq(clock.minute(), 59)


func test_midday_is_1000_to_1600() -> void:
	clock.set_time(119.9, 1)
	assert_false(clock.is_midday())
	clock.set_time(120.0, 1)
	assert_true(clock.is_midday())
	assert_eq(clock.hour(), 10)
	clock.set_time(299.9, 1)
	assert_true(clock.is_midday())
	clock.set_time(300.0, 1)
	assert_false(clock.is_midday())
	assert_eq(clock.hour(), 16)


func test_a_full_day_wraps_to_dawn_of_day_2() -> void:
	_run(720.0, 0.5)
	assert_signal_emit_count(clock, "phase_changed", 4)
	var order: Array = []
	for i: int in 4:
		order.append(get_signal_parameters(clock, "phase_changed", i)[0])
	assert_eq(order, [P.DAY, P.DUSK, P.NIGHT, P.DAWN])
	assert_signal_emit_count(clock, "day_started", 1)
	assert_signal_emitted_with_parameters(clock, "day_started", [2])
	assert_almost_eq(clock.time_of_day_s, 0.0, 0.001)
	assert_eq(clock.hour(), 6)
	assert_eq(clock.day, 2)


func test_set_time_ignores_nan_and_wraps() -> void:
	clock.set_time(100.0, 1)
	clock.set_time(NAN, 5)
	assert_eq(clock.time_of_day_s, 100.0)
	assert_eq(clock.day, 1)
	clock.set_time(730.0, 1)
	assert_almost_eq(clock.time_of_day_s, 10.0, 0.001)
