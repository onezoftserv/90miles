class_name CaptureRules
extends RefCounted
## guardacostas-capture design.md §2 and §7: what a capture and a rescue do to a player's body, on the
## host. A captive cannot move or act (PlayerBody.captive): a soldier leads them by the drag handle's
## dragger at drag speed, or they sit in the dinghy, or ride aboard the boat that hauled them. Their
## spot meter is cleared and their hold on anything is dropped. Freeing undoes it where they stand.


## Host: `body` is captured by `by` (the soldier that leads them away, or the boat that hauled them
## aboard) with `patrol`'s freeing numbers.
static func capture(body: PlayerBody, by: Node2D, patrol: PatrolData, aboard: bool = false) -> void:
	body.set_captive(true, by, aboard)
	body.free_handle.guard_radius_tiles = patrol.free_guard_radius_tiles
	body.free_handle.hold_time_s = patrol.free_hold_s
	body.spot_meter.clear()


## Host: `body` is free again, standing where it is.
static func release(body: PlayerBody) -> void:
	body.set_captive(false)
