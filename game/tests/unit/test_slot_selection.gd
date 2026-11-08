extends GutTest
## inventory-hud "Selecting a slot with the keyboard and mouse", "Selecting a slot with a gamepad",
## "Selection is not holding", "Inputs do not collide" and "Screens take input first", with exactly
## 1 player: the number row picks screen slots by key position, the wheel and the D-pad cycle the
## slots that hold something, a click picks a slot, and nothing is selected or sent while typing,
## paused, or with the run summary or the host-lost screen up.

const SESSION_SCENE: PackedScene = preload("res://scenes/net/coop_session.tscn")
const HUD_SCENE: PackedScene = preload("res://scenes/ui/run_hud.tscn")
const SHELL_SCENE: PackedScene = preload("res://scenes/shell/game_shell.tscn")
const SETTINGS_PATH: String = "user://test_slot_selection_settings.cfg"
const NUMBER_ROW: Array[Key] = [KEY_1, KEY_2, KEY_3, KEY_4, KEY_5, KEY_6, KEY_7, KEY_8, KEY_9, KEY_0, KEY_MINUS, KEY_EQUAL]


func before_each() -> void:
	NetManager.start_solo()


func after_each() -> void:
	get_tree().paused = false
	NetManager.leave()
	if FileAccess.file_exists(SETTINGS_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SETTINGS_PATH))


func _session() -> CoopSession:
	var session := SESSION_SCENE.instantiate() as CoopSession
	add_child_autofree(session)
	session.start()
	session.body(CoopSession.HOST_ID).player_input.enabled = false
	return session


func _hud(session: CoopSession) -> RunHud:
	var hud := HUD_SCENE.instantiate() as RunHud
	add_child_autofree(hud)
	hud.bind(session, CoopSession.HOST_ID, true)
	return hud


func _put(inventory: Inventory, index: int, id: StringName, count: int = 1) -> void:
	var slot := inventory.slots[index]
	slot.item_id = id
	slot.count = count
	slot.uses_left = 0
	inventory.changed.emit()


func _key(keycode: Key) -> InputEventKey:
	var event := InputEventKey.new()
	event.physical_keycode = keycode
	event.keycode = keycode
	event.pressed = true
	return event


func _press_key(keycode: Key) -> void:
	get_viewport().push_input(_key(keycode))
	var release := _key(keycode)
	release.pressed = false
	get_viewport().push_input(release)


func _wheel(down: bool, at: Vector2 = Vector2(320.0, 150.0)) -> void:
	for pressed: bool in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_WHEEL_DOWN if down else MOUSE_BUTTON_WHEEL_UP
		event.pressed = pressed
		event.position = at
		event.global_position = at
		get_viewport().push_input(event, true)


func _d_pad(button: JoyButton) -> void:
	for pressed: bool in [true, false]:
		var event := InputEventJoypadButton.new()
		event.button_index = button
		event.pressed = pressed
		get_viewport().push_input(event)


func _click(at: Vector2) -> void:
	for pressed: bool in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		event.position = at
		event.global_position = at
		get_viewport().push_input(event, true)


# --- number row ------------------------------------------------------------------------------

func test_the_number_row_picks_screen_slots_1_to_12_even_when_empty() -> void:
	var hud := _hud(_session())
	for n: int in NUMBER_ROW.size():
		_press_key(NUMBER_ROW[n])
		assert_eq(hud.strip.selected, n, "%s picks screen slot %d" % [OS.get_keycode_string(NUMBER_ROW[n]), n + 1])
	_press_key(KEY_0)
	assert_eq(hud.strip.selected, 9, "0 is screen slot 10")
	assert_true(hud.strip.slot_view(9).selected)


# --- wheel and D-pad -------------------------------------------------------------------------

func test_the_wheel_skips_empty_slots_and_wraps() -> void:
	var session := _session()
	var hud := _hud(session)
	var inventory := session.body(1).inventory
	_put(inventory, 0, &"coco")
	_put(inventory, 3, &"rope")
	hud.strip.select(0)
	_wheel(true)
	assert_eq(hud.strip.selected, 3, "down: screen slot 4")
	_wheel(true)
	assert_eq(hud.strip.selected, 0, "down again: back to screen slot 1")
	_wheel(false)
	assert_eq(hud.strip.selected, 3, "up wraps the other way")


func test_the_wheel_over_the_strip_moves_the_same_way() -> void:
	var session := _session()
	var hud := _hud(session)
	var inventory := session.body(1).inventory
	_put(inventory, 0, &"coco")
	_put(inventory, 3, &"rope")
	hud.strip.select(0)
	var over_the_strip: Vector2 = hud.strip.slot_view(1).get_global_rect().get_center()
	_wheel(true, over_the_strip)
	assert_eq(hud.strip.selected, 3, "the slot under the pointer does not swallow it")
	_wheel(false, over_the_strip)
	assert_eq(hud.strip.selected, 0)


func test_with_every_slot_empty_the_wheel_stays() -> void:
	var hud := _hud(_session())
	hud.strip.select(4)
	_wheel(true)
	assert_eq(hud.strip.selected, 4)
	_d_pad(JOY_BUTTON_DPAD_LEFT)
	assert_eq(hud.strip.selected, 4)


func test_d_pad_right_and_left_cycle_like_the_wheel() -> void:
	var session := _session()
	var hud := _hud(session)
	var inventory := session.body(1).inventory
	_put(inventory, 1, &"coco")
	_put(inventory, 4, &"rope")
	_put(inventory, 8, &"driftwood")
	hud.strip.select(8)
	_d_pad(JOY_BUTTON_DPAD_RIGHT)
	assert_eq(hud.strip.selected, 1, "from screen slot 9 to screen slot 2")
	_d_pad(JOY_BUTTON_DPAD_RIGHT)
	assert_eq(hud.strip.selected, 4)
	_d_pad(JOY_BUTTON_DPAD_LEFT)
	assert_eq(hud.strip.selected, 1)
	_d_pad(JOY_BUTTON_DPAD_LEFT)
	assert_eq(hud.strip.selected, 8, "left wraps")


func test_next_filled_slot() -> void:
	var session := _session()
	var hud := _hud(session)
	var inventory := session.body(1).inventory
	_put(inventory, 2, &"coco")
	assert_eq(hud.strip.next_filled(2, 1), 2, "the only full slot keeps the selection")
	assert_eq(hud.strip.next_filled(7, -1), 2)
	assert_eq(hud.strip.next_filled(7, 1), 2, "wrapping round")


# --- clicks and focus ------------------------------------------------------------------------

func test_a_click_on_a_slot_selects_it() -> void:
	var hud := _hud(_session())
	_click(hud.strip.slot_view(6).get_global_rect().get_center())
	assert_eq(hud.strip.selected, 6, "screen slot 7")


func test_slots_take_clicks_but_never_focus() -> void:
	var hud := _hud(_session())
	_click(hud.strip.slot_view(2).get_global_rect().get_center())
	assert_null(get_viewport().gui_get_focus_owner(), "nothing took focus")
	for i: int in hud.strip.slot_count():
		assert_eq(hud.strip.slot_view(i).focus_mode, Control.FOCUS_NONE)


# --- what the selection is not ----------------------------------------------------------------

func test_the_selection_stays_on_a_slot_that_empties() -> void:
	var session := _session()
	var hud := _hud(session)
	var inventory := session.body(1).inventory
	inventory.add(&"knife", 1)
	inventory.add(&"coco", 1)
	_press_key(KEY_2)
	inventory.remove_id(&"coco", 1)
	assert_eq(hud.strip.selected, 1, "screen slot 2 stays selected")
	assert_true(hud.strip.slot_view(1).selected)
	assert_eq(hud.strip.slot_view(1).name_label.text, "")


func test_selecting_a_knife_is_not_holding_it() -> void:
	var session := _session()
	var hud := _hud(session)
	var inventory := session.body(1).inventory
	inventory.add(&"knife", 1)
	inventory.add(&"rope", 1)
	inventory.add(&"coco", 1)
	assert_eq(inventory.held_food(), &"coco")
	_press_key(KEY_1)
	assert_eq(hud.strip.selected, 0)
	assert_eq(inventory.held_food(), &"coco", "held food is still the first food slot")


func test_selecting_sends_nothing_and_changes_nothing() -> void:
	var session := _session()
	var hud := _hud(session)
	var me := session.body(1)
	me.inventory.add(&"coco", 2)
	me.inventory.add(&"rain_cup", 1)
	me.meters.thirst = 50.0
	var before: Array = me.inventory.to_net()
	_press_key(KEY_2)
	_wheel(true)
	_d_pad(JOY_BUTTON_DPAD_RIGHT)
	_click(hud.strip.slot_view(3).get_global_rect().get_center())
	assert_eq(me.inventory.to_net(), before, "nothing used")
	assert_eq(me.meters.thirst, 50.0)


# --- input that is not for the strip -----------------------------------------------------------

func test_typing_in_a_text_field_selects_nothing() -> void:
	var hud := _hud(_session())
	hud.strip.body.inventory.add(&"coco", 1)
	hud.strip.body.inventory.add(&"rope", 1)
	var field := LineEdit.new()
	add_child_autofree(field)
	field.grab_focus()
	assert_true(get_viewport().gui_get_focus_owner() == field, "the field has focus")
	for keycode: Key in NUMBER_ROW:
		_press_key(keycode)
	_wheel(true)
	_d_pad(JOY_BUTTON_DPAD_RIGHT)
	hud.strip._unhandled_input(_key(KEY_5))
	assert_eq(hud.strip.selected, 0, "no slot key reached the strip")


func test_paused_nothing_changes() -> void:
	var session := _session()
	var hud := _hud(session)
	hud.strip.body.inventory.add(&"coco", 1)
	hud.strip.body.inventory.add(&"rope", 1)
	assert_true(hud.pause_menu.open(), "solo pauses")
	_press_key(KEY_3)
	_wheel(true)
	_d_pad(JOY_BUTTON_DPAD_RIGHT)
	hud.strip._unhandled_input(_key(KEY_3))
	assert_eq(hud.strip.selected, 0, "the selection does not change")
	hud.pause_menu.resume()
	_press_key(KEY_3)
	assert_eq(hud.strip.selected, 2, "and works again once resumed")


func test_a_screen_takes_input_first() -> void:
	var hud := _hud(_session())
	hud.strip.body.inventory.add(&"coco", 1)
	hud.strip.body.inventory.add(&"rope", 1)
	hud.set_screen_shown(true)
	_press_key(KEY_3)
	_wheel(true)
	_d_pad(JOY_BUTTON_DPAD_RIGHT)
	assert_eq(hud.strip.selected, 0)
	assert_false(hud.strip.visible, "the strip hides under a screen")
	hud.set_screen_shown(false)
	_press_key(KEY_3)
	assert_eq(hud.strip.selected, 2)


func _shell() -> GameShell:
	var shell := SHELL_SCENE.instantiate() as GameShell
	shell.settings_path = SETTINGS_PATH
	add_child_autofree(shell)
	return shell


func test_the_run_summary_takes_the_slot_keys() -> void:
	var shell := _shell()
	shell.start_solo()
	var hud := shell.hud
	assert_false(hud.screen_shown)
	shell.session.body(1).meters.dead = true
	assert_eq(shell.flow, GameShell.Flow.SUMMARY)
	assert_true(hud.screen_shown, "the shell tells the HUD")
	var before: int = hud.strip.selected
	_press_key(KEY_3)
	assert_eq(hud.strip.selected, before)


func test_the_host_lost_screen_takes_the_slot_keys() -> void:
	var shell := _shell()
	shell.start_solo()
	var hud := shell.hud
	shell._on_host_lost()
	assert_true(hud.screen_shown, "told before the run is freed")
	_press_key(KEY_3)
	assert_eq(hud.strip.selected, 0)
	await wait_process_frames(2)
	assert_null(shell.hud, "the HUD went with the run")
	_press_key(KEY_4)
	assert_eq(shell.flow, GameShell.Flow.HOST_LOST)
