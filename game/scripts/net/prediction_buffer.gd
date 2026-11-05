class_name PredictionBuffer
extends RefCounted
## The client's numbered intents (coop-networking "Host authority"): each intent the client
## predicts is kept until the host acknowledges it, so a correction from the host can be
## followed by a replay of the intents the host has not processed yet.

## About 2 s at 60 Hz. If the host stops acknowledging, the oldest are dropped; the next host
## state corrects whatever they would have replayed.
const MAX_PENDING: int = 120

## The seq of the newest pushed intent (0 before the first).
var last_seq: int = 0
## The newest seq the host has acknowledged.
var acked_seq: int = 0
var _pending: Array[PendingIntent] = []


## Stores a copy of `intent` with its time step and returns its seq (1, 2, 3...).
func push(intent: MoveIntent, delta: float) -> int:
	last_seq += 1
	_pending.append(PendingIntent.create(last_seq, intent.copy(), delta))
	while _pending.size() > MAX_PENDING:
		_pending.pop_front()
	return last_seq


## Drops every intent up to and including `seq`. Older acknowledgements change nothing.
func acknowledge(seq: int) -> void:
	if seq <= acked_seq:
		return
	acked_seq = seq
	while not _pending.is_empty() and _pending[0].seq <= seq:
		_pending.pop_front()


## The unacknowledged intents, oldest first.
func pending() -> Array[PendingIntent]:
	return _pending.duplicate()


func size() -> int:
	return _pending.size()


func clear() -> void:
	_pending.clear()
