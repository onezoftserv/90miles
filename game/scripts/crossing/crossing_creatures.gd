class_name CrossingCreatures
extends Node
## The creatures that ride along with a crossing (creature-perch-ride "Crossing creature roll"). Host
## only: when a crossing launches, the shell attaches one to it, which rolls every creature's
## CROSSING spawn rules against the departing island's chain family, the distance band, the phase
## and the weather. Chance-1.0 rules are always placed (within `max_per_run`); at most
## `CrossingTuning.max_rolled_creatures` of the others are. They come through the session's entity
## spawner, so clients and late joiners see them; they are passing creatures, so the island never
## counts them, and they go when the crossing ends. The dice are the run's own (run seed and
## crossing number), so the shell's crossing dice and every plan are untouched. Nothing here
## names a creature: a creature file with a crossing rule rides along with no edit.

const NODE_NAME: StringName = &"Creatures"
## They come in from the sea's north edge, this far inside it.
const EDGE_INSET_PX: float = 8.0
## Spawn spots along the edge are this far apart.
const SPAWN_SPACING_PX: float = 16.0
## Air and vessel creatures sit this far inside the deck's corners.
const RIM_INSET_PX: float = 3.0
## Water creatures keep this many tiles off the deck's side.
const WATER_OFFSET_TILES: float = 2.0
const STATION_SLOTS: int = 4

var crossing: Crossing
var world: CreatureWorld
## Typed with the base class: a typed array of its own class leaks at exit.
var placed: Array[Node2D] = []


## Host: rolls and places `on`'s creatures for a departure from an island of `family`, at `band`.
## `pool` replaces the session's creature catalog (tests); empty reads the catalog. Null on a client.
static func attach(on: Crossing, family: DataEnums.ChainFamily, band: DataEnums.DistanceBand, pool: Array[CreatureData] = []) -> CrossingCreatures:
	var session := on.session()
	if session == null or not session.multiplayer.is_server():
		return null
	var node := CrossingCreatures.new()
	node.name = NODE_NAME
	node.crossing = on
	node.world = CreatureWorld.for_crossing(on)
	on.add_child(node)
	on.ended.connect(node._on_ended)
	var creatures: Array[CreatureData] = pool if not pool.is_empty() else _catalog_creatures(session)
	var dice := RandomNumberGenerator.new()
	dice.seed = hash([node.world.run_seed(), on.serial, NODE_NAME])
	node.place(roll(creatures, family, band, WeatherManager.phase(), WeatherManager.weather_id(), dice, on.tuning.max_rolled_creatures, node.world.record))
	return node


## The creatures to place, in `creatures`' order: every matching chance-1.0 rule, then at most
## `cap` of the other matching rules whose dice come up (`rng.randf() < chance`). One rule places
## one creature. A creature the run has placed `max_per_run` times is skipped; each one placed is
## counted in `record`. Island rules never match. Pure apart from `rng` and `record`.
static func roll(creatures: Array[CreatureData], family: DataEnums.ChainFamily, band: DataEnums.DistanceBand, phase: DataEnums.DayPhase, weather_id: StringName, rng: RandomNumberGenerator, cap: int, record: RunRecord) -> Array[CreatureData]:
	var sure: Array[CreatureData] = []
	var rolled: Array[CreatureData] = []
	var chances: Array[float] = []
	for data: CreatureData in creatures:
		for rule: CreatureSpawnRuleData in data.spawn_rules:
			if not matches(rule, family, band, phase, weather_id):
				continue
			if rule.chance >= 1.0:
				sure.append(data)
			else:
				rolled.append(data)
				chances.append(rule.chance)
	var picked: Array[CreatureData] = []
	for data: CreatureData in sure:
		if _allowed(data, record):
			record.count_creature(data.id)
			picked.append(data)
	var taken: int = 0
	for index: int in rolled.size():
		if taken >= cap:
			break
		var data: CreatureData = rolled[index]
		if not _allowed(data, record) or rng.randf() >= chances[index]:
			continue
		record.count_creature(data.id)
		picked.append(data)
		taken += 1
	return picked


## Whether `rule` puts its creature on a crossing out of `family`, at `band`, in `phase` and
## `weather_id`. Empty lists match anything. Chain ids are not checked: a crossing knows the
## departing island's family, not its chain.
static func matches(rule: CreatureSpawnRuleData, family: DataEnums.ChainFamily, band: DataEnums.DistanceBand, phase: DataEnums.DayPhase, weather_id: StringName) -> bool:
	if rule.context == DataEnums.SceneContext.ISLAND:
		return false
	if not rule.chain_families.is_empty() and not rule.chain_families.has(family):
		return false
	if not rule.distance_bands.is_empty() and not rule.distance_bands.has(band):
		return false
	if not rule.phases.is_empty() and not rule.phases.has(phase):
		return false
	if not rule.weather_ids.is_empty() and not rule.weather_ids.has(weather_id):
		return false
	return not rule.excluded_weather_ids.has(weather_id)


## Host: puts `picked` in at the sea's north edge, each with its station by the deck as its nest.
func place(picked: Array[CreatureData]) -> void:
	var session := crossing.session()
	if session == null:
		return
	var top: float = crossing.sea_rect().position.y + EDGE_INSET_PX
	for index: int in picked.size():
		var data: CreatureData = picked[index]
		var x: float = crossing.deck_center().x + (index - (picked.size() - 1) * 0.5) * SPAWN_SPACING_PX
		var creature := session.spawn_creature(data, Vector2(x, top))
		if creature == null:
			continue
		creature.passing = true
		creature.world = world
		creature.nest = station(data, index)
		placed.append(creature)


## Where the `index`-th placed creature keeps station: air and vessel creatures on one of the
## deck's four corners, water creatures 2 tiles off its left or right side.
func station(data: CreatureData, index: int) -> Vector2:
	var deck := crossing.deck_rect().grow(-RIM_INSET_PX)
	var slot: int = index % STATION_SLOTS
	if data.domains.has(CreatureData.Domain.AIR) or data.domains.has(CreatureData.Domain.VESSEL) or data.domains.is_empty():
		var corners: Array[Vector2] = [deck.position, Vector2(deck.end.x, deck.position.y), Vector2(deck.position.x, deck.end.y), deck.end]
		return corners[slot]
	var side: float = -1.0 if slot % 2 == 0 else 1.0
	var off_px: float = deck.size.x * 0.5 + WATER_OFFSET_TILES * CreatureNav.TILE
	return crossing.deck_center() + Vector2(side * off_px, (slot / 2) * CreatureNav.TILE)


## The placed creatures still out, in placing order.
func creatures() -> Array[Creature]:
	var found: Array[Creature] = []
	for node: Node2D in placed:
		if is_instance_valid(node) and not node.is_queued_for_deletion():
			found.append(node as Creature)
	return found


func _exit_tree() -> void:
	_clear()


func _on_ended(_result: CrossingResult) -> void:
	_clear()


# The host frees them; the entity spawner takes them off every client.
func _clear() -> void:
	for creature: Creature in creatures():
		creature.queue_free()
	placed.clear()


static func _allowed(data: CreatureData, record: RunRecord) -> bool:
	return data.max_per_run <= 0 or record.creature_count(data.id) < data.max_per_run


# Every creature in the session's catalog, by id as text.
static func _catalog_creatures(session: CoopSession) -> Array[CreatureData]:
	var catalog: ContentCatalog = session.creature_catalog if session.creature_catalog != null else GameState.content
	var found: Array[CreatureData] = []
	for id: StringName in catalog.list_ids(&"creatures"):
		var data := catalog.get_entry(&"creatures", id) as CreatureData
		if data != null:
			found.append(data)
	return found
