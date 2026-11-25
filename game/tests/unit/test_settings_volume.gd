extends GutTest
## ui-shell "Settings", scenario "Volume kept" (menu-clarity group 6; sound-pass owner decision
## Q1 A): a "Volumen" row from 0 to 100 % in steps of 10, 80 % on a fresh install, saved and heard
## at once, on the title's settings and in a run's Ajustes. Exactly 1 player, offline.

const SHELL_SCENE: PackedScene = preload("res://scenes/shell/game_shell.tscn")

var settings_path: String = UserTmp.path("test_settings_volume.cfg")
var _volume_before: float = 1.0


func before_each() -> void:
	NetManager.start_solo()
	_volume_before = AudioManager.volume()
	_remove()


func after_each() -> void:
	AudioManager.set_volume(_volume_before)
	get_tree().paused = false
	NetManager.leave()
	_remove()


func _remove() -> void:
	if FileAccess.file_exists(settings_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(settings_path))


func _shell() -> GameShell:
	var config := ConfigFile.new()
	config.set_value("player", "name_asked", true)
	config.save(settings_path)
	var shell := SHELL_SCENE.instantiate() as GameShell
	shell.settings_path = settings_path
	add_child_autofree(shell)
	return shell


func test_volume_kept_from_80_down_to_50() -> void:
	var shell := _shell()
	shell.show_settings()
	var screen := shell.screen as SettingsScreen
	assert_eq(screen.volume_value.text, "80 %", "a fresh install")
	watch_signals(screen)
	for i: int in 3:
		screen.volume_down.pressed.emit()
		assert_almost_eq(AudioManager.volume(), 0.7 - 0.1 * i, 0.001, "heard at once, step %d" % (i + 1))
	assert_signal_emit_count(screen, "volume_changed", 3)
	assert_eq(screen.volume_value.text, "50 %")
	assert_eq(GameSettings.load_from(settings_path).volume, 5, "saved")
	var again := GameSettings.load_from(settings_path)
	assert_eq(again.volume * 100 / GameSettings.MAX_VOLUME, 50, "the next launch reads 50 %")


func test_the_row_stops_at_0_and_100() -> void:
	var shell := _shell()
	shell.show_settings()
	var screen := shell.screen as SettingsScreen
	for i: int in 12:
		screen.volume_up.pressed.emit()
	assert_eq(screen.volume_value.text, "100 %")
	assert_true(screen.volume_up.disabled)
	for i: int in 12:
		screen.volume_down.pressed.emit()
	assert_eq(screen.volume_value.text, "0 %")
	assert_true(screen.volume_down.disabled)
	assert_almost_eq(AudioManager.volume(), 0.0, 0.001)


func test_the_row_is_in_a_runs_ajustes_too() -> void:
	var shell := _shell()
	shell.start_solo()
	var menu: PauseMenu = shell.hud.pause_menu
	menu.open()
	menu.open_settings()
	var screen := menu.view as SettingsScreen
	assert_not_null(screen)
	if screen == null:
		return
	assert_true(screen.volume_value.is_visible_in_tree())
	screen.volume_down.pressed.emit()
	assert_almost_eq(AudioManager.volume(), 0.7, 0.001, "heard at once in the run")
	assert_eq(GameSettings.load_from(settings_path).volume, 7)
	menu.resume()
