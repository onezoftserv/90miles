extends GutTest
## weather-daynight "Run uses the sky": a run started from the shell (solo, host, client) runs on
## the game's one sky: the clock, the tint over the world and the horizon line in the HUD.

const SHELL_SCENE: PackedScene = preload("res://scenes/shell/game_shell.tscn")
const SETTINGS_PATH: String = "user://test_shell_sky_settings.cfg"
## A run's first morning: the clock reads 06:00, dawn (docs/GAME_DESIGN.md §5).
const FIRST_MORNING_S: float = 0.0


func before_each() -> void:
	NetManager.start_solo()
	WeatherManager.stop()


func after_each() -> void:
	WeatherManager.stop()
	NetManager.leave()
	if FileAccess.file_exists(SETTINGS_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SETTINGS_PATH))


func _shell() -> GameShell:
	var shell := SHELL_SCENE.instantiate() as GameShell
	shell.settings_path = SETTINGS_PATH
	shell.port = 0
	add_child_autofree(shell)
	return shell


func _solo(shell: GameShell) -> void:
	(shell.screen as TitleScreen).solo_requested.emit()


func test_a_solo_run_starts_the_clock() -> void:
	var shell := _shell()
	assert_false(WeatherManager.running, "nothing runs on the title")
	_solo(shell)
	assert_true(WeatherManager.running)
	await wait_seconds(0.3)
	assert_gt(WeatherManager.time_of_day_s(), FIRST_MORNING_S, "the clock advances in the run")


func test_a_solo_run_starts_at_dawn() -> void:
	var shell := _shell()
	WeatherManager.sky.start_at(300.0)
	_solo(shell)
	assert_lt(WeatherManager.time_of_day_s(), 1.0, "the first morning, not the earlier clock")


func test_a_solo_run_shares_the_one_sky() -> void:
	var shell := _shell()
	_solo(shell)
	var sky: WorldSky = WeatherManager.sky
	assert_eq(shell.session.sky, sky)
	assert_eq(shell.session.climate, sky.climate)
	assert_eq(shell.island.climate, sky.climate)
	assert_eq(shell.session.body(1).climate, sky.climate, "the body reads the sky's climate")
	shell.session._add_player(7)
	assert_eq(shell.session.body(7).climate, sky.climate)


func test_a_host_run_starts_the_clock_when_the_run_begins() -> void:
	var shell := _shell()
	(shell.screen as TitleScreen).host_requested.emit()
	assert_eq(shell.session.sky, WeatherManager.sky)
	assert_false(WeatherManager.running, "the lobby waits")
	shell.session.begin_run()
	assert_true(WeatherManager.running)
	assert_eq(shell.session.body(1).climate, WeatherManager.sky.climate)


func test_a_client_run_follows_the_host_and_never_rolls() -> void:
	var shell := _shell()
	WeatherManager.sky.weather.rolls_enabled = true
	shell._join("127.0.0.1", 1)
	assert_eq(shell.session.sky, WeatherManager.sky)
	assert_false(WeatherManager.sky.weather.rolls_enabled, "the client never rolls weather")
	shell._enter_run()
	assert_false(WeatherManager.running, "the client's clock follows receive_sky")


func test_leaving_the_run_stops_the_clock() -> void:
	var shell := _shell()
	_solo(shell)
	shell.back_to_title()
	assert_false(WeatherManager.running)


func test_the_end_of_the_run_stops_the_clock() -> void:
	var shell := _shell()
	_solo(shell)
	shell.session.body(1).meters.dead = true
	assert_eq(shell.flow, GameShell.Flow.SUMMARY)
	assert_false(WeatherManager.running)


func test_losing_the_host_stops_the_clock() -> void:
	var shell := _shell()
	_solo(shell)
	shell.session.host_lost.emit()
	await wait_frames(2)
	assert_false(WeatherManager.running)


func test_the_tint_covers_the_world_and_not_the_hud() -> void:
	var shell := _shell()
	_solo(shell)
	var tints: Array[Node] = shell.find_children("*", "DayNightTint", true, false)
	assert_eq(tints.size(), 1)
	assert_eq(tints[0].get_viewport(), shell.world_viewport, "inside the world view")
	assert_ne(shell.hud.get_viewport(), shell.world_viewport, "the HUD is outside it")
	shell.back_to_title()
	assert_eq(shell.find_children("*", "DayNightTint", true, false).size(), 0, "none on the title")


func test_the_run_hud_has_the_horizon_line() -> void:
	var shell := _shell()
	_solo(shell)
	assert_eq(shell.hud.find_children("*", "HorizonLine", true, false).size(), 1)
