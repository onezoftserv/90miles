extends GutTest
## crossing "Shark pass event": a weak swimmer first, else an intact raft, through a replaceable hook.

const SHARK := CrossingBeat.Kind.SHARK_PASS


class FakeThreats extends CrossingThreats:
	var calls: int = 0

	func resolve(_event: CrossingBeat, _crossing: Crossing) -> void:
		calls += 1


func before_each() -> void:
	NetManager.start_solo()
	WeatherManager.stop()
	WeatherManager.sky.start_at(0.0)


func after_each() -> void:
	NetManager.leave()


func test_shark_hits_raft() -> void:
	var crossing := CrossingRig.make(self, &"raft", 1, 100.0, 90.0, [CrossingRig.beat(1.0, SHARK)])
	CrossingRig.run(crossing, 1.1)
	assert_eq(crossing.integrity.value, 80.0)


func test_shark_prefers_weak_swimmer() -> void:
	var crossing := CrossingRig.make(self, &"raft", 1, 100.0, 90.0, [CrossingRig.beat(1.0, SHARK)])
	var body := crossing.body_of(1)
	crossing.throw_in(1)
	body.meters.energy = 15.0
	CrossingRig.run(crossing, 0.9)
	assert_eq(body.meters.health, 100.0)
	CrossingRig.run(crossing, 0.2)
	assert_eq(body.meters.health, 75.0)
	assert_true(body.meters.has_status(DataEnums.Status.BLEEDING))
	assert_eq(crossing.integrity.value, 100.0)


func test_shark_leaves_a_fit_swimmer_alone_when_there_is_no_vessel() -> void:
	var crossing := CrossingRig.make(self, &"binoculars_swim", 1, 0.0, 60.0, [CrossingRig.beat(1.0, SHARK)])
	CrossingRig.run(crossing, 1.1)
	assert_eq(crossing.body_of(1).meters.health, 100.0)


func test_threat_hook_is_replaceable() -> void:
	var crossing := CrossingRig.make(self, &"raft", 1, 100.0, 90.0, [CrossingRig.beat(1.0, SHARK)])
	var fake := FakeThreats.new()
	crossing.threats = fake
	CrossingRig.run(crossing, 1.1)
	assert_eq(fake.calls, 1)
	assert_eq(crossing.integrity.value, 100.0)
