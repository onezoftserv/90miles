class_name CreatureSpawner
extends Node
## Host only: puts an island's creatures in the session from their spawn rules (creatures-ai).
## Rules without phases fire once at setup (the offshore shark); rules with phases fire when one of
## them begins and nothing of that rule is alive (crabs at night, gulls from dawn). A creature's
## despawn phases remove it. A creature with a FIRE_LIGHT-DISPERSE counter spawns half as many
## while a fire burns, and half of the living ones leave when a fire is lit. Nothing here names a
## creature: a new file with a rule spawns with no edit. Clients receive the spawns and do nothing.

## Open-water spawns stay within this many tiles of land, so the creature is near the island.
const OFFSHORE_MAX_TILES: int = 10
const WORLD_SEED: int = 90

## The party the counts scale for; the island sets `auto_party` to read it from the session.
var party_size: int = 1
var auto_party: bool = false
var session: CoopSession
var layout: IslandLayoutData
var built: IslandLayout
var nav: CreatureNav
var world: CreatureWorld = CreatureWorld.new()

var _catalog: ContentCatalog
var _live: Dictionary[String, Array] = {}
var _fire_seen: bool = false


## Reads the island. Nothing spawns until `spawn_permanent` or `start`.
func setup(for_session: CoopSession, layout_data: IslandLayoutData, catalog: ContentCatalog = null) -> void:
	session = for_session
	layout = layout_data
	_catalog = catalog if catalog != null else GameState.content
	session.creature_catalog = _catalog
	built = IslandLayout.build(layout)
	nav = CreatureNav.build(built.terrain, built.size)
	world.terrain = built.terrain
	world.nav = nav
	world.pickups = session.pickups
	world.rng.seed = WORLD_SEED


## Host: spawns the creatures that need no phase (the offshore shark).
func spawn_permanent() -> void:
	if session.multiplayer.is_server():
		_spawn_rules(null)


## Follows the day from now on. Deferred: the island is set up before the session's peer is
## connected, and only then is it known whether this peer is the host.
func start() -> void:
	_begin.call_deferred()


func _begin() -> void:
	if not is_inside_tree() or not session.multiplayer.is_server():
		return
	spawn_permanent()
	WeatherManager.phase_changed.connect(apply_phase)
	apply_phase(WeatherManager.phase())


func _exit_tree() -> void:
	if WeatherManager.phase_changed.is_connected(apply_phase):
		WeatherManager.phase_changed.disconnect(apply_phase)


func _physics_process(_delta: float) -> void:
	if session != null and session.multiplayer.is_server():
		check_fires()


## The island's living creatures of `id` (all of them when empty). A passing creature (the
## crossing's shark) is not the island's, so phases, fires and counts never touch it.
func creatures(id: StringName = &"") -> Array[Creature]:
	var found: Array[Creature] = []
	for node: Node in session.entities.get_children():
		var creature := node as Creature
		if creature == null or creature.is_queued_for_deletion() or creature.is_passing():
			continue
		if id.is_empty() or creature.data.id == id:
			found.append(creature)
	return found


## A phase began: despawn what leaves, spawn what the phase brings.
func apply_phase(phase: DataEnums.DayPhase) -> void:
	if auto_party:
		party_size = session.island_difficulty().players
	world.phase = phase
	for creature: Creature in creatures():
		if creature.data.despawn_phases.has(phase):
			_remove(creature)
	_fire_seen = not world.lit_fires().is_empty()
	_spawn_rules(phase)


## A fire lit since the last check sends half the living fire-shy creatures away.
func check_fires() -> void:
	var burning: bool = not world.lit_fires().is_empty()
	if burning and not _fire_seen:
		for id: StringName in _ids():
			var data := _data(id)
			if not _is_fire_shy(data):
				continue
			var living := creatures(id)
			for i: int in living.size() / 2:
				_remove(living[living.size() - 1 - i])
	_fire_seen = burning


func _spawn_rules(phase: Variant) -> void:
	for id: StringName in _ids():
		var data := _data(id)
		for index: int in data.spawn_rules.size():
			var rule := data.spawn_rules[index]
			var key := "%s:%d" % [id, index]
			if not _matches(rule, phase) or _has_live(key):
				continue
			if rule.chance < 1.0 and world.rng.randf() > rule.chance:
				continue
			_live[key] = _spawn_rule(data, rule)


func _spawn_rule(data: CreatureData, rule: CreatureSpawnRuleData) -> Array:
	var spawned: Array = []
	var each: int = _count(data, rule)
	var spots: Array[Vector2] = []
	if rule.anchor == CreatureSpawnRuleData.Anchor.NEST_PALM:
		for palm: int in layout.nest_palms:
			for i: int in each:
				spots.append(IslandLayout.cell_center(built.palms[palm]))
	elif rule.per_beach:
		for group: PackedVector2Array in nav.beach_groups():
			spots.append_array(_beach_spots(group, each))
	else:
		spots.append_array(_offshore_spots(data, rule, each))
	for spot: Vector2 in spots:
		var creature := session.spawn_creature(data, spot)
		if creature == null:
			continue
		creature.world = world
		creature.nest = spot
		spawned.append(creature)
	return spawned


# Per anchor, beach or island: the rolled count, scaled by the party (not for anchored members),
# halved while a fire burns for creatures that flee fire.
func _count(data: CreatureData, rule: CreatureSpawnRuleData) -> int:
	var count: int = world.rng.randi_range(rule.count.x, rule.count.y)
	if rule.anchor == CreatureSpawnRuleData.Anchor.NONE:
		count = floori(count * pow(data.party_rate_mult_per_extra_player, maxi(party_size, 1) - 1))
	if _is_fire_shy(data) and not world.lit_fires().is_empty():
		count /= 2
	return count


func _beach_spots(group: PackedVector2Array, count: int) -> Array[Vector2]:
	var cells: Array[Vector2] = []
	for point: Vector2 in group:
		var center := CreatureNav.center_of(Vector2i(point))
		if world.fire_covering(center) == null:
			cells.append(center)
	var picked: Array[Vector2] = []
	for i: int in mini(count, cells.size()):
		picked.append(cells.pop_at(world.rng.randi_range(0, cells.size() - 1)))
	return picked


func _offshore_spots(data: CreatureData, rule: CreatureSpawnRuleData, count: int) -> Array[Vector2]:
	var margin: int = maxi(rule.min_shore_distance_tiles, data.keep_off_shore_tiles)
	var cells: Array[Vector2i] = []
	for cell: Vector2i in built.terrain.cells:
		var near: int = nav.land_distance(cell)
		if rule.terrain.has(built.terrain.cells[cell]) and near >= margin and near <= OFFSHORE_MAX_TILES:
			cells.append(cell)
	var picked: Array[Vector2] = []
	for i: int in mini(count, cells.size()):
		picked.append(CreatureNav.center_of(cells.pop_at(world.rng.randi_range(0, cells.size() - 1))))
	return picked


# The rule fits this island (its layout's chain family) and, for a phased rule, the phase.
func _matches(rule: CreatureSpawnRuleData, phase: Variant) -> bool:
	if rule.context == DataEnums.SceneContext.CROSSING or rule.tide != DataEnums.Tide.ANY:
		return false
	if not rule.chain_families.is_empty() and not rule.chain_families.has(layout.chain_family):
		return false
	if rule.phases.is_empty():
		return phase == null
	return phase != null and rule.phases.has(phase)


func _has_live(key: String) -> bool:
	var alive: Array = []
	for node: Variant in _live.get(key, []):
		if is_instance_valid(node) and not (node as Node).is_queued_for_deletion():
			alive.append(node)
	_live[key] = alive
	return not alive.is_empty()


func _is_fire_shy(data: CreatureData) -> bool:
	var counter := CreatureBrain.counter_for(data, CreatureCounterData.Trigger.FIRE_LIGHT)
	for each: CreatureCounterData in data.counters:
		if each.trigger == CreatureCounterData.Trigger.FIRE_LIGHT and each.response == CreatureCounterData.Response.DISPERSE:
			return true
	return counter != null and counter.response == CreatureCounterData.Response.DISPERSE


func _remove(creature: Creature) -> void:
	creature.get_parent().remove_child(creature)
	creature.queue_free()


# Creature ids sorted as text (Array[StringName].sort() does not sort by text).
func _ids() -> Array[StringName]:
	return _catalog.list_ids(&"creatures")


func _data(id: StringName) -> CreatureData:
	return _catalog.get_entry(&"creatures", id) as CreatureData
