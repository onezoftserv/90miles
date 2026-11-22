class_name BoatChase
extends RefCounted
## guardacostas-capture design.md §3 (spec "Boat chase at sea"): a boat chasing a swimmer, as a pure
## rule over plain values. Every Vector2 is in tiles. The boat closes at its chase speed (2× the swim
## speed, 6 tiles/s) through deep water only: a step whose cell is not deep is refused, so it stops at
## the edge of the deep water. While the swimmer stays within `haul_tiles` the haul counts, and at
## `haul_s` they are hauled aboard; the count resets the moment they leave that reach. The chase breaks
## when the swimmer dives (submerged), stands in shallow water, comes ashore (a landing: the boat's
## brain makes it a land alert) or gets more than `break_tiles` away. The boat's brain owns one per
## chase. Threshold checks use the movement model's 1e-6 tolerance.

enum Outcome {
	CHASING,
	HAULED,
	DIVED,
	SHALLOWS,
	LANDED,
	LOST,
}

const EPSILON: float = 0.000001

var speed_tiles_s: float = 6.0
var haul_tiles: float = 1.0
var haul_s: float = 2.0
var break_tiles: float = 10.0
## Seconds the swimmer has been within haul_tiles without a break.
var touch_s: float = 0.0


## One step's result: where the boat is now and how the chase stands.
class Step extends RefCounted:
	var position: Vector2 = Vector2.ZERO
	var outcome: BoatChase.Outcome = BoatChase.Outcome.CHASING


## A chase with `patrol`'s numbers; `own_speed_tiles_s` is the boat's own speed (for a patrol whose
## chase speed is not a multiple of the swim speed).
static func from_patrol(patrol: PatrolData, own_speed_tiles_s: float) -> BoatChase:
	var chase := BoatChase.new()
	chase.speed_tiles_s = patrol.chase_speed_tiles_s(own_speed_tiles_s)
	chase.haul_tiles = patrol.haul_tiles
	chase.haul_s = patrol.haul_s
	chase.break_tiles = patrol.chase_break_tiles
	return chase


## Whether a patrol with these numbers chases at all (a speed and a haul time above 0).
static func can_chase(patrol: PatrolData, own_speed_tiles_s: float) -> bool:
	return patrol.chase_speed_tiles_s(own_speed_tiles_s) > 0.0 and patrol.haul_s > 0.0


## True for the outcome that becomes a landing (the swimmer came ashore).
static func is_landing(outcome: Outcome) -> bool:
	return outcome == Outcome.LANDED


## One step of `delta` seconds: the boat at `boat`, the swimmer at `target` on a cell of
## `target_terrain`, `submerged` while they dive. `is_deep(cell: Vector2i) -> bool` answers the sea.
func step(boat: Vector2, target: Vector2, target_terrain: DataEnums.Terrain, submerged: bool, delta: float, is_deep: Callable) -> Step:
	var result := Step.new()
	result.position = boat
	result.outcome = _broken(boat, target, target_terrain, submerged)
	if result.outcome != Outcome.CHASING:
		touch_s = 0.0
		return result
	result.position = BoatChase.move_toward(boat, target, speed_tiles_s * delta, is_deep)
	if result.position.distance_to(target) <= haul_tiles + EPSILON:
		touch_s += delta
		if touch_s >= haul_s - EPSILON:
			result.outcome = Outcome.HAULED
	else:
		touch_s = 0.0
	return result


func _broken(boat: Vector2, target: Vector2, target_terrain: DataEnums.Terrain, submerged: bool) -> Outcome:
	if submerged:
		return Outcome.DIVED
	if not TerrainQuery.is_water(target_terrain):
		return Outcome.LANDED
	if target_terrain != DataEnums.Terrain.DEEP:
		return Outcome.SHALLOWS
	if boat.distance_to(target) > break_tiles + EPSILON:
		return Outcome.LOST
	return Outcome.CHASING


## Up to `distance` tiles from `boat` toward `target`, straight or sliding along an axis, never onto
## a cell `is_deep` refuses; standing still when every way is refused.
static func move_toward(boat: Vector2, target: Vector2, distance: float, is_deep: Callable) -> Vector2:
	var gap: Vector2 = target - boat
	var length: float = gap.length()
	if length <= EPSILON or distance <= 0.0:
		return boat
	var move: float = minf(distance, length)
	var direction: Vector2 = gap / length
	for option: Vector2 in [direction, Vector2(signf(direction.x), 0.0), Vector2(0.0, signf(direction.y))]:
		if option == Vector2.ZERO:
			continue
		var next: Vector2 = boat + option * move
		if is_deep.call(Vector2i(floori(next.x), floori(next.y))):
			return next
	return boat
