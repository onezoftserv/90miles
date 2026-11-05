class_name MovementModel
extends RefCounted
## The player-movement rules as pure logic: terrain, energy, an intent and a time step in,
## velocity (tiles/s), energy spent and movement/stealth states out. PlayerBody only applies
## the result. One model per player: it remembers the dive in progress.

const WALK_SPEED: float = 4.0
const RUN_SPEED: float = 6.0
const CROUCH_SPEED: float = 2.0
## Provisional (proposal.md, decision 1): no doc gives a crawl speed.
const CRAWL_SPEED: float = 1.0
const SWIM_SPEED: float = 3.0
const DRAG_SPEED: float = 2.0
## A dragged body stops this close (tiles) to the dragger.
const DRAG_STOP_DISTANCE: float = 0.5

const RUN_ENERGY_PER_S: float = 0.5
const SWIM_ENERGY_PER_S: float = 3.0
const DIVE_ENERGY_COST: float = 10.0
const DIVE_MAX_S: float = 5.0

var _diving: bool = false
var _dive_time_s: float = 0.0
## Set once a dive ended or was refused; cleared when crouch is released or the water left.
var _dive_locked: bool = false


func step(terrain: DataEnums.Terrain, current: Vector2, energy: float, intent: MoveIntent, delta: float) -> MovementStep:
	var result := MovementStep.new()
	var direction: Vector2 = intent.direction.limit_length(1.0)
	var moving: bool = direction.length_squared() > 0.0
	var brush: bool = TerrainQuery.is_brush(terrain)
	var cost: float = 0.0

	if TerrainQuery.is_water(terrain):
		if energy <= 0.0:
			_end_dive(intent.crouch)
			result.movement = MovementStep.Move.FLOAT
			result.velocity = current
		else:
			result.movement = MovementStep.Move.SWIM
			result.velocity = direction * SWIM_SPEED
			if moving:
				cost += SWIM_ENERGY_PER_S * delta
			cost += _update_dive(result, energy, intent.crouch, delta)
	else:
		_end_dive(false)
		_dive_locked = false
		if energy <= 0.0:
			result.movement = MovementStep.Move.CRAWL
			result.velocity = direction * CRAWL_SPEED
		elif intent.crouch:
			result.movement = MovementStep.Move.CROUCH
			result.velocity = direction * CROUCH_SPEED
		elif intent.run and moving:
			result.movement = MovementStep.Move.RUN
			result.velocity = direction * RUN_SPEED
			cost += RUN_ENERGY_PER_S * delta
		else:
			result.movement = MovementStep.Move.WALK
			result.velocity = direction * WALK_SPEED
		if intent.crouch and brush:
			result.stealth = MovementStep.Stealth.HIDDEN

	result.energy_spent = minf(cost, maxf(energy, 0.0))
	return result


## A downed body being dragged: 2 tiles/s toward the dragger, stopping DRAG_STOP_DISTANCE short
## and never overshooting within one step. `to_dragger` is in tiles.
func drag_step(to_dragger: Vector2, delta: float) -> MovementStep:
	var result := MovementStep.new()
	result.movement = MovementStep.Move.DRAGGED
	var gap: float = to_dragger.length() - DRAG_STOP_DISTANCE
	if gap > 0.0 and delta > 0.0:
		result.velocity = to_dragger.normalized() * minf(DRAG_SPEED, gap / delta)
	return result


# Dive bookkeeping while swimming with energy. Returns the energy a dive start costs.
func _update_dive(result: MovementStep, energy: float, crouching: bool, delta: float) -> float:
	if not crouching:
		_end_dive(false)
		_dive_locked = false
		return 0.0
	var cost: float = 0.0
	if not _diving and not _dive_locked:
		if energy >= DIVE_ENERGY_COST:
			_diving = true
			_dive_time_s = 0.0
			cost = DIVE_ENERGY_COST
		else:
			_dive_locked = true
	if _diving:
		_dive_time_s += delta
		if _dive_time_s > DIVE_MAX_S + 0.000001:
			_end_dive(true)
		else:
			result.movement = MovementStep.Move.DIVE
			result.stealth = MovementStep.Stealth.SUBMERGED
	return cost


func _end_dive(lock: bool) -> void:
	_diving = false
	_dive_time_s = 0.0
	_dive_locked = lock
