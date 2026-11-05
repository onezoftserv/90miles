extends GutTest
## coop-networking "Quick chat": the radial wheel, opened by holding the quick-chat button;
## 8 sectors of 45° clockwise from north.

const WHEEL_SCENE: PackedScene = preload("res://scenes/ui/quick_chat_wheel.tscn")


func _wheel() -> QuickChatWheel:
	var wheel := WHEEL_SCENE.instantiate() as QuickChatWheel
	wheel.phrases = QuickChatPhrases.from_catalog(ContentCatalog.new())
	add_child_autofree(wheel)
	return wheel


func test_eight_sectors_clockwise_from_north() -> void:
	var directions: Array[Vector2] = [
		Vector2.UP, Vector2(1, -1), Vector2.RIGHT, Vector2(1, 1),
		Vector2.DOWN, Vector2(-1, 1), Vector2.LEFT, Vector2(-1, -1),
	]
	for slot: int in directions.size():
		assert_eq(QuickChatWheel.slot_for(directions[slot]), slot, "direction %s" % directions[slot])


func test_sector_edges_are_22_5_degrees_either_side() -> void:
	assert_eq(QuickChatWheel.slot_for(Vector2.UP.rotated(deg_to_rad(22.0))), 0)
	assert_eq(QuickChatWheel.slot_for(Vector2.UP.rotated(deg_to_rad(23.0))), 1)
	assert_eq(QuickChatWheel.slot_for(Vector2.UP.rotated(deg_to_rad(-23.0))), 7)


func test_the_center_picks_nothing() -> void:
	assert_eq(QuickChatWheel.slot_for(Vector2.ZERO), -1)
	assert_eq(QuickChatWheel.slot_for(Vector2(0.1, 0.1)), -1)


func test_the_wheel_shows_the_phrase_file_text() -> void:
	var wheel := _wheel()
	for slot: int in QuickChatPhrases.SLOTS:
		assert_eq(wheel.slot_label(slot).text, wheel.phrases.text(slot))


func test_it_is_hidden_until_opened() -> void:
	var wheel := _wheel()
	assert_false(wheel.visible)
	wheel.open()
	assert_true(wheel.visible)


func test_releasing_over_a_phrase_picks_it() -> void:
	var wheel := _wheel()
	watch_signals(wheel)
	wheel.open()
	wheel.aim(Vector2.RIGHT)
	assert_eq(wheel.selected, 2)
	assert_eq(wheel.release(), 2)
	assert_signal_emitted_with_parameters(wheel, "phrase_picked", [2])
	assert_false(wheel.visible)


func test_releasing_in_the_center_picks_nothing() -> void:
	var wheel := _wheel()
	watch_signals(wheel)
	wheel.open()
	wheel.aim(Vector2.ZERO)
	assert_eq(wheel.release(), -1)
	assert_signal_not_emitted(wheel, "phrase_picked")


func test_the_quick_chat_button_is_q_and_the_right_shoulder() -> void:
	assert_true(InputMap.has_action(&"quick_chat"))
	var keys: Array[int] = []
	var buttons: Array[int] = []
	for event: InputEvent in InputMap.action_get_events(&"quick_chat"):
		if event is InputEventKey:
			keys.append((event as InputEventKey).physical_keycode)
		elif event is InputEventJoypadButton:
			buttons.append((event as InputEventJoypadButton).button_index)
	assert_eq(keys, [KEY_Q] as Array[int])
	assert_eq(buttons, [JOY_BUTTON_RIGHT_SHOULDER] as Array[int])
