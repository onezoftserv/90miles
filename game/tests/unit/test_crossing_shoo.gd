extends GutTest
## crossing "Shark pass event", "Shooing the shark", "Which job a press takes" and creatures-ai
## "Crossing reef shark" with 1 and 2 riders, offline: the fin circles its side 5 s before the
## strike, a 1 s hold on it shoos the shark off, a hold still running at the strike is too late, a
## tired swimmer climbs out in time, a teammate saves a tired swimmer, a shooed shark leaves the
## crossing, an early pass gets the lead that is left, and a press reaching a fin and a leak shoos.

const K := CrossingBeat.Kind
const W := CrossingBeat.Side.WEST
const E := CrossingBeat.Side.EAST


func _sharks(crossing: Crossing) -> Array[Creature]:
	var found: Array[Creature] = []
	for child: Node in (crossing.get_parent() as CoopSession).entities.get_children():
		var creature := child as Creature
		if creature != null and creature.data != null and creature.data.id == CreatureThreats.SHARK_ID and not creature.is_queued_for_deletion():
			found.append(creature)
	return found


func _edge(crossing: Crossing, body: PlayerBody, side: int) -> void:
	var deck := crossing.deck_rect()
	var x: float = deck.end.x - 1.0 if side == E else deck.position.x + 1.0
	body.global_position = Vector2(x, deck.get_center().y)


func test_the_fin_shows_before_the_strike() -> void:
	var crossing := CrossingRig.make(self, &"raft", 1, 100.0, 60.0, [CrossingBeat.create(30.0, K.SHARK_PASS, 0, E)])
	CrossingRig.run(crossing, 24.9)
	assert_eq(_sharks(crossing).size(), 0, "nothing before the warning")
	CrossingRig.run(crossing, 0.2)
	assert_true(crossing.fins.has(0), "the fin is warned at 25 s")
	var spot: Vector2 = crossing.fins[0]
	assert_almost_eq(spot.x, crossing.deck_rect().end.x + Crossing.TILE_PX, 0.01, "1 tile off the raft's east edge")
	var sharks := _sharks(crossing)
	assert_eq(sharks.size(), 1, "a reef shark circles there")
	assert_lt(sharks[0].global_position.distance_to(spot), 8.0)
	assert_eq(crossing.integrity.value, 100.0, "and has hit nothing yet")


func test_solo_shoos_the_shark() -> void:
	var crossing := CrossingRig.make(self, &"raft", 1, 100.0, 60.0, [CrossingBeat.create(30.0, K.SHARK_PASS, 0, W)])
	var body := crossing.body_of(1)
	CrossingRig.run(crossing, 27.0)
	_edge(crossing, body, W)
	CrossingRig.hold(crossing, body, 1.1)
	CrossingRig.release(crossing, body)
	assert_true(crossing.shooed.has(0), "shooed")
	await wait_frames(2)
	assert_eq(_sharks(crossing).size(), 0, "the shark left the crossing")
	CrossingRig.run(crossing, 30.5 - crossing.elapsed_s)
	assert_eq(crossing.integrity.value, 100.0, "the raft at 100 after the strike time")


func test_too_late_to_shoo() -> void:
	var crossing := CrossingRig.make(self, &"raft", 1, 100.0, 60.0, [CrossingBeat.create(30.0, K.SHARK_PASS, 0, W)])
	var body := crossing.body_of(1)
	CrossingRig.run(crossing, 29.5)
	_edge(crossing, body, W)
	CrossingRig.hold(crossing, body, 1.1)
	CrossingRig.release(crossing, body)
	assert_false(crossing.shooed.has(0), "a hold still running at the strike shoos nothing")
	assert_eq(crossing.integrity.value, 80.0)


func test_idle_takes_the_bite_as_before() -> void:
	var crossing := CrossingRig.make(self, &"raft", 1, 100.0, 60.0, [CrossingBeat.create(30.0, K.SHARK_PASS)])
	CrossingRig.run(crossing, 30.0)
	assert_eq(crossing.integrity.value, 80.0)


func test_a_tired_solo_swimmer_climbs_out_in_time() -> void:
	var crossing := CrossingRig.make(self, &"raft", 1, 100.0, 60.0, [CrossingBeat.create(30.0, K.SHARK_PASS, 0, E)])
	var body := crossing.body_of(1)
	CrossingRig.run(crossing, 24.0)
	crossing.throw_in(1)
	body.meters.energy = 15.0
	CrossingRig.put_beside_deck(crossing, body, 4.0)
	CrossingRig.run(crossing, 1.0)
	CrossingRig.hold(crossing, body, 3.1)
	CrossingRig.release(crossing, body)
	assert_eq(crossing.rider_state(1), Crossing.Rider.ABOARD, "aboard before the strike")
	var health: float = body.meters.health
	CrossingRig.run(crossing, 30.5 - crossing.elapsed_s)
	assert_eq(body.meters.health, health, "nobody bitten")
	assert_eq(crossing.integrity.value, 80.0, "the raft takes the strike")


func test_a_teammate_saves_a_tired_swimmer() -> void:
	var crossing := CrossingRig.make(self, &"raft", 2, 100.0, 60.0, [CrossingBeat.create(30.0, K.SHARK_PASS, 0, E)])
	var swimmer := crossing.body_of(2)
	CrossingRig.run(crossing, 20.0)
	crossing.throw_in(2)
	swimmer.global_position = crossing.deck_rect().position + Vector2(-20.0, 0.0)
	CrossingRig.run(crossing, 6.0)
	_edge(crossing, crossing.body_of(1), E)
	CrossingRig.hold(crossing, crossing.body_of(1), 1.1)
	CrossingRig.release(crossing, crossing.body_of(1))
	assert_true(crossing.shooed.has(0))
	# Tired at the strike (below 20 energy) but not drowning before it.
	swimmer.meters.energy = 19.0
	var health: float = swimmer.meters.health
	CrossingRig.run(crossing, 30.5 - crossing.elapsed_s)
	assert_eq(swimmer.meters.health, health, "the client's health is unchanged")
	assert_eq(crossing.integrity.value, 100.0)


func test_an_early_pass_gets_the_lead_that_is_left() -> void:
	var crossing := CrossingRig.make(self, &"raft", 1, 100.0, 60.0, [CrossingBeat.create(3.0, K.SHARK_PASS, 0, W)])
	CrossingRig.run(crossing, 0.2)
	assert_true(crossing.fins.has(0), "warned at once")
	assert_eq(_sharks(crossing).size(), 1)


func test_a_press_reaching_a_fin_and_a_leak_shoos_first() -> void:
	var beats: Array[RefCounted] = [CrossingBeat.create(20.0, K.DEBRIS, -1), CrossingBeat.create(30.0, K.SHARK_PASS, 0, W)]
	var crossing := CrossingRig.make(self, &"raft", 1, 100.0, 60.0, beats)
	var body := crossing.body_of(1)
	CrossingRig.run(crossing, 26.0)
	assert_eq(crossing.leaks.list.size(), 1)
	var leak: Vector2 = crossing.leak_position(crossing.leaks.list[0])
	body.global_position = Vector2(crossing.deck_rect().position.x + 1.0, leak.y)
	CrossingRig.hold(crossing, body, 1.1)
	CrossingRig.release(crossing, body)
	assert_true(crossing.shooed.has(1), "the press shooed the shark (beat 1; the debris is beat 0)")
	assert_eq(crossing.leaks.list.size(), 1, "and left the leak for later")


func test_the_scripted_threats_honour_a_shoo() -> void:
	var crossing := CrossingRig.make(self, &"raft", 1, 100.0, 60.0, [CrossingBeat.create(30.0, K.SHARK_PASS, 0, W)])
	crossing.threats = ScriptedThreats.new()
	CrossingRig.run(crossing, 26.0)
	assert_true(crossing.shoo_shark(0))
	CrossingRig.run(crossing, 5.0)
	assert_eq(crossing.integrity.value, 100.0)
