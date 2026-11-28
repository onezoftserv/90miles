extends GutTest
## run-menu design D4: MenuLook.to_run turns a paper menu screen into the dark run look (the Fable
## review's MN-01), and every line still reads at 4.5:1 or more on the dark window. Solo, offline.

const DARK: String = "res://assets/art/ui/window_dark.png"
const SCREENS: Array[String] = [
	"res://scenes/shell/settings_screen.tscn",
	"res://scenes/shell/controls_card.tscn",
	"res://scenes/ui/confirm_box.tscn",
]


func _dark(path: String) -> Control:
	var screen := (load(path) as PackedScene).instantiate() as Control
	add_child_autofree(screen)
	var box := screen as ConfirmBox
	if box != null:
		box.ask("¿Abandonar el viaje?", "Este viaje se pierde.", "Abandonar")
	MenuLook.to_run(screen)
	return screen


func test_paper_variations_become_the_run_ones() -> void:
	var screen := _dark(SCREENS[0]) as SettingsScreen
	await wait_process_frames(1)
	assert_eq((screen.get_node(^"Panel") as PanelContainer).theme_type_variation, &"HudPanel")
	assert_eq(screen.fullscreen_box.theme_type_variation, &"HudCheckBox")
	assert_eq(screen.reduce_flashes_box.theme_type_variation, &"HudCheckBox")
	for label: Label in screen.find_children("*", "Label", true, false):
		assert_false(label.theme_type_variation in [&"PanelLabel", &"PanelHeading"], "'%s' left paper" % label.text)


func test_every_line_reads_on_the_dark_window() -> void:
	var fill: Color = HudContrast.centre_color(DARK)
	for path: String in SCREENS:
		var screen := _dark(path)
		await wait_process_frames(2)
		for label: Label in screen.find_children("*", "Label", true, false):
			if not label.is_visible_in_tree() or label.text.is_empty():
				continue
			var ink: Color = label.get_theme_color(&"font_color")
			assert_gte(HudContrast.ratio(ink, fill), HudContrast.STEADY, "%s: '%s' at 4.5:1 or more" % [path.get_file(), label.text])
		for check: CheckBox in screen.find_children("*", "CheckBox", true, false):
			assert_gte(HudContrast.ratio(check.get_theme_color(&"font_color"), fill), HudContrast.STEADY, "%s: '%s'" % [path.get_file(), check.text])
