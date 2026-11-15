class_name Ambient
extends CreatureBrain
## The harmless visitors' machine (creature-perch-ride "Ambient visits"; the songbird, the booby,
## the sperm whale and the pelican): ARRIVE at its station (its `nest`: a slot by the deck on a
## crossing, its spawn spot on an island), STAY, then LEAVE. Its sighting effects reach each
## player who sees it while it stays. It leaves when a CONDITION_HOLDS counter that answers FLEE or
## REMOVE holds for any player (the booby in a squall), when its stay time (`circle_time_s.x`)
## is up, or with its crossing (which frees it). It never attacks, steals, touches the vessel or
## answers a shoo. A NOISE counter waits for the noise bus: until then it never fires.

enum State {
	ARRIVE,
	STAY,
	LEAVE,
}

## Gone this long after it starts to leave, wherever it is.
const LEAVE_S: float = 5.0
## Off an island it flies this many tiles away before it is gone.
const ISLAND_EXIT_TILES: float = 10.0

var _stay_s: float = 0.0
var _leave_s: float = 0.0
var _exit: Vector2 = Vector2.ZERO


func names() -> Array[StringName]:
	return [&"ARRIVE", &"STAY", &"LEAVE"]


func tick(creature: Creature, world: CreatureWorld, delta: float) -> void:
	if history.is_empty():
		enter(State.ARRIVE)
	match state:
		State.ARRIVE:
			if _must_leave(creature, world):
				_begin_leave(creature, world)
			elif not step_toward(creature, world, creature.nest, creature.data.speed_tiles_s, delta):
				enter(State.STAY)
				Sightings.see(creature, world)
		State.STAY:
			_stay_s += delta
			Sightings.see(creature, world)
			var stay_limit_s: float = creature.data.circle_time_s.x
			if _must_leave(creature, world) or (stay_limit_s > 0.0 and _stay_s >= stay_limit_s):
				_begin_leave(creature, world)
		State.LEAVE:
			_leave_s += delta
			if not step_toward(creature, world, _exit, creature.data.speed_tiles_s, delta) or _leave_s >= LEAVE_S:
				creature.queue_free()


# A flee or remove counter whose conditions hold for any player it can see.
func _must_leave(creature: Creature, world: CreatureWorld) -> bool:
	for counter: CreatureCounterData in creature.data.counters:
		if counter.trigger != CreatureCounterData.Trigger.CONDITION_HOLDS or counter.conditions.is_empty():
			continue
		if counter.response != CreatureCounterData.Response.FLEE and counter.response != CreatureCounterData.Response.REMOVE:
			continue
		for body: PlayerBody in world.players():
			if ConditionCheck.all_hold(counter.conditions, body):
				return true
	return false


func _begin_leave(creature: Creature, world: CreatureWorld) -> void:
	_exit = _exit_point(creature, world)
	enter(State.LEAVE)


# The nearest edge of the crossing's sea, or a spot well away from the island's.
func _exit_point(creature: Creature, world: CreatureWorld) -> Vector2:
	if world.crossing == null:
		return creature.position + Vector2.UP * ISLAND_EXIT_TILES * CreatureNav.TILE
	var sea := world.crossing.sea_rect()
	var at := creature.position
	var exits: Array[Vector2] = [Vector2(sea.position.x, at.y), Vector2(sea.end.x, at.y), Vector2(at.x, sea.position.y), Vector2(at.x, sea.end.y)]
	var best: Vector2 = exits[0]
	for exit: Vector2 in exits:
		if at.distance_to(exit) < at.distance_to(best):
			best = exit
	return best
