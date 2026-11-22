class_name SightCone
extends RefCounted
## guardacostas-capture design.md §5 (spec "Soldier sight"): a soldier's sight as host geometry, beside
## the boat's Searchlight. A cone along the soldier's facing: by day `soldier_day_sight_deg` wide and
## `soldier_day_sight_tiles` long, at night (the phases the patrol's searchlight is on) the narrower,
## shorter flashlight. A point is seen when it is within the length and within half the cone of the
## facing. Terrain does not block it, as it does not block the searchlight: cover is the hidden states,
## which the spot meter applies. In weather that disables SIGHT nothing is seen. Every Vector2 is in
## tiles; angles are degrees in screen space (y down).

const EPSILON: float = 0.000001

## The cone's full width in degrees.
var cone_deg: float = 120.0
## The cone's length in tiles.
var range_tiles: float = 6.0


## The soldier's cone for `phase`: the flashlight in the phases `patrol`'s searchlight is on, the day
## cone otherwise.
static func for_soldier(patrol: PatrolData, phase: DataEnums.DayPhase) -> SightCone:
	var cone := SightCone.new()
	if patrol.searchlight_phases.has(phase):
		cone.cone_deg = patrol.soldier_night_sight_deg
		cone.range_tiles = patrol.soldier_night_sight_tiles
	else:
		cone.cone_deg = patrol.soldier_day_sight_deg
		cone.range_tiles = patrol.soldier_day_sight_tiles
	return cone


## True when `point` is within the length and within half the cone of `facing` from `eye`. A soldier
## standing on the point sees it whatever its facing.
func sees(point: Vector2, eye: Vector2, facing: Vector2) -> bool:
	var gap: Vector2 = point - eye
	var distance: float = gap.length()
	if distance > range_tiles + EPSILON:
		return false
	if distance <= EPSILON or facing == Vector2.ZERO:
		return distance <= EPSILON
	var off: float = absf(wrapf(rad_to_deg(gap.angle() - facing.angle()), -180.0, 180.0))
	return off <= cone_deg / 2.0 + EPSILON


## Whether a chase holds: the chased player is not hidden and still within the cone's length (the
## soldier runs facing them, so the width does not matter), and the weather leaves sight working.
func chase_holds(point: Vector2, eye: Vector2, hidden: bool, disabled_senses: Array[DataEnums.Sense]) -> bool:
	if hidden or disabled_senses.has(DataEnums.Sense.SIGHT):
		return false
	return eye.distance_to(point) <= range_tiles + EPSILON


## Whether sight works in weather that disables `disabled_senses`.
static func sight_works(disabled_senses: Array[DataEnums.Sense]) -> bool:
	return not disabled_senses.has(DataEnums.Sense.SIGHT)
