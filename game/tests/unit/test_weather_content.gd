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


## art-mood-pass D4, D5: calm runs the sea and the foam at their own pace, and every weather that is
## not clear names itself in 9 glyphs or fewer, so its name fits the HUD's weather window.
func test_calm_keeps_the_sea_at_pace_one() -> void:
	var calm := _weather(&"calm")
	assert_eq(calm.sea_pace, 1.0)
	assert_eq(calm.foam_pace, 1.0)


func test_every_weather_that_is_not_clear_names_itself_in_nine_glyphs() -> void:
	var checked: int = 0
	for weather_id: StringName in GameState.content.list_ids(&"weather"):
		var weather := _weather(weather_id)
		if weather == null or weather.is_clear:
			continue
		checked += 1
		assert_lte(weather.name_es.length(), 9, "%s: '%s' fits the weather window" % [weather_id, weather.name_es])
		assert_lte(weather.name_en.length(), 9, "%s: '%s' fits the weather window" % [weather_id, weather.name_en])
	assert_gt(checked, 0, "the squall at least")
