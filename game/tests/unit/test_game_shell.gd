extends GutTest
## ui-shell "Screen flow", "Settings", "Join screen" and "Run summary", driven through the
## shell's screens without a network (solo is the offline peer).

const SHELL_SCENE: PackedScene = preload("res://scenes/shell/game_shell.tscn")
const SETTINGS_PATH: String = "user://test_game_shell_settings.cfg"

var now_s: float = 0.0


func before_each() -> void:
	now_s = 0.0
	NetManager.start_solo()


func after_each() -> void:
	NetManager.leave()
	if FileAccess.file_exists(SETTINGS_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SETTINGS_PATH))


func _shell() -> GameShell:
	var shell := SHELL_SCENE.instantiate() as GameShell
	shell.settings_path = SETTINGS_PATH
	shell.clock = func() -> float: return now_s
	add_child_autofree(shell)
	return shell


func _cancel_event() -> InputEventAction:
	var event := InputEventAction.new()
	event.action = &"ui_cancel"
	event.pressed = true
	return event


func test_the_shell_is_the_main_scene() -> void:
	assert_eq(ProjectSettings.get_setting("application/run/main_scene"), "res://scenes/shell/game_shell.tscn")


func test_the_game_opens_on_the_title() -> void:
	var shell := _shell()
	assert_eq(shell.flow, GameShell.Flow.TITLE)
	assert_true(shell.screen is TitleScreen)


func test_solo_from_the_title() -> void:
	var shell := _shell()
	(shell.screen as TitleScreen).solo_requested.emit()
	assert_eq(shell.flow, GameShell.Flow.RUN)
	assert_true(shell.multiplayer.multiplayer_peer is OfflineMultiplayerPeer, "no network port")
	assert_not_null(shell.session)
	assert_eq(shell.session.peer_ids(), [1] as Array[int])
	assert_eq(shell.session.body(1).position, DevIsland.SPAWN_POINTS[0], "on the beach")
	assert_null(shell.screen, "no lobby or menu over the run")
	assert_not_null(shell.hud, "the run HUD")
	assert_true(shell.hud.solo)
	assert_null(shell.hud.wheel, "no quick chat in solo")


func test_settings_are_kept() -> void:
	var shell := _shell()
	(shell.screen as TitleScreen).settings_requested.emit()
	assert_eq(shell.flow, GameShell.Flow.SETTINGS)
	var screen := shell.screen as SettingsScreen
	screen.name_field.text = "Dayana"
	screen.name_field.text_submitted.emit("Dayana")
	screen.scale_picker.select(2)
	screen.scale_picker.item_selected.emit(2)
	assert_eq(GameSettings.load_from(SETTINGS_PATH).player_name, "Dayana")
	assert_eq(GameSettings.load_from(SETTINGS_PATH).ui_scale, 2)
	screen.back_requested.emit()
	assert_eq(shell.flow, GameShell.Flow.TITLE)


func test_esc_goes_back_from_menu_screens() -> void:
	var shell := _shell()
	(shell.screen as TitleScreen).settings_requested.emit()
	shell.screen._unhandled_input(_cancel_event())
	assert_eq(shell.flow, GameShell.Flow.TITLE)
	(shell.screen as TitleScreen).join_requested.emit()
	assert_eq(shell.flow, GameShell.Flow.JOIN)
	shell.screen._unhandled_input(_cancel_event())
	assert_eq(shell.flow, GameShell.Flow.TITLE)


func test_join_addresses() -> void:
	assert_eq(JoinScreen.parse_address("192.168.1.20"), {"address": "192.168.1.20", "port": 7777, "error": ""})
	assert_eq(JoinScreen.parse_address(" 10.0.0.5:7780 "), {"address": "10.0.0.5", "port": 7780, "error": ""})
	assert_false(String(JoinScreen.parse_address("192.168.1.20:99999")["error"]).is_empty(), "bad port")
	assert_false(String(JoinScreen.parse_address("")["error"]).is_empty(), "blank")
	assert_false(String(JoinScreen.parse_address("host:abc")["error"]).is_empty(), "port not a number")


func test_a_bad_port_is_refused_on_the_join_screen() -> void:
	var shell := _shell()
	(shell.screen as TitleScreen).join_requested.emit()
	var screen := shell.screen as JoinScreen
	watch_signals(screen)
	screen.address_field.text = "192.168.1.20:99999"
	screen.connect_button.pressed.emit()
	assert_signal_not_emitted(screen, "connect_requested")
	assert_string_contains(screen.status.text, "puerto")
	assert_true(shell.multiplayer.multiplayer_peer is OfflineMultiplayerPeer, "nothing connects")


func test_end_of_a_solo_run() -> void:
	var shell := _shell()
	(shell.screen as TitleScreen).solo_requested.emit()
	now_s = 180.0
	shell.session.body(1).meters.dead = true
	assert_eq(shell.flow, GameShell.Flow.SUMMARY)
	var summary := shell.screen as SummaryScreen
	assert_eq(summary.run_length.text, "3:00")
	assert_eq(summary.rows().size(), 1)
	assert_string_contains(summary.rows()[0], "Balsero")
	assert_string_contains(summary.rows()[0], "Murió")
	summary.home_button.pressed.emit()
	assert_eq(shell.flow, GameShell.Flow.TITLE)
	assert_null(shell.session, "the run is over")


func test_a_run_summary_formats_its_length() -> void:
	assert_eq(SummaryScreen.format_length(185.4), "3:05")
	assert_eq(SummaryScreen.format_length(3725.0), "62:05")
	assert_eq(SummaryScreen.format_length(-3.0), "0:00")


func test_a_run_ends_when_the_last_living_teammate_is_removed() -> void:
	# A dropped teammate keeps the run open until they are removed; the removal ends it.
	var shell := _shell()
	(shell.screen as TitleScreen).solo_requested.emit()
	shell.session._add_player(7)
	shell.session.body(1).meters.dead = true
	assert_eq(shell.flow, GameShell.Flow.RUN, "a teammate is still in the run")
	shell.session._remove_player(7)
	assert_eq(shell.flow, GameShell.Flow.SUMMARY)


func test_enter_while_connecting_does_not_join_twice() -> void:
	var shell := _shell()
	(shell.screen as TitleScreen).join_requested.emit()
	var screen := shell.screen as JoinScreen
	var asked: Array[String] = []
	for connection: Dictionary in screen.connect_requested.get_connections():
		screen.connect_requested.disconnect(connection["callable"])
	screen.connect_requested.connect(func(address: String, _port: int) -> void: asked.append(address))
	screen.address_field.text = "192.168.1.20"
	screen.address_field.text_submitted.emit(screen.address_field.text)
	screen.address_field.text_submitted.emit(screen.address_field.text)
	assert_eq(asked, ["192.168.1.20"] as Array[String], "one attempt at a time")
