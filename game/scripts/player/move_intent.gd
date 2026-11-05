class_name MoveIntent
extends RefCounted
## What a player wants to do this frame (player-movement spec, "Movement follows intents").
## Built by PlayerInput for the local player; set directly by tests and, later, by coop-networking.

## Move direction; its length is clamped to 1 (analog strength).
var direction: Vector2 = Vector2.ZERO:
	set(value):
		direction = value.limit_length(1.0)
var run: bool = false
var crouch: bool = false
var interact_held: bool = false


static func create(move_direction: Vector2 = Vector2.ZERO, running: bool = false, crouching: bool = false, interacting: bool = false) -> MoveIntent:
	var intent := MoveIntent.new()
	intent.direction = move_direction
	intent.run = running
	intent.crouch = crouching
	intent.interact_held = interacting
	return intent


## An independent copy (the network keeps intents after the input code has moved on).
func copy() -> MoveIntent:
	return MoveIntent.create(direction, run, crouch, interact_held)
