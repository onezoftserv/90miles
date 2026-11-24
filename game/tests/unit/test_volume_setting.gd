extends GutTest
## sound-pass audio "Volume level" (owner Q1 A): each install keeps a volume from 0 to 10 (shown as
## 0 to 100 % in Ajustes), 8 on a fresh install, never synced, and the shell applies it to every
## sound at start. 1 player, offline.

const SHELL_SCENE: PackedScene = preload("res://scenes/shell/game_shell.tscn")

var settings_path: String = UserTmp.path("test_volume_setting.cfg")


func after_each() -> void:
	AudioManager.set_volume(1.0)
	if FileAccess.file_exists(settings_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(settings_path))


func test_a_fresh_install_is_at_80_percent() -> void:
	assert_eq(GameSettings.new(settings_path).volume, 8)
	assert_eq(GameSettings.load_from(UserTmp.path("test_volume_setting_missing.cfg")).volume, 8)


func test_the_volume_is_kept() -> void:
	var settings := GameSettings.new(settings_path)
	settings.volume = 3
	assert_eq(settings.save(), OK)
	assert_eq(GameSettings.load_from(settings_path).volume, 3)
	var config := ConfigFile.new()
	config.load(settings_path)
	assert_eq(config.get_value("audio", "volume"), 3, "stored under [audio]")


func test_the_volume_stays_in_its_steps() -> void:
	var settings := GameSettings.new(settings_path)
	settings.volume = 11
	assert_eq(settings.volume, 10)
	settings.volume = -1
	assert_eq(settings.volume, 0)


func test_a_malformed_volume_falls_back_to_the_default() -> void:
	for bad: Variant in ["loud", -1, 11, 5.5]:
		var config := ConfigFile.new()
		config.set_value("audio", "volume", bad)
		config.save(settings_path)
		assert_eq(GameSettings.load_from(settings_path).volume, 8, "%s falls back" % [bad])


func test_the_shell_applies_the_stored_volume_at_start() -> void:
	var settings := GameSettings.new(settings_path)
	settings.volume = 3
	settings.save()
	var shell := SHELL_SCENE.instantiate() as GameShell
	shell.settings_path = settings_path
	add_child_autofree(shell)
	assert_almost_eq(AudioManager.volume(), 0.3, 0.0001)
	shell.settings.volume = 0
	shell.apply_volume()
	assert_eq(AudioManager.volume(), 0.0, "0 silences the game")
	assert_true(AudioServer.is_bus_mute(0))
