extends GutTest
## ui-shell "Title screen": the menu, the description of the focused option and the version.

const TITLE_SCENE: PackedScene = preload("res://scenes/shell/title_screen.tscn")
const LABELS: Array[String] = ["Jugar solo", "Hospedar partida", "Unirse", "Ajustes", "Salir"]


func _title() -> TitleScreen:
	var title := TITLE_SCENE.instantiate() as TitleScreen
	add_child_autofree(title)
	return title


func test_the_menu_in_order() -> void:
	var labels: Array[String] = []
	for button: Button in _title().buttons():
		labels.append(button.text)
	assert_eq(labels, LABELS)


func test_the_first_button_has_focus_on_arrival() -> void:
	var title := _title()
	assert_eq(get_viewport().gui_get_focus_owner(), title.buttons()[0])


func test_focus_describes_the_option() -> void:
	var title := _title()
	title.buttons()[1].grab_focus()
	assert_string_contains(title.description.text, "7777")
	assert_string_contains(title.description.text, "IP")
	for button: Button in title.buttons():
		button.grab_focus()
		assert_false(title.description.text.is_empty(), button.text)


func test_each_button_asks_the_shell_for_its_screen() -> void:
	var title := _title()
	watch_signals(title)
	var expected: Array[String] = ["solo_requested", "host_requested", "join_requested", "settings_requested", "quit_requested"]
	for i: int in expected.size():
		title.buttons()[i].pressed.emit()
		assert_signal_emitted(title, expected[i])


func test_logo_flavour_and_version() -> void:
	var title := _title()
	assert_eq(title.logo.text, "90 Millas")
	assert_eq(title.logo.theme_type_variation, &"TitleLabel")
	assert_eq(title.flavour.text, "De Cuba a la Florida: 90 millas de mar.")
	assert_eq(title.version.text, "v%s" % ProjectSettings.get_setting("application/config/version", ""))
	assert_false(String(ProjectSettings.get_setting("application/config/version", "")).is_empty())


func test_the_sea_moves() -> void:
	var title := _title()
	assert_not_null(title.sea)
	assert_true(title.sea.material is ShaderMaterial, "an animated sea shader")
