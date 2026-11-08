extends GutTest
## inventory-hud "Using the selected item", "Which use the button picks", "Refused uses" and
## "Screens take input first" with exactly 1 player, offline: holding the use button (F, gamepad
## X) for the selected item's use time asks the host to apply it, a ring on the slot shows the
## hold, letting go or changing the selection cancels, a solo last stand drinks its own reviving
## cup, and a refused use shows its reason for 2 s and sends nothing. The strip's `_process` is
## driven by hand in 0.1 s steps, with no frame awaited, so the times are exact.

const SESSION_SCENE: PackedScene = preload("res://scenes/net/coop_session.tscn")
const HUD_SCENE: PackedScene = preload("res://scenes/ui/run_hud.tscn")
const STEP_S: float = 0.1
const M := DataEnums.Meter
const SENT: String = "use_sent"


func before_each() -> void:
	NetManager.start_solo()


func after_each() -> void:
	_f(false)
	_x(false)
	Input.action_release(InventoryStrip.USE_ACTION)
	get_tree().paused = false
	NetManager.leave()


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
	watch_signals(hud.strip)
	return hud


# F on the keyboard, pressed or let go, as the engine would read it.
func _f(pressed: bool) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = KEY_F
	event.keycode = KEY_F
	event.pressed = pressed
	Input.parse_input_event(event)
	Input.flush_buffered_events()


# X on a gamepad.
func _x(pressed: bool) -> void:
	var event := InputEventJoypadButton.new()
	event.button_index = JOY_BUTTON_X
	event.pressed = pressed
	Input.parse_input_event(event)
	Input.flush_buffered_events()


# `seconds` of HUD frames in 0.1 s steps.
func _hold(hud: RunHud, seconds: float) -> void:
	for i: int in roundi(seconds / STEP_S):
		hud.strip._process(STEP_S)


func _press_key(keycode: Key) -> void:
	for pressed: bool in [true, false]:
		var event := InputEventKey.new()
		event.physical_keycode = keycode
		event.keycode = keycode
		event.pressed = pressed
		get_viewport().push_input(event)


func _thirsty(me: PlayerBody) -> void:
	me.meters.thirst = 50.0
	me.meters.hunger = 50.0
	me.meters.energy = 50.0


func _sent(hud: RunHud) -> int:
	return get_signal_emit_count(hud.strip, SENT)


# --- a use that goes through ---------------------------------------------------------------------

func test_holding_f_for_2_s_drinks_a_coconut() -> void:
	var session := _session()
	var hud := _hud(session)
	var me := session.body(1)
	_thirsty(me)
	me.inventory.add(&"knife", 1)
	me.inventory.add(&"coco", 1)
	hud.strip.select(1)
	_f(true)
	_hold(hud, 1.9)
	assert_eq(me.inventory.count_id(&"coco"), 1, "not yet at 1.9 s")
	assert_eq(_sent(hud), 0)
	_hold(hud, 0.1)
	assert_eq(_sent(hud), 1, "one request at 2 s")
	assert_signal_emitted_with_parameters(hud.strip, SENT, [1, 0, 0])
	assert_almost_eq(me.meters.thirst, 65.0, 0.01)
	assert_almost_eq(me.meters.hunger, 55.0, 0.01)
	assert_almost_eq(me.meters.energy, 60.0, 0.01, "a meal gives +10 energy")
	assert_eq(me.inventory.count_id(&"coco"), 0, "the coconut is gone")
	assert_eq(me.inventory.slots[0].uses_left, 39, "the knife has one use less")
	assert_eq(hud.strip.selected, 1, "the emptied slot stays selected")
	_hold(hud, 3.0)
	assert_eq(_sent(hud), 1, "one use per press")


func test_letting_go_early_uses_nothing_and_the_next_hold_starts_at_0() -> void:
	var session := _session()
	var hud := _hud(session)
	var me := session.body(1)
	_thirsty(me)
	me.inventory.add(&"knife", 1)
	me.inventory.add(&"coco", 1)
	hud.strip.select(1)
	_f(true)
	_hold(hud, 1.5)
	_f(false)
	_hold(hud, 0.1)
	assert_eq(me.inventory.count_id(&"coco"), 1, "nothing used")
	assert_eq(me.meters.thirst, 50.0)
	assert_eq(hud.strip.slot_view(1).ring, 0.0, "the ring empties")
	_f(true)
	_hold(hud, 1.9)
	assert_eq(me.inventory.count_id(&"coco"), 1, "the new hold started from 0 s")
	_hold(hud, 0.1)
	assert_eq(me.inventory.count_id(&"coco"), 0)
	assert_eq(_sent(hud), 1)


func test_changing_the_selection_mid_hold_cancels() -> void:
	var session := _session()
	var hud := _hud(session)
	var me := session.body(1)
	me.inventory.add(&"knife", 1)
	me.inventory.add(&"coco", 1)
	hud.strip.select(1)
	_f(true)
	_hold(hud, 1.0)
	_press_key(KEY_1)
	assert_eq(hud.strip.selected, 0)
	assert_eq(hud.strip.slot_view(1).ring, 0.0, "the ring empties at once")
	_press_key(KEY_2)
	_hold(hud, 3.0)
	assert_eq(me.inventory.count_id(&"coco"), 1, "cancelled: the held button starts nothing new")
	assert_eq(_sent(hud), 0)
	_f(false)
	_hold(hud, 0.1)
	_f(true)
	_hold(hud, 2.0)
	assert_eq(me.inventory.count_id(&"coco"), 0, "a fresh press works")


func test_x_on_a_gamepad_does_the_same_as_f() -> void:
	var session := _session()
	var hud := _hud(session)
	var me := session.body(1)
	_thirsty(me)
	me.inventory.add(&"rain_cup", 1)
	_x(true)
	_hold(hud, 0.9)
	assert_eq(me.inventory.count_id(&"rain_cup"), 1)
	_hold(hud, 0.1)
	assert_almost_eq(me.meters.thirst, 75.0, 0.01)
	assert_eq(me.inventory.count_id(&"rain_cup"), 0)
	assert_eq(_sent(hud), 1)


func test_the_slots_ring_is_half_full_at_1_s_of_a_2_s_use() -> void:
	var session := _session()
	var hud := _hud(session)
	var me := session.body(1)
	me.inventory.add(&"knife", 1)
	me.inventory.add(&"coco", 1)
	hud.strip.select(1)
	assert_eq(hud.strip.slot_view(1).ring, 0.0)
	_f(true)
	_hold(hud, 1.0)
	assert_almost_eq(hud.strip.slot_view(1).ring, 0.5, 0.01)
	assert_eq(hud.strip.slot_view(0).ring, 0.0, "only the selected slot")
	_f(false)
	_hold(hud, 0.1)
	assert_eq(hud.strip.slot_view(1).ring, 0.0)


# --- the last stand -------------------------------------------------------------------------------

func test_a_solo_last_stand_drinks_its_own_rain_cup() -> void:
	var session := _session()
	var hud := _hud(session)
	var me := session.body(1)
	me.inventory.add(&"rain_cup", 1)
	me.meters.solo = true
	me.meters.downed_bonus_s = 15.0
	me.meters.add(M.HEALTH, -me.meters.health)
	assert_true(me.meters.last_stand)
	_f(true)
	_hold(hud, 1.0)
	assert_signal_emitted_with_parameters(hud.strip, SENT, [0, 1, 0])
	assert_false(me.meters.last_stand, "on their feet")
	assert_almost_eq(me.meters.health, 30.0, 0.01)
	assert_eq(me.inventory.count_id(&"rain_cup"), 0, "the cup is gone")


func test_going_down_mid_hold_cancels() -> void:
	var session := _session()
	var hud := _hud(session)
	var me := session.body(1)
	me.inventory.add(&"rain_cup", 1)
	me.meters.solo = true
	me.meters.downed_bonus_s = 15.0
	_f(true)
	_hold(hud, 0.5)
	me.meters.add(M.HEALTH, -me.meters.health)
	assert_true(me.meters.last_stand)
	_hold(hud, 1.0)
	assert_eq(me.inventory.count_id(&"rain_cup"), 1, "the drink was cancelled")
	assert_eq(_sent(hud), 0)
	_f(false)
	_hold(hud, 0.1)
	_f(true)
	_hold(hud, 1.0)
	assert_false(me.meters.last_stand, "a fresh press stands them up")


# --- refusals ---------------------------------------------------------------------------------------

func test_without_a_knife_the_coconut_is_refused_with_a_reason() -> void:
	var session := _session()
	var hud := _hud(session)
	var me := session.body(1)
	_thirsty(me)
	me.inventory.add(&"coco", 1)
	_f(true)
	_hold(hud, 0.1)
	assert_eq(hud.notice.shown_text(), "Te falta con qué abrir el coco.")
	_hold(hud, 3.0)
	assert_eq(_sent(hud), 0, "nothing is sent")
	assert_eq(me.inventory.count_id(&"coco"), 1, "the coconut stays")
	assert_eq(me.meters.thirst, 50.0)
	hud.notice._process(1.8)
	assert_eq(hud.notice.shown_text(), "Te falta con qué abrir el coco.", "shown for 2 s")
	hud.notice._process(0.2)
	assert_eq(hud.notice.shown_text(), "", "gone after 2 s")


func test_an_empty_slot_says_so() -> void:
	var session := _session()
	var hud := _hud(session)
	session.body(1).inventory.add(&"rain_cup", 1)
	hud.strip.select(3)
	_f(true)
	_hold(hud, 1.0)
	assert_eq(hud.notice.shown_text(), "No tienes nada ahí.")
	assert_eq(_sent(hud), 0)
	assert_eq(session.body(1).inventory.count_id(&"rain_cup"), 1)


func test_an_item_with_no_use_says_so() -> void:
	var session := _session()
	var hud := _hud(session)
	session.body(1).inventory.add(&"driftwood", 1)
	_f(true)
	_hold(hud, 0.1)
	assert_eq(hud.notice.shown_text(), "Eso no se usa así.")
	assert_eq(_sent(hud), 0)


func test_a_refusal_shows_once_per_press() -> void:
	var session := _session()
	var hud := _hud(session)
	_f(true)
	_hold(hud, 0.1)
	hud.notice.clear()
	_hold(hud, 1.0)
	assert_eq(hud.notice.shown_text(), "", "holding on does not repeat it")
	_f(false)
	_hold(hud, 0.1)
	_f(true)
	_hold(hud, 0.1)
	assert_eq(hud.notice.shown_text(), "No tienes nada ahí.", "a new press does")


# --- input the use button does not take ----------------------------------------------------------

func test_with_the_crafting_list_open_f_uses_nothing() -> void:
	var session := _session()
	var hud := _hud(session)
	var me := session.body(1)
	me.inventory.add(&"rain_cup", 1)
	hud.list_open = true
	_f(true)
	_hold(hud, 1.5)
	assert_eq(me.inventory.count_id(&"rain_cup"), 1, "nothing is used")
	assert_eq(_sent(hud), 0)
	assert_eq(hud.notice.shown_text(), "", "and nothing is refused either: F is not for the list")
	assert_true(hud.list_open, "the list stays open")
	hud.list_open = false
	_hold(hud, 1.0)
	assert_eq(me.inventory.count_id(&"rain_cup"), 1, "the press made while the list was open stays spent")


# Real frames here: the pause freezes the run, and what the strip sees then is the point.
func test_paused_f_uses_nothing() -> void:
	var session := _session()
	var hud := _hud(session)
	var me := session.body(1)
	me.inventory.add(&"rain_cup", 1)
	assert_true(hud.pause_menu.open())
	_f(true)
	await wait_process_frames(5)
	assert_eq(me.inventory.count_id(&"rain_cup"), 1)
	assert_eq(_sent(hud), 0)
	hud.pause_menu.resume()
	await wait_seconds(1.3)
	assert_eq(me.inventory.count_id(&"rain_cup"), 1, "the press made while paused does not carry over")
	assert_eq(_sent(hud), 0)


func test_under_a_screen_f_uses_nothing() -> void:
	var session := _session()
	var hud := _hud(session)
	var me := session.body(1)
	me.inventory.add(&"rain_cup", 1)
	_f(true)
	_hold(hud, 0.5)
	hud.set_screen_shown(true)
	_hold(hud, 1.5)
	assert_eq(me.inventory.count_id(&"rain_cup"), 1)
	assert_eq(_sent(hud), 0)
	hud.set_screen_shown(false)
	_hold(hud, 1.5)
	assert_eq(me.inventory.count_id(&"rain_cup"), 1, "the press the screen took stays taken")
	assert_eq(_sent(hud), 0)
