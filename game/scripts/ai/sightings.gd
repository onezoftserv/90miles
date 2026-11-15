class_name Sightings
extends RefCounted
## Sighting effects (creature-perch-ride "Sighting effects"): each player who sees a creature gets
## its `sighting_effects` once, held to each effect's limit by the host's run record. On a crossing
## every living rider sees it; on an island, each living player within its sight radius. The
## limit is keyed by the player's body, not their connection, so a rejoin never pays twice. Host
## only: a brain calls `see` when it reaches its sighting moment.


## Host: every player who sees `creature` now and has not seen it yet gets its sighting effects.
static func see(creature: Creature, world: CreatureWorld) -> void:
	for body: PlayerBody in viewers(creature, world):
		var key: int = body.get_instance_id()
		if creature.seen_by.has(key):
			continue
		creature.seen_by[key] = true
		pay(creature.data, body, world)


## The players who see `creature`: every living rider of its crossing, or on an island each living
## player within its sight radius.
static func viewers(creature: Creature, world: CreatureWorld) -> Array[PlayerBody]:
	if world.crossing != null:
		return world.players()
	var sight_px: float = creature.data.sight_radius_tiles * CreatureNav.TILE
	var found: Array[PlayerBody] = []
	for body: PlayerBody in world.players():
		if body.global_position.distance_to(creature.global_position) <= sight_px:
			found.append(body)
	return found


## Applies `data`'s sighting effects to `body`, each one only if its limit allows it.
static func pay(data: CreatureData, body: PlayerBody, world: CreatureWorld) -> void:
	for index: int in data.sighting_effects.size():
		var effect: EffectData = data.sighting_effects[index]
		if effect == null:
			continue
		var key: String = "%s#%d@%d" % [data.id, index, body.get_instance_id()]
		if world.record.claim(key, effect.limit, world.day()):
			EffectApplier.apply(effect, body, body)
