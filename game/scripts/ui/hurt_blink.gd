class_name HurtBlink
extends RefCounted
## The hurt blink of one body (survival-meters "Hurt cue on the body"; damage-feedback design D4):
## white for the frame of the hit, then hidden and shown at `hz` until `duration_s`, or a steady
## tint for that time with "Reducir destellos". A pure state stepped by the look that draws it:
## time comes only from the frames it is given.

## Slack for the frame times added up in floats.
const EPSILON_S: float = 0.000001

var duration_s: float = 0.6
var hz: float = 10.0

var _active: bool = false
var _elapsed_s: float = 0.0


func _init(blink_s: float = 0.6, blink_hz: float = 10.0) -> void:
	duration_s = blink_s
	hz = blink_hz


## A hit: the blink starts again from its white frame.
func start() -> void:
	_active = true
	_elapsed_s = 0.0


## After a drawn frame of `delta` seconds.
func advance(delta: float) -> void:
	if not _active:
		return
	_elapsed_s += maxf(delta, 0.0)
	if _elapsed_s >= duration_s - EPSILON_S:
		_active = false


func active() -> bool:
	return _active


## Whether this frame draws the body white: only the frame of the hit, never with reduce flashes.
func white(reduce_flashes: bool) -> bool:
	return _active and not reduce_flashes and _elapsed_s <= EPSILON_S


## Whether this frame hides the body: half of each blink after the white frame.
func hidden(reduce_flashes: bool) -> bool:
	if not _active or reduce_flashes or _elapsed_s <= EPSILON_S:
		return false
	return int(floor(_elapsed_s * hz * 2.0 + EPSILON_S)) % 2 == 0


## Whether this frame tints the body: the whole blink, only with reduce flashes.
func tinted(reduce_flashes: bool) -> bool:
	return _active and reduce_flashes
