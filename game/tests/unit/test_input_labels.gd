extends GutTest
## inventory-hud "Key labels follow the device": every key the HUD shows is read from the input
## map for the last device used; gamepad names come from the HUD text file; only a button press or
## a stick past its action's deadzone counts as picking up the gamepad.

const K := InputLabels.Device.KEYBOARD
const PAD := InputLabels.Device.GAMEPAD


func _button(index: JoyButton, pressed: bool = true) -> InputEventJoypadButton:
	var event := InputEventJoypadButton.new()
	event.button_index = index
	event.pressed = pressed
	return event


func _motion(axis: JoyAxis, value: float) -> InputEventJoypadMotion:
	var event := InputEventJoypadMotion.new()
	event.axis = axis
	event.axis_value = value
	return event


func _key(keycode: Key, pressed: bool = true) -> InputEventKey:
	var event := InputEventKey.new()
	event.physical_keycode = keycode
	event.keycode = keycode
	event.pressed = pressed
	return event


func test_interact_and_use_on_each_device() -> void:
	assert_eq(InputLabels.label_for(&"interact", K), "E")
	assert_eq(InputLabels.label_for(&"interact", PAD), "A")
	assert_eq(InputLabels.label_for(&"use_item", K), "F")
	assert_eq(InputLabels.label_for(&"use_item", PAD), "X")


func test_slot_keys_read_as_the_key_prints() -> void:
	assert_eq(InputLabels.label_for(&"slot_1", K), "1")
	assert_eq(InputLabels.label_for(&"slot_9", K), "9")
	assert_eq(InputLabels.label_for(&"slot_10", K), "0")
	assert_eq(InputLabels.label_for(&"slot_11", K), "-")
	assert_eq(InputLabels.label_for(&"slot_12", K), "=")
	assert_eq(InputLabels.label_for(&"slot_1", PAD), "", "no slot key on a gamepad")


func test_a_mouse_wheel_action_reads_its_name() -> void:
	var text := HudText.load_default()
	assert_eq(InputLabels.label_for(&"slot_next", K), text.mouse_button(MOUSE_BUTTON_WHEEL_DOWN))
	assert_eq(InputLabels.label_for(&"slot_next", PAD), text.joy_button(JOY_BUTTON_DPAD_RIGHT))


func test_gamepad_names_come_from_the_hud_text() -> void:
	var text := HudText.new()
	text.joy_buttons[JOY_BUTTON_A] = PackedStringArray(["Botón A", "Button A"])
	assert_eq(InputLabels.label_for(&"interact", PAD, text), "Botón A")
	assert_eq(InputLabels.label_for(&"interact", PAD, text, "en"), "Button A")
	assert_eq(HudText.load_default().joy_button(JOY_BUTTON_X), "X")


func test_an_unknown_action_has_no_label() -> void:
	assert_eq(InputLabels.label_for(&"no_such_action", K), "")


func test_a_gamepad_button_press_picks_the_gamepad() -> void:
	assert_eq(InputLabels.device_after(_button(JOY_BUTTON_Y), K), PAD)
	assert_eq(InputLabels.device_after(_button(JOY_BUTTON_Y, false), K), K, "a release alone is not a press")


func test_a_stick_past_the_deadzone_picks_the_gamepad() -> void:
	assert_eq(InputLabels.device_after(_motion(JOY_AXIS_LEFT_X, 0.9), K), PAD)
	assert_eq(InputLabels.device_after(_motion(JOY_AXIS_LEFT_Y, -0.6), K), PAD)


func test_drift_and_trigger_noise_do_not() -> void:
	assert_eq(InputLabels.device_after(_motion(JOY_AXIS_LEFT_X, 0.1), K), K, "a stick resting at 0.1")
	assert_eq(InputLabels.device_after(_motion(JOY_AXIS_LEFT_Y, -0.1), K), K)
	assert_eq(InputLabels.device_after(_motion(JOY_AXIS_TRIGGER_LEFT, 0.3), K), K, "trigger noise")
	assert_eq(InputLabels.device_after(_motion(JOY_AXIS_TRIGGER_RIGHT, 0.3), K), K)


func test_a_key_or_a_mouse_button_switches_back() -> void:
	assert_eq(InputLabels.device_after(_key(KEY_W), PAD), K)
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	assert_eq(InputLabels.device_after(click, PAD), K)
	var moved := InputEventMouseMotion.new()
	moved.relative = Vector2(3.0, 1.0)
	assert_eq(InputLabels.device_after(moved, PAD), PAD, "moving the mouse alone does not")
