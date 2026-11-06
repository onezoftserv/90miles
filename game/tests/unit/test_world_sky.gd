extends GutTest
## weather-daynight: the sky (clock + weather) writes the climate the meters read, gives the tint
## and syncs as a dictionary.

const P := DataEnums.DayPhase

var sky: WorldSky


func before_each() -> void:
	sky = WorldSky.from_catalog(GameState.content)


func _tint_of(phase: DataEnums.DayPhase) -> Color:
	return sky.tuning.phase_tints[phase]


func _assert_color(actual: Color, expected: Color) -> void:
	assert_true(actual.is_equal_approx(expected), "%s should be %s" % [actual, expected])


func test_climate_follows_the_clock() -> void:
	sky.start_at(0.0)
	assert_eq(sky.climate.phase, P.DAWN)
	assert_false(sky.climate.midday)
	sky.advance(120.0)
	assert_eq(sky.climate.phase, P.DAY)
	assert_true(sky.climate.midday)
	assert_eq(sky.climate.heat_factor, 2.0)
	sky.advance(180.0)
	assert_false(sky.climate.midday)
	sky.advance(120.0)
	assert_eq(sky.climate.phase, P.NIGHT)


func test_climate_heat_factor_is_the_squalls_during_a_squall() -> void:
	sky.start_at(200.0)
	sky.weather.start_weather(&"squall")
	assert_eq(sky.climate.heat_factor, 1.0)


func test_tint_is_the_night_colour_times_calm_after_the_blend() -> void:
	sky.start_at(420.0 + sky.tuning.blend_s + 0.1)
	_assert_color(sky.tint(), _tint_of(P.NIGHT) * sky.weather.current.canvas_tint)


func test_tint_blends_from_the_previous_phase() -> void:
	sky.start_at(60.0)
	_assert_color(sky.tint(), _tint_of(P.DAWN))
	sky.start_at(60.0 + sky.tuning.blend_s * 0.5)
	_assert_color(sky.tint(), _tint_of(P.DAWN).lerp(_tint_of(P.DAY), 0.5))


func test_tint_multiplies_the_squall_tint() -> void:
	sky.start_at(200.0)
	sky.weather.start_weather(&"squall")
	_assert_color(sky.tint(), _tint_of(P.DAY) * sky.weather.current.canvas_tint)
	assert_ne(sky.tint(), _tint_of(P.DAY))


func test_state_round_trip() -> void:
	sky.start_at(450.0)
	sky.weather.warn_weather(&"squall")
	sky.advance(30.0)
	var other := WorldSky.from_catalog(GameState.content)
	assert_true(other.apply_state(sky.to_state()))
	assert_almost_eq(other.clock.time_of_day_s, 480.0, 0.001)
	assert_eq(other.clock.phase(), P.NIGHT)
	assert_almost_eq(other.weather.pending_in_s, 30.0, 0.001)
	assert_eq(other.weather.pending.id, &"squall")


func test_apply_state_rejects_bad_values() -> void:
	sky.start_at(100.0)
	var good: Dictionary = sky.to_state()
	for bad: Dictionary in [
		{"time_of_day_s": 9999.0}, {"time_of_day_s": -1.0}, {"time_of_day_s": NAN},
		{"weather": &"hurricane"}, {"day": -3},
	]:
		var state: Dictionary = good.duplicate()
		state.merge(bad, true)
		assert_false(sky.apply_state(state), str(bad))
	assert_eq(sky.clock.time_of_day_s, 100.0)
	assert_eq(sky.weather.current.id, &"calm")
