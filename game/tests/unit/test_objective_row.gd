extends GutTest
## hud-clarity, ui-shell "Objective row" and "HUD layout", with exactly 1 player, offline: the row
## shows under the clock inside (152,20)-(380,30), centred, in the session's language; it hides while
## a sign note is open and while a screen is over the run, and shows again after.

const SHELL_SCENE: PackedScene = preload("res://scenes/shell/game_shell.tscn")
const BAND: Rect2 = Rect2(152.0, 20.0, 228.0, 10.0)
const CLOCK_RECT: Rect2 = Rect2(152.0, 4.0, 228.0, 14.0)
const MORNING_S: float = 90.0

var settings_path: String = UserTmp.path("test_objective_row_settings.cfg")


func after_each() -> void:
	WeatherManager.stop()
	NetManager.leave()
	if FileAccess.file_exists(settings_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(settings_path))


func _shell() -> GameShell:
	NetManager.start_solo()
	WeatherManager.stop()
	var shell := SHELL_SCENE.instantiate() as GameShell
	shell.settings_path = settings_path
	add_child_autofree(shell)
	(shell.screen as TitleScreen).solo_requested.emit()
	shell.session.body(1).player_input.enabled = false
	WeatherManager.sky.weather.rolls_enabled = false
	WeatherManager.sky.start_at(MORNING_S)
	return shell


func _row(shell: GameShell) -> ObjectiveRow:
	return shell.hud.get_node(^"ObjectiveRow") as ObjectiveRow


func test_the_row_shows_under_the_clock() -> void:
	var shell := _shell()
	await wait_process_frames(2)
	var row := _row(shell)
	assert_not_null(row, "the objective row")
	if row == null:
		return
	assert_true(row.is_visible_in_tree())
	assert_eq(row.label.text, "Arma la balsa: 0/6 madera")
	assert_eq(row.theme_type_variation, &"HudPanelThin")
	var rect := row.get_global_rect()
	assert_true(BAND.encloses(rect), "inside the band: %s" % rect)
	assert_false(rect.intersects(CLOCK_RECT), "under the clock row")
	assert_almost_eq(rect.get_center().x, CLOCK_RECT.get_center().x, 1.0, "centred under the clock")
	assert_eq(rect.size.y, 10.0)


func test_the_row_follows_the_goal() -> void:
	var shell := _shell()
	await wait_process_frames(2)
	shell.session.body(1).inventory.add(&"driftwood", 6)
	await wait_process_frames(2)
	assert_eq(_row(shell).label.text, "Arma la balsa: 0/2 cámaras")
	assert_true(BAND.encloses(_row(shell).get_global_rect()), "resized, still inside the band")


func test_english() -> void:
	var shell := _shell()
	shell.session.locale = "en"
	await wait_process_frames(2)
	assert_eq(_row(shell).label.text, "Build the raft: 0/6 wood")


func test_a_sign_note_covers_the_row() -> void:
	var shell := _shell()
	await wait_process_frames(2)
	var sign := IslandSign.new()
	sign.line_es = "Pa'l que venga detrás."
	shell.session.add_child(sign)
	sign.global_position = shell.session.body(1).global_position + Vector2(0.0, -8.0)
	shell.hud.sign_note.open(sign)
	await wait_process_frames(2)
	assert_true(shell.hud.sign_note.is_open())
	assert_false(_row(shell).is_visible_in_tree(), "hidden while the note is open")
	shell.hud.sign_note.close()
	await wait_process_frames(2)
	assert_true(_row(shell).is_visible_in_tree(), "shown again after")


func test_a_screen_hides_the_row() -> void:
	var shell := _shell()
	await wait_process_frames(2)
	shell.hud.set_screen_shown(true)
	await wait_process_frames(2)
	assert_false(_row(shell).is_visible_in_tree())
	shell.hud.set_screen_shown(false)
	await wait_process_frames(2)
	assert_true(_row(shell).is_visible_in_tree())
