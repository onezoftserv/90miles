extends GutTest
## coop-networking "Pause" and ui-shell "Run menu", "Abandoning a run" and "Pause and host-lost
## windows" with a host and a client (run-menu design D2, D5, D8): real shells over ENet on
## localhost (ShellHarness). The client's menu pauses nothing and holds only its own player; the
## host's "Abandonar" sends the client to the host-lost screen; a client's leaves the host listing it
## "Desconectado". GUT fails any case that logs an engine error. The solo cases are in
## test_run_menu.gd and test_game_shell.gd.

const HOLD_S: float = 0.2

var shells: ShellHarness


func before_each() -> void:
	NetManager.start_solo()
	WeatherManager.stop()
	shells = ShellHarness.new(self)


func after_each() -> void:
	Input.action_release(&"move_right")
	shells.teardown()
	WeatherManager.stop()
	get_tree().paused = false
	NetManager.leave()


# Yuni hosting and Papo, both in the run. [] on a timeout.
func _pair_in_run() -> Array[GameShell]:
	var host := shells.add_host("Yuni", func() -> int: return 7)
	var papo := await shells.join_lobby("Papo")
	assert_not_null(papo, "Papo reached the lobby")
	if papo == null:
		return []
	assert_true(await shells.begin_run(), "both in the run")
	return [host, papo]


# `shell` confirms "Abandonar". In the game, back_to_title() closes the peer through NetManager in
# the same call; the harness closes the branch's peer in the same deferred flush, right after it, so
# no packet reaches a run that is already freed.
func _confirm_abandon(shell: GameShell) -> void:
	var menu: PauseMenu = shell.hud.pause_menu
	menu.abandon_confirmed.connect(func() -> void: shells.go_home(shell), CONNECT_DEFERRED)
	menu.open()
	menu.ask_abandon()
	(menu.view as ConfirmBox).confirm_button.pressed.emit()


func _row(hud: RunHud, player_name: String) -> String:
	hud.refresh()
	for row: String in hud.teammate_rows():
		if row.begins_with(player_name + " "):
			return row
	return ""


func test_a_client_menu_pauses_nothing_and_holds_its_own_player_on_the_host() -> void:
	var pair := await _pair_in_run()
	if pair.is_empty():
		return
	var host: GameShell = pair[0]
	var papo: GameShell = pair[1]
	var papo_id: int = shells.peer_id(papo)
	var own: PlayerBody = papo.session.body(papo_id)
	var on_host: PlayerBody = host.session.body(papo_id)
	# Papo walks east with real input (only his own body reads the keyboard).
	own.player_input.enabled = true
	Input.action_press(&"move_right")
	var walking := func() -> bool: return on_host.velocity.x > 0.0
	assert_true(await shells.wait(walking), "the host sees Papo walk")
	var menu: PauseMenu = papo.hud.pause_menu
	assert_true(menu.open())
	assert_eq(menu.title.text, "Menú")
	assert_true(menu.line.visible, "La partida sigue.")
	assert_false(get_tree().paused, "nothing pauses")
	assert_true(host.hud.pause_menu.visible == false, "the host's menu stays shut")
	await get_tree().create_timer(HOLD_S).timeout
	var held_at: Vector2 = on_host.position
	await wait_physics_frames(10)
	assert_almost_eq(on_host.position.distance_to(held_at), 0.0, 0.5, "within 0.2 s the host has Papo standing still")
	assert_true(host.session.can_process(), "the host's run goes on")
	menu.resume()
	assert_true(await shells.wait(walking), "closing the menu lets Papo walk again")


func test_the_host_abandoning_sends_the_client_to_host_lost() -> void:
	var pair := await _pair_in_run()
	if pair.is_empty():
		return
	var host: GameShell = pair[0]
	var papo: GameShell = pair[1]
	papo.hud.pause_menu.open()
	_confirm_abandon(host)
	assert_true(await shells.wait(func() -> bool: return host.flow == GameShell.Flow.TITLE), "the host is on the title")
	assert_null(host.session, "the host's run is gone")
	assert_true(await shells.wait(func() -> bool: return papo.flow == GameShell.Flow.HOST_LOST), "Papo shows host-lost")
	var lost: HostLostScreen = papo.host_lost_screen
	assert_not_null(lost)
	if lost == null:
		return
	await wait_process_frames(1)
	assert_eq(get_viewport().gui_get_focus_owner(), lost.back_button, "Volver has the focus")
	assert_true(papo.hud == null or not papo.hud.pause_menu.visible, "Papo's open menu closed")
	var cancel := InputEventAction.new()
	cancel.action = &"ui_cancel"
	cancel.pressed = true
	lost._unhandled_input(cancel)
	assert_eq(papo.flow, GameShell.Flow.TITLE, "Esc leaves to the title")


func test_a_client_abandoning_leaves_its_player_waiting_on_the_host() -> void:
	var pair := await _pair_in_run()
	if pair.is_empty():
		return
	var host: GameShell = pair[0]
	var papo: GameShell = pair[1]
	_confirm_abandon(papo)
	assert_true(await shells.wait(func() -> bool: return papo.flow == GameShell.Flow.TITLE), "Papo is on the title")
	var dropped := func() -> bool: return _row(host.hud, "Papo").ends_with("Desconectado")
	assert_true(await shells.wait(dropped), "the host lists Papo as Desconectado: %s" % _row(host.hud, "Papo"))
	assert_eq(host.flow, GameShell.Flow.RUN, "the host's run goes on")
