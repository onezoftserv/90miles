extends GutTest
## survival-meters "Bleeding drains health" and "Bleeding stops on its own" (bleeding-and-sabila
## design D1-D3), on plain meters with the shipped tuning: 0.1 health per second, never below 1,
## ending 120 s after the latest wound. The time left is the host's; only the bit is synced.

const BLEEDING := DataEnums.Status.BLEEDING
const POISON := DataEnums.Status.POISON
## Half-second steps: exact in binary, so the 120 s edge lands on a step.
const STEP_S: float = 0.5


func _meters() -> SurvivalMeters:
	var meters := SurvivalMeters.new()
	autofree(meters)
	return meters


# Ticks `meters` for `seconds` at rest out of the sun (thirst stays well above 0).
func _run(meters: SurvivalMeters, seconds: float) -> void:
	var context := MeterContext.new()
	var left: float = seconds
	while left > 0.000001:
		var delta: float = minf(STEP_S, left)
		meters.tick(delta, context)
		left -= delta


func test_solo_bleeding_drains_a_tenth_of_a_point_per_second() -> void:
	var meters := _meters()
	meters.solo = true
	meters.set_status(BLEEDING, true)
	_run(meters, 30.0)
	assert_almost_eq(meters.health, 97.0, 0.001)
	assert_true(meters.has_status(BLEEDING))


func test_bleeding_never_takes_the_last_point() -> void:
	var meters := _meters()
	meters.solo = true
	meters.health = 2.0
	meters.set_status(BLEEDING, true)
	_run(meters, 60.0)
	assert_eq(meters.health, 1.0)
	assert_false(meters.last_stand)
	assert_false(meters.downed)
	assert_false(meters.dead)
	assert_eq(meters.death_cause, &"", "bleeding names no cause")


func test_bleeding_ends_120_s_after_the_wound() -> void:
	var meters := _meters()
	meters.set_status(BLEEDING, true)
	assert_eq(meters.status_time_left(BLEEDING), 120.0)
	_run(meters, 119.5)
	assert_true(meters.has_status(BLEEDING), "still bleeding at 119.5 s")
	_run(meters, 0.5)
	assert_false(meters.has_status(BLEEDING), "over at 120 s")
	assert_almost_eq(meters.health, 88.0, 0.001, "120 s took 12")
	assert_eq(meters.status_time_left(BLEEDING), 0.0)
	_run(meters, 30.0)
	assert_almost_eq(meters.health, 88.0, 0.001, "and health stops falling")


func test_a_second_wound_restarts_the_time_and_does_not_stack() -> void:
	var meters := _meters()
	meters.set_status(BLEEDING, true)
	_run(meters, 100.0)
	meters.set_status(BLEEDING, true)
	assert_eq(meters.status_time_left(BLEEDING), 120.0, "the count starts again")
	_run(meters, 119.0)
	assert_true(meters.has_status(BLEEDING))
	assert_almost_eq(meters.health, 100.0 - 21.9, 0.001, "one drain, not two")
	_run(meters, 2.0)
	assert_false(meters.has_status(BLEEDING))


func test_a_cure_stops_the_drain_and_the_count() -> void:
	var meters := _meters()
	meters.set_status(BLEEDING, true)
	_run(meters, 10.0)
	meters.set_status(BLEEDING, false)
	assert_eq(meters.status_time_left(BLEEDING), 0.0)
	_run(meters, 10.0)
	assert_almost_eq(meters.health, 99.0, 0.001)
	meters.set_status(BLEEDING, true)
	assert_eq(meters.status_time_left(BLEEDING), 120.0, "a new wound after a cure gets the full time")


func test_a_downed_bleeder_loses_nothing() -> void:
	var meters := _meters()
	meters.harm(100.0, &"reef_shark")
	assert_true(meters.downed)
	meters.set_status(BLEEDING, true)
	_run(meters, 10.0)
	assert_eq(meters.health, 0.0)
	assert_true(meters.downed, "still waiting for a revive")


func test_a_revive_keeps_the_bleeding_and_its_time() -> void:
	var meters := _meters()
	meters.harm(100.0, &"reef_shark")
	meters.set_status(BLEEDING, true)
	_run(meters, 20.0)
	assert_true(meters.revive())
	assert_true(meters.has_status(BLEEDING))
	assert_eq(meters.status_time_left(BLEEDING), 100.0)
	_run(meters, 10.0)
	assert_almost_eq(meters.health, 29.0, 0.001)


func test_statuses_changed_fires_once_when_the_time_runs_out() -> void:
	var meters := _meters()
	meters.set_status(BLEEDING, true)
	watch_signals(meters)
	_run(meters, 125.0)
	assert_signal_emit_count(meters, "statuses_changed", 1)
	assert_signal_emitted_with_parameters(meters, "statuses_changed", [0])


func test_other_statuses_have_no_time_and_no_drain() -> void:
	var meters := _meters()
	meters.set_status(POISON, true)
	assert_eq(meters.status_time_left(POISON), 0.0)
	_run(meters, 200.0)
	assert_true(meters.has_status(POISON), "lasts until cured, as before")
	assert_eq(meters.health, 100.0)


func test_with_thirst_empty_the_death_is_thirsts() -> void:
	var meters := _meters()
	meters.solo = true
	meters.thirst = 0.0
	meters.health = 3.0
	meters.set_status(BLEEDING, true)
	_run(meters, 5.0)
	assert_true(meters.last_stand, "island-pressure: a 12 s last stand first")
	_run(meters, 12.0)
	assert_true(meters.dead)
	assert_eq(meters.death_cause, DeathCause.THIRST)


func test_a_synced_bit_starts_no_time() -> void:
	var meters := _meters()
	meters.status_flags = 1 << BLEEDING
	assert_true(meters.has_status(BLEEDING))
	assert_eq(meters.status_time_left(BLEEDING), 0.0, "a client reads the bit, never the time")
