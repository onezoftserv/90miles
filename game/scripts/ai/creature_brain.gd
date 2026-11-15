class_name CreatureBrain
extends RefCounted
## One state machine per behavior (creatures-ai): `tick` runs on the host only. The subclass for a
## CreatureData.Behavior is game/scripts/ai/<snake_case>.gd, so a new creature file with an
## existing behavior needs no script. Movement is shared: path following with a recompute cap, and
## `step_toward`, which asks `can_stand` before every step.

const PATH_RECOMPUTE_S: float = 0.5
const ARRIVE_PX: float = 1.0

var state: int = 0
## Every state entered, in order (tests and the codex read it).
var history: Array[StringName] = []
var path_computes: int = 0

var _path: PackedVector2Array = PackedVector2Array()
var _path_index: int = 0
var _path_goal: Vector2i = Vector2i(-1, -1)
var _path_age_s: float = 0.0
var _replan: bool = true


## The brain for `behavior`, or null when its script does not exist yet.
static func for_behavior(behavior: CreatureData.Behavior) -> CreatureBrain:
	var key: String = String(CreatureData.Behavior.keys()[behavior]).to_lower()
	var path: String = "res://scripts/ai/%s.gd" % key
	if not ResourceLoader.exists(path):
		return null
	return (load(path) as GDScript).new() as CreatureBrain


## The creature's counter for `trigger`, or null.
static func counter_for(data: CreatureData, trigger: CreatureCounterData.Trigger) -> CreatureCounterData:
	for counter: CreatureCounterData in data.counters:
		if counter.trigger == trigger:
			return counter
	return null


func tick(_creature: Creature, _world: CreatureWorld, _delta: float) -> void:
	pass


## The state names, indexed by `state`.
func names() -> Array[StringName]:
	return [&"NONE"]


func state_name() -> StringName:
	var all := names()
	return all[state] if state >= 0 and state < all.size() else &"NONE"


## A player shoos the creature; true if it reacted.
func shoo(_creature: Creature, _by: Node2D) -> bool:
	return false


## Its shoo prompt's interaction priority: 1 beats the ground's 0 (a gull over its palm); a
## machine that stays by a rider ranks itself lower (creature-perch-ride).
func interact_priority() -> int:
	return 1


## Whether the creature may stand at `position`.
func can_stand(_creature: Creature, _world: CreatureWorld, _position: Vector2) -> bool:
	return true


func enter(new_state: int) -> void:
	if new_state == state and not history.is_empty():
		return
	state = new_state
	history.append(state_name())


## Moves `creature` toward `target` (px) up to `speed_tiles` tiles/s, sliding along an axis when
## the straight step is refused. Returns whether it moved.
func step_toward(creature: Creature, world: CreatureWorld, target: Vector2, speed_tiles: float, delta: float) -> bool:
	var to := target - creature.position
	var dist: float = to.length()
	if dist < 0.001:
		return false
	var move: float = minf(dist, speed_tiles * CreatureNav.TILE * delta)
	var dir: Vector2 = to / dist
	var options: Array[Vector2] = [dir, Vector2(signf(dir.x), 0.0), Vector2(0.0, signf(dir.y))]
	for option: Vector2 in options:
		if option == Vector2.ZERO:
			continue
		var next: Vector2 = creature.position + option * move
		if can_stand(creature, world, next):
			creature.position = next
			creature.facing = option
			return true
	return false


## Walks `creature` along a path on `grid` to the cell of `goal`, replanning at most every
## PATH_RECOMPUTE_S when the goal moves.
func follow_path(creature: Creature, world: CreatureWorld, grid: AStarGrid2D, goal: Vector2, speed_tiles: float, delta: float) -> void:
	_path_age_s += delta
	var goal_cell: Vector2i = CreatureNav.cell_of(goal)
	var due: bool = path_computes == 0 or _path_age_s >= PATH_RECOMPUTE_S
	if due and (goal_cell != _path_goal or _replan):
		_compute(grid, CreatureNav.cell_of(creature.position), goal_cell)
	if _path_index >= _path.size():
		return
	var waypoint: Vector2 = _path[_path_index]
	if not step_toward(creature, world, waypoint, speed_tiles, delta):
		_replan = true
	elif creature.position.distance_to(waypoint) < ARRIVE_PX:
		_path_index += 1


func forget_path() -> void:
	_path = PackedVector2Array()
	_path_index = 0
	_path_goal = Vector2i(-1, -1)
	_replan = true


func _compute(grid: AStarGrid2D, from: Vector2i, to: Vector2i) -> void:
	path_computes += 1
	_path_age_s = 0.0
	_path_goal = to
	_replan = false
	_path = PackedVector2Array()
	_path_index = 0
	if not CreatureNav.is_open(grid, from) or not CreatureNav.is_open(grid, to):
		return
	for point: Vector2 in grid.get_point_path(from, to):
		_path.append((point + Vector2(0.5, 0.5)) * CreatureNav.TILE)
	if _path.size() > 1:
		_path_index = 1
