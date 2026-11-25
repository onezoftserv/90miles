extends GutTest
## coop-networking "Pause" (approved 2026-11-05; run-menu 2026-11-23): in a solo session (one player,
## offline) the run menu freezes the whole host simulation; in co-op it opens but pauses nothing.

const SESSION_SCENE: PackedScene = preload("res://scenes/net/coop_session.tscn")
const MENU_SCENE: PackedScene = preload("res://scenes/ui/pause_menu.tscn")

var net: NetHarness


func before_each() -> void:
	NetManager.start_solo()


func after_each() -> void:
	get_tree().paused = false
	if net != null:
		net.teardown()
		net = null


func _solo() -> CoopSession:
	var session := SESSION_SCENE.instantiate() as CoopSession
	add_child_autofree(session)
	session.start()
	return session


func _menu(session: CoopSession) -> PauseMenu:
	var menu := MENU_SCENE.instantiate() as PauseMenu
	menu.session = session
	add_child_autofree(menu)
	return menu


func _pause_event() -> InputEventAction:
	var event := InputEventAction.new()
	event.action = PauseMenu.ACTION
	event.pressed = true
	return event


func test_a_solo_session_can_pause() -> void:
	assert_true(_solo().can_pause())


func test_solo_pause_freezes_the_whole_simulation() -> void:
	var session := _solo()
	var menu := _menu(session)
	assert_true(menu.open())
	assert_true(get_tree().paused)
	assert_true(menu.visible)
	assert_false(session.body(1).can_process(), "the player")
	assert_false(session.can_process(), "the session's countdowns and entities")
	assert_false(WeatherManager.can_process(), "the clock and weather")
	assert_false(GameState.can_process(), "run state")
	assert_true(menu.can_process(), "the menu itself keeps running")


func test_resuming_runs_the_simulation_again() -> void:
	var session := _solo()
	var menu := _menu(session)
	menu.open()
	assert_true(menu.resume())
	assert_false(get_tree().paused)
	assert_false(menu.visible)
	assert_true(session.body(1).can_process())


func test_the_pause_button_toggles_the_menu() -> void:
	var menu := _menu(_solo())
	menu._unhandled_input(_pause_event())
	assert_true(get_tree().paused)
	menu._unhandled_input(_pause_event())
	assert_false(get_tree().paused)


func test_the_menu_says_pausa_and_seguir() -> void:
	var menu := _menu(_solo())
	assert_eq(menu.title.text, "Pausa")
	assert_eq(menu.resume_button.text, "Seguir")
	assert_false(menu.visible)


func test_the_pause_button_is_escape_and_start() -> void:
	assert_true(InputMap.has_action(PauseMenu.ACTION))
	var keys: Array[int] = []
	var buttons: Array[int] = []
	for event: InputEvent in InputMap.action_get_events(PauseMenu.ACTION):
		if event is InputEventKey:
			keys.append((event as InputEventKey).physical_keycode)
		elif event is InputEventJoypadButton:
			buttons.append((event as InputEventJoypadButton).button_index)
	assert_eq(keys, [KEY_ESCAPE] as Array[int])
	assert_eq(buttons, [JOY_BUTTON_START] as Array[int])


func test_co_op_has_no_pause() -> void:
	net = NetHarness.new(self)
	var host := net.add_host()
	var client := await net.join()
	assert_not_null(client)
	if client == null:
		return
	for session: CoopSession in [host, client]:
		assert_false(session.can_pause())
		assert_false(session.set_paused(true))
		var menu := _menu(session)
		assert_true(menu.open(), "the run menu opens in co-op (run-menu)")
		assert_true(menu.visible)
		assert_false(get_tree().paused, "and pauses nothing")
		menu.resume()
	assert_false(get_tree().paused)


func test_hosting_alone_is_not_solo_and_has_no_pause() -> void:
	net = NetHarness.new(self)
	var host := net.add_host()
	assert_false(host.can_pause())
	assert_false(host.set_paused(true))
	assert_false(get_tree().paused)


func test_the_coop_playground_has_a_pause_menu_on_its_session() -> void:
	var playground := (load("res://scenes/dev/coop_playground.tscn") as PackedScene).instantiate() as CoopPlayground
	add_child_autofree(playground)
	assert_eq(playground.pause_menu.session, playground.session)


## ui-shell "Pause and host-lost windows" (hud-window-kit design D9): a solo pause shows one dark
## window centred in the 640x360 view, its "Pausa" tab on the window's top edge, "Seguir" inside it
## and focused. One player, offline.
func test_the_solo_pause_shows_a_centred_window_with_its_tab() -> void:
	var menu := _menu(_solo())
	assert_true(menu.open())
	await wait_process_frames(2)
	var window := menu.get_node(^"%Window") as PanelContainer
	var tab := menu.get_node(^"%Tab") as PanelContainer
	assert_eq(window.theme_type_variation, &"HudPanel")
	assert_eq(tab.theme_type_variation, &"HudTab")
	var view := Rect2(Vector2.ZERO, Vector2(640.0, 360.0))
	var frame := (menu.get_node(^"%Frame") as Control).get_global_rect()
	assert_true(view.encloses(frame), "the window lies inside the view: %s" % frame)
	var centre: Vector2 = frame.get_center()
	assert_almost_eq(centre.x, 320.0, 1.0, "centred across")
	assert_almost_eq(centre.y, 180.0, 1.0, "centred down")
	var window_rect := window.get_global_rect()
	var tab_rect := tab.get_global_rect()
	assert_almost_eq(tab_rect.end.y, window_rect.position.y + 1.0, 0.01, "the tab sits on the window's top edge")
	assert_true(window_rect.encloses(menu.resume_button.get_global_rect()), "Seguir inside the window")
	assert_true(menu.resume_button.has_focus(), "Seguir has the focus")
	assert_eq(menu.title.get_parent(), tab, "the title is on the tab")
