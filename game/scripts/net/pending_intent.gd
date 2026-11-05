class_name PendingIntent
extends RefCounted
## One intent a client has sent and predicted but the host has not acknowledged yet.

var seq: int = 0
var intent: MoveIntent = MoveIntent.new()
## The client's physics step for this intent; the host steps the body by the same amount.
var delta: float = 0.0


static func create(number: int, move_intent: MoveIntent, step_s: float) -> PendingIntent:
	var pending := PendingIntent.new()
	pending.seq = number
	pending.intent = move_intent
	pending.delta = step_s
	return pending
