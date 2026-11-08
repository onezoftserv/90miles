extends GutTest
## inventory-hud "Inputs do not collide" and player-movement "Named input actions": the use,
## slot and list actions exist with their keyboard, mouse and gamepad defaults, and no key, mouse
## button or gamepad button is bound to two of the project's actions (the engine's built-in
## `ui_*` focus actions share Enter, Esc, the arrows, the D-pad and A/B by design).

const PROJECT_FILE: String = "res://project.godot"
const SLOT_KEYS: Array[Key] = [KEY_1, KEY_2, KEY_3, KEY_4, KEY_5, KEY_6, KEY_7, KEY_8, KEY_9, KEY_0, KEY_MINUS, KEY_EQUAL]


func _has_key(action: StringName, keycode: Key) -> bool:
	for event: InputEvent in InputMap.action_get_events(action):
		var key := event as InputEventKey
		if key != null and key.physical_keycode == keycode:
			return true
	return false


func _has_mouse(action: StringName, button: MouseButton) -> bool:
	for event: InputEvent in InputMap.action_get_events(action):
		var mouse := event as InputEventMouseButton
		if mouse != null and mouse.button_index == button:
			return true
	return false


func _joy_buttons(action: StringName) -> Array[int]:
	var buttons: Array[int] = []
	for event: InputEvent in InputMap.action_get_events(action):
		var button := event as InputEventJoypadButton
		if button != null:
			buttons.append(button.button_index)
	return buttons


# The actions project.godot defines, read from the file itself so built-ins never count.
func _project_actions() -> PackedStringArray:
	var config := ConfigFile.new()
	assert_eq(config.load(PROJECT_FILE), OK, "project.godot reads")
	return config.get_section_keys("input")


# One string per physical input: the same key (with the same modifiers), mouse button or
# gamepad button always gives the same string.
func _signature(event: InputEvent) -> String:
	var key := event as InputEventKey
	if key != null:
		var code: int = key.physical_keycode if key.physical_keycode != KEY_NONE else key.keycode
		return "key %d mods %d" % [code, key.get_modifiers_mask()]
	var mouse := event as InputEventMouseButton
	if mouse != null:
		return "mouse %d mods %d" % [mouse.button_index, mouse.get_modifiers_mask()]
	var button := event as InputEventJoypadButton
	if button != null:
		return "joypad button %d" % button.button_index
	var motion := event as InputEventJoypadMotion
	if motion != null:
		return "joypad axis %d %+d" % [motion.axis, signi(roundi(signf(motion.axis_value)))]
	return ""


func test_use_item_is_f_and_gamepad_x() -> void:
	assert_true(InputMap.has_action(&"use_item"))
	assert_true(_has_key(&"use_item", KEY_F))
	assert_eq(_joy_buttons(&"use_item"), [JOY_BUTTON_X] as Array[int])


func test_slots_1_to_12_are_the_number_row_by_key_position() -> void:
	for n: int in SLOT_KEYS.size():
		var action := StringName("slot_%d" % (n + 1))
		assert_true(InputMap.has_action(action), "action %s" % action)
		assert_true(_has_key(action, SLOT_KEYS[n]), "%s on %s" % [action, OS.get_keycode_string(SLOT_KEYS[n])])
		assert_eq(_joy_buttons(action), [] as Array[int], "%s has no gamepad default" % action)


func test_next_and_previous_slot_are_the_wheel_and_the_d_pad() -> void:
	assert_true(_has_mouse(&"slot_next", MOUSE_BUTTON_WHEEL_DOWN))
	assert_true(_has_mouse(&"slot_prev", MOUSE_BUTTON_WHEEL_UP))
	assert_eq(_joy_buttons(&"slot_next"), [JOY_BUTTON_DPAD_RIGHT] as Array[int])
	assert_eq(_joy_buttons(&"slot_prev"), [JOY_BUTTON_DPAD_LEFT] as Array[int])


func test_list_up_and_down_are_the_arrows_and_the_d_pad() -> void:
	assert_true(_has_key(&"list_up", KEY_UP))
	assert_true(_has_key(&"list_down", KEY_DOWN))
	assert_eq(_joy_buttons(&"list_up"), [JOY_BUTTON_DPAD_UP] as Array[int])
	assert_eq(_joy_buttons(&"list_down"), [JOY_BUTTON_DPAD_DOWN] as Array[int])


func test_the_hud_actions_are_in_the_project_file() -> void:
	var actions := _project_actions()
	for action: String in ["use_item", "slot_1", "slot_12", "slot_next", "slot_prev", "list_up", "list_down"]:
		assert_true(actions.has(action), action)


func test_no_input_is_bound_to_two_project_actions() -> void:
	var owners: Dictionary[String, String] = {}
	var clashes: PackedStringArray = []
	for action: String in _project_actions():
		for event: InputEvent in InputMap.action_get_events(StringName(action)):
			var signature := _signature(event)
			if signature.is_empty():
				continue
			if owners.has(signature) and owners[signature] != action:
				clashes.append("%s: %s and %s" % [signature, owners[signature], action])
			owners[signature] = action
	assert_gt(owners.size(), 20, "the project's inputs were read")
	assert_eq(clashes, PackedStringArray(), "inputs bound to two actions")
