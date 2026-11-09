class_name InputLabels
extends RefCounted
## The keys the HUD shows (inventory-hud "Key labels follow the device", design D10), read from
## the input map for the last device used: a key as the player's keyboard layout prints it, a
## mouse or gamepad button by its name in the HUD text file. Only a gamepad button press or a
## stick past its action's deadzone counts as picking up the gamepad, so drift and trigger noise
## never flip the labels; a key press or a mouse button switches back.

enum Device {
	KEYBOARD,
	GAMEPAD,
}

## Above this keycode Godot's keys are named keys (Shift, F11, arrows), not printed characters.
const LAST_PRINTED_KEY: int = 0xFFFF


## The label of `action`'s first binding for `device`, or "" when it has none there. Keyboard:
## a key, else a mouse button; gamepad: a button, else a stick or trigger.
static func label_for(action: StringName, device: Device, text: HudText = null, locale: String = "es") -> String:
	if not InputMap.has_action(action):
		return ""
	var names: HudText = text if text != null else HudText.load_default()
	var events: Array[InputEvent] = InputMap.action_get_events(action)
	if device == Device.KEYBOARD:
		for event: InputEvent in events:
			var key := event as InputEventKey
			if key != null:
				return key_label(key.physical_keycode if key.physical_keycode != KEY_NONE else key.keycode)
		for event: InputEvent in events:
			var mouse := event as InputEventMouseButton
			if mouse != null:
				return names.mouse_button(mouse.button_index, locale)
		return ""
	for event: InputEvent in events:
		var button := event as InputEventJoypadButton
		if button != null:
			return names.joy_button(button.button_index, locale)
	for event: InputEvent in events:
		var motion := event as InputEventJoypadMotion
		if motion != null:
			return names.joy_axis(motion.axis, locale)
	return ""


## What the key at `physical` prints on this keyboard: "E", "-", or "¡" on a Spanish layout. The
## headless display server has no layout, so there the US key position stands for itself.
static func key_label(physical: Key) -> String:
	var printed: int = physical
	if DisplayServer.get_name() != "headless":
		printed = DisplayServer.keyboard_get_label_from_physical(physical)
	if printed > KEY_SPACE and printed <= LAST_PRINTED_KEY:
		return String.chr(printed).to_upper()
	return OS.get_keycode_string(printed)


## The last device after `event`, from `current`.
static func device_after(event: InputEvent, current: Device) -> Device:
	if event is InputEventJoypadButton:
		return Device.GAMEPAD if event.is_pressed() else current
	if event is InputEventJoypadMotion:
		return Device.GAMEPAD if _presses_an_action(event) else current
	if event is InputEventKey or event is InputEventMouseButton:
		return Device.KEYBOARD if event.is_pressed() else current
	return current


# A stick or trigger counts only past the deadzone of an action it is bound to.
static func _presses_an_action(event: InputEvent) -> bool:
	for action: StringName in InputMap.get_actions():
		if event.is_action_pressed(action):
			return true
	return false
