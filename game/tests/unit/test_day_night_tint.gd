extends GutTest
## weather-daynight: the CanvasModulate takes the sky's tint; the horizon line shows during a
## squall warning only.

var sky: WorldSky


func before_each() -> void:
	sky = WorldSky.from_catalog(GameState.content)


func test_the_tint_node_takes_night_times_calm() -> void:
	sky.start_at(440.1)
	var tint := DayNightTint.new()
	tint.sky = sky
	add_child_autofree(tint)
	tint._process(0.016)
	var expected: Color = sky.tuning.phase_tints[DataEnums.DayPhase.NIGHT] * sky.weather.current.canvas_tint
	assert_true(tint.color.is_equal_approx(expected))


func test_horizon_line_follows_the_warning() -> void:
	sky.start_at(200.0)
	var line := HorizonLine.new()
	line.sky = sky
	add_child_autofree(line)
	line._process(0.016)
	assert_false(line.visible)
	sky.weather.warn_weather(&"squall")
	line._process(0.016)
	assert_true(line.visible)
	sky.advance(59.9)
	line._process(0.016)
	assert_true(line.visible)
	sky.advance(0.2)
	line._process(0.016)
	assert_false(line.visible)
