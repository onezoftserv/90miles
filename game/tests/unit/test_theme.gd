extends GutTest
## ui-shell "Shared theme": one project theme, two crisp pixel fonts at the sizes where they are
## crisp, and every panel, button and widget from the window kit (hud-window-kit design D2, D3):
## StyleBoxTextures on tracked kit pieces in master palette colours, HUD windows 94% opaque, and the
## menu font with its wider word spaces.

const THEME_PATH: String = "res://scenes/ui/theme/game_theme.tres"
const SMALL_FONT: String = "res://assets/fonts/PressStart2P-Regular.ttf"
const BIG_FONT: String = "res://assets/fonts/PixelifySans[wght].ttf"
const MENU_FONT: String = "res://assets/fonts/menu_font.tres"
const KIT_DIR: String = "res://assets/art/ui/"
const PALETTE_PATH: String = "res://assets/art/palette/master_palette.png"
## Each kit style the theme defines: [theme type, stylebox name, kit piece].
const KIT_STYLES: Array[Array] = [
	[&"HudPanel", &"panel", "window_dark"],
	[&"HudPanelThin", &"panel", "window_thin"],
	[&"HudStripBack", &"panel", "window_thin"],
	[&"HudTab", &"panel", "tab_dark"],
	[&"HudNote", &"panel", "window_paper"],
	[&"HudSlot", &"panel", "slot_well"],
	[&"HudSlotSelected", &"panel", "slot_selected"],
	[&"Panel", &"panel", "panel_paper"],
	[&"PanelContainer", &"panel", "panel_paper"],
	[&"Button", &"normal", "button"],
	[&"Button", &"hover", "button_hover"],
	[&"Button", &"pressed", "button_pressed"],
	[&"Button", &"hover_pressed", "button_pressed"],
	[&"Button", &"disabled", "button"],
	[&"Button", &"focus", "focus_ring"],
	[&"OptionButton", &"normal", "button"],
	[&"OptionButton", &"focus", "focus_ring"],
	[&"CheckBox", &"focus", "focus_ring"],
	[&"LineEdit", &"normal", "line_edit"],
	[&"LineEdit", &"focus", "focus_ring"],
	[&"VScrollBar", &"scroll", "scroll_track"],
	[&"VScrollBar", &"grabber", "scroll_grabber"],
	[&"PopupMenu", &"panel", "window_dark"],
	[&"TooltipPanel", &"panel", "window_thin"],
	[&"PaperInset", &"panel", "window_paper"],
]


func _theme() -> Theme:
	return load(THEME_PATH) as Theme


func _palette() -> Dictionary:
	return ArtChecks.palette_from_image(ArtChecks.read_png(PALETTE_PATH))


func test_the_theme_is_the_project_theme() -> void:
	assert_eq(ProjectSettings.get_setting("gui/theme/custom", ""), THEME_PATH)
	assert_not_null(_theme())


func test_small_text_is_press_start_2p_at_8() -> void:
	var theme := _theme()
	assert_eq(theme.default_font.resource_path, SMALL_FONT)
	assert_eq(theme.default_font_size, 8)


func test_the_logo_and_headings_use_the_menu_font_at_32_and_16() -> void:
	# menu-clarity design D1 (owner Q16, 2026-11-23): Pixelify Sans only on the logo and headings.
	var theme := _theme()
	for type: StringName in [&"TitleLabel", &"HeadingLabel"]:
		assert_eq(theme.get_font(&"font", type).resource_path, MENU_FONT, String(type))
	assert_eq(theme.get_type_variation_base(&"TitleLabel"), &"Label")
	assert_eq(theme.get_font_size(&"font_size", &"TitleLabel"), 32)
	assert_eq(theme.get_font_size(&"font_size", &"HeadingLabel"), 16)
	assert_eq(theme.get_type_variation_base(&"PanelHeading"), &"HeadingLabel")


func test_controls_fields_and_body_text_use_press_start_2p_at_8() -> void:
	# menu-clarity design D1: buttons, check boxes, dropdowns and their lists, text fields, error
	# lines and the credits read in Press Start 2P at 8, so digits are unambiguous.
	var theme := _theme()
	for type: StringName in [&"Button", &"OptionButton", &"CheckBox", &"LineEdit", &"PopupMenu", &"ErrorLabel", &"CreditsLabel", &"Label", &"PanelLabel"]:
		assert_eq(theme.get_font(&"font", type).resource_path, SMALL_FONT, String(type))
		assert_eq(theme.get_font_size(&"font_size", type), 8, String(type))


func test_the_menu_font_is_pixelify_sans_with_wider_word_spaces() -> void:
	var font := load(MENU_FONT) as FontVariation
	assert_not_null(font)
	if font == null:
		return
	assert_eq(font.base_font.resource_path, BIG_FONT)
	var plain := load(BIG_FONT) as Font
	# The gap each space adds between two words, measured inside real headings (a lone space is
	# trimmed by the measure, so it would read the bare glyph).
	for line: String in ["Fin del viaje", "Conexión perdida", "A bordo"]:
		var spaces: float = float(line.count(" "))
		var gap: float = (_width(font, line) - _width(font, line.replace(" ", ""))) / spaces
		var plain_gap: float = (_width(plain, line) - _width(plain, line.replace(" ", ""))) / spaces
		assert_gte(gap, 5.0, "'%s': a space is at least 5 px at 16 px (ui-shell \"Shared theme\")" % line)
		assert_almost_eq(gap, plain_gap + 2.0, 0.01, "'%s': two pixels wider than the font's own" % line)


func _width(font: Font, text: String) -> float:
	return font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x


func test_both_fonts_are_imported_crisp() -> void:
	for path: String in [SMALL_FONT, BIG_FONT]:
		var font := load(path) as FontFile
		assert_eq(font.antialiasing, TextServer.FONT_ANTIALIASING_NONE, path)
		assert_eq(font.hinting, TextServer.HINTING_NONE, path)
		assert_eq(font.subpixel_positioning, TextServer.SUBPIXEL_POSITIONING_DISABLED, path)


func test_every_panel_and_button_is_a_kit_piece() -> void:
	var theme := _theme()
	for entry: Array in KIT_STYLES:
		var style := theme.get_stylebox(entry[1], entry[0]) as StyleBoxTexture
		assert_not_null(style, "%s/%s is a StyleBoxTexture" % [entry[0], entry[1]])
		if style != null:
			assert_eq(style.texture.resource_path, KIT_DIR + entry[2] + ".png", "%s/%s" % [entry[0], entry[1]])
	assert_eq(theme.get_type_variation_base(&"HudPanel"), &"PanelContainer")
	assert_eq(theme.get_type_variation_base(&"HudPanelThin"), &"PanelContainer")
	assert_eq(theme.get_type_variation_base(&"HudTab"), &"PanelContainer")


func test_hud_windows_are_94_percent_opaque() -> void:
	var theme := _theme()
	for type: StringName in [&"HudPanel", &"HudPanelThin", &"HudStripBack"]:
		var style := theme.get_stylebox(&"panel", type) as StyleBoxTexture
		assert_almost_eq(style.modulate_color.a, 0.94, 0.001, String(type))
	var note := theme.get_stylebox(&"panel", &"HudNote") as StyleBoxTexture
	assert_eq(note.modulate_color.a, 1.0, "the sign note is opaque")


func test_the_focus_ring_sits_one_pixel_outside_the_button() -> void:
	var focus := _theme().get_stylebox(&"focus", &"Button") as StyleBoxTexture
	for side: Side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
		assert_eq(focus.get_expand_margin(side), 1.0)


func test_every_theme_colour_is_a_palette_colour() -> void:
	var theme := _theme()
	var palette: Dictionary = _palette()
	for type: StringName in theme.get_color_type_list():
		for name: StringName in theme.get_color_list(type):
			var color: Color = theme.get_color(name, type)
			if color.a == 0.0:
				continue
			assert_true(palette.has(ArtChecks.rgb_key(color)), "%s/%s %s is a master palette colour" % [type, name, color.to_html(false)])


func test_the_tooltip_is_a_thin_window_with_small_cream_text() -> void:
	var theme := _theme()
	assert_eq(theme.get_font(&"font", &"TooltipLabel").resource_path, SMALL_FONT)
	assert_eq(theme.get_font_size(&"font_size", &"TooltipLabel"), 8)
	assert_true(theme.get_color(&"font_color", &"TooltipLabel").is_equal_approx(HudStyle.CREAM))


func test_the_theme_only_uses_tracked_art() -> void:
	for dependency: String in ResourceLoader.get_dependencies(THEME_PATH):
		assert_false(dependency.contains("res://assets/kenney/"), dependency)
	for entry: Array in KIT_STYLES:
		assert_true(FileAccess.file_exists(KIT_DIR + entry[2] + ".png"), entry[2])
	assert_true(FileAccess.file_exists(KIT_DIR + "License.txt"))
	for gone: String in ["panel_tan.png", "button_blue.png", "button_blue_pressed.png"]:
		assert_false(FileAccess.file_exists(KIT_DIR + gone), "Kenney's %s is gone" % gone)
