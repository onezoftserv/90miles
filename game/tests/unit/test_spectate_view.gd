extends GutTest
## ui-shell "Spectating a teammate", "Whom a spectator watches", "Switching the watched teammate"
## and "Losing the watched teammate", offline: SpectateView on an offline session with extra
## bodies (peer 1 is the local player, peers 2-4 its teammates), the cameras it switches, and
## "The HUD while watching": the run HUD's line, meters, strip and keys.

const SESSION_SCENE: PackedScene = preload("res://scenes/net/coop_session.tscn")
const HUD_SCENE: PackedScene = preload("res://scenes/ui/run_hud.tscn")
const NAMES: Dictionary[int, String] = {2: "Papo", 3: "Dayana", 4: "Ramón"}


func before_each() -> void:
	NetManager.start_solo()


# An offline session: peer 1 at the origin and `extra` teammates where `spots` says.
func _session(spots: Dictionary[int, Vector2] = {}) -> CoopSession:
	var session := SESSION_SCENE.instantiate() as CoopSession
	session.local_name = "Yuni"
	add_child_autofree(session)
	session.start()
	for peer_id: int in spots:
		session._add_player(peer_id)
		session.roster[peer_id] = NAMES[peer_id]
	for peer_id: int in session.peer_ids():
		var player := session.body(peer_id)
		player.player_input.enabled = false
		player.position = spots.get(peer_id, Vector2.ZERO)
	return session


func _view(session: CoopSession, solo: bool = false) -> SpectateView:
	var view := SpectateView.new()
	view.bind(session, CoopSession.HOST_ID, solo)
	view.set_own(session.body(CoopSession.HOST_ID))
	return view


func _kill(session: CoopSession, peer_id: int) -> void:
	session.body(peer_id).meters.dead = true


func _watched_peer(session: CoopSession, view: SpectateView) -> int:
	return session.peer_of(view.watched()) if view.active() else 0


func test_a_solo_death_never_watches() -> void:
	# 1 player, offline: nobody to watch, and the view stays on the player's own body.
	var session := _session()
	var view := _view(session, true)
	_kill(session, 1)
	view.update()
	assert_false(view.active(), "a solo death watches nobody")
	assert_null(view.watched())
	assert_true(session.body(1).camera.enabled, "the solo player's own camera stays on")


func test_a_living_player_never_watches() -> void:
	var session := _session({2: Vector2(40.0, 0.0)})
	var view := _view(session)
	view.update()
	view.cycle(1)
	assert_false(view.active(), "a living player who is not waiting watches nobody")
	assert_true(session.body(1).camera.enabled)
	assert_false(session.body(2).camera.enabled)


func test_the_nearest_teammate_first() -> void:
	var session := _session({2: Vector2(200.0, 0.0), 3: Vector2(40.0, 0.0)})
	var view := _view(session)
	_kill(session, 1)
	view.update()
	assert_true(view.active())
	assert_eq(_watched_peer(session, view), 3, "Dayana stands nearer")


func test_stepping_follows_the_list_and_wraps() -> void:
	var session := _session({2: Vector2(40.0, 0.0), 3: Vector2(200.0, 0.0), 4: Vector2(300.0, 0.0)})
	var view := _view(session)
	_kill(session, 1)
	view.update()
	assert_eq(_watched_peer(session, view), 2)
	view.cycle(1)
	assert_eq(_watched_peer(session, view), 3)
	view.cycle(1)
	assert_eq(_watched_peer(session, view), 4)
	view.cycle(1)
	assert_eq(_watched_peer(session, view), 2, "next wraps round to the first")
	view.cycle(-1)
	assert_eq(_watched_peer(session, view), 4, "previous wraps round to the last")


func test_dead_and_waiting_teammates_are_skipped() -> void:
	var session := _session({2: Vector2(10.0, 0.0), 3: Vector2(20.0, 0.0), 4: Vector2(300.0, 0.0)})
	var view := _view(session)
	_kill(session, 2)
	IslandArrival.hold(session.body(3))
	_kill(session, 1)
	view.update()
	assert_eq(_watched_peer(session, view), 4, "only Ramón is still playing")
	view.cycle(1)
	assert_eq(_watched_peer(session, view), 4)
	view.cycle(-1)
	assert_eq(_watched_peer(session, view), 4)


func test_a_disconnected_teammate_only_when_no_connected_one_is_left() -> void:
	var session := _session({2: Vector2(10.0, 0.0), 3: Vector2(300.0, 0.0)})
	session._dropped[2] = CoopSession.DISCONNECT_DOWNED_S
	session.body(2).net.net_dropped = true
	session.body(2).set_downed(true)
	var view := _view(session)
	_kill(session, 1)
	view.update()
	assert_eq(_watched_peer(session, view), 3, "the connected Dayana comes first, though Papo is nearer")
	assert_false(view.watched_dropped())
	view.cycle(1)
	assert_eq(_watched_peer(session, view), 3, "stepping never reaches the disconnected Papo")
	_kill(session, 3)
	view.update()
	assert_eq(_watched_peer(session, view), 2, "with nobody connected left, the disconnected Papo is watched")
	assert_true(view.watched_dropped())


func test_losing_the_watched_teammate_moves_to_the_one_nearest_them() -> void:
	# From Yuni (0, 0) Ramón is nearer; from Papo's last spot Dayana is.
	var session := _session({2: Vector2(50.0, 0.0), 3: Vector2(90.0, 0.0), 4: Vector2(-60.0, 0.0)})
	var view := _view(session)
	_kill(session, 1)
	view.update()
	assert_eq(_watched_peer(session, view), 2)
	_kill(session, 2)
	view.update()
	assert_eq(_watched_peer(session, view), 3, "the one nearest the lost teammate, not the dead player")


func test_a_teammate_who_goes_to_wait_is_lost() -> void:
	var session := _session({2: Vector2(40.0, 0.0), 3: Vector2(300.0, 0.0)})
	var view := _view(session)
	_kill(session, 1)
	view.update()
	assert_eq(_watched_peer(session, view), 2)
	IslandArrival.hold(session.body(2))
	view.update()
	assert_eq(_watched_peer(session, view), 3)
	assert_false(session.body(2).camera.enabled, "the lost teammate's camera is off again")


func test_a_freed_body_is_lost() -> void:
	var session := _session({2: Vector2(40.0, 0.0), 3: Vector2(300.0, 0.0)})
	var view := _view(session)
	_kill(session, 1)
	view.update()
	assert_eq(_watched_peer(session, view), 2)
	session.body(2).free()
	view.update()
	assert_eq(_watched_peer(session, view), 3, "a removed body is never watched")


func test_nobody_left_goes_back_to_the_own_body() -> void:
	var session := _session({2: Vector2(40.0, 0.0)})
	var view := _view(session)
	_kill(session, 1)
	view.update()
	assert_true(view.active())
	_kill(session, 2)
	view.update()
	assert_false(view.active(), "nobody is left to watch")
	assert_true(session.body(1).camera.enabled, "the view is back on the player's own body")
	assert_false(session.body(2).camera.enabled)


func test_a_freed_own_body_watches_nobody() -> void:
	# The host lost: the client's bodies go before its HUD does.
	var session := _session({2: Vector2(40.0, 0.0)})
	var view := _view(session)
	_kill(session, 1)
	view.update()
	assert_true(view.active())
	session.body(1).free()
	view.update()
	assert_false(view.active())
	assert_false(session.body(2).camera.enabled, "the teammate's camera is off again")


func test_a_waiting_rider_watches_until_the_party_lands() -> void:
	var session := _session({2: Vector2(40.0, 0.0)})
	var view := _view(session)
	IslandArrival.hold(session.body(1))
	view.update()
	assert_eq(_watched_peer(session, view), 2, "a rider waiting on the shore watches the one still playing")
	IslandArrival.land(session.body(1), Vector2(16.0, 16.0), session.terrain)
	view.update()
	assert_false(view.active(), "the landed rider plays again")
	assert_true(session.body(1).camera.enabled)


func test_cameras_while_watching_and_after() -> void:
	var session := _session({2: Vector2(40.0, 0.0), 3: Vector2(300.0, 0.0)})
	var view := _view(session)
	var own := session.body(1)
	_kill(session, 1)
	view.update()
	assert_false(own.camera.enabled, "the dead player's own camera is off")
	assert_true(session.body(2).camera.enabled, "the watched teammate's camera is on")
	assert_false(session.body(3).camera.enabled)
	view.cycle(1)
	assert_false(session.body(2).camera.enabled, "the camera left behind is off")
	assert_true(session.body(3).camera.enabled)
	assert_false(own.camera.enabled)


func test_a_rebound_teammate_keeps_the_camera() -> void:
	# coop-reconnect: rebind() runs refresh_local(), which turns a teammate's camera off.
	var session := _session({2: Vector2(40.0, 0.0)})
	var view := _view(session)
	_kill(session, 1)
	view.update()
	session.body(2).refresh_local()
	assert_false(session.body(2).camera.enabled, "refresh_local turned it off")
	view.update()
	assert_true(session.body(2).camera.enabled, "the view turns it on again")


func test_the_dead_body_does_not_move_while_watching() -> void:
	# A and D step the view and are also move_left / move_right: a dead body still goes nowhere.
	var session := _session({2: Vector2(40.0, 0.0)})
	var view := _view(session)
	var own := session.body(1)
	_kill(session, 1)
	view.update()
	var before: Vector2 = own.position
	own.intent = MoveIntent.create(Vector2.RIGHT, false, false, false)
	for i: int in 10:
		own.advance(1.0 / 60.0)
	assert_eq(own.position, before)


# ui-shell "The HUD while watching": the run HUD bound to the offline session as a co-op HUD.
func _hud(session: CoopSession, solo: bool = false) -> RunHud:
	var hud := HUD_SCENE.instantiate() as RunHud
	add_child_autofree(hud)
	hud.bind(session, CoopSession.HOST_ID, solo)
	return hud


# A key press as the keyboard sends it: the walk keys match by position, the engine's arrows by key.
func _key(keycode: Key) -> InputEventKey:
	var event := InputEventKey.new()
	event.physical_keycode = keycode
	event.keycode = keycode
	event.pressed = true
	return event


func test_the_hud_line_and_the_watched_meters() -> void:
	var session := _session({2: Vector2(40.0, 0.0)})
	var hud := _hud(session)
	session.body(2).meters.thirst = 30.0
	_kill(session, 1)
	await wait_process_frames(2)
	assert_true(hud.watching_panel.visible)
	assert_eq(hud.watching_label.text, "Mirando a: Papo  [A] [D] Cambiar")
	assert_eq(hud.meters.shown(), session.body(2).meters, "the meters panel shows Papo's meters")
	assert_eq(hud.meters.bar_for(DataEnums.Meter.THIRST).value_label.text, "30")
	assert_false(hud.strip.visible, "the dead player's strip is hidden")
	assert_false(hud.prompt.visible)
	assert_not_null(hud.wheel, "quick chat stays")


func test_a_disconnected_teammate_is_marked_on_the_line() -> void:
	var session := _session({2: Vector2(40.0, 0.0)})
	session._dropped[2] = CoopSession.DISCONNECT_DOWNED_S
	session.body(2).net.net_dropped = true
	var hud := _hud(session)
	_kill(session, 1)
	hud.refresh()
	assert_eq(hud.watching_label.text, "Mirando a: Papo (desconectado)  [A] [D] Cambiar")


func test_the_keys_step_the_view() -> void:
	var session := _session({2: Vector2(40.0, 0.0), 3: Vector2(300.0, 0.0)})
	var hud := _hud(session)
	_kill(session, 1)
	hud.refresh()
	assert_eq(session.peer_of(hud.spectate.watched()), 2)
	hud._input(_key(KEY_D))
	assert_eq(session.peer_of(hud.spectate.watched()), 3, "D steps to the next teammate")
	assert_eq(hud.watching_label.text, "Mirando a: Dayana  [A] [D] Cambiar")
	hud._input(_key(KEY_A))
	assert_eq(session.peer_of(hud.spectate.watched()), 2, "A steps back")
	hud._input(_key(KEY_RIGHT))
	assert_eq(session.peer_of(hud.spectate.watched()), 3, "→ steps to the next teammate")
	hud._input(_key(KEY_LEFT))
	assert_eq(session.peer_of(hud.spectate.watched()), 2, "← steps back")
	var stick := InputEventJoypadMotion.new()
	stick.axis = JOY_AXIS_LEFT_X
	stick.axis_value = 1.0
	hud._input(stick)
	assert_eq(session.peer_of(hud.spectate.watched()), 2, "a stick does not step: it repeats while held")
	var pad := InputEventJoypadButton.new()
	pad.button_index = JOY_BUTTON_DPAD_RIGHT
	pad.pressed = true
	hud._input(pad)
	assert_eq(session.peer_of(hud.spectate.watched()), 3, "the D-pad steps too")
	assert_eq(hud.watching_label.text, "Mirando a: Dayana  [Cruz ←] [Cruz →] Cambiar", "the keys follow the device")
	var wheel := InputEventMouseButton.new()
	wheel.button_index = MOUSE_BUTTON_WHEEL_DOWN
	wheel.pressed = true
	hud._input(wheel)
	assert_eq(session.peer_of(hud.spectate.watched()), 2, "the wheel steps and wraps")


func test_back_to_the_own_hud_when_the_party_lands() -> void:
	var session := _session({2: Vector2(40.0, 0.0)})
	var own := session.body(1)
	var hud := _hud(session)
	IslandArrival.hold(own)
	await wait_process_frames(2)
	assert_true(hud.watching_panel.visible, "a waiting rider watches Papo")
	assert_eq(hud.meters.shown(), session.body(2).meters)
	IslandArrival.land(own, Vector2(16.0, 16.0), session.terrain)
	await wait_process_frames(2)
	assert_false(hud.watching_panel.visible, "the line hides")
	assert_eq(hud.meters.shown(), own.meters, "the own meters are back")
	assert_true(hud.strip.visible, "the strip shows again")
	assert_true(own.camera.enabled)


func test_a_solo_hud_never_shows_the_line() -> void:
	# 1 player, offline.
	var session := _session()
	var hud := _hud(session, true)
	_kill(session, 1)
	await wait_process_frames(2)
	assert_false(hud.watching_panel.visible)
	assert_false(hud.spectate.active())
	assert_eq(hud.meters.shown(), session.body(1).meters)


func test_the_step_keys_bind_no_input_twice() -> void:
	# inventory-hud "Inputs do not collide": stepping reuses actions a spectator has no other use for.
	for action: StringName in RunHud.SPECTATE_PREV + RunHud.SPECTATE_NEXT:
		assert_true(InputMap.has_action(action), action)
	assert_eq(RunHud.spectate_step(_key(KEY_D)), 1)
	assert_eq(RunHud.spectate_step(_key(KEY_A)), -1)
	assert_eq(RunHud.spectate_step(_key(KEY_E)), 0, "interact is not a step")
	var released := _key(KEY_D)
	released.pressed = false
	assert_eq(RunHud.spectate_step(released), 0, "a release is not a step")
	var echo := _key(KEY_D)
	echo.echo = true
	assert_eq(RunHud.spectate_step(echo), 0, "a held key does not repeat")


func test_a_living_players_keys_do_not_step() -> void:
	var session := _session({2: Vector2(40.0, 0.0)})
	var hud := _hud(session)
	hud.refresh()
	hud._input(_key(KEY_D))
	assert_false(hud.spectate.active())
	assert_false(hud.watching_panel.visible)
	assert_true(session.body(1).camera.enabled)
