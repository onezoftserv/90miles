class_name VesselIntegrity
extends RefCounted
## The hit points of a crossing's vessel (crossing "Vessel integrity"). Pure logic: a swimmers'
## route has a vessel with none, which takes no hits and never breaks.

## Emitted once, by the hit that takes the vessel to 0.
signal broke

var maximum: float = 0.0
var value: float = 0.0
var broken: bool = false


## A vessel at `starting`, whose maximum is `top` when given (the route's full integrity, so a plank
## can mend a raft launched damaged), else `starting`.
static func create(starting: float, top: float = -1.0) -> VesselIntegrity:
	var integrity := VesselIntegrity.new()
	integrity.maximum = maxf(maxf(starting, top), 0.0)
	integrity.value = maxf(starting, 0.0)
	return integrity


## False for swimmers: there is no vessel to hit, climb or pull people onto.
func has_integrity() -> bool:
	return maximum > 0.0


## True while there is a vessel people can be aboard.
func intact() -> bool:
	return has_integrity() and not broken


## Adds `amount` back, never above the maximum; nothing for a broken vessel (crossing "Flotsam").
func repair(amount: float) -> void:
	if intact():
		value = minf(value + amount, maximum)


## Takes `amount` off, never below 0. True on the hit that breaks the vessel.
func hit(amount: float) -> bool:
	if not intact():
		return false
	value = maxf(value - amount, 0.0)
	if value > 0.0:
		return false
	broken = true
	broke.emit()
	return true
