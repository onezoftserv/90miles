class_name PressTimer
extends RefCounted
## Times one held press for the HUD (inventory-hud "Using the selected item", "Hold ring"; design
## D3): it counts the seconds a button has been held against a duration and says on which call
## they are up, with InteractionHold's tolerance, so a hold the HUD times ends on the frame the
## host's would. An interact press also locks its target as InteractionHold does (`lock`, `keeps`):
## it stays on it while held, even when another comes nearer, and lets go when the target is
## freed or disabled, or, before the hold is done, when the player is out of reach. It never uses
## anything: the HUD sends the request and the host decides.

## A sum of frame deltas that falls this short of the duration still counts as reaching it.
const TOLERANCE_S: float = 0.000001

var duration_s: float = 0.0
var elapsed_s: float = 0.0
## A hold is being timed.
var running: bool = false
## The hold reached its duration; it stays done until reset.
var completed: bool = false
## The interactable an interact press is locked on, or null.
var target: Interactable = null


## Starts timing a hold of `duration` seconds (0: the first `advance` ends it).
func start(duration: float) -> void:
	duration_s = maxf(duration, 0.0)
	elapsed_s = 0.0
	running = true
	completed = false
	target = null


## Starts timing a press on `on` for its hold time and locks it.
func lock(on: Interactable) -> void:
	start(on.hold_time_s)
	target = on


## Adds `delta` to the running hold; true on the call that reaches the duration, which also ends
## it. False while nothing runs.
func advance(delta: float) -> bool:
	if not running:
		return false
	elapsed_s += delta
	if elapsed_s >= duration_s - TOLERANCE_S:
		running = false
		completed = true
		return true
	return false


## How much of the duration has been held, 0 to 1: 1 once done, 0 when nothing runs.
func progress() -> float:
	if completed:
		return 1.0
	if not running:
		return 0.0
	if duration_s <= 0.0:
		return 1.0
	return clampf(elapsed_s / duration_s, 0.0, 1.0)


## Stops timing and drops the lock.
func reset() -> void:
	running = false
	completed = false
	elapsed_s = 0.0
	target = null


## Whether the locked target still holds for `by`: it exists and is enabled, and, until the hold is
## done, `by` is within `reach_px` of it (a finished press, such as a drag, keeps it however far).
## A lock that no longer holds is dropped.
func keeps(by: Node2D, reach_px: float) -> bool:
	var holds: bool = is_instance_valid(target) and target.enabled
	if holds and not completed:
		holds = by.global_position.distance_to(target.global_position) <= reach_px
	if not holds:
		reset()
	return holds
