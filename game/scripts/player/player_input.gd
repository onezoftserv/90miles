class_name PlayerInput
extends Node
## Turns the named input actions into a MoveIntent for the local player and hands it to the
## parent PlayerBody. The body itself never reads Input (player-movement spec, intents).

## Off for remote players: their intents arrive from the network instead.
var enabled: bool = true


func _init() -> void:
	# Run before the body so its intent is current in the same physics frame.
	process_physics_priority = -10


func build_intent() -> MoveIntent:
	var intent := MoveIntent.new()
	intent.direction = Input.get_vector(&"move_left", &"move_right", &"move_up", &"move_down")
	intent.run = Input.is_action_pressed(&"run")
	intent.crouch = Input.is_action_pressed(&"crouch")
	intent.interact_held = Input.is_action_pressed(&"interact")
	return intent


func _physics_process(_delta: float) -> void:
	if not enabled:
		return
	var body := get_parent() as PlayerBody
	if body != null:
		body.intent = build_intent()
