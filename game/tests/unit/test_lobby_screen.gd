extends GutTest
## ui-shell "Lobby" and "Screen flow": the lobby screen alone, and the shell's host, join
## failure and host-lost paths on the game's own multiplayer API (hosting on a free port).

const LOBBY_SCENE: PackedScene = preload("res://scenes/shell/lobby_screen.tscn")
const SHELL_SCENE: PackedScene = preload("res://scenes/shell/game_shell.tscn")
const SETTINGS_PATH: String = "user://test_lobby_screen_settings.cfg"


func before_each() -> void:
	NetManager.start_solo()


func after_each() -> void:
	NetManager.leave()
	if FileAccess.file_exists(SETTINGS_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SETTINGS_PATH))


func _lobby(host: bool) -> LobbyScreen:
	var lobby := LOBBY_SCENE.instantiate() as LobbyScreen
	lobby.is_host = host
	add_child_autofree(lobby)
	return lobby


func _shell() -> GameShell:
	var shell := SHELL_SCENE.instantiate() as GameShell
	shell.settings_path = SETTINGS_PATH
	shell.port = 0
	add_child_autofree(shell)
	return shell


func test_the_host_sees_the_roster_and_the_start_button() -> void:
	var lobby := _lobby(true)
	lobby.show_roster({5: "Papo", 1: "Yuni"} as Dictionary[int, String])
	assert_eq(lobby.rows(), ["Yuni (anfitrión)", "Papo"] as Array[String], "the host first")
	assert_true(lobby.start_button.visible)
	assert_string_contains(lobby.note.text, "7777")
	assert_false(lobby.waiting.visible)


func test_a_client_waits_for_the_host() -> void:
	var lobby := _lobby(false)
	assert_false(lobby.start_button.visible)
	assert_true(lobby.waiting.visible)
	assert_eq(lobby.waiting.text, "Esperando al anfitrión…")


func test_buttons_ask_the_shell() -> void:
	var lobby := _lobby(true)
	watch_signals(lobby)
	lobby.start_button.pressed.emit()
	lobby.leave_button.pressed.emit()
	assert_signal_emitted(lobby, "start_requested")
	assert_signal_emitted(lobby, "back_requested")


func test_only_lan_ipv4_addresses_are_shown() -> void:
	var shown := LobbyScreen.local_addresses(PackedStringArray(["127.0.0.1", "192.168.1.20", "::1", "fe80::1", "10.0.0.5", "169.254.3.4"]))
	assert_eq(shown, PackedStringArray(["10.0.0.5", "192.168.1.20"]))


func test_host_and_start() -> void:
	var shell := _shell()
	(shell.screen as TitleScreen).host_requested.emit()
	assert_eq(shell.flow, GameShell.Flow.LOBBY)
	var lobby := shell.screen as LobbyScreen
	assert_eq(lobby.rows(), ["Balsero (anfitrión)"] as Array[String])
	assert_true(NetManager.is_online(), "hosting")
	assert_eq(shell.session.peer_ids().size(), 0, "nobody spawned yet")
	lobby.start_button.pressed.emit()
	assert_eq(shell.flow, GameShell.Flow.RUN)
	assert_eq(shell.session.body(1).position, DevIsland.SPAWN_POINTS[0])
	shell.back_to_title()
	assert_eq(shell.flow, GameShell.Flow.TITLE)
	assert_false(NetManager.is_online())


func test_leaving_the_lobby_returns_to_the_title() -> void:
	var shell := _shell()
	(shell.screen as TitleScreen).host_requested.emit()
	(shell.screen as LobbyScreen).back_requested.emit()
	assert_eq(shell.flow, GameShell.Flow.TITLE)
	assert_null(shell.session)
	assert_false(NetManager.is_online())


func test_a_failed_join_says_so_and_stays() -> void:
	var shell := _shell()
	(shell.screen as TitleScreen).join_requested.emit()
	var join := shell.screen as JoinScreen
	join.address_field.text = "127.0.0.1:7999"
	join.connect_button.pressed.emit()
	assert_eq(join.status.text, JoinScreen.CONNECTING)
	NetManager.join_failed.emit()
	assert_eq(shell.flow, GameShell.Flow.JOIN)
	assert_eq(join.status.text, JoinScreen.FAILED)
	assert_null(shell.session)


func test_host_lost() -> void:
	var shell := _shell()
	(shell.screen as TitleScreen).solo_requested.emit()
	shell.session.host_lost.emit()
	assert_eq(shell.flow, GameShell.Flow.HOST_LOST)
	assert_not_null(shell.host_lost_screen)
	shell.host_lost_screen.back_requested.emit()
	assert_eq(shell.flow, GameShell.Flow.TITLE)
