class_name PressTimer
extends RefCounted
## Times one held press for the HUD (inventory-hud "Using the selected item", "Hold ring"; design
## D3): it counts the seconds a button has been held against a duration and says on which call
## they are up, with InteractionHold's tolerance, so a hold the HUD times ends on the frame the
## host's would. It never uses anything: the HUD sends the request and the host decides.

## A sum of frame deltas that falls this short of the duration still counts as reaching it.
const TOLERANCE_S: float = 0.000001

var duration_s: float = 0.0
var elapsed_s: float = 0.0
## A hold is being timed.
var running: bool = false


## Starts timing a hold of `duration` seconds (0: the first `advance` ends it).
func start(duration: float) -> void:
	duration_s = maxf(duration, 0.0)
	elapsed_s = 0.0
	running = true


## Adds `delta` to the running hold; true on the call that reaches the duration, which also ends
## it. False while nothing runs.
func advance(delta: float) -> bool:
	if not running:
		return false
	elapsed_s += delta
	if elapsed_s >= duration_s - TOLERANCE_S:
		running = false
		return true
	return false


## How much of the duration has been held, 0 to 1; 0 when nothing runs.
func progress() -> float:
	if not running:
		return 0.0
	if duration_s <= 0.0:
		return 1.0
	return clampf(elapsed_s / duration_s, 0.0, 1.0)


## Stops timing without ending the hold.
func reset() -> void:
	running = false
	elapsed_s = 0.0
