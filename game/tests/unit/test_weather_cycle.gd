extends GutTest
## weather-daynight "Weather states": calm or squall rolled per phase, a squall warned 60 s early,
## lasting 120 s, then calm; no roll during a squall; clients never roll.

const P := DataEnums.DayPhase

var cycle: WeatherCycle


func _calm(weight: float) -> WeatherData:
	var calm := WeatherData.new()
	calm.id = &"calm"
	calm.roll_weight = weight
	return calm


func _squall(weight: float) -> WeatherData:
	var squall := WeatherData.new()
	squall.id = &"squall"
	squall.roll_weight = weight
	squall.duration_s = 120.0
	squall.warning_lead_s = 60.0
	squall.followed_by_weather_id = &"calm"
	return squall


func _build(calm_weight: float, squall_weight: float, seed_value: int = 1) -> WeatherCycle:
	var states: Array[WeatherData] = [_calm(calm_weight), _squall(squall_weight)]
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var built := WeatherCycle.new(states, rng)
	watch_signals(built)
	return built


func test_starts_calm() -> void:
	cycle = _build(1.0, 0.0)
	assert_eq(cycle.current.id, &"calm")
	assert_null(cycle.pending)


func test_a_rolled_squall_is_warned_60_s_before_it_starts() -> void:
	cycle = _build(0.0, 1.0)
	cycle.on_phase_started(P.DAY)
	assert_signal_emitted_with_parameters(cycle, "weather_warned", [&"squall", 60.0])
	cycle.advance(59.9)
	assert_eq(cycle.current.id, &"calm")
	assert_almost_eq(cycle.pending_in_s, 0.1, 0.001)
	cycle.advance(0.1)
	assert_eq(cycle.current.id, &"squall")
	assert_signal_emitted_with_parameters(cycle, "weather_changed", [&"squall"])
	assert_null(cycle.pending)


func test_a_squall_lasts_120_s_then_calm() -> void:
	cycle = _build(0.0, 1.0)
	cycle.on_phase_started(P.DAY)
	cycle.advance(60.0)
	cycle.advance(119.9)
	assert_eq(cycle.current.id, &"squall")
	cycle.advance(0.1)
	assert_eq(cycle.current.id, &"calm")
	assert_signal_emitted_with_parameters(cycle, "weather_changed", [&"calm"])


func test_no_roll_while_a_squall_is_warned_or_running() -> void:
	cycle = _build(0.0, 1.0)
	cycle.on_phase_started(P.DAY)
	cycle.on_phase_started(P.DUSK)
	cycle.advance(60.0)
	cycle.on_phase_started(P.NIGHT)
	assert_signal_emit_count(cycle, "weather_warned", 1)
	assert_eq(cycle.current.id, &"squall")
	assert_null(cycle.pending)


func test_a_calm_roll_keeps_calm_and_warns_nothing() -> void:
	cycle = _build(1.0, 0.0)
	cycle.on_phase_started(P.DAY)
	assert_signal_not_emitted(cycle, "weather_warned")
	assert_eq(cycle.current.id, &"calm")
	assert_null(cycle.pending)


func test_clients_never_roll() -> void:
	cycle = _build(0.0, 1.0)
	cycle.rolls_enabled = false
	cycle.on_phase_started(P.DAY)
	assert_signal_not_emitted(cycle, "weather_warned")
	assert_eq(cycle.current.id, &"calm")


func test_squall_chance_from_the_data_is_one_in_four() -> void:
	# Follows the provisional roll weights in resources/weather: retune them, retune this.
	var states: Array[WeatherData] = []
	for id: StringName in [&"calm", &"squall"]:
		states.append(GameState.content.get_entry(&"weather", id) as WeatherData)
	assert_almost_eq(WeatherCycle.chance_of(states, &"squall", P.DAY), 0.25, 0.0001)


func test_seeded_rolls_are_repeatable() -> void:
	var outcomes: Array[Array] = [[], []]
	for run: int in 2:
		var seeded := _build(3.0, 1.0, 77)
		for i: int in 20:
			seeded.on_phase_started(P.DAY)
			outcomes[run].append(seeded.pending != null)
			seeded.advance(200.0)
	assert_eq(outcomes[0], outcomes[1])
