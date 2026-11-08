class_name PatrolCircleStrike
extends CreatureBrain
## The reef shark's machine (creatures-ai "Reef shark patrol, circle and strike"): PATROL water at
## least `keep_off_shore_tiles` from land, INVESTIGATE a swimmer in hearing range, CIRCLE them for
## the rolled circle time, then STRIKE only a swimmer who qualifies (bleeding, or tired) and
## RETREAT, or LEAVE and ignore them. A swimmer inside the shore margin is out of reach.

enum State {
	PATROL,
	INVESTIGATE,
	CIRCLE,
	STRIKE,
	RETREAT,
	LEAVE,
}

const CIRCLE_RADIUS_TILES: float = 3.0
## The shark starts circling once this close.
const CIRCLE_ENTER_TILES: float = 3.5
const CIRCLE_SPEED_MULT: float = 1.5
## How far a swimmer may get before the shark loses interest.
const LOSE_TILES: float = 16.0
const PATROL_RANGE_TILES: int = 10
const PATROL_TRIES: int = 12
const LEAVE_S: float = 2.0
const IGNORE_S: float = 20.0
## Radians per second round the swimmer.
const ORBIT_RATE: float = 1.0

var _clock_s: float = 0.0
var _target: PlayerBody = null
var _ignored_until: Dictionary[int, float] = {}
var _circle_left_s: float = 0.0
var _retreat_left_s: float = 0.0
var _leave_left_s: float = 0.0
var _angle: float = 0.0
var _patrol_goal: Vector2 = Vector2.ZERO
var _has_goal: bool = false


## Whether `body` meets any of the creature's strike conditions (none listed means any swimmer).
static func qualifies(body: PlayerBody, data: CreatureData) -> bool:
	if data.strike_conditions.is_empty():
		return true
	for condition: CreatureData.TargetCondition in data.strike_conditions:
		match condition:
			CreatureData.TargetCondition.BLEEDING:
				if body.meters.has_status(DataEnums.Status.BLEEDING):
					return true
			CreatureData.TargetCondition.LOW_ENERGY:
				if body.meters.energy < data.low_energy_threshold:
					return true
	return false


func names() -> Array[StringName]:
	return [&"PATROL", &"INVESTIGATE", &"CIRCLE", &"STRIKE", &"RETREAT", &"LEAVE"]


func can_stand(creature: Creature, world: CreatureWorld, position: Vector2) -> bool:
	return CreatureNav.is_open(world.nav.water(creature.data.keep_off_shore_tiles), CreatureNav.cell_of(position))


func tick(creature: Creature, world: CreatureWorld, delta: float) -> void:
	_clock_s += delta
	var data := creature.data
	var grid := world.nav.water(data.keep_off_shore_tiles)
	match state:
		State.PATROL:
			_patrol(creature, world, grid, delta)
		State.INVESTIGATE:
			_investigate(creature, world, grid, delta)
		State.CIRCLE:
			_circle(creature, world, delta)
		State.RETREAT:
			_retreat(creature, world, delta)
		State.LEAVE:
			_leave(creature, world, delta)


func _patrol(creature: Creature, world: CreatureWorld, grid: AStarGrid2D, delta: float) -> void:
	var swimmer := _pick_target(creature, world)
	if swimmer != null:
		_target = swimmer
		forget_path()
		enter(State.INVESTIGATE)
		_investigate(creature, world, grid, delta)
		return
	if not _has_goal or creature.position.distance_to(_patrol_goal) < CreatureNav.TILE:
		_has_goal = _choose_goal(creature, world, grid)
	if _has_goal:
		follow_path(creature, world, grid, _patrol_goal, creature.data.speed_tiles_s, delta)


func _investigate(creature: Creature, world: CreatureWorld, grid: AStarGrid2D, delta: float) -> void:
	if not _reachable(creature, world, _target):
		enter(State.PATROL)
		return
	if creature.position.distance_to(_target.global_position) <= CIRCLE_ENTER_TILES * CreatureNav.TILE:
		_angle = (creature.position - _target.global_position).angle()
		_circle_left_s = world.rng.randf_range(creature.data.circle_time_s.x, creature.data.circle_time_s.y)
		enter(State.CIRCLE)
		_circle(creature, world, delta)
		return
	follow_path(creature, world, grid, _target.global_position, creature.data.speed_tiles_s, delta)


func _circle(creature: Creature, world: CreatureWorld, delta: float) -> void:
	if not _reachable(creature, world, _target):
		enter(State.PATROL)
		return
	_circle_left_s -= delta
	if _circle_left_s <= 0.0:
		_end_circle(creature, world)
		return
	_angle += ORBIT_RATE * delta
	var orbit: Vector2 = _target.global_position + Vector2.from_angle(_angle) * CIRCLE_RADIUS_TILES * CreatureNav.TILE
	step_toward(creature, world, orbit, creature.data.speed_tiles_s * CIRCLE_SPEED_MULT, delta)


func _end_circle(creature: Creature, world: CreatureWorld) -> void:
	if not qualifies(_target, creature.data):
		_ignored_until[_target.get_instance_id()] = _clock_s + IGNORE_S
		_leave_left_s = LEAVE_S
		enter(State.LEAVE)
		return
	enter(State.STRIKE)
	var lunge: Vector2 = _target.global_position + (creature.position - _target.global_position).normalized() * CreatureNav.TILE
	if can_stand(creature, world, lunge):
		creature.position = lunge
	world.strike(_target, creature.data)
	_retreat_left_s = creature.data.retreat_time_s
	enter(State.RETREAT)


func _retreat(creature: Creature, world: CreatureWorld, delta: float) -> void:
	_retreat_left_s -= delta
	if _retreat_left_s <= 0.0:
		if _reachable(creature, world, _target):
			_circle_left_s = world.rng.randf_range(creature.data.circle_time_s.x, creature.data.circle_time_s.y)
			enter(State.CIRCLE)
		else:
			enter(State.PATROL)
		return
	_swim_away(creature, world, delta)


func _leave(creature: Creature, world: CreatureWorld, delta: float) -> void:
	_leave_left_s -= delta
	if _leave_left_s <= 0.0:
		_target = null
		_has_goal = false
		forget_path()
		enter(State.PATROL)
		return
	_swim_away(creature, world, delta)


func _swim_away(creature: Creature, world: CreatureWorld, delta: float) -> void:
	var away: Vector2 = creature.position - _target.global_position
	if away == Vector2.ZERO:
		away = Vector2.RIGHT
	step_toward(creature, world, creature.position + away.normalized() * CreatureNav.TILE * 4.0, creature.data.speed_tiles_s, delta)


# The nearest swimmer in hearing range that is out of the shore margin and not being ignored.
func _pick_target(creature: Creature, world: CreatureWorld) -> PlayerBody:
	var best: PlayerBody = null
	var best_dist: float = creature.data.hearing_radius_tiles * CreatureNav.TILE
	for body: PlayerBody in world.players():
		if _ignored_until.get(body.get_instance_id(), 0.0) > _clock_s or not _reachable(creature, world, body, best_dist):
			continue
		best = body
		best_dist = creature.position.distance_to(body.global_position)
	return best


# In the water, outside the margin, and not too far from the shark.
func _reachable(creature: Creature, world: CreatureWorld, body: PlayerBody, limit_px: float = LOSE_TILES * CreatureNav.TILE) -> bool:
	if not is_instance_valid(body) or not CoopSession.is_alive(body):
		return false
	var cell := CreatureNav.cell_of(body.global_position)
	if not CreatureNav.is_open(world.nav.water(creature.data.keep_off_shore_tiles), cell):
		return false
	return creature.position.distance_to(body.global_position) <= limit_px


func _choose_goal(creature: Creature, world: CreatureWorld, grid: AStarGrid2D) -> bool:
	var here := CreatureNav.cell_of(creature.position)
	for i: int in PATROL_TRIES:
		var offset := Vector2i(world.rng.randi_range(-PATROL_RANGE_TILES, PATROL_RANGE_TILES), world.rng.randi_range(-PATROL_RANGE_TILES, PATROL_RANGE_TILES))
		if CreatureNav.is_open(grid, here + offset):
			_patrol_goal = CreatureNav.center_of(here + offset)
			return true
	return false
