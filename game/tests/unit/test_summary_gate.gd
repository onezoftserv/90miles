extends GutTest
## endings-progression "No skipping the summary" (menu-clarity design D5): for 0.8 s after the run
## summary shows, no press of the keyboard, gamepad or mouse reaches its buttons, and nothing pressed
## meanwhile is kept for later. Solo, offline; the clock is injected, so no test waits on the wall
## clock.

const SUMMARY_SCENE: PackedScene = preload("res://scenes/shell/summary_screen.tscn")

var now_s: float = 0.0


func _screen() -> SummaryScreen:
	now_s = 0.0
	var screen := SUMMARY_SCENE.instantiate() as SummaryScreen
	add_child_autofree(screen)
	screen.clock = func() -> float: return now_s
	var made := RunSummary.new()
	made.entries = [{"name": "Balsero", "dead": true, "cause": &"thirst", "cause_label": "sed", "line": "", "line_id": &"", "peer": 1}] as Array[Dictionary]
	screen.show_summary(made, "Otra vez", 1)
	return screen


func _accept(pressed: bool) -> InputEventAction:
	var event := InputEventAction.new()
	event.action = &"ui_accept"
	event.pressed = pressed
	return event


func test_a_held_a_button_let_go_at_0_3_s_picks_nothing() -> void:
	var screen := _screen()
	watch_signals(screen)
	await wait_process_frames(1)
	assert_eq(get_viewport().gui_get_focus_owner(), screen.restart_button, "Otra vez has the focus")
	now_s = 0.3
	get_viewport().push_input(_accept(true))
	get_viewport().push_input(_accept(false))
	screen.restart_button.pressed.emit()
	assert_signal_not_emitted(screen, "restart_requested", "nothing is picked")
	assert_signal_not_emitted(screen, "home_requested")
	assert_eq(get_viewport().gui_get_focus_owner(), screen.restart_button, "and Otra vez keeps the focus")
	now_s = 1.0
	await wait_process_frames(1)
	assert_signal_not_emitted(screen, "restart_requested", "a dropped press is not kept for later")


func test_after_the_delay_enter_starts_again() -> void:
	var screen := _screen()
	watch_signals(screen)
	now_s = 1.0
	await wait_process_frames(1)
	assert_true(screen.accepts_presses())
	screen.restart_button.pressed.emit()
	assert_signal_emitted(screen, "restart_requested")


func test_the_pointer_passes_through_the_buttons_during_the_gate() -> void:
	var screen := _screen()
	now_s = 0.3
	await wait_process_frames(1)
	assert_eq(screen.restart_button.mouse_filter, Control.MOUSE_FILTER_IGNORE, "a click inside the gate is dropped")
	assert_eq(screen.home_button.mouse_filter, Control.MOUSE_FILTER_IGNORE)
	now_s = 0.9
	await wait_process_frames(1)
	assert_eq(screen.restart_button.mouse_filter, Control.MOUSE_FILTER_STOP, "the pointer works after it")
	assert_eq(screen.home_button.mouse_filter, Control.MOUSE_FILTER_STOP)


func test_the_gate_is_0_8_s() -> void:
	assert_eq(SummaryScreen.ACCEPT_DELAY_S, 0.8)
	var screen := _screen()
	now_s = 0.79
	assert_false(screen.accepts_presses())
	now_s = 0.8
	assert_true(screen.accepts_presses())
