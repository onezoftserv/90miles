class_name InteractionHold
extends RefCounted
## One player's interact button state: locks the target when the press starts, counts how long
## it has been held, uses the target when its hold time is reached, and resets on release.

## A sum of frame deltas that falls this short of the hold time still counts as reaching it (the
## HUD's PressTimer reads the same, so its ring ends on this frame).
const TOLERANCE_S: float = 0.000001

## The interactable locked by the current press, or null.
var target: Interactable = null
var progress_s: float = 0.0
## True once the target was used by the current press.
var completed: bool = false


## Call every frame. `held`: the interact button is down. `candidate`: what the picker found
## now (only looked at when a press starts). Returns true on the frame the target was used.
func update(held: bool, delta: float, by: Node, candidate: Interactable) -> bool:
	if not held:
		_reset(by)
		return false
	if not is_instance_valid(target):
		# No press in progress, or the target was freed under it: start over.
		target = null
		progress_s = 0.0
		completed = false
		if candidate == null or not is_instance_valid(candidate) or not candidate.enabled:
			return false
		target = candidate
	elif not target.enabled:
		_reset(by)
		return false
	if completed:
		return false
	progress_s += delta
	if progress_s >= target.hold_time_s - TOLERANCE_S:
		completed = true
		target.use(by)
		return true
	return false


## Drops the press in progress (the target went out of reach) without using it.
func cancel(by: Node) -> void:
	_reset(by)


func _reset(by: Node) -> void:
	if completed and target != null and is_instance_valid(target):
		target.release(by)
	target = null
	progress_s = 0.0
	completed = false
