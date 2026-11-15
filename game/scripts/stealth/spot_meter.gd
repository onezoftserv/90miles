class_name SpotMeter
extends RefCounted
## guardacostas-stealth decision 5: one meter per player, in seconds, on the host. It fills
## `fill_per_s` per second while the player is lit by any cone and not hidden, and loses
## `drain_per_s` per second otherwise, never going below 0. At the spot time plus the player's
## Stealth bonus the player is spotted and the meter goes back to 0. A dead or dropped player's
## meter is cleared. Threshold checks use the movement model's 1e-6 tolerance.

const EPSILON: float = 0.000001
## Stealth levels that count (each adds STEALTH_SECONDS_PER_LEVEL to the spot time).
const MAX_STEALTH_LEVELS: int = 3
const STEALTH_SECONDS_PER_LEVEL: float = 1.0

var fill_per_s: float = 1.0
var drain_per_s: float = 0.5
var spot_time_s: float = 2.0
## Seconds on the meter now.
var value: float = 0.0


static func from_patrol(patrol: PatrolData) -> SpotMeter:
	var meter := SpotMeter.new()
	meter.fill_per_s = patrol.spot_fill_per_s
	meter.drain_per_s = patrol.spot_drain_per_s
	meter.spot_time_s = patrol.spot_time_s
	return meter


## One step of `delta` seconds. `bonus_s` is the player's Stealth bonus (stealth_bonus_s).
## Returns true when this step spotted the player; the meter is then 0.
func step(lit: bool, hidden: bool, delta: float, bonus_s: float = 0.0) -> bool:
	if lit and not hidden:
		value += fill_per_s * delta
	else:
		value = maxf(value - drain_per_s * delta, 0.0)
	if delta > 0.0 and value >= spot_time_s + bonus_s - EPSILON:
		value = 0.0
		return true
	return false


## The meter as a fraction of the time it needs, 0 to 1: what PlayerNet sends as net_spot.
func fraction(bonus_s: float = 0.0) -> float:
	var needed: float = spot_time_s + bonus_s
	return clampf(value / needed, 0.0, 1.0) if needed > 0.0 else 0.0


## Empties the meter: the player died or dropped.
func clear() -> void:
	value = 0.0


## Seconds Stealth adds to the spot time: 1 s a level, up to 3 levels, plus any PATROL_SPOT_TIME
## ADD modifier the player carries (a seam: no modifier source feeds it yet).
static func stealth_bonus_s(level: int, modifiers: Array[ModifierData] = []) -> float:
	var bonus: float = float(clampi(level, 0, MAX_STEALTH_LEVELS)) * STEALTH_SECONDS_PER_LEVEL
	for modifier: ModifierData in modifiers:
		if modifier.stat == ModifierData.Stat.PATROL_SPOT_TIME and modifier.op == ModifierData.Op.ADD:
			bonus += modifier.value
	return bonus


## The Stealth skill level of `_player`. The seam for the skill: 0 until the skill exists.
static func stealth_level_of(_player: Node) -> int:
	return 0
