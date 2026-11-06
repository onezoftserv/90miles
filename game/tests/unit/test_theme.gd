extends GutTest
## ui-shell "Shared theme": one project theme, two crisp pixel fonts at the sizes where they are
## crisp, and panels and buttons from tracked art only.

const THEME_PATH: String = "res://scenes/ui/theme/game_theme.tres"
const SMALL_FONT: String = "res://assets/fonts/PressStart2P-Regular.ttf"
const BIG_FONT: String = "res://assets/fonts/PixelifySans[wght].ttf"


func _theme() -> Theme:
	return load(THEME_PATH) as Theme


func test_the_theme_is_the_project_theme() -> void:
	assert_eq(ProjectSettings.get_setting("gui/theme/custom", ""), THEME_PATH)
	assert_not_null(_theme())


func test_small_text_is_press_start_2p_at_8() -> void:
	var theme := _theme()
	assert_eq(theme.default_font.resource_path, SMALL_FONT)
	assert_eq(theme.default_font_size, 8)


func test_buttons_and_titles_use_pixelify_sans_at_16_and_32() -> void:
	var theme := _theme()
	assert_eq(theme.get_font(&"font", &"Button").resource_path, BIG_FONT)
	assert_eq(theme.get_font_size(&"font_size", &"Button"), 16)
	assert_eq(theme.get_type_variation_base(&"TitleLabel"), &"Label")
	assert_eq(theme.get_font(&"font", &"TitleLabel").resource_path, BIG_FONT)
	assert_eq(theme.get_font_size(&"font_size", &"TitleLabel"), 32)
	assert_eq(theme.get_font_size(&"font_size", &"HeadingLabel"), 16)


func test_both_fonts_are_imported_crisp() -> void:
	for path: String in [SMALL_FONT, BIG_FONT]:
		var font := load(path) as FontFile
		assert_eq(font.antialiasing, TextServer.FONT_ANTIALIASING_NONE, path)
		assert_eq(font.hinting, TextServer.HINTING_NONE, path)
		assert_eq(font.subpixel_positioning, TextServer.SUBPIXEL_POSITIONING_DISABLED, path)


func test_buttons_have_a_focus_frame_and_panels_have_chrome() -> void:
	var theme := _theme()
	assert_true(theme.get_stylebox(&"normal", &"Button") is StyleBoxTexture)
	assert_true(theme.get_stylebox(&"pressed", &"Button") is StyleBoxTexture)
	var focus := theme.get_stylebox(&"focus", &"Button") as StyleBoxFlat
	assert_not_null(focus)
	assert_gt(focus.border_width_left, 0)
	assert_true(theme.get_stylebox(&"panel", &"PanelContainer") is StyleBoxTexture)
	assert_eq(theme.get_type_variation_base(&"HudPanel"), &"PanelContainer")
	assert_lt((theme.get_stylebox(&"panel", &"HudPanel") as StyleBoxFlat).bg_color.a, 1.0, "see-through over the world")


func test_the_theme_only_uses_tracked_art() -> void:
	for dependency: String in ResourceLoader.get_dependencies(THEME_PATH):
		assert_false(dependency.contains("res://assets/kenney/"), dependency)
	for path: String in ["res://assets/art/ui/panel_tan.png", "res://assets/art/ui/button_blue.png", "res://assets/art/ui/button_blue_pressed.png", "res://assets/art/ui/License.txt"]:
		assert_true(FileAccess.file_exists(path), path)
