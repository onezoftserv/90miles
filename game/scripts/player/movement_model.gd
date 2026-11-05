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
## Energy at or below this counts as empty: repeated float subtraction leaves crumbs like 2e-15.
const EXHAUSTED_EPSILON: float = 0.000001
## Length of get_state(): diving, dive time, locked.
const STATE_SIZE: int = 3

var _diving: bool = false
var _dive_time_s: float = 0.0
## Set once a dive ended or was refused; cleared when crouch is released or the water left.
var _dive_locked: bool = false


## `speed_factor` scales the player's own speed (sunstroke: 0.6), never the current or a drag.
func step(terrain: DataEnums.Terrain, current: Vector2, energy: float, intent: MoveIntent, delta: float, speed_factor: float = 1.0) -> MovementStep:
	var result := MovementStep.new()
	var direction: Vector2 = intent.direction.limit_length(1.0)
	var moving: bool = direction.length_squared() > 0.0
	var stride: Vector2 = direction * speed_factor
	var brush: bool = TerrainQuery.is_brush(terrain)
	var cost: float = 0.0

	if TerrainQuery.is_water(terrain):
		if energy <= EXHAUSTED_EPSILON:
			_end_dive(intent.crouch)
			result.movement = MovementStep.Move.FLOAT
			result.velocity = current
		else:
			result.movement = MovementStep.Move.SWIM
			result.velocity = stride * SWIM_SPEED
			if moving:
				cost += SWIM_ENERGY_PER_S * delta
			cost += _update_dive(result, energy, intent.crouch, delta)
	else:
		_end_dive(false)
		_dive_locked = false
		if energy <= EXHAUSTED_EPSILON:
			result.movement = MovementStep.Move.CRAWL
			result.velocity = stride * CRAWL_SPEED
		elif intent.crouch:
			result.movement = MovementStep.Move.CROUCH
			result.velocity = stride * CROUCH_SPEED
		elif intent.run and moving:
			result.movement = MovementStep.Move.RUN
			result.velocity = stride * RUN_SPEED
			cost += RUN_ENERGY_PER_S * delta
		else:
			result.movement = MovementStep.Move.WALK
			result.velocity = stride * WALK_SPEED
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
		# A dive that leaves no energy would end on the next step, so it needs more than the cost.
		if energy - DIVE_ENERGY_COST > EXHAUSTED_EPSILON:
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


## Forgets the dive in progress (the player went down).
func reset() -> void:
	_end_dive(false)


## The dive bookkeeping as [diving, dive time in s, locked]: the host sends it so a client
## replays its unacknowledged intents from the same state (coop-networking).
func get_state() -> PackedFloat64Array:
	return PackedFloat64Array([1.0 if _diving else 0.0, _dive_time_s, 1.0 if _dive_locked else 0.0])


## Restores what get_state() returned. Refuses (and changes nothing) for a malformed state.
func set_state(state: PackedFloat64Array) -> bool:
	if state.size() != STATE_SIZE:
		return false
	for value: float in state:
		if not is_finite(value):
			return false
	_diving = state[0] != 0.0
	_dive_time_s = maxf(state[1], 0.0)
	_dive_locked = state[2] != 0.0
	return true


func _end_dive(lock: bool) -> void:
	_diving = false
	_dive_time_s = 0.0
	_dive_locked = lock
