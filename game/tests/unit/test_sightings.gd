extends GutTest
## creature-perch-ride "Sighting effects": each player who sees a creature gets its sighting
## effects, held to each effect's limit per player by the host's run record. On a crossing every
## living rider sees it; on an island, a player within its sight radius. One offline player.

const FLAG: StringName = &"galleguito_a_bordo"
const SANDBAR: IslandLayoutData = preload("res://resources/islands/sandbar.tres")


func before_each() -> void:
	NetManager.start_solo()
	WeatherManager.stop()
	WeatherManager.sky.start_at(0.0)


func after_each() -> void:
	NetManager.leave()
	WeatherManager.sky.clock.set_time(0.0, 1)


static func _morale_effect(amount: float, limit: EffectData.Limit) -> EffectData:
	var effect := EffectData.new()
	effect.kind = EffectData.Kind.METER_ADD
	effect.meter = DataEnums.Meter.MORALE
	effect.amount = amount
	effect.limit = limit
	return effect


static func _bird(id: StringName, effects: Array[EffectData], sight_tiles: float = 0.0) -> CreatureData:
	var data := CreatureData.new()
	data.id = id
	data.behavior = CreatureData.Behavior.AMBIENT
	data.domains = [CreatureData.Domain.AIR] as Array[CreatureData.Domain]
	data.sighting_effects = effects
	data.sight_radius_tiles = sight_tiles
	return data


func _creature(data: CreatureData) -> Creature:
	var made := Creature.make(data)
	autofree(made)
	return made


func test_solo_songbird_pays_once_a_day() -> void:
	var crossing := CrossingRig.make(self, &"raft", 1, 100.0, 90.0)
	var body := crossing.body_of(1)
	body.meters.morale = 50.0
	var world := CreatureWorld.for_crossing(crossing)
	var songbird := _bird(&"pajarito_prueba", [_morale_effect(5.0, EffectData.Limit.ONCE_PER_DAY)] as Array[EffectData])
	Sightings.see(_creature(songbird), world)
	assert_eq(body.meters.morale, 55.0, "the first songbird on day 1")
	Sightings.see(_creature(songbird), world)
	assert_eq(body.meters.morale, 55.0, "a second songbird on day 1 pays nothing")
	WeatherManager.sky.clock.set_time(0.0, 2)
	Sightings.see(_creature(songbird), world)
	assert_eq(body.meters.morale, 60.0, "a third on day 2")


func test_a_flag_is_set_once_per_run() -> void:
	var crossing := CrossingRig.make(self, &"raft", 1, 100.0, 90.0)
	var record := crossing.session().run_record
	var world := CreatureWorld.for_crossing(crossing)
	assert_eq(world.record, record, "the crossing world writes the session's record")
	var effect := EffectData.new()
	effect.kind = EffectData.Kind.SET_FLAG
	effect.ref_id = FLAG
	effect.limit = EffectData.Limit.ONCE_PER_RUN
	var gull := _bird(&"galleguito_prueba", [effect] as Array[EffectData])
	Sightings.see(_creature(gull), world)
	assert_true(record.has_flag(FLAG), "set by the first sighting")
	record.clear_flag(FLAG)
	Sightings.see(_creature(gull), world)
	assert_false(record.has_flag(FLAG), "a once-per-run effect never fires twice")


func test_an_island_creature_is_seen_only_within_its_sight_radius() -> void:
	var rig := CreatureRig.make(self)
	var body := rig.player(Vector2i(20, 10))
	body.meters.morale = 50.0
	var bird := rig.creature(&"", Vector2i(10, 10), _bird(&"pajarito_prueba", [_morale_effect(5.0, EffectData.Limit.NONE)] as Array[EffectData], 3.0))
	Sightings.see(bird, rig.world)
	assert_eq(body.meters.morale, 50.0, "10 tiles off: not seen")
	body.global_position = CreatureRig.center(Vector2i(12, 10))
	Sightings.see(bird, rig.world)
	assert_eq(body.meters.morale, 55.0, "2 tiles off: seen")


func test_the_same_player_seeing_the_same_creature_twice_pays_once() -> void:
	var crossing := CrossingRig.make(self, &"raft", 1, 100.0, 90.0)
	var body := crossing.body_of(1)
	body.meters.morale = 50.0
	var world := CreatureWorld.for_crossing(crossing)
	var data := _bird(&"pajaro_bobo_prueba", [_morale_effect(5.0, EffectData.Limit.NONE)] as Array[EffectData])
	var booby := _creature(data)
	Sightings.see(booby, world)
	Sightings.see(booby, world)
	assert_eq(body.meters.morale, 55.0, "one creature pays a player once")
	Sightings.see(_creature(data), world)
	assert_eq(body.meters.morale, 60.0, "another one with no limit pays again")


func test_the_island_spawner_writes_the_sessions_record_so_a_run_limit_holds_across_scenes() -> void:
	var crossing := CrossingRig.make(self, &"raft", 1, 100.0, 90.0)
	var session := crossing.session()
	var body := crossing.body_of(1)
	body.meters.morale = 50.0
	var spawner := CreatureSpawner.new()
	session.add_child(spawner)
	spawner.setup(session, SANDBAR)
	assert_eq(spawner.world.record, session.run_record, "the island's creatures write the run's record")
	var data := _bird(&"pajaro_bobo_prueba", [_morale_effect(5.0, EffectData.Limit.ONCE_PER_RUN)] as Array[EffectData], 4.0)
	Sightings.see(_creature(data), CreatureWorld.for_crossing(crossing))
	assert_eq(body.meters.morale, 55.0, "seen at sea")
	var on_island := Creature.make(data)
	add_child_autofree(on_island)
	on_island.global_position = body.global_position
	Sightings.see(on_island, spawner.world)
	assert_eq(body.meters.morale, 55.0, "a once-per-run sighting already paid at sea is not paid again on the island")


func test_a_dead_rider_sees_nothing() -> void:
	var crossing := CrossingRig.make(self, &"raft", 1, 100.0, 90.0)
	var body := crossing.body_of(1)
	body.meters.morale = 50.0
	body.meters.dead = true
	var world := CreatureWorld.for_crossing(crossing)
	assert_true(world.players().is_empty(), "no living rider")
	Sightings.see(_creature(_bird(&"pajarito_prueba", [_morale_effect(5.0, EffectData.Limit.NONE)] as Array[EffectData])), world)
	assert_eq(body.meters.morale, 50.0)
