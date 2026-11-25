extends GutTest
## ui-shell "Menu windows", "Pause and host-lost windows" and "Readable HUD and menu text"
## (hud-window-kit design D9, D10, D12), solo and offline: every menu panel is a paper window, every
## label on a panel or a button reads at 4.5:1 or more in the theme's fonts, a focused button and
## its ring stay inside the panel's inner area, the join error is a red band, and host-lost sits in
## a centred dark window.

const VIEW: Rect2 = Rect2(0.0, 0.0, 640.0, 360.0)
const SCREENS: Dictionary[String, String] = {
	"title": "res://scenes/shell/title_screen.tscn",
	"settings": "res://scenes/shell/settings_screen.tscn",
	"join": "res://scenes/shell/join_screen.tscn",
	"lobby": "res://scenes/shell/lobby_screen.tscn",
	"credits": "res://scenes/shell/credits_screen.tscn",
	"summary": "res://scenes/shell/summary_screen.tscn",
}
const HOST_LOST_SCENE: PackedScene = preload("res://scenes/ui/host_lost_screen.tscn")
const PAPER: String = "res://assets/art/ui/panel_paper.png"
const INSET: String = "res://assets/art/ui/window_paper.png"
const DARK: String = "res://assets/art/ui/window_dark.png"
const BUTTON: String = "res://assets/art/ui/button.png"
const MENU_FONT: String = "res://assets/fonts/menu_font.tres"
const SMALL_FONT: String = "res://assets/fonts/PressStart2P-Regular.ttf"
## The paper panel's border: its outline, bevel and one fill row (design D2).
const PAPER_BORDER: float = 3.0


func _open(key: String) -> Control:
	var screen := (load(SCREENS[key]) as PackedScene).instantiate() as Control
	add_child_autofree(screen)
	match key:
		"lobby":
			(screen as LobbyScreen).is_host = true
			(screen as LobbyScreen).show_roster({1: "Yuni", 5: "Papo"} as Dictionary[int, String])
		"summary":
			var made := RunSummary.new()
			made.entries = [{"name": "Yuni", "dead": true, "cause": &"thirst", "cause_label": "sed", "line": "Se acabó la lucha.", "line_id": &"death_thirst_1", "peer": 1}] as Array[Dictionary]
			(screen as SummaryScreen).show_summary(made)
		"join":
			(screen as JoinScreen).show_failed()
	return screen


func _labels_under(node: Node, into: Array[Label]) -> void:
	for child: Node in node.get_children():
		var label := child as Label
		if label != null and label.is_visible_in_tree() and not label.text.is_empty():
			into.append(label)
		_labels_under(child, into)


# The fill a label is drawn on: the error band, a paper inset, a dark window or tab, or the paper
# panel; Color.TRANSPARENT when it sits on no panel (the title's logo over the sea).
func _fill_under(label: Label) -> Color:
	if label.theme_type_variation == &"ErrorLabel":
		return (label.get_theme_stylebox(&"normal") as StyleBoxFlat).bg_color
	var node: Node = label.get_parent()
	while node != null:
		var scroll := node as ScrollContainer
		if scroll != null and scroll.theme_type_variation == &"PaperInset":
			return HudContrast.centre_color(INSET)
		var box := node as PanelContainer
		if box != null:
			var style := box.get_theme_stylebox(&"panel") as StyleBoxTexture
			return HudContrast.centre_color(style.texture.resource_path) if style != null else Color.TRANSPARENT
		node = node.get_parent()
	return Color.TRANSPARENT


func _font_ok(label: Label) -> bool:
	var path: String = label.get_theme_font(&"font").resource_path
	var size: int = label.get_theme_font_size(&"font_size")
	return (path == MENU_FONT and size in [16, 32]) or (path == SMALL_FONT and size == 8)


func test_every_menu_label_reads_on_its_panel_in_the_theme_fonts() -> void:
	for key: String in SCREENS:
		var screen := _open(key)
		await wait_process_frames(2)
		var labels: Array[Label] = []
		_labels_under(screen, labels)
		assert_gt(labels.size(), 0, key)
		for label: Label in labels:
			assert_true(_font_ok(label), "%s: '%s' in a theme font and size" % [key, label.text])
			var fill: Color = _fill_under(label)
			if fill.a == 0.0:
				continue
			var ink: Color = label.get_theme_color(&"font_color")
			assert_gte(HudContrast.ratio(ink, fill), HudContrast.STEADY, "%s: '%s' at 4.5:1 or more" % [key, label.text])


func test_every_menu_panel_is_paper_with_its_buttons_inside() -> void:
	for key: String in SCREENS:
		var screen := _open(key)
		await wait_process_frames(2)
		var panel := screen.get_node_or_null(^"Panel") as PanelContainer
		if panel == null:
			panel = screen.get_node_or_null(^"DescriptionPanel") as PanelContainer
		assert_not_null(panel, key)
		if panel == null:
			continue
		var style := panel.get_theme_stylebox(&"panel") as StyleBoxTexture
		assert_eq(style.texture.resource_path, PAPER, "%s's panel is paper with even edges" % key)
		assert_true(VIEW.encloses(panel.get_global_rect()), "%s's panel inside 640x360" % key)
		var inner: Rect2 = panel.get_global_rect().grow(-PAPER_BORDER)
		for button: Button in panel.find_children("*", "Button", true, false):
			if button.is_visible_in_tree():
				assert_true(inner.encloses(button.get_global_rect().grow(1.0)), "%s: '%s' and its focus ring inside the panel" % [key, button.text])


func test_buttons_read_in_every_lit_state() -> void:
	var fill: Color = HudContrast.centre_color(BUTTON)
	var theme := load("res://scenes/ui/theme/game_theme.tres") as Theme
	for name: StringName in [&"font_color", &"font_focus_color", &"font_pressed_color"]:
		assert_gte(HudContrast.ratio(theme.get_color(name, &"Button"), fill), HudContrast.STEADY, String(name))
	assert_gte(HudContrast.ratio(theme.get_color(&"font_hover_color", &"Button"), HudContrast.centre_color("res://assets/art/ui/button_hover.png")), HudContrast.STEADY, "hover")
	var pressed: Color = HudContrast.centre_color("res://assets/art/ui/button_pressed.png")
	assert_gte(HudContrast.ratio(theme.get_color(&"font_pressed_color", &"Button"), pressed), HudContrast.STEADY, "pressed")


func test_join_failure_is_a_red_band_and_connecting_is_not() -> void:
	var join := _open("join") as JoinScreen
	assert_eq(join.status.text, JoinScreen.FAILED)
	assert_eq(join.status.theme_type_variation, &"ErrorLabel")
	var band := join.status.get_theme_stylebox(&"normal") as StyleBoxFlat
	assert_not_null(band)
	if band != null:
		assert_gte(HudContrast.ratio(join.status.get_theme_color(&"font_color"), band.bg_color), HudContrast.STEADY)
	join.show_connecting("127.0.0.1")
	assert_eq(join.status.theme_type_variation, &"PanelLabel")


func test_host_lost_sits_in_a_centred_dark_window_with_its_tab() -> void:
	var screen := HOST_LOST_SCENE.instantiate() as HostLostScreen
	add_child_autofree(screen)
	await wait_process_frames(2)
	var window := screen.get_node(^"%Window") as PanelContainer
	var tab := screen.get_node(^"%Tab") as PanelContainer
	assert_eq((window.get_theme_stylebox(&"panel") as StyleBoxTexture).texture.resource_path, DARK)
	assert_eq(tab.theme_type_variation, &"HudTab")
	var frame := (screen.get_node(^"%Frame") as Control).get_global_rect()
	assert_true(VIEW.encloses(frame), "inside the view: %s" % frame)
	assert_almost_eq(frame.get_center().x, 320.0, 1.0)
	assert_almost_eq(frame.get_center().y, 180.0, 1.0)
	assert_true(window.get_global_rect().encloses(screen.back_button.get_global_rect()), "Volver inside the window")
	assert_true(window.get_global_rect().encloses(screen.message.get_global_rect()), "the line inside the window")
	# menu-clarity design D1: the line is body text, so it reads in Press Start 2P at 8.
	assert_eq(screen.message.get_theme_font(&"font").resource_path, SMALL_FONT, "the host-lost line is body text")
	assert_eq(screen.message.get_theme_font_size(&"font_size"), 8)


const HEADINGS: Array[StringName] = [&"TitleLabel", &"HeadingLabel", &"PanelHeading"]


func _is_heading(label: Label) -> bool:
	return label.theme_type_variation in HEADINGS


func test_headings_in_pixelify_and_every_other_line_and_control_in_press_start_2p() -> void:
	# ui-shell "Shared theme" and "Readable HUD and menu text" (menu-clarity design D1, owner Q16):
	# asked of the real nodes, so a per-node override would show here.
	for key: String in SCREENS:
		var screen := _open(key)
		await wait_process_frames(2)
		var labels: Array[Label] = []
		_labels_under(screen, labels)
		for label: Label in labels:
			var path: String = label.get_theme_font(&"font").resource_path
			var size: int = label.get_theme_font_size(&"font_size")
			if _is_heading(label):
				assert_eq(path, MENU_FONT, "%s: heading '%s' in Pixelify Sans" % [key, label.text])
				assert_true(size in [16, 32], "%s: heading '%s' at 16 or 32" % [key, label.text])
			else:
				assert_eq(path, SMALL_FONT, "%s: '%s' in Press Start 2P" % [key, label.text])
				assert_eq(size, 8, "%s: '%s' at 8" % [key, label.text])
		for control: Control in screen.find_children("*", "BaseButton", true, false) + screen.find_children("*", "LineEdit", true, false):
			if not control.is_visible_in_tree():
				continue
			assert_eq(control.get_theme_font(&"font").resource_path, SMALL_FONT, "%s: %s in Press Start 2P" % [key, control.name])
			assert_eq(control.get_theme_font_size(&"font_size"), 8, "%s: %s at 8" % [key, control.name])


func test_the_join_field_draws_an_address_in_press_start_2p() -> void:
	# ui-shell "Shared theme", scenario "Digits in a text field", solo and offline.
	var join := _open("join") as JoinScreen
	join.address_field.text = "192.168.1.70"
	await wait_process_frames(2)
	var font: Font = join.address_field.get_theme_font(&"font")
	assert_eq(font.resource_path, SMALL_FONT)
	assert_eq(join.address_field.get_theme_font_size(&"font_size"), 8)
	assert_eq(font.get_string_size("192.168.1.70", HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x, 96.0, "8 px a character")
	assert_true(join.address_field.size.x >= 96.0 + 8.0, "the address fits its field")


func test_the_title_buttons_stay_at_least_20_px_tall() -> void:
	var title := _open("title") as TitleScreen
	await wait_process_frames(2)
	for button: Button in title.find_children("*", "Button", true, false):
		assert_gte(button.size.y, 20.0, "'%s' at least 20 px tall" % button.text)
