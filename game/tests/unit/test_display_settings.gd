extends GutTest
## ui-shell "Display scaling" and "Settings": the whole-number window fit, the fullscreen
## toggle and the settings each install keeps.

const PATH: String = "user://test_ui_shell_settings.cfg"


func after_each() -> void:
	if FileAccess.file_exists(PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))


func test_a_1080p_desktop_fits_2x_windowed() -> void:
	assert_eq(DisplayFit.best_scale(Vector2i(1920, 1040)), 2)
	assert_eq(DisplayFit.window_size(2), Vector2i(1280, 720))


func test_a_1080p_screen_fits_3x_fullscreen() -> void:
	assert_eq(DisplayFit.best_scale(Vector2i(1920, 1080)), 3)


func test_other_screens() -> void:
	assert_eq(DisplayFit.best_scale(Vector2i(2560, 1440)), 4)
	assert_eq(DisplayFit.best_scale(Vector2i(1366, 768)), 2)
	assert_eq(DisplayFit.best_scale(Vector2i(320, 200)), 1, "never below 1")


func test_a_fixed_scale_wins_but_never_outgrows_the_screen() -> void:
	assert_eq(DisplayFit.window_scale(0, Vector2i(1920, 1040)), 2, "automatic")
	assert_eq(DisplayFit.window_scale(1, Vector2i(1920, 1040)), 1)
	assert_eq(DisplayFit.window_size(DisplayFit.window_scale(1, Vector2i(1920, 1040))), Vector2i(640, 360))
	assert_eq(DisplayFit.window_scale(4, Vector2i(1920, 1040)), 2, "4x does not fit a 1080p desktop")


func test_settings_defaults() -> void:
	var settings := GameSettings.new(PATH)
	assert_eq(settings.player_name, "Balsero")
	assert_false(settings.fullscreen)
	assert_eq(settings.ui_scale, 0)


func test_saved_settings_load_again() -> void:
	var settings := GameSettings.new(PATH)
	settings.player_name = "Dayana"
	settings.fullscreen = true
	settings.ui_scale = 3
	assert_eq(settings.save(), OK)
	var again := GameSettings.load_from(PATH)
	assert_eq(again.player_name, "Dayana")
	assert_true(again.fullscreen)
	assert_eq(again.ui_scale, 3)


func test_a_missing_file_gives_the_defaults() -> void:
	var settings := GameSettings.load_from("user://does_not_exist_ui_shell.cfg")
	assert_eq(settings.player_name, "Balsero")


func test_bad_values_in_the_file_fall_back() -> void:
	var config := ConfigFile.new()
	config.set_value("player", "name", 5)
	config.set_value("display", "fullscreen", "yes")
	config.set_value("display", "ui_scale", 9)
	config.save(PATH)
	var settings := GameSettings.load_from(PATH)
	assert_eq(settings.player_name, "Balsero")
	assert_false(settings.fullscreen)
	assert_eq(settings.ui_scale, 0)


func test_names_are_cleaned() -> void:
	assert_eq(GameSettings.clean_name("  Yuni  "), "Yuni")
	assert_eq(GameSettings.clean_name("Pa\u0001po\n"), "Papo")
	assert_eq(GameSettings.clean_name("abcdefghijklmnopqrstuvwxyz1234"), "abcdefghijklmnop")
	assert_eq(GameSettings.clean_name(""), "Balsero")
	assert_eq(GameSettings.clean_name("\u0002\u0003"), "Balsero")
	assert_eq(GameSettings.clean_name("", "Balsero 3"), "Balsero 3")


func test_setting_a_name_cleans_it() -> void:
	var settings := GameSettings.new(PATH)
	settings.player_name = "\tEl Chino\u0007 de la Habana Vieja"
	assert_eq(settings.player_name, "El Chino de la H")


func test_scale_setting_is_clamped() -> void:
	var settings := GameSettings.new(PATH)
	settings.ui_scale = 7
	assert_eq(settings.ui_scale, GameSettings.MAX_SCALE)
	settings.ui_scale = -2
	assert_eq(settings.ui_scale, 0)


func test_fullscreen_is_f11_and_alt_enter() -> void:
	assert_true(InputMap.has_action(&"toggle_fullscreen"))
	var keys: Array[String] = []
	for event: InputEvent in InputMap.action_get_events(&"toggle_fullscreen"):
		var key := event as InputEventKey
		if key != null:
			keys.append("%s%d" % ["alt+" if key.alt_pressed else "", key.physical_keycode])
	keys.sort()
	assert_eq(keys, ["%d" % KEY_F11, "alt+%d" % KEY_ENTER] as Array[String])
