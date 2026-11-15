class_name Searchlight
extends RefCounted
## guardacostas-stealth decision 4: the patrol boat's light as host geometry, not an Area2D. The
## beam's centre aims along the line from the boat to the island's centroid and swings from it as
## a triangle wave of amplitude arc / 2 at the sweep speed, so with the shipped 120 degree arc at
## 30 degrees per second a full back-and-forth takes 4 * 60 / 30 = 8 s. Its phase is the boat's
## time in sight (0 gives offset 0, rising positive first), so it is reproducible. A point is lit
## when it is within the range and within half the cone of the beam's centre. Terrain does not
## block the light. All angles are degrees in screen space (y down), as Vector2.angle() gives them.

const EPSILON: float = 0.000001

## The cone's full width in degrees.
var cone_deg: float = 60.0
## The cone's length in tiles.
var range_tiles: float = 10.0
## How fast the beam's centre swings, in degrees per second.
var sweep_deg_s: float = 30.0
## The range of the beam's centre in degrees (it swings +/- half of it).
var arc_deg: float = 120.0
## The day phases the light is on.
var phases: Array[DataEnums.DayPhase] = []


static func from_patrol(patrol: PatrolData) -> Searchlight:
	var light := Searchlight.new()
	light.cone_deg = patrol.searchlight_cone_deg
	light.range_tiles = patrol.searchlight_range_tiles
	light.sweep_deg_s = patrol.searchlight_sweep_deg_s
	light.arc_deg = patrol.searchlight_arc_deg
	light.phases = patrol.searchlight_phases.duplicate()
	return light


## Seconds one full back-and-forth takes; 0 when the beam does not sweep.
func period_s() -> float:
	if sweep_deg_s <= 0.0 or arc_deg <= 0.0:
		return 0.0
	return 2.0 * arc_deg / sweep_deg_s


## Degrees the beam's centre is from the island line after `sight_s` seconds in sight.
func offset_deg(sight_s: float) -> float:
	var period: float = period_s()
	if period <= 0.0:
		return 0.0
	var half_arc: float = arc_deg / 2.0
	var quarter: float = period / 4.0
	var t: float = fposmod(sight_s, period)
	if t < quarter:
		return sweep_deg_s * t
	if t < 3.0 * quarter:
		return half_arc - sweep_deg_s * (t - quarter)
	return -half_arc + sweep_deg_s * (t - 3.0 * quarter)


## The beam's centre angle: the direction from the boat to the centroid plus the sweep offset.
func beam_deg(boat: Vector2, centroid: Vector2, sight_s: float) -> float:
	return rad_to_deg((centroid - boat).angle()) + offset_deg(sight_s)


## True when `point` is within the range and within half the cone of the beam's centre.
func is_lit(point: Vector2, boat: Vector2, beam_angle_deg: float) -> bool:
	var gap: Vector2 = point - boat
	var distance: float = gap.length()
	if distance > range_tiles + EPSILON:
		return false
	if distance <= EPSILON:
		return true
	var off: float = absf(wrapf(rad_to_deg(gap.angle()) - beam_angle_deg, -180.0, 180.0))
	return off <= cone_deg / 2.0 + EPSILON


## is_lit for the swept beam `sight_s` seconds into the boat's time in sight.
func lights(point: Vector2, boat: Vector2, centroid: Vector2, sight_s: float) -> bool:
	return is_lit(point, boat, beam_deg(boat, centroid, sight_s))


## On only in a phase the data lists (night) and when the weather leaves sight enabled.
func is_on(phase: DataEnums.DayPhase, disabled_senses: Array[DataEnums.Sense]) -> bool:
	return phases.has(phase) and not disabled_senses.has(DataEnums.Sense.SIGHT)
