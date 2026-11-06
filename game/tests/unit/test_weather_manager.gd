extends GutTest
## weather-daynight: the WeatherManager autoload owns the clock, idle until a level starts it;
## in solo (1 player, offline) the pause freezes it.

const SESSION_SCENE: PackedScene = preload("res://scenes/net/coop_session.tscn")


func before_each() -> void:
	NetManager.start_solo()


func after_each() -> void:
	get_tree().paused = false
	WeatherManager.stop()


func _frames(count: int) -> void:
	for i: int in count:
		await get_tree().process_frame


func test_the_manager_is_idle_until_started() -> void:
	var before: float = WeatherManager.time_of_day_s()
	await _frames(10)
	assert_eq(WeatherManager.time_of_day_s(), before)


func test_started_it_advances_with_frames() -> void:
	WeatherManager.start(0.0)
	await _frames(10)
	assert_gt(WeatherManager.time_of_day_s(), 0.0)


func test_solo_pause_freezes_the_clock() -> void:
	var session := SESSION_SCENE.instantiate() as CoopSession
	add_child_autofree(session)
	session.start()
	WeatherManager.start(100.0)
	await _frames(5)
	assert_true(session.set_paused(true))
	await _frames(2)
	var frozen: float = WeatherManager.time_of_day_s()
	await _frames(30)
	assert_eq(WeatherManager.time_of_day_s(), frozen)
	session.set_paused(false)
	await _frames(10)
	assert_gt(WeatherManager.time_of_day_s(), frozen)


func test_the_manager_reads_match_the_clock() -> void:
	WeatherManager.start(120.0)
	assert_eq(WeatherManager.hour(), 10)
	assert_true(WeatherManager.is_midday())
	assert_eq(WeatherManager.phase(), DataEnums.DayPhase.DAY)
	assert_eq(WeatherManager.weather_id(), &"calm")


func test_phase_changed_is_forwarded() -> void:
	watch_signals(WeatherManager)
	WeatherManager.start(59.0)
	WeatherManager.sky.advance(2.0)
	assert_signal_emitted_with_parameters(WeatherManager, "phase_changed", [DataEnums.DayPhase.DAY])
