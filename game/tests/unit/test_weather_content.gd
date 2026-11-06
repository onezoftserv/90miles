extends GutTest
## weather-daynight "Calm and squall data": the weather files validate and carry the numbers
## from GAME_DESIGN §5; the day-cycle tuning has a tint per phase.

const DAY_CYCLE_PATH: String = "res://resources/day_cycle.tres"


func _weather(id: StringName) -> WeatherData:
	return GameState.content.get_entry(&"weather", id) as WeatherData


func test_weather_files_validate() -> void:
	for line: String in ContentValidator.validate(GameState.content):
		assert_false(line.begins_with("weather/"), line)
	assert_not_null(_weather(&"calm"))
	assert_not_null(_weather(&"squall"))


func test_squall_numbers() -> void:
	var squall := _weather(&"squall")
	assert_eq(squall.duration_s, 120.0)
	assert_eq(squall.warning_lead_s, 60.0)
	assert_eq(squall.tell, WeatherData.Tell.HORIZON_LINE)
	assert_eq(squall.followed_by_weather_id, &"calm")
	assert_true(squall.is_storm)


func test_calm_is_scorching() -> void:
	var calm := _weather(&"calm")
	assert_eq(calm.heat_gain_mult, 2.0)
	assert_true(calm.is_clear)
	assert_eq(calm.tell, WeatherData.Tell.WHITE_SKY)


func test_day_cycle_has_a_tint_per_phase() -> void:
	var tuning := load(DAY_CYCLE_PATH) as DayCycleTuning
	assert_not_null(tuning)
	assert_eq(tuning.phase_tints.size(), 4)
	assert_gt(tuning.blend_s, 0.0)
	assert_gt(tuning.resync_s, 0.0)
