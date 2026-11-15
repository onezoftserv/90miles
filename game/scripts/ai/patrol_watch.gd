class_name PatrolWatch
extends RefCounted
## guardacostas-stealth decision 5: the one place the spot meters are stepped. Host only, owned by the
## island's CreatureSpawner, which calls `step` once per physics tick after the boats. The meter is
## per player, not per boat: a player lit by any lit cone and not hidden fills, otherwise it drains,
## so two boats never fill it twice as fast. A player who is spotted is handed to the nearest boat that
## lit them (that boat's PatrolRoute locks on them). Downed players can be spotted; dead players and
## players who left the island have no meter. A test calls `step` by hand.

var world: CreatureWorld = null
## The island's patrol boats (Creature nodes with a PatrolRoute brain), registered by the spawner.
var boats: Array[Creature] = []


func step(delta: float) -> void:
	if world == null:
		return
	var live: Array[Creature] = _live_boats()
	var reference: PatrolData = null
	if not live.is_empty():
		reference = live[0].data.patrol
	for body: PlayerBody in world.all_players():
		if body.meters.dead or body.left_island:
			body.spot_meter.clear()
			continue
		if reference != null:
			body.spot_meter.fill_per_s = reference.spot_fill_per_s
			body.spot_meter.drain_per_s = reference.spot_drain_per_s
			body.spot_meter.spot_time_s = reference.spot_time_s
		var lighting: Array[Creature] = []
		for boat: Creature in live:
			if (boat.brain as PatrolRoute).lights(body.global_position):
				lighting.append(boat)
		var hidden: bool = body.stealth_state != MovementStep.Stealth.VISIBLE
		var bonus: float = SpotMeter.stealth_bonus_s(SpotMeter.stealth_level_of(body))
		if body.spot_meter.step(not lighting.is_empty(), hidden, delta, bonus):
			(_nearest(lighting, body).brain as PatrolRoute).spot(body, &"sight")


func _live_boats() -> Array[Creature]:
	var live: Array[Creature] = []
	for boat: Creature in boats:
		if is_instance_valid(boat) and not boat.is_queued_for_deletion() and boat.brain is PatrolRoute:
			live.append(boat)
	return live


func _nearest(lighting: Array[Creature], body: PlayerBody) -> Creature:
	var best: Creature = lighting[0]
	for boat: Creature in lighting:
		if boat.position.distance_to(body.global_position) < best.position.distance_to(body.global_position):
			best = boat
	return best
