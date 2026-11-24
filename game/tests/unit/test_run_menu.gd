extends GutTest
## ui-shell "Run menu", "Abandoning a run" and "Pause and host-lost windows", coop-networking
## "Pause" (run-menu design D1-D5): one menu in every mode. Each test starts with exactly 1 player,
## offline, unless it builds a host (and a client) with NetHarness.

const SESSION_SCENE: PackedScene = preload("res://scenes/net/coop_session.tscn")
const MENU_SCENE: PackedScene = preload("res://scenes/ui/pause_menu.tscn")
const VIEW: Rect2 = Rect2(0.0, 0.0, 640.0, 360.0)
const BUTTONS: Array[String] = ["Seguir", "Ajustes", "Controles", "Abandonar viaje"]

var net: NetHarness
var settings_path: String = UserTmp.path("test_run_menu_settings.cfg")


func before_each() -> void:
	NetManager.start_solo()


func after_each() -> void:
	get_tree().paused = false
	if net != null:
		net.teardown()
		net = null
	if FileAccess.file_exists(settings_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(settings_path))


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


func _press(menu: PauseMenu, action: StringName) -> void:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = true
	# Through the viewport, so the deepest node takes it first: an open view, then the menu.
	assert_not_null(menu)
	get_viewport().push_input(event)


func _focused() -> Control:
	return get_viewport().gui_get_focus_owner()


func _texts(menu: PauseMenu) -> Array[String]:
	var found: Array[String] = []
	for button: Button in [menu.resume_button, menu.settings_button, menu.controls_button, menu.abandon_button]:
		if button.is_visible_in_tree():
			found.append(button.text)
	return found


func test_a_solo_menu_reads_pausa_with_four_buttons_and_freezes() -> void:
	var menu := _menu(_solo())
	assert_true(menu.open())
	await wait_process_frames(2)
	assert_eq(menu.title.text, "Pausa")
	assert_false(menu.line.visible, "no 'La partida sigue.' in solo")
	assert_eq(_texts(menu), BUTTONS)
	assert_eq(_focused(), menu.resume_button, "Seguir focused")
	assert_true(get_tree().paused)
	assert_eq(menu.role(), PauseMenu.Role.SOLO)


func test_the_menu_window_lies_inside_the_view_with_every_button_in_it() -> void:
	var menu := _menu(_solo())
	menu.open()
	await wait_process_frames(2)
	var window := menu.get_node(^"%Window") as Control
	assert_true(VIEW.encloses(menu.frame.get_global_rect()), "inside 640x360: %s" % menu.frame.get_global_rect())
	assert_almost_eq(menu.frame.get_global_rect().get_center().x, 320.0, 1.0)
	for button: Button in [menu.resume_button, menu.settings_button, menu.controls_button, menu.abandon_button]:
		assert_true(window.get_global_rect().encloses(button.get_global_rect()), "'%s' inside the window" % button.text)


func test_seguir_resumes() -> void:
	var menu := _menu(_solo())
	menu.open()
	menu.resume_button.pressed.emit()
	assert_false(menu.visible)
	assert_false(get_tree().paused)


func test_the_back_button_never_opens_the_menu() -> void:
	var menu := _menu(_solo())
	_press(menu, &"ui_cancel")
	assert_false(menu.visible, "B is also crouch")
	_press(menu, PauseMenu.ACTION)
	assert_true(menu.visible, "Esc and Start open it")


func test_esc_closes_one_layer_at_a_time() -> void:
	var menu := _menu(_solo())
	menu.open()
	menu.controls_button.pressed.emit()
	await wait_process_frames(1)
	assert_true(menu.view is ControlsCard, "Controles open")
	assert_false(menu.frame.visible, "the buttons give way to the card")
	_press(menu, PauseMenu.ACTION)
	await wait_process_frames(1)
	assert_null(menu.view, "the first press closes the card")
	assert_true(menu.visible)
	assert_true(get_tree().paused, "still paused")
	assert_eq(_focused(), menu.controls_button, "Controles focused again")
	_press(menu, PauseMenu.ACTION)
	assert_false(menu.visible, "the second closes the menu")
	assert_false(get_tree().paused, "and resumes the run")


func test_the_back_button_closes_a_view_then_the_menu() -> void:
	var menu := _menu(_solo())
	menu.open()
	menu.controls_button.pressed.emit()
	await wait_process_frames(1)
	_press(menu, &"ui_cancel")
	await wait_process_frames(1)
	assert_null(menu.view)
	assert_true(menu.visible)
	_press(menu, &"ui_cancel")
	assert_false(menu.visible)


func test_the_controles_card_in_a_solo_run_is_dark_with_no_quick_chat() -> void:
	var menu := _menu(_solo())
	menu.open()
	menu.open_controls()
	await wait_process_frames(2)
	var card := menu.view as ControlsCard
	assert_not_null(card)
	var panel := card.get_node(^"%Panel") as PanelContainer
	assert_eq(panel.theme_type_variation, &"HudPanel", "a dark window")
	assert_true(VIEW.encloses(panel.get_global_rect()), "inside 640x360: %s" % panel.get_global_rect())
	assert_eq(card.shown[&"interact"], PackedStringArray(["Interactuar", "E", "A"]))
	assert_eq(card.shown[&"pause"], PackedStringArray(["Menú", "Esc", "Start"]))
	assert_false(card.shown.has(&"quick_chat"), "no quick chat in a solo run")


func test_ajustes_in_a_run_is_dark_nameless_saves_and_esc_returns() -> void:
	var menu := _menu(_solo())
	menu.settings = GameSettings.new(settings_path)
	watch_signals(menu)
	menu.open()
	menu.settings_button.pressed.emit()
	await wait_process_frames(2)
	var screen := menu.view as SettingsScreen
	assert_not_null(screen)
	assert_false(screen.name_field.is_visible_in_tree(), "no name in a run")
	assert_eq((screen.get_node(^"Panel") as PanelContainer).theme_type_variation, &"HudPanel")
	assert_eq(screen.reduce_flashes_box.theme_type_variation, &"HudCheckBox")
	assert_eq(_focused(), screen.fullscreen_box, "the first setting left has the focus")
	screen.reduce_flashes_box.button_pressed = true
	assert_signal_emitted(menu, "flashes_changed")
	assert_true(GameSettings.load_from(settings_path).reduce_flashes, "saved")
	# Esc is ui_cancel too: the settings screen takes it and goes back.
	_press(menu, &"ui_cancel")
	await wait_process_frames(1)
	assert_null(menu.view)
	assert_true(menu.visible)
	assert_eq(_focused(), menu.settings_button, "Ajustes focused again")


func test_abandon_asks_with_cancelar_focused() -> void:
	var menu := _menu(_solo())
	watch_signals(menu)
	menu.open()
	menu.abandon_button.pressed.emit()
	await wait_process_frames(1)
	var box := menu.view as ConfirmBox
	assert_not_null(box)
	assert_eq(box.question.text, "¿Abandonar el viaje?")
	assert_eq(box.line.text, "Este viaje se pierde.")
	assert_eq(box.cancel_button.text, "Cancelar")
	assert_eq(box.confirm_button.text, "Abandonar")
	assert_eq(_focused(), box.cancel_button, "Cancelar focused")
	assert_eq((box.get_node(^"%Panel") as PanelContainer).theme_type_variation, &"HudPanel", "dark in a run")
	# Scenario "Cancel keeps the run": Enter at once presses the focused Cancelar.
	box.cancel_button.pressed.emit()
	await wait_process_frames(1)
	assert_null(menu.view)
	assert_true(menu.visible)
	assert_true(get_tree().paused)
	assert_eq(_focused(), menu.abandon_button)
	assert_signal_not_emitted(menu, "abandon_confirmed")
	menu.ask_abandon()
	(menu.view as ConfirmBox).confirm_button.pressed.emit()
	assert_signal_emitted(menu, "abandon_confirmed")
	assert_false(menu.visible)
	assert_false(get_tree().paused, "the run is not left frozen")


func test_a_host_alone_opens_menu_with_its_line_and_pauses_nothing() -> void:
	net = NetHarness.new(self)
	var host := net.add_host()
	var menu := _menu(host)
	assert_true(menu.open())
	assert_eq(menu.title.text, "Menú")
	assert_true(menu.line.visible)
	assert_eq(menu.line.text, "La partida sigue.")
	assert_false(get_tree().paused)
	assert_eq(menu.role(), PauseMenu.Role.HOST)
	menu.ask_abandon()
	assert_eq((menu.view as ConfirmBox).line.text, "La partida se cierra para todos.")


func test_a_co_op_menu_holds_only_the_local_player() -> void:
	net = NetHarness.new(self)
	var host := net.add_host()
	var client := await net.join()
	assert_not_null(client)
	if client == null:
		return
	var menu := _menu(client)
	assert_true(menu.open())
	assert_false(get_tree().paused, "nothing pauses")
	var own: PlayerBody = client.body(client.multiplayer.get_unique_id())
	assert_not_null(own)
	if own == null:
		return
	assert_true(own.menu_holds_input, "the client's own player is held")
	assert_false(host.body(1).menu_holds_input, "the host's player is not")
	assert_eq(menu.role(), PauseMenu.Role.CLIENT)
	menu.ask_abandon()
	assert_eq((menu.view as ConfirmBox).line.text, "Sales de la partida. Tu balsero espera 90 s por si vuelves.")
	menu.resume()
	assert_false(own.menu_holds_input, "let go once it closes")
