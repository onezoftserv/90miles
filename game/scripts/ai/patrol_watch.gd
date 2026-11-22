class_name PatrolWatch
extends RefCounted
## guardacostas-stealth decision 5: the one place the spot meters are stepped. Host only, owned by the
## island's CreatureSpawner, which calls `step` once per physics tick after the boats. The meter is
## per player, not per boat: a player lit by any lit cone and not hidden fills, otherwise it drains,
## so two boats never fill it twice as fast. A player who is spotted is handed to the nearest boat that
## lit them (that boat's PatrolRoute locks on them). Downed players can be spotted; dead players and
## players who left the island have no meter. A test calls `step` by hand.
##
## guardacostas-capture design.md §5: the shore soldiers are sight sources too. A soldier's cone
## (SearchCapture.sees) counts as a lit cone, unless the weather disables sight, and a spot goes to
## the nearest source that saw the player, boat or soldier, whose patrol's numbers the meter runs on.

var world: CreatureWorld = null
## The island's patrol boats (Creature nodes with a PatrolRoute brain), registered by the spawner.
var boats: Array[Creature] = []
## The soldiers ashore (Creature nodes with a SearchCapture brain), registered as they land.
var soldiers: Array[Creature] = []


func step(delta: float) -> void:
	if world == null:
		return
	var live: Array[Creature] = _live(boats)
	var eyes: Array[Creature] = []
	if SightCone.sight_works(world.weather().disabled_senses):
		eyes = _live(soldiers)
	for body: PlayerBody in world.all_players():
		if body.meters.dead or body.left_island or CreatureWorld.is_dropped(body):
			body.spot_meter.clear()
			continue
		var lighting: Array[Creature] = []
		for boat: Creature in live:
			if (boat.brain as PatrolRoute).lights(body.global_position):
				lighting.append(boat)
		for soldier: Creature in eyes:
			if (soldier.brain as SearchCapture).sees(soldier, body.global_position):
				lighting.append(soldier)
		# The meter runs on the numbers of the source that sees the player (the nearest); an unlit
		# meter keeps the numbers it last had and just drains.
		var lighter: Creature = _nearest(lighting, body)
		if lighter != null:
			var numbers: PatrolData = _patrol_of(lighter)
			body.spot_meter.fill_per_s = numbers.spot_fill_per_s
			body.spot_meter.drain_per_s = numbers.spot_drain_per_s
			body.spot_meter.spot_time_s = numbers.spot_time_s
		var hidden: bool = body.stealth_state != MovementStep.Stealth.VISIBLE
		var bonus: float = SpotMeter.stealth_bonus_s(SpotMeter.stealth_level_of(body))
		if body.spot_meter.step(not lighting.is_empty(), hidden, delta, bonus):
			if lighter.brain is PatrolRoute:
				(lighter.brain as PatrolRoute).spot(body, &"sight")
			else:
				(lighter.brain as SearchCapture).spot(lighter, body)


# The sources still in play: boats with a PatrolRoute, soldiers with a SearchCapture and its patrol.
func _live(sources: Array[Creature]) -> Array[Creature]:
	var alive: Array[Creature] = []
	for source: Creature in sources:
		if not is_instance_valid(source) or source.is_queued_for_deletion():
			continue
		if source.brain is PatrolRoute or (source.brain is SearchCapture and (source.brain as SearchCapture).patrol != null):
			alive.append(source)
	return alive


static func _patrol_of(source: Creature) -> PatrolData:
	if source.brain is SearchCapture:
		return (source.brain as SearchCapture).patrol
	return source.data.patrol


func _nearest(lighting: Array[Creature], body: PlayerBody) -> Creature:
	if lighting.is_empty():
		return null
	var best: Creature = lighting[0]
	for boat: Creature in lighting:
		if boat.position.distance_to(body.global_position) < best.position.distance_to(body.global_position):
			best = boat
	return best
