extends GutTest
## crossing "Shark dumps" (vessel-car-board): on a route whose dump triggers include a shark attack,
## a shark hit on a vessel throws its untied riders in at the fall-in cost. Routes without the
## trigger are unchanged: the raft lists only the squall.

const SHARK := CrossingBeat.Kind.SHARK_PASS
const ROCK := CrossingBeat.Kind.ROCK


func before_each() -> void:
	NetManager.start_solo()
	WeatherManager.stop()
	WeatherManager.sky.start_at(0.0)


func after_each() -> void:
	WeatherManager.stop()
	NetManager.leave()


func _beats(list: Array) -> Array[RefCounted]:
	var beats: Array[RefCounted] = []
	for pair: Array in list:
		beats.append(CrossingRig.beat(pair[0], pair[1]))
	return beats


func _with_shark_dumps(crossing: Crossing) -> void:
	crossing.route.dump_triggers = [RouteData.DumpTrigger.SQUALL, RouteData.DumpTrigger.SHARK_ATTACK] as Array[RouteData.DumpTrigger]


func test_solo_raft_without_the_trigger_keeps_its_rider_aboard() -> void:
	var crossing := CrossingRig.make(self, &"raft", 1, 100.0, 90.0, _beats([[1.0, SHARK]]))
	assert_eq(crossing.route.dump_triggers, [RouteData.DumpTrigger.SQUALL] as Array[RouteData.DumpTrigger], "the raft lists only the squall")
	crossing.body_of(1).meters.energy = 80.0
	CrossingRig.run(crossing, 1.1)
	assert_eq(crossing.integrity.value, 80.0)
	assert_eq(crossing.rider_state(1), Crossing.Rider.ABOARD)
	assert_almost_eq(crossing.body_of(1).meters.energy, 80.0, 0.5)


func test_solo_shark_dump_throws_the_rider_in() -> void:
	var crossing := CrossingRig.make(self, &"raft", 1, 100.0, 90.0, _beats([[1.0, SHARK]]))
	_with_shark_dumps(crossing)
	crossing.body_of(1).meters.energy = 80.0
	CrossingRig.run(crossing, 1.0)
	assert_eq(crossing.integrity.value, 80.0)
	assert_eq(crossing.rider_state(1), Crossing.Rider.IN_WATER)
	assert_almost_eq(crossing.body_of(1).meters.energy, 70.0, 0.5, "fell in for 10")


func test_shark_dump_spares_a_tied_rider() -> void:
	var crossing := CrossingRig.make(self, &"raft", 2, 100.0, 90.0, _beats([[1.0, SHARK]]))
	_with_shark_dumps(crossing)
	crossing.tie(1)
	CrossingRig.run(crossing, 1.1)
	assert_eq(crossing.rider_state(1), Crossing.Rider.TIED)
	assert_eq(crossing.rider_state(2), Crossing.Rider.IN_WATER)


func test_a_rock_never_dumps() -> void:
	var crossing := CrossingRig.make(self, &"raft", 1, 100.0, 90.0, _beats([[1.0, ROCK]]))
	_with_shark_dumps(crossing)
	CrossingRig.run(crossing, 1.1)
	assert_eq(crossing.integrity.value, 60.0)
	assert_eq(crossing.rider_state(1), Crossing.Rider.ABOARD)


func test_scripted_threats_dump_too() -> void:
	var crossing := CrossingRig.make(self, &"raft", 1, 100.0, 90.0, _beats([[1.0, SHARK]]))
	crossing.threats = ScriptedThreats.new()
	_with_shark_dumps(crossing)
	CrossingRig.run(crossing, 1.1)
	assert_eq(crossing.integrity.value, 80.0)
	assert_eq(crossing.rider_state(1), Crossing.Rider.IN_WATER)


func test_hit_vessel_returns_the_deck_centre() -> void:
	var crossing := CrossingRig.make(self, &"raft", 1, 100.0, 90.0)
	assert_eq(crossing.hit_vessel(10.0), crossing.deck_center())
	assert_eq(crossing.hit_vessel(10.0, true), crossing.deck_center())
	assert_eq(crossing.integrity.value, 80.0)


func test_the_shark_shows_beside_the_deck_it_hit() -> void:
	var crossing := CrossingRig.make(self, &"raft", 1, 100.0, 90.0, _beats([[1.0, SHARK]]))
	CrossingRig.run(crossing, 1.1)
	var sharks: Array[Creature] = []
	for child: Node in crossing.session().entities.get_children():
		if child is Creature and (child as Creature).data.id == &"reef_shark":
			sharks.append(child as Creature)
	assert_eq(sharks.size(), 1, "a shark circles")
	if not sharks.is_empty():
		assert_eq(sharks[0].position, crossing.deck_center() + CreatureThreats.SHARK_OFFSET_PX)
