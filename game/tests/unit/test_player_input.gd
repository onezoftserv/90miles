extends GutTest
## player-movement: named input actions with keyboard and gamepad defaults, and the intent
## PlayerInput builds from them.

const ACTIONS: Array[StringName] = [&"move_up", &"move_down", &"move_left", &"move_right", &"run", &"crouch", &"interact"]

var player_input: PlayerInput


func before_each() -> void:
	player_input = PlayerInput.new()
	add_child_autofree(player_input)


func after_each() -> void:
	Input.action_release(&"move_right")
	_stick(0, 0.0)
	_stick(1, 0.0)
	for action: StringName in ACTIONS:
		Input.action_release(action)


func _stick(axis: int, value: float) -> void:
	var event := InputEventJoypadMotion.new()
	event.device = 0
	event.axis = axis
	event.axis_value = value
	Input.parse_input_event(event)
	Input.flush_buffered_events()


func _has_key(action: StringName, keycode: Key) -> bool:
	for event: InputEvent in InputMap.action_get_events(action):
		var key := event as InputEventKey
		if key != null and key.physical_keycode == keycode:
			return true
	return false


func _has_button(action: StringName) -> bool:
	for event: InputEvent in InputMap.action_get_events(action):
		if event is InputEventJoypadButton:
			return true
	return false


func _has_axis(action: StringName, axis: int, sign_value: float) -> bool:
	for event: InputEvent in InputMap.action_get_events(action):
		var motion := event as InputEventJoypadMotion
		if motion != null and motion.axis == axis and signf(motion.axis_value) == sign_value:
			return true
	return false


func test_every_action_is_defined() -> void:
	for action: StringName in ACTIONS:
		assert_true(InputMap.has_action(action), "action %s" % action)


func test_keyboard_defaults() -> void:
	assert_true(_has_key(&"move_up", KEY_W))
	assert_true(_has_key(&"move_down", KEY_S))
	assert_true(_has_key(&"move_left", KEY_A))
	assert_true(_has_key(&"move_right", KEY_D))
	assert_true(_has_key(&"run", KEY_SHIFT))
	assert_true(_has_key(&"crouch", KEY_CTRL))
	assert_true(_has_key(&"crouch", KEY_C))
	assert_true(_has_key(&"interact", KEY_E))


func test_gamepad_defaults() -> void:
	assert_true(_has_axis(&"move_up", 1, -1.0))
	assert_true(_has_axis(&"move_down", 1, 1.0))
	assert_true(_has_axis(&"move_left", 0, -1.0))
	assert_true(_has_axis(&"move_right", 0, 1.0))
	assert_true(_has_button(&"run"), "run on a shoulder button")
	assert_true(_has_button(&"crouch"), "crouch on a face button")
	assert_true(_has_button(&"interact"), "interact on another face button")


func test_idle_gives_a_zero_intent() -> void:
	var intent := player_input.build_intent()
	assert_eq(intent.direction, Vector2.ZERO)
	assert_false(intent.run or intent.crouch or intent.interact_held)


func test_d_key_gives_an_east_intent_of_strength_1() -> void:
	Input.action_press(&"move_right")
	var intent := player_input.build_intent()
	assert_almost_eq(intent.direction.x, 1.0, 0.001)
	assert_almost_eq(intent.direction.y, 0.0, 0.001)
	assert_almost_eq(intent.direction.length(), 1.0, 0.001)


func test_full_right_stick_gives_an_east_intent_of_strength_1() -> void:
	_stick(0, 1.0)
	var intent := player_input.build_intent()
	assert_almost_eq(intent.direction.x, 1.0, 0.001)
	assert_almost_eq(intent.direction.length(), 1.0, 0.001)


func test_diagonal_keys_are_clamped_to_length_1() -> void:
	Input.action_press(&"move_right")
	Input.action_press(&"move_down")
	var intent := player_input.build_intent()
	assert_almost_eq(intent.direction.length(), 1.0, 0.001)


func test_run_crouch_and_interact_are_copied_into_the_intent() -> void:
	Input.action_press(&"run")
	Input.action_press(&"crouch")
	Input.action_press(&"interact")
	var intent := player_input.build_intent()
	assert_true(intent.run)
	assert_true(intent.crouch)
	assert_true(intent.interact_held)


func test_body_follows_the_input_node_when_enabled() -> void:
	var body := (preload("res://scenes/player/player.tscn") as PackedScene).instantiate() as PlayerBody
	add_child_autofree(body)
	Input.action_press(&"move_right")
	body.get_node(^"PlayerInput")._physics_process(1.0 / 60.0)
	assert_almost_eq(body.intent.direction.x, 1.0, 0.001)


func test_disabled_input_leaves_the_intent_alone() -> void:
	var body := (preload("res://scenes/player/player.tscn") as PackedScene).instantiate() as PlayerBody
	add_child_autofree(body)
	var remote_input := body.get_node(^"PlayerInput") as PlayerInput
	remote_input.enabled = false
	body.intent = MoveIntent.create(Vector2.UP)
	Input.action_press(&"move_right")
	remote_input._physics_process(1.0 / 60.0)
	assert_eq(body.intent.direction, Vector2.UP)
