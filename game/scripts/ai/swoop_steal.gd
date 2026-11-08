class_name SwoopSteal
extends CreatureBrain
## The seagull's machine (creatures-ai "Seagull swoop and steal"): PERCH at the nest palm, SWOOP on
## food within sight of the nest (on the ground, or a player's held food), take one item, FLEE for
## 30 s and RETURN so it is perched again when they are up. A shoo is a flee. Night: PERCH only.
## Air creatures ignore terrain.

enum State {
	PERCH,
	SWOOP,
	FLEE,
	RETURN,
}

## A gull this close to its target takes the item.
const REACH_TILES: float = 0.5
const FLEE_RADIUS_TILES: float = 10.0
const DEFAULT_FLEE_S: float = 30.0

var _flee_left_s: float = 0.0
var _away: Vector2 = Vector2.UP


func names() -> Array[StringName]:
	return [&"PERCH", &"SWOOP", &"FLEE", &"RETURN"]


func tick(creature: Creature, world: CreatureWorld, delta: float) -> void:
	match state:
		State.PERCH:
			if world.phase != DataEnums.DayPhase.NIGHT and _find_target(creature, world) != null:
				enter(State.SWOOP)
		State.SWOOP:
			_swoop(creature, world, delta)
		State.FLEE:
			_flee(creature, world, delta)
		State.RETURN:
			_return(creature, world, delta)


func shoo(creature: Creature, by: Node2D) -> bool:
	var counter := counter_for(creature.data, CreatureCounterData.Trigger.INTERACT)
	_away = creature.position - by.global_position
	_begin_flee(counter.duration_s if counter != null else DEFAULT_FLEE_S)
	return true


func _begin_flee(seconds: float) -> void:
	_flee_left_s = seconds
	if _away == Vector2.ZERO:
		_away = Vector2.UP
	_away = _away.normalized()
	enter(State.FLEE)


func _swoop(creature: Creature, world: CreatureWorld, delta: float) -> void:
	var target: Variant = _find_target(creature, world)
	if target == null or world.phase == DataEnums.DayPhase.NIGHT:
		enter(State.RETURN)
		return
	var at: Vector2 = (target as Node2D).global_position
	step_toward(creature, world, at, creature.data.speed_tiles_s, delta)
	if creature.position.distance_to(at) > REACH_TILES * CreatureNav.TILE:
		return
	var id: StringName = &""
	if target is WorldItem:
		id = (target as WorldItem).item_id
		if world.take_from_pickup(target as WorldItem, creature.data.steal_count) <= 0:
			id = &""
	else:
		id = world.take_held(target as PlayerBody)
	if id.is_empty():
		return
	creature.carried[id] = creature.carried.get(id, 0) + 1
	_away = creature.position - creature.nest
	_begin_flee(creature.data.steal_interval_s)


# Flies off, then hovers; heads home so as to be perched when the flee time is up.
func _flee(creature: Creature, world: CreatureWorld, delta: float) -> void:
	_flee_left_s -= delta
	var home_px: float = creature.position.distance_to(creature.nest)
	var speed_px: float = creature.data.speed_tiles_s * CreatureNav.TILE
	if _flee_left_s <= home_px / speed_px:
		enter(State.RETURN)
		return
	if home_px < FLEE_RADIUS_TILES * CreatureNav.TILE:
		step_toward(creature, world, creature.position + _away * CreatureNav.TILE, creature.data.speed_tiles_s, delta)


func _return(creature: Creature, world: CreatureWorld, delta: float) -> void:
	if step_toward(creature, world, creature.nest, creature.data.speed_tiles_s, delta):
		return
	creature.carried.clear()
	enter(State.PERCH)


# The nearest food within sight of the nest: on the ground, or held by a player on land.
func _find_target(creature: Creature, world: CreatureWorld) -> Node2D:
	var sight_px: float = creature.data.sight_radius_tiles * CreatureNav.TILE
	var best: Node2D = null
	var best_dist: float = INF
	var candidates: Array[Node2D] = []
	for item: WorldItem in world.food_pickups():
		candidates.append(item)
	for body: PlayerBody in world.players():
		if not CreatureWorld.is_swimming(body) and not body.inventory.held_food().is_empty():
			candidates.append(body)
	for candidate: Node2D in candidates:
		var dist: float = creature.position.distance_to(candidate.global_position)
		if candidate.global_position.distance_to(creature.nest) <= sight_px and dist < best_dist:
			best = candidate
			best_dist = dist
	return best
