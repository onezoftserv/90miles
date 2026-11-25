extends GutTest
## ui-shell "Controles card" (run-menu design D6): each control with its key and its gamepad button,
## read from the input map when the card opens. Exactly 1 player, offline.

const CARD_SCENE: PackedScene = preload("res://scenes/shell/controls_card.tscn")
const SHELL_SCENE: PackedScene = preload("res://scenes/shell/game_shell.tscn")
const VIEW: Rect2 = Rect2(0.0, 0.0, 640.0, 360.0)

var settings_path: String = UserTmp.path("test_controls_card_settings.cfg")
var _saved_interact: Array[InputEvent] = []


func before_each() -> void:
	NetManager.start_solo()
	_saved_interact = InputMap.action_get_events(&"interact")


func after_each() -> void:
	InputMap.action_erase_events(&"interact")
	for event: InputEvent in _saved_interact:
		InputMap.action_add_event(&"interact", event)
	NetManager.leave()
	if FileAccess.file_exists(settings_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(settings_path))


func _card() -> ControlsCard:
	var card := CARD_SCENE.instantiate() as ControlsCard
	add_child_autofree(card)
	return card


func _cancel_event() -> InputEventAction:
	var event := InputEventAction.new()
	event.action = &"ui_cancel"
	event.pressed = true
	return event


func test_the_rows_read_the_input_map() -> void:
	var card := _card()
	assert_eq(card.shown[&"interact"], PackedStringArray(["Interactuar", "E", "A"]))
	assert_eq(card.shown[&"pause"], PackedStringArray(["Menú", "Esc", "Start"]))
	assert_eq(card.shown[&"move"], PackedStringArray(["Moverse", "W A S D", "Palanca izq."]))
	assert_eq(card.shown[&"run"], PackedStringArray(["Correr", "Mayús", "LB"]))
	assert_eq(card.shown[&"crouch"], PackedStringArray(["Agacharse, bucear", "Ctrl / C", "B"]))
	assert_eq(card.shown[&"use_item"], PackedStringArray(["Usar objeto", "F", "X"]))
	assert_eq(card.shown[&"pick_item"], PackedStringArray(["Elegir objeto", "1 … =", "Cruz ← →"]))
	assert_eq(card.shown[&"craft_list"], PackedStringArray(["Lista de fabricar", "↑ ↓", "Cruz ↑ ↓"]))
	assert_eq(card.shown[&"fullscreen"], PackedStringArray(["Pantalla completa", "F11 / Alt+Intro", "—"]))


func test_the_body_font_draws_the_arrows() -> void:
	for glyph: String in ["↑", "↓", "←", "→", "…", "—"]:
		assert_true(ControlsCard.body_font_has(glyph), "Press Start 2P draws %s" % glyph)


func test_the_card_follows_the_bindings() -> void:
	InputMap.action_erase_events(&"interact")
	var key := InputEventKey.new()
	key.physical_keycode = KEY_F
	InputMap.action_add_event(&"interact", key)
	var card := _card()
	assert_eq(card.shown[&"interact"][1], "F")


func test_quick_chat_on_the_title_is_marked_for_a_group() -> void:
	var card := _card()
	assert_eq(card.shown[&"quick_chat"], PackedStringArray(["Chat rápido (en grupo)", "Q", "RB"]))


func test_a_solo_run_has_no_quick_chat_and_a_co_op_run_no_mark() -> void:
	var card := _card()
	card.for_run(true)
	assert_false(card.shown.has(&"quick_chat"))
	card.for_run(false)
	assert_eq(card.shown[&"quick_chat"][0], "Chat rápido")


func test_volver_and_esc_close_it() -> void:
	var card := _card()
	await wait_process_frames(1)
	assert_eq(get_viewport().gui_get_focus_owner(), card.back_button, "Volver focused")
	watch_signals(card)
	card.back_button.pressed.emit()
	assert_signal_emit_count(card, "back_requested", 1)
	card._unhandled_input(_cancel_event())
	assert_signal_emit_count(card, "back_requested", 2)


func test_the_card_fits_the_view_on_paper() -> void:
	var card := _card()
	await wait_process_frames(2)
	var panel := card.get_node(^"%Panel") as PanelContainer
	assert_eq(panel.theme_type_variation, &"", "paper on the title")
	assert_true(VIEW.encloses(panel.get_global_rect()), "inside 640x360: %s" % panel.get_global_rect())
	for label: Label in panel.find_children("*", "Label", true, false):
		assert_true(panel.get_global_rect().encloses(label.get_global_rect()), "'%s' inside the card" % label.text)


func test_from_the_title_and_back_with_controles_focused() -> void:
	var config := ConfigFile.new()
	config.set_value("player", "name", "Yuni")
	config.save(settings_path)
	var shell := SHELL_SCENE.instantiate() as GameShell
	shell.settings_path = settings_path
	add_child_autofree(shell)
	(shell.screen as TitleScreen).controls_requested.emit()
	assert_eq(shell.flow, GameShell.Flow.CONTROLS)
	assert_true(shell.screen is ControlsCard)
	assert_true(shell.multiplayer.multiplayer_peer is OfflineMultiplayerPeer, "no network port")
	shell.screen._unhandled_input(_cancel_event())
	assert_eq(shell.flow, GameShell.Flow.TITLE)
	var title := shell.screen as TitleScreen
	assert_eq(get_viewport().gui_get_focus_owner(), title.buttons()[4], "Controles focused")
	assert_eq(title.buttons()[4].text, "Controles")
