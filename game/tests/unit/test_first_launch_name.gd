extends GutTest
## ui-shell "First-launch name" (run-menu design D7; owner, 2026-11-23: once per install, Esc
## skips): while the name is "Balsero" and this install was never asked, the title opens a name
## window. Exactly 1 player, offline.

const SHELL_SCENE: PackedScene = preload("res://scenes/shell/game_shell.tscn")

var settings_path: String = UserTmp.path("test_first_launch_name.cfg")


func before_each() -> void:
	NetManager.start_solo()
	_remove()


func after_each() -> void:
	NetManager.leave()
	_remove()


func _remove() -> void:
	if FileAccess.file_exists(settings_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(settings_path))


func _shell() -> GameShell:
	var shell := SHELL_SCENE.instantiate() as GameShell
	shell.settings_path = settings_path
	add_child_autofree(shell)
	return shell


func _title(shell: GameShell) -> TitleScreen:
	return shell.screen as TitleScreen


func _focused() -> Control:
	return get_viewport().gui_get_focus_owner()


func _cancel_event() -> InputEventAction:
	var event := InputEventAction.new()
	event.action = &"ui_cancel"
	event.pressed = true
	return event


func test_a_first_launch_opens_the_window_with_the_field_focused() -> void:
	var shell := _shell()
	var prompt := _title(shell).name_prompt
	assert_not_null(prompt, "the name window is open")
	if prompt == null:
		return
	assert_eq(prompt.question.text, "¿Cómo te llamas?")
	assert_eq(prompt.done_button.text, "Listo")
	assert_eq(_focused(), prompt.field, "the field has the focus")
	for button: Button in _title(shell).buttons():
		assert_eq(button.focus_mode, Control.FOCUS_NONE, "'%s' gives up the focus" % button.text)
	assert_true(shell.multiplayer.multiplayer_peer is OfflineMultiplayerPeer, "offline")


func test_a_name_given_is_saved_and_never_asked_again() -> void:
	var shell := _shell()
	var prompt := _title(shell).name_prompt
	prompt.field.text = "Dayana"
	prompt.field.text_submitted.emit("Dayana")
	await wait_process_frames(1)
	assert_null(_title(shell).name_prompt, "the window closed")
	assert_eq(shell.settings.player_name, "Dayana")
	var saved := GameSettings.load_from(settings_path)
	assert_eq(saved.player_name, "Dayana", "saved")
	assert_true(saved.name_asked)
	assert_eq(_focused(), _title(shell).buttons()[0], "Jugar solo has the focus")
	assert_eq(_title(shell).buttons()[0].focus_mode, Control.FOCUS_ALL)
	var again := _shell()
	assert_null(_title(again).name_prompt, "the next launch opens no window")


func test_a_blank_name_keeps_balsero() -> void:
	var shell := _shell()
	var prompt := _title(shell).name_prompt
	prompt.field.text = "   "
	prompt.done_button.pressed.emit()
	assert_eq(GameSettings.load_from(settings_path).player_name, GameSettings.DEFAULT_NAME)
	assert_true(GameSettings.load_from(settings_path).name_asked)


func test_esc_skips_and_is_never_asked_again() -> void:
	var shell := _shell()
	var prompt := _title(shell).name_prompt
	prompt.field.text = "Papo"
	prompt._unhandled_input(_cancel_event())
	await wait_process_frames(1)
	assert_null(_title(shell).name_prompt)
	assert_eq(shell.flow, GameShell.Flow.TITLE, "Esc closes only the window")
	var saved := GameSettings.load_from(settings_path)
	assert_eq(saved.player_name, GameSettings.DEFAULT_NAME, "the name stays Balsero")
	assert_true(saved.name_asked)
	assert_null(_title(_shell()).name_prompt)


func test_a_name_chosen_before_this_change_is_not_asked() -> void:
	var config := ConfigFile.new()
	config.set_value("player", "name", "Yuni")
	config.save(settings_path)
	var shell := _shell()
	assert_null(_title(shell).name_prompt)
	assert_eq(_focused(), _title(shell).buttons()[0])


func test_ajustes_still_changes_the_name_after_asking() -> void:
	var shell := _shell()
	_title(shell).name_prompt._unhandled_input(_cancel_event())
	await wait_process_frames(1)
	shell.show_settings()
	var screen := shell.screen as SettingsScreen
	screen.name_field.text_submitted.emit("Dayana")
	assert_eq(GameSettings.load_from(settings_path).player_name, "Dayana")
	assert_true(GameSettings.load_from(settings_path).name_asked, "asking stays done")
