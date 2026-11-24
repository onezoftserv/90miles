extends GutTest
## ui-shell "Lobby", scenarios "The rematch lobby" and "The host closes the lobby" (menu-clarity
## design D7), with real shells for a host and a client over ENet on localhost (ShellHarness). The
## 1-player cases are in test_lobby_screen.gd. GUT fails any case that logs an engine error.

var shells: ShellHarness


func before_each() -> void:
	NetManager.start_solo()
	WeatherManager.stop()
	shells = ShellHarness.new(self)


func after_each() -> void:
	shells.teardown()
	WeatherManager.stop()
	get_tree().paused = false
	NetManager.leave()


func _lobby_of(shell: GameShell) -> LobbyScreen:
	return shell.screen as LobbyScreen


func _two_aboard(shell: GameShell) -> Callable:
	return func() -> bool:
		var lobby := _lobby_of(shell)
		return lobby != null and lobby.heading.text == "A bordo (2/4)"


func test_the_rematch_lobby_says_so_with_both_aboard() -> void:
	var host := shells.add_host("Yuni", func() -> int: return 11)
	var papo := await shells.join_lobby("Papo")
	assert_not_null(papo)
	if papo == null:
		return
	assert_false(_lobby_of(host).rematch_line.visible, "a fresh lobby is not a rematch")
	assert_true(await shells.begin_run(), "both in the run")
	assert_true(await shells.end_run(), "both on their summaries")
	var summary := host.screen as SummaryScreen
	summary.shown_at_s -= SummaryScreen.ACCEPT_DELAY_S
	summary.restart_button.pressed.emit()
	assert_true(await shells.wait(_two_aboard(host)), "the host's lobby reads A bordo (2/4)")
	assert_true(await shells.wait(_two_aboard(papo)), "Papo's lobby reads A bordo (2/4)")
	for shell: GameShell in [host, papo]:
		var lobby := _lobby_of(shell)
		assert_true(lobby.rematch_line.visible, "says it is a rematch")
		assert_eq(lobby.rematch_line.text, "Otro viaje con el mismo grupo.")
		assert_eq(lobby.seats(), ["Yuni (anfitrión)", "Papo", "Libre", "Libre"] as Array[String])


func test_the_host_closing_the_lobby_asks_then_sends_the_client_to_host_lost() -> void:
	var host := shells.add_host("Yuni", func() -> int: return 12)
	var papo := await shells.join_lobby("Papo")
	assert_not_null(papo)
	if papo == null:
		return
	assert_true(await shells.wait(_two_aboard(host)))
	var lobby := _lobby_of(host)
	assert_eq(lobby.leave_button.text, "Cerrar partida")
	lobby.leave_button.pressed.emit()
	assert_not_null(lobby.confirm, "the host is asked first")
	if lobby.confirm == null:
		return
	assert_eq(get_viewport().gui_get_focus_owner(), lobby.confirm.cancel_button, "Cancelar focused")
	lobby.confirm.cancel_button.pressed.emit()
	await wait_process_frames(1)
	assert_eq(host.flow, GameShell.Flow.LOBBY, "Cancelar keeps the lobby")
	assert_eq(papo.flow, GameShell.Flow.LOBBY)
	lobby.leave_button.pressed.emit()
	lobby.confirm.confirm_button.pressed.emit()
	assert_true(await shells.wait(func() -> bool: return host.flow == GameShell.Flow.TITLE), "the host is on the title")
	# NetManager.leave() closes the game's peer; the harness closes the branch's.
	shells.go_home(host)
	assert_true(await shells.wait(func() -> bool: return papo.flow == GameShell.Flow.HOST_LOST), "Papo shows host-lost")
