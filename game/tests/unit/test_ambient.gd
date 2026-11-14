extends GutTest
## creature-perch-ride "Ambient visits" (balsero-lore 7.1): an ambient creature arrives at its
## station, stays and leaves when its flee condition holds, its stay time ends or its crossing
## ends. It never attacks, steals or touches the vessel. One offline player throughout.

const FIXTURES: String = "res://tests/fixtures/content"
const STEP_S: float = 0.1
const B := DataEnums.DistanceBand
const F := DataEnums.ChainFamily

var catalog: ContentCatalog = ContentCatalog.new(FIXTURES)


func before_each() -> void:
	NetManager.start_solo()
	WeatherManager.stop()
	WeatherManager.sky.start_at(0.0)
	WeatherManager.sky.weather.apply(&"calm", 600.0, &"", -1.0)


func after_each() -> void:
	WeatherManager.sky.weather.apply(&"calm", 600.0, &"", -1.0)
	NetManager.leave()


# A fixture creature whose crossing rules all come up (chance 1.0), with `stay_s` as its stay time.
func _sure(id: StringName, stay_s: float = 0.0) -> CreatureData:
	var data := (catalog.get_entry(&"creatures", id) as CreatureData).duplicate() as CreatureData
	var rules: Array[CreatureSpawnRuleData] = []
	for rule: CreatureSpawnRuleData in data.spawn_rules:
		var sure := rule.duplicate() as CreatureSpawnRuleData
		sure.chance = 1.0
		rules.append(sure)
	data.spawn_rules = rules
	data.circle_time_s = Vector2(stay_s, stay_s)
	return data


# A 1-player mid crossing at dawn with `pool` riding along; the rider at morale 50 under the sky's weather.
func _crossing(pool: Array[CreatureData], length_s: float = 90.0) -> CrossingCreatures:
	var session := CrossingRig.make_session(self, 1)
	session.creature_catalog = catalog
	var crossing := CrossingRig.launch_on(session, &"raft", [1] as Array[int], 100.0, length_s)
	var body := crossing.body_of(1)
	body.climate = WeatherManager.sky.climate
	body.meters.morale = 50.0
	return CrossingCreatures.attach(crossing, F.COAST, B.MID, pool)


func _run(riders: CrossingCreatures, seconds: float) -> void:
	var crossing := riders.crossing
	var creatures := riders.creatures()
	for i: int in roundi(seconds / STEP_S):
		crossing.advance(STEP_S)
		for node: Creature in creatures:
			if is_instance_valid(node) and not node.is_queued_for_deletion():
				node.advance(STEP_S)


func _by_id(riders: CrossingCreatures, id: StringName) -> Creature:
	for creature: Creature in riders.creatures():
		if creature.data.id == id:
			return creature
	return null


func test_a_songbird_and_a_booby_reach_their_stations_and_each_pay_once_that_day() -> void:
	var riders := _crossing([_sure(&"pajarito_prueba"), _sure(&"pajaro_bobo_prueba")] as Array[CreatureData])
	var body := riders.crossing.body_of(1)
	var health: float = body.meters.health
	assert_eq(riders.creatures().size(), 2, "a mid crossing at dawn places both")
	for creature: Creature in riders.creatures():
		assert_true(creature.brain is Ambient, "%s runs the ambient machine" % creature.data.id)
	_run(riders, 6.0)
	for creature: Creature in riders.creatures():
		assert_eq(creature.state_name(), &"STAY", "%s is at its station" % creature.data.id)
		assert_eq(creature.position, creature.nest)
	assert_eq(body.meters.morale, 60.0, "+5 for each kind, once that day")
	_run(riders, 20.0)
	assert_eq(body.meters.morale, 60.0, "and no more")
	assert_eq(body.meters.health, health)
	assert_eq(riders.crossing.integrity.value, 100.0)


func test_the_booby_leaves_in_a_squall_and_the_songbird_stays_to_the_end() -> void:
	var riders := _crossing([_sure(&"pajarito_prueba"), _sure(&"pajaro_bobo_prueba")] as Array[CreatureData], 60.0)
	var body := riders.crossing.body_of(1)
	body.inventory.add(&"coco", 2)
	var held: int = body.inventory.count_tag(DataEnums.ItemTag.FOOD)
	var songbird := _by_id(riders, &"pajarito_prueba")
	var booby := _by_id(riders, &"pajaro_bobo_prueba")
	_run(riders, 6.0)
	assert_eq(booby.state_name(), &"STAY")
	WeatherManager.sky.weather.apply(&"squall", 100.0, &"", -1.0)
	_run(riders, 0.2)
	assert_eq(booby.state_name(), &"LEAVE", "the squall sends the booby off")
	_run(riders, 5.0)
	assert_true(booby.is_queued_for_deletion(), "gone within 5 s")
	assert_eq(songbird.state_name(), &"STAY", "the songbird has no squall rule")
	_run(riders, 50.0)
	assert_true(riders.crossing.finished)
	assert_eq(songbird.brain.history, [&"ARRIVE", &"STAY"] as Array[StringName], "it stayed the whole crossing")
	assert_true(songbird.is_queued_for_deletion(), "and left with it")
	assert_eq(body.inventory.count_tag(DataEnums.ItemTag.FOOD), held, "nothing stolen")
	assert_eq(riders.crossing.integrity.value, 100.0, "the vessel untouched")


func test_a_stay_time_ends_the_visit() -> void:
	var short_stay := _sure(&"pajaro_bobo_prueba", 10.0)
	var riders := _crossing([short_stay] as Array[CreatureData])
	var booby := riders.creatures()[0]
	# The spawner reads the catalog's booby by id; this one stays 10 s.
	booby.data = short_stay
	_run(riders, 6.0)
	assert_eq(booby.state_name(), &"STAY")
	_run(riders, 10.0)
	assert_eq(booby.state_name(), &"LEAVE", "its stay is up")
	_run(riders, 5.0)
	assert_true(booby.is_queued_for_deletion())
	assert_false(riders.crossing.finished, "the crossing goes on")


func test_an_island_ambient_lingers_at_its_spot() -> void:
	var rig := CreatureRig.make(self)
	var body := rig.player(Vector2i(14, 10))
	body.meters.morale = 50.0
	var data := _sure(&"pajarito_prueba")
	data.sight_radius_tiles = 6.0
	var bird := rig.creature(&"", Vector2i(10, 10), data)
	rig.run(30.0)
	assert_eq(bird.state_name(), &"STAY")
	assert_eq(bird.position, bird.nest, "still at its spot")
	assert_eq(body.meters.morale, 55.0, "seen from 4 tiles")
	assert_eq(bird.brain.history, [&"ARRIVE", &"STAY"] as Array[StringName])
