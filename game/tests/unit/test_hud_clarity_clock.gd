extends GutTest
## hud-clarity, ui-shell "Clock strip", "Time left before dark" and "HUD layout", with exactly 1
## player, offline: a solo run's clock row reads the day, the time left and the phase word, keeps
## the day across travel, and sits at (152,4)-(380,18) with the old PhasePanel and %Phase names.

const SHELL_SCENE: PackedScene = preload("res://scenes/shell/game_shell.tscn")
const COAST: StringName = &"coast_cay"
const CLOCK_RECT: Rect2 = Rect2(152.0, 4.0, 228.0, 14.0)

var settings_path: String = UserTmp.path("test_hud_clarity_clock_settings.cfg")


func after_each() -> void:
	WeatherManager.stop()
	NetManager.leave()
	if FileAccess.file_exists(settings_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(settings_path))


func _shell() -> GameShell:
	NetManager.start_solo()
	WeatherManager.stop()
	var shell := SHELL_SCENE.instantiate() as GameShell
	shell.settings_path = settings_path
	add_child_autofree(shell)
	(shell.screen as TitleScreen).solo_requested.emit()
	shell.session.body(1).player_input.enabled = false
	WeatherManager.sky.weather.rolls_enabled = false
	return shell


# Puts the one sky at hh:mm on `day`, as a host sync would, and lets the HUD redraw.
func _set_time(hours: int, minutes: int, day: int) -> void:
	var t: float = fposmod(float(hours - DayClock.DAWN_HOUR) * DayClock.HOUR_S + float(minutes) / 2.0, DayClock.DAY_S)
	WeatherManager.sky.apply_state({"time_of_day_s": t, "day": day, "weather": WeatherCycle.DEFAULT_ID, "weather_left_s": 0.0, "pending": &"", "pending_in_s": -1.0})


func _clock(shell: GameShell) -> ClockStrip:
	return shell.hud.get_node(^"PhasePanel/Clock") as ClockStrip


func test_a_solo_morning() -> void:
	var shell := _shell()
	_set_time(9, 0, 1)
	await wait_process_frames(2)
	var clock := _clock(shell)
	assert_not_null(clock, "the clock row")
	if clock == null:
		return
	assert_eq(clock.day_label.text, "Día 1")
	assert_eq(clock.left_label.text, "11h")
	assert_false(clock.counts_to_dawn, "the moon mark")
	assert_eq(shell.hud.phase_label.text, "Mañana")
	assert_eq(clock.strip.marker_px, 6, "an eighth of the way along")
	assert_true(clock.left_label.get_theme_color(&"font_color").is_equal_approx(HudStyle.CREAM), "cream by day")


func test_late_afternoon_turns_orange_and_night_counts_to_dawn() -> void:
	var shell := _shell()
	_set_time(18, 30, 2)
	await wait_process_frames(2)
	var clock := _clock(shell)
	assert_eq(clock.day_label.text, "Día 2")
	assert_eq(clock.left_label.text, "2h")
	assert_true(clock.left_label.get_theme_color(&"font_color").is_equal_approx(HudStyle.ORANGE), "orange from dusk")
	assert_eq(shell.hud.phase_label.text, "Atardecer")
	_set_time(5, 40, 1)
	await wait_process_frames(2)
	assert_eq(clock.left_label.text, "20m")
	assert_true(clock.counts_to_dawn, "the sun mark")
	assert_true(clock.left_label.get_theme_color(&"font_color").is_equal_approx(HudStyle.CREAM), "cream at night")
	assert_eq(shell.hud.phase_label.text, "Noche")


func test_the_afternoon_word() -> void:
	var shell := _shell()
	_set_time(17, 0, 1)
	await wait_process_frames(2)
	assert_eq(shell.hud.phase_label.text, "Tarde")


func test_travel_keeps_the_day() -> void:
	var shell := _shell()
	_set_time(9, 0, 2)
	shell.travel.travel(COAST)
	await wait_process_frames(3)
	assert_eq(shell.island.layout.id, COAST, "on the coast cay")
	assert_eq(_clock(shell).day_label.text, "Día 2", "travel never resets the day count")


func test_the_clock_row_rect_and_names() -> void:
	var shell := _shell()
	_set_time(14, 0, 1)
	await wait_process_frames(2)
	var panel := shell.hud.get_node(^"PhasePanel") as PanelContainer
	assert_not_null(panel)
	assert_eq(panel.get_global_rect(), CLOCK_RECT)
	assert_eq(panel.theme_type_variation, &"HudPanel")
	assert_eq(shell.hud.phase_label, shell.hud.get_node(^"%Phase"), "%Phase is still the phase word")
	assert_eq(shell.hud.phase_label.text, "Mediodía")
	var clock := _clock(shell)
	for piece: Control in [clock.day_label, clock.strip, clock.left_label, shell.hud.phase_label]:
		assert_true(CLOCK_RECT.encloses(piece.get_global_rect()), "%s inside the clock row" % piece.name)
	assert_lt(clock.day_label.get_global_rect().end.x, clock.strip.get_global_rect().position.x + 0.5, "the day, then the strip")
	assert_lt(clock.strip.get_global_rect().end.x, clock.left_label.get_global_rect().position.x + 0.5, "then the time left")
	assert_lt(clock.left_label.get_global_rect().end.x, shell.hud.phase_label.get_global_rect().position.x + 0.5, "then the phase")
