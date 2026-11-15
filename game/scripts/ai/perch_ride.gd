class_name PerchRide
extends CreatureBrain
## The galleguito's machine (creature-perch-ride "Perch ride details"; BESTIARY "The final
## passenger"): it rides a crossing. CIRCLE the deck for its circle time, then HOP to its pick (the
## rider aboard holding the most food, ties broken by the run seed) and PERCH on their head. Each
## rider gets its sighting effects when it first lands. Shooed, it HOPs to another rider's head, or
## with nobody else aboard HOVERs for the shoo counter's time and lands on the same rider. While its
## rider swims it HOVERs over them until they are aboard; if they die it picks again. From 60 s
## (`steal_interval_s`) after its first landing, at each multiple of that while PERCHed on a rider
## out of the water who carries no negating item, it rolls `steal_chance` to take one held food
## item; a roll that falls in any other state is skipped. It never leaves after a theft, and it
## never touches the vessel, the plan, the speed or the drift. Off a crossing it does nothing.

enum State {
	CIRCLE,
	PERCH,
	HOP,
	HOVER,
}

const CIRCLE_RADIUS_TILES: float = 2.0
const HOVER_RADIUS_TILES: float = 1.0
## Hover time after a solo shoo when its shoo counter gives none.
const DEFAULT_HOVER_S: float = 5.0
## It lands when this close to its rider.
const LAND_PX: float = 1.0
const EPSILON_S: float = 0.0001

## Host: the body it rides or heads for; null while nobody is aboard.
var rider: PlayerBody = null

var _circle_s: float = 0.0
var _hover_left_s: float = 0.0
## Seconds since its first landing; negative before it.
var _since_land_s: float = -1.0
var _rolls: int = 0
var _angle: float = 0.0


func names() -> Array[StringName]:
	return [&"CIRCLE", &"PERCH", &"HOP", &"HOVER"]


## Below the crossing's tie-down, climb and pull points (0), so a gull on a rider's head never
## hides them.
func interact_priority() -> int:
	return -1


func tick(creature: Creature, world: CreatureWorld, delta: float) -> void:
	if world.crossing == null:
		return
	if history.is_empty():
		enter(State.CIRCLE)
	_tick_theft(creature, world, delta)
	match state:
		State.CIRCLE:
			_circle(creature, world, delta)
		State.HOP:
			_hop(creature, world, delta)
		State.PERCH:
			_perch(creature, world)
		State.HOVER:
			_hover(creature, world, delta)
	if state != State.PERCH:
		creature.perch_peer = 0


func shoo(creature: Creature, _by: Node2D) -> bool:
	var world: CreatureWorld = creature.world
	if world == null or world.crossing == null or state != State.PERCH:
		return false
	creature.perch_peer = 0
	var next := pick(world, rider)
	if next != null and next != rider:
		rider = next
		enter(State.HOP)
		return true
	var counter := counter_for(creature.data, CreatureCounterData.Trigger.INTERACT)
	_hover_left_s = counter.duration_s if counter != null and counter.duration_s > 0.0 else DEFAULT_HOVER_S
	enter(State.HOVER)
	return true


## The rider to land on: among the living riders aboard or tied (all but `exclude` when anyone
## else is), the one holding the most food items; a tie is broken by dice seeded from the run seed
## and the crossing's number, over the tied riders in the crossing's order. Null with nobody aboard.
func pick(world: CreatureWorld, exclude: PlayerBody) -> PlayerBody:
	var aboard: Array[PlayerBody] = []
	for peer: int in world.crossing.peers():
		var body := world.crossing.body_of(peer)
		var rider_state: Crossing.Rider = world.crossing.rider_state(peer)
		if body != null and CoopSession.is_alive(body) and (rider_state == Crossing.Rider.ABOARD or rider_state == Crossing.Rider.TIED):
			aboard.append(body)
	var pool: Array[PlayerBody] = []
	for body: PlayerBody in aboard:
		if body != exclude:
			pool.append(body)
	if pool.is_empty():
		pool = aboard
	if pool.is_empty():
		return null
	var most: int = -1
	var tied: Array[PlayerBody] = []
	for body: PlayerBody in pool:
		var food: int = body.inventory.count_tag(CreatureWorld.FOOD_TAG)
		if food > most:
			most = food
			tied = [body]
		elif food == most:
			tied.append(body)
	if tied.size() == 1:
		return tied[0]
	var dice := RandomNumberGenerator.new()
	dice.seed = hash([world.run_seed(), world.crossing.serial])
	return tied[dice.randi_range(0, tied.size() - 1)]


func _circle(creature: Creature, world: CreatureWorld, delta: float) -> void:
	_circle_s += delta
	_orbit(creature, world, world.deck_center(), CIRCLE_RADIUS_TILES, delta)
	if _circle_s + EPSILON_S < creature.data.circle_time_s.x:
		return
	rider = pick(world, null)
	if rider != null:
		enter(State.HOP)


func _hop(creature: Creature, world: CreatureWorld, delta: float) -> void:
	if not _rides(world, rider):
		_pick_again(world)
		return
	if world.rider_state(rider) == Crossing.Rider.IN_WATER:
		_wait_over_swimmer()
		return
	step_toward(creature, world, rider.global_position, creature.data.speed_tiles_s, delta)
	if creature.position.distance_to(rider.global_position) < LAND_PX:
		_land(creature, world)


func _perch(creature: Creature, world: CreatureWorld) -> void:
	if not _rides(world, rider):
		_pick_again(world)
		return
	if world.rider_state(rider) == Crossing.Rider.IN_WATER:
		_wait_over_swimmer()
		return
	creature.position = rider.global_position
	creature.perch_peer = world.peer_of(rider)


func _hover(creature: Creature, world: CreatureWorld, delta: float) -> void:
	if not _rides(world, rider):
		_pick_again(world)
		return
	_hover_left_s -= delta
	_orbit(creature, world, rider.global_position, HOVER_RADIUS_TILES, delta)
	var rider_state: Crossing.Rider = world.rider_state(rider)
	if _hover_left_s <= EPSILON_S and (rider_state == Crossing.Rider.ABOARD or rider_state == Crossing.Rider.TIED):
		enter(State.HOP)


func _land(creature: Creature, world: CreatureWorld) -> void:
	creature.position = rider.global_position
	creature.perch_peer = world.peer_of(rider)
	enter(State.PERCH)
	if _since_land_s < 0.0:
		_since_land_s = 0.0
		Sightings.see(creature, world)


func _wait_over_swimmer() -> void:
	_hover_left_s = 0.0
	enter(State.HOVER)


func _pick_again(world: CreatureWorld) -> void:
	rider = pick(world, null)
	enter(State.HOP if rider != null else State.CIRCLE)


func _rides(world: CreatureWorld, body: PlayerBody) -> bool:
	return body != null and is_instance_valid(body) and CoopSession.is_alive(body) and world.rider_state(body) != Crossing.Rider.DEAD


# The theft clock runs from the first landing, whatever the state; a roll is taken only while
# perched on a rider out of the water who carries nothing that negates it.
func _tick_theft(creature: Creature, world: CreatureWorld, delta: float) -> void:
	if _since_land_s < 0.0:
		return
	_since_land_s += delta
	var interval: float = creature.data.steal_interval_s
	if interval <= 0.0:
		return
	while _since_land_s + EPSILON_S >= (_rolls + 1) * interval:
		_rolls += 1
		_roll_theft(creature, world)


func _roll_theft(creature: Creature, world: CreatureWorld) -> void:
	if state != State.PERCH or not _rides(world, rider) or world.rider_state(rider) == Crossing.Rider.IN_WATER:
		return
	if CreatureWorld.carries_negator(creature.data, rider):
		return
	if world.rng.randf() >= creature.data.steal_chance:
		return
	var taken: StringName = world.take_held(rider)
	if not taken.is_empty():
		creature.carried[taken] = creature.carried.get(taken, 0) + 1


# Flies round `center` at its speed, `radius_tiles` out.
func _orbit(creature: Creature, world: CreatureWorld, center: Vector2, radius_tiles: float, delta: float) -> void:
	var radius_px: float = radius_tiles * CreatureNav.TILE
	var speed_px: float = creature.data.speed_tiles_s * CreatureNav.TILE
	_angle = fposmod(_angle + speed_px / radius_px * delta, TAU)
	step_toward(creature, world, center + Vector2.from_angle(_angle) * radius_px, creature.data.speed_tiles_s, delta)
