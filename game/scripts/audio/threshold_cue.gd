class_name ThresholdCue
extends RefCounted
## sound-pass design D5: a cue for a value falling to a step (low thirst at the Sed bar's pulse step).
## It fires once when the value falls to `at` or below while armed, and arms again only once the
## value has been above `rearm_above`. The first value only seeds: it is armed if above `at`, so a
## player first seen already at the step (a joiner) is not warned until they have recovered.

var at: float = 0.0
var rearm_above: float = 0.0
var _armed: bool = false
var _seen: bool = false


func _init(step: float = 25.0, rearm: float = 30.0) -> void:
	at = step
	rearm_above = rearm


## True when this value plays the cue.
func observe(value: float) -> bool:
	if not _seen:
		_seen = true
		_armed = value > at
		return false
	if _armed and value <= at:
		_armed = false
		return true
	if not _armed and value > rearm_above:
		_armed = true
	return false


## The next value seeds again (a new body).
func reset() -> void:
	_seen = false
	_armed = false
