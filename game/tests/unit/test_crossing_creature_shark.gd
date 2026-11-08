extends GutTest
## creatures-ai "Crossing reef shark": the crossing's shark pass is resolved by a reef shark
## creature, with the crossing's own numbers.

const SHARK := CrossingBeat.Kind.SHARK_PASS


func before_each() -> void:
	NetManager.start_solo()
	WeatherManager.stop()
	WeatherManager.sky.start_at(0.0)


func after_each() -> void:
	NetManager.leave()


func _sharks(crossing: Crossing) -> Array[Creature]:
	var found: Array[Creature] = []
	for child: Node in crossing.get_children():
		var creature := child as Creature
		if creature != null and creature.data.id == &"reef_shark":
			found.append(creature)
	return found


func test_the_default_threats_are_the_creature_backed_ones() -> void:
	var crossing := CrossingRig.make(self, &"raft", 1, 100.0, 90.0)
	assert_true(crossing.threats is CreatureThreats)


func test_solo_pass_bites_the_tired_swimmer_and_a_reef_shark_circles_then_leaves() -> void:
	var crossing := CrossingRig.make(self, &"raft", 1, 100.0, 90.0, [CrossingRig.beat(1.0, SHARK)])
	var body := crossing.body_of(1)
	crossing.throw_in(1)
	body.meters.energy = 15.0
	CrossingRig.run(crossing, 1.1)
	assert_eq(body.meters.health, 75.0)
	assert_true(body.meters.has_status(DataEnums.Status.BLEEDING))
	assert_eq(crossing.integrity.value, 100.0)
	var sharks := _sharks(crossing)
	assert_eq(sharks.size(), 1)
	sharks[0].advance(6.1)
	assert_true(sharks[0].is_queued_for_deletion(), "gone after its circle time")


func test_a_fit_swimmer_is_left_alone_and_the_raft_takes_the_hit() -> void:
	var crossing := CrossingRig.make(self, &"raft", 1, 100.0, 90.0, [CrossingRig.beat(1.0, SHARK)])
	crossing.throw_in(1)
	crossing.body_of(1).meters.energy = 80.0
	CrossingRig.run(crossing, 1.1)
	assert_eq(crossing.body_of(1).meters.health, 100.0)
	assert_eq(crossing.integrity.value, 80.0)
