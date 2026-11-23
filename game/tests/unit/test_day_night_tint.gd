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


# --- art-mood-pass C33a ("A readable night and dusk", design D1): properties, not numbers, because
# the tints are provisional data (weather-daynight "Calm and squall data") ---

## The base (shade 1) of a sea ramp row, read from the art tuning's ramp texture.
func _ramp_base(row: int) -> Color:
	var ramps: Image = ArtChecks.read_png(ArtTuning.standard().sea_ramps.resource_path)
	return ramps.get_pixel(1, row)


func test_at_dusk_the_tinted_sea_stays_blue() -> void:
	var dusk: Color = sky.tuning.phase_tints[DataEnums.DayPhase.DUSK]
	var steps: Dictionary = TerrainArt.data().depth_steps
	for kind: DataEnums.Terrain in [DataEnums.Terrain.DEEP, DataEnums.Terrain.SHALLOWS]:
		var tinted: Color = _ramp_base(int(steps[kind])) * dusk
		assert_gt(tinted.b, tinted.g, "%s at dusk: blue is its strongest channel, not teal (%s)" % [DataEnums.Terrain.keys()[kind], tinted])


func test_night_is_dark_but_readable() -> void:
	var night: Color = sky.tuning.phase_tints[DataEnums.DayPhase.NIGHT]
	assert_between(night.get_luminance(), 0.44, 0.52, "the night tint's luminance")

