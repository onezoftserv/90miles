class_name NightThief
extends CreatureBrain
## The land crab's machine (creatures-ai "Land crab night theft"): WANDER the beach, SEEK the
## nearest food on the ground, STEAL one item per `steal_interval_s`, FLEE carrying it, PINCH a
## player who stays next to it. A lit fire's light overrides everything: LIGHT_FLEE, and a crab
## never steps into the light.

enum State {
	WANDER,
	SEEK,
	STEAL,
	FLEE,
	PINCH,
	LIGHT_FLEE,
}

## Within this many tiles a crab is "next to" a stash or a player.
const ADJACENT_TILES: float = 1.5
const FLEE_S: float = 10.0
const WANDER_RANGE_TILES: int = 4
const WANDER_S: float = 3.0

var _since_steal_s: float = 0.0
var _flee_left_s: float = 0.0
var _flee_dir: Vector2 = Vector2.UP
var _adjacent_s: float = 0.0
var _wander_left_s: float = 0.0
var _wander_goal: Vector2 = Vector2.ZERO


func names() -> Array[StringName]:
	return [&"WANDER", &"SEEK", &"STEAL", &"FLEE", &"PINCH", &"LIGHT_FLEE"]


# Never into the light; inside it, only outward.
func can_stand(creature: Creature, world: CreatureWorld, position: Vector2) -> bool:
	if not CreatureNav.is_open(world.nav.land, CreatureNav.cell_of(position)):
		return false
	for fire: Node2D in world.lit_fires():
		var next: float = fire.global_position.distance_to(position)
		if next < world.light_radius_px() and next <= fire.global_position.distance_to(creature.position):
			return false
	return true


func tick(creature: Creature, world: CreatureWorld, delta: float) -> void:
	var data := creature.data
	var fire := world.fire_covering(creature.position)
	if fire != null:
		enter(State.LIGHT_FLEE)
		forget_path()
		_run(creature, world, creature.position - fire.global_position, delta)
		return
	if state == State.FLEE:
		_flee_left_s -= delta
		if _flee_left_s > 0.0:
			_run(creature, world, _flee_dir, delta)
			return
		_since_steal_s = 0.0
	_since_steal_s += delta
	if _pinch(creature, world, delta):
		return
	var stash := _nearest_stash(creature, world)
	if stash == null:
		_wander(creature, world, delta)
	elif creature.position.distance_to(stash.position) <= ADJACENT_TILES * CreatureNav.TILE:
		enter(State.STEAL)
		if _since_steal_s >= data.steal_interval_s:
			_steal(creature, world, stash)
	else:
		enter(State.SEEK)
		follow_path(creature, world, world.nav.land, stash.position, data.speed_tiles_s, delta)


# A player next to the crab holds it still; every `attack_cooldown_s` there is a pinch.
func _pinch(creature: Creature, world: CreatureWorld, delta: float) -> bool:
	for body: PlayerBody in world.players():
		if creature.position.distance_to(body.global_position) > ADJACENT_TILES * CreatureNav.TILE:
			continue
		enter(State.PINCH)
		_adjacent_s += delta
		if _adjacent_s >= creature.data.attack_cooldown_s:
			_adjacent_s -= creature.data.attack_cooldown_s
			world.pinch(body, creature.data.damage)
		return true
	_adjacent_s = 0.0
	return false


func _steal(creature: Creature, world: CreatureWorld, stash: WorldItem) -> void:
	var id: StringName = stash.item_id
	var taken: int = world.take_from_pickup(stash, creature.data.steal_count)
	if taken <= 0:
		return
	creature.carried[id] = creature.carried.get(id, 0) + taken
	_flee_dir = (creature.position - stash.position).normalized()
	if _flee_dir == Vector2.ZERO:
		_flee_dir = Vector2.UP
	_flee_left_s = FLEE_S
	forget_path()
	enter(State.FLEE)


# The nearest food a crab can reach without stepping into a fire's light.
func _nearest_stash(creature: Creature, world: CreatureWorld) -> WorldItem:
	var best: WorldItem = null
	var best_dist: float = INF
	var reach_px: float = world.light_radius_px() + ADJACENT_TILES * CreatureNav.TILE
	for item: WorldItem in world.food_pickups():
		var lit := false
		for fire: Node2D in world.lit_fires():
			lit = lit or fire.global_position.distance_to(item.position) < reach_px
		var dist: float = creature.position.distance_to(item.position)
		if not lit and dist < best_dist:
			best = item
			best_dist = dist
	return best


func _wander(creature: Creature, world: CreatureWorld, delta: float) -> void:
	enter(State.WANDER)
	_wander_left_s -= delta
	if _wander_left_s <= 0.0:
		var offset := Vector2i(world.rng.randi_range(-WANDER_RANGE_TILES, WANDER_RANGE_TILES), world.rng.randi_range(-WANDER_RANGE_TILES, WANDER_RANGE_TILES))
		_wander_goal = CreatureNav.center_of(CreatureNav.cell_of(creature.position) + offset)
		_wander_left_s = WANDER_S
	follow_path(creature, world, world.nav.land, _wander_goal, creature.data.speed_tiles_s * 0.5, delta)


# Runs along `direction`, turning aside when something blocks the way.
func _run(creature: Creature, world: CreatureWorld, direction: Vector2, delta: float) -> void:
	var dir: Vector2 = direction.normalized() if direction != Vector2.ZERO else Vector2.UP
	for turn: float in [0.0, PI / 2.0, -PI / 2.0, PI]:
		var heading: Vector2 = dir.rotated(turn)
		if step_toward(creature, world, creature.position + heading * CreatureNav.TILE, creature.data.speed_tiles_s, delta):
			if turn != 0.0 and state == State.FLEE:
				_flee_dir = heading
			return
