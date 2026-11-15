extends GutTest
## creature-perch-ride "Perch ride details" (balsero-lore 7.2, 7.3; BESTIARY "The final passenger"):
## the galleguito circles, lands on the rider holding the most food, gives +10 morale once per
## player, may take one held food item per 60 s while perched and never changes the crossing. Shooed,
## it hops to another head or, solo, circles 5 s and lands again; it waits overhead while its rider
## swims. One offline player unless a test says otherwise.

const FIXTURES: String = "res://tests/fixtures/content"
const STEP_S: float = 0.1
const GULL: StringName = &"galleguito_prueba"
const FLAG: StringName = &"galleguito_a_bordo"
const FOOD := DataEnums.ItemTag.FOOD
const PALM_SCENE: PackedScene = preload("res://scenes/levels/palm.tscn")

var catalog: ContentCatalog = ContentCatalog.new(FIXTURES)


func before_each() -> void:
	NetManager.start_solo()
	WeatherManager.stop()
	WeatherManager.sky.start_at(0.0)


func after_each() -> void:
	NetManager.leave()


# A final crossing of `length_s` with `players` riders at morale 50, `food[i]` coconuts on rider
# i + 1, and the galleguito riding along. `sure_theft` makes every theft roll succeed.
func _crossing(players: int = 1, food: Array[int] = [], sure_theft: bool = false, length_s: float = 200.0, run_seed: int = 0) -> CrossingCreatures:
	var session := CrossingRig.make_session(self, players)
	session.creature_catalog = catalog
	session.world_state["run_seed"] = run_seed
	var ids: Array[int] = []
	for id: int in range(1, players + 1):
		ids.append(id)
	var crossing := CrossingRig.launch_on(session, &"raft", ids, 100.0, length_s)
	for index: int in players:
		var body := crossing.body_of(index + 1)
		body.meters.morale = 50.0
		if index < food.size() and food[index] > 0:
			body.inventory.add(&"coco", food[index])
	var riders := CrossingCreatures.attach(crossing, DataEnums.ChainFamily.FINAL, DataEnums.DistanceBand.COAST)
	if sure_theft:
		var gull := _gull(riders)
		var sure := gull.data.duplicate() as CreatureData
		sure.steal_chance = 1.0
		gull.data = sure
	return riders


func _gull(riders: CrossingCreatures) -> Creature:
	for creature: Creature in riders.creatures():
		if creature.data.id == GULL:
			return creature
	return null


func _run(riders: CrossingCreatures, seconds: float) -> void:
	for i: int in roundi(seconds / STEP_S):
		riders.crossing.advance(STEP_S)
		for creature: Creature in riders.creatures():
			creature.advance(STEP_S)


# Runs until the gull is perched (at most `limit_s`); the seconds it took.
func _until_perched(riders: CrossingCreatures, limit_s: float = 30.0) -> float:
	var gull := _gull(riders)
	var waited: float = 0.0
	while gull.state_name() != &"PERCH" and waited < limit_s:
		_run(riders, STEP_S)
		waited += STEP_S
	return waited


func _food(body: PlayerBody) -> int:
	return body.inventory.count_tag(FOOD)


func test_it_circles_then_lands_on_the_solo_player_and_pays_once() -> void:
	var riders := _crossing()
	var gull := _gull(riders)
	assert_not_null(gull, "the final crossing always places the galleguito")
	if gull == null:
		return
	assert_true(gull.brain is PerchRide)
	var body := riders.crossing.body_of(1)
	_run(riders, 3.0)
	assert_eq(gull.state_name(), &"CIRCLE", "it circles first")
	assert_eq(body.meters.morale, 50.0, "nothing before it lands")
	assert_lt(_until_perched(riders), 30.0, "then it lands")
	assert_eq(gull.position, body.global_position, "on the player")
	assert_eq(gull.perch_peer, 1, "and says whose head it is on")
	assert_eq(body.meters.morale, 60.0, "+10 morale on landing")
	assert_true(riders.crossing.session().run_record.has_flag(FLAG))
	gull.shoo(body)
	_run(riders, 8.0)
	assert_eq(gull.state_name(), &"PERCH", "landed again")
	assert_eq(body.meters.morale, 60.0, "+10 only once per player")


func test_theft_rolls_start_60_s_after_landing_and_take_only_held_food() -> void:
	var riders := _crossing(1, [3] as Array[int], true)
	var body := riders.crossing.body_of(1)
	body.inventory.add(&"rope", 1)
	_until_perched(riders)
	_run(riders, 59.0)
	assert_eq(_food(body), 3, "nothing after 59 s")
	_run(riders, 1.0)
	assert_eq(_food(body), 2, "one at 60 s")
	_run(riders, 60.0)
	assert_eq(_food(body), 1, "two after 120 s")
	assert_eq(body.inventory.count_id(&"rope"), 1, "never anything but food")
	assert_eq(_gull(riders).state_name(), &"PERCH", "it never flies off after a theft")


func test_a_solo_shoo_circles_5_s_and_lands_again_skipping_a_roll() -> void:
	var riders := _crossing(1, [3] as Array[int], true)
	var gull := _gull(riders)
	var body := riders.crossing.body_of(1)
	_until_perched(riders)
	_run(riders, 58.0)
	assert_true(gull.shoo(body), "shooed")
	assert_eq(gull.state_name(), &"HOVER")
	assert_eq(gull.perch_peer, 0, "off the head")
	_run(riders, 4.9)
	assert_eq(gull.state_name(), &"HOVER", "still circling at 4.9 s")
	assert_eq(_food(body), 3, "the roll at 60 s fell while it circled: skipped")
	_run(riders, 1.0)
	assert_eq(gull.state_name(), &"PERCH", "back on the same head")
	assert_eq(gull.perch_peer, 1)
	_run(riders, 60.0)
	assert_eq(_food(body), 2, "the next roll, at 120 s, takes one")


func test_it_waits_overhead_while_the_player_swims_and_lands_on_the_climb() -> void:
	var riders := _crossing(1, [3] as Array[int], true)
	var gull := _gull(riders)
	var body := riders.crossing.body_of(1)
	_until_perched(riders)
	_run(riders, 50.0)
	riders.crossing.throw_in(1)
	_run(riders, 0.2)
	assert_eq(gull.state_name(), &"HOVER", "it lifts off")
	_run(riders, 20.0)
	assert_eq(gull.state_name(), &"HOVER", "and waits while the player swims")
	assert_lt(gull.position.distance_to(body.global_position), 2.0 * CreatureNav.TILE, "overhead")
	assert_eq(_food(body), 3, "the roll at 60 s took nothing in the water")
	riders.crossing.bring_aboard(1)
	_run(riders, 1.0)
	assert_eq(gull.state_name(), &"PERCH", "lands again on the climb")
	assert_eq(gull.position, body.global_position)


func test_it_never_changes_speed_drift_plan_or_vessel() -> void:
	var riders := _crossing(1, [3] as Array[int], true)
	var crossing := riders.crossing
	var plan: Array = crossing.plan.to_array()
	var speed: float = crossing.route.speed_multiplier
	_until_perched(riders)
	_run(riders, 130.0)
	assert_eq(crossing.integrity.value, 100.0)
	assert_eq(crossing.plan.to_array(), plan)
	assert_eq(crossing.route.speed_multiplier, speed)
	assert_eq(crossing.sea.current, Vector2.ZERO, "no drift")
	assert_eq(crossing.body_of(1).meters.health, 100.0)


func test_in_co_op_it_picks_the_rider_holding_the_most_food() -> void:
	var riders := _crossing(3, [1, 3, 1] as Array[int])
	_until_perched(riders)
	assert_eq(_gull(riders).perch_peer, 2, "3 coconuts beat 1 and 1")
	for peer: int in [1, 2, 3]:
		assert_eq(riders.crossing.body_of(peer).meters.morale, 60.0, "+10 for rider %d" % peer)


func test_a_tie_is_broken_by_the_run_seed() -> void:
	var picks: Dictionary[int, bool] = {}
	for run_seed: int in 8:
		var first := _crossing(3, [2, 2, 2] as Array[int], false, 200.0, run_seed)
		_until_perched(first)
		var again := _crossing(3, [2, 2, 2] as Array[int], false, 200.0, run_seed)
		_until_perched(again)
		assert_eq(_gull(first).perch_peer, _gull(again).perch_peer, "seed %d picks the same rider twice" % run_seed)
		picks[_gull(first).perch_peer] = true
	assert_gt(picks.size(), 1, "different seeds pick different riders")


func test_a_shoo_with_another_rider_aboard_hops_to_that_head() -> void:
	var riders := _crossing(2, [0, 3] as Array[int])
	var gull := _gull(riders)
	_until_perched(riders)
	assert_eq(gull.perch_peer, 2)
	assert_true(gull.shoo(riders.crossing.body_of(2)))
	assert_eq(gull.state_name(), &"HOP")
	_run(riders, 1.0)
	assert_eq(gull.state_name(), &"PERCH")
	assert_eq(gull.perch_peer, 1, "on the other head")
	assert_eq(gull.position, riders.crossing.body_of(1).global_position)


func test_when_its_rider_dies_it_picks_again() -> void:
	var riders := _crossing(2, [0, 3] as Array[int])
	var gull := _gull(riders)
	_until_perched(riders)
	assert_eq(gull.perch_peer, 2)
	riders.crossing.body_of(2).meters.dead = true
	_run(riders, 1.5)
	assert_eq(gull.state_name(), &"PERCH")
	assert_eq(gull.perch_peer, 1, "on the living rider")


func test_a_solo_rider_ties_down_and_climbs_aboard_with_the_gull_on_their_head() -> void:
	var riders := _crossing()
	var gull := _gull(riders)
	var crossing := riders.crossing
	var body := crossing.body_of(1)
	_until_perched(riders)
	assert_eq(gull.interactable.priority, -1, "its shoo ranks below the rescue points")
	CrossingRig.hold(crossing, body, crossing.tuning.tie_hold_s + 0.2)
	assert_eq(crossing.rider_state(1), Crossing.Rider.TIED, "tied down with the gull aboard")
	assert_eq(gull.state_name(), &"PERCH", "the gull is still on their head")
	CrossingRig.release(crossing, body)
	crossing.throw_in(1)
	_run(riders, 1.0)
	assert_eq(gull.state_name(), &"HOVER", "over the swimmer")
	CrossingRig.hold(crossing, body, crossing.tuning.climb_hold_s + 0.2)
	assert_eq(crossing.rider_state(1), Crossing.Rider.ABOARD, "climbed aboard past the hovering gull")


func test_an_island_gull_still_outranks_the_palm() -> void:
	var rig := CreatureRig.make(self)
	var gull := rig.creature(&"seagull", Vector2i(3, 10))
	var palm := PALM_SCENE.instantiate() as Palm
	add_child_autofree(palm)
	palm.global_position = CreatureRig.center(Vector2i(3, 10))
	assert_eq(gull.interactable.priority, 1, "every other creature keeps priority 1")
	var picked := InteractionPicker.pick(palm.global_position, [palm.interactable, gull.interactable] as Array[Interactable])
	assert_eq(picked, gull.interactable, "the shoo beats the palm's climb")


# The fixture galleguito, plus the booby and the songbird with crossing rules at 0.99 and no filters.
func _final_pool() -> Array[CreatureData]:
	var pool: Array[CreatureData] = [catalog.get_entry(&"creatures", GULL) as CreatureData]
	for id: StringName in [&"pajaro_bobo_prueba", &"pajarito_prueba"]:
		var data := (catalog.get_entry(&"creatures", id) as CreatureData).duplicate() as CreatureData
		var rule := CreatureSpawnRuleData.new()
		rule.context = DataEnums.SceneContext.CROSSING
		rule.chance = 0.99
		data.spawn_rules = [rule] as Array[CreatureSpawnRuleData]
		pool.append(data)
	return pool


func _final_crossing(players: int) -> CrossingCreatures:
	var session := CrossingRig.make_session(self, players)
	session.creature_catalog = catalog
	var ids: Array[int] = []
	for id: int in range(1, players + 1):
		ids.append(id)
	var crossing := CrossingRig.launch_on(session, &"raft", ids, 100.0, 120.0)
	for peer: int in ids:
		crossing.body_of(peer).meters.morale = 50.0
	return CrossingCreatures.attach(crossing, DataEnums.ChainFamily.FINAL, DataEnums.DistanceBand.COAST, _final_pool())


func _placed_ids(riders: CrossingCreatures) -> Array[String]:
	var ids: Array[String] = []
	for creature: Creature in riders.creatures():
		ids.append(String(creature.data.id))
	ids.sort()
	return ids


func test_a_solo_final_crossing_places_the_galleguito_over_a_full_cap() -> void:
	var riders := _final_crossing(1)
	assert_eq(_placed_ids(riders), ["galleguito_prueba", "pajarito_prueba", "pajaro_bobo_prueba"] as Array[String], "2 rolled fill the cap; the galleguito still comes")
	_until_perched(riders)
	assert_eq(riders.crossing.body_of(1).meters.morale, 70.0, "+10 from the gull, +5 each from the birds once they settle")


func test_a_4_player_final_crossing_places_it_and_pays_each_player_once() -> void:
	var riders := _final_crossing(4)
	assert_true(_placed_ids(riders).has("galleguito_prueba"))
	var gull := _gull(riders)
	_until_perched(riders)
	var perched_on := riders.crossing.body_of(gull.perch_peer)
	gull.shoo(perched_on)
	_run(riders, 6.0)
	assert_eq(gull.state_name(), &"PERCH", "on another head")
	for peer: int in [1, 2, 3, 4]:
		var morale: float = riders.crossing.body_of(peer).meters.morale
		assert_eq(morale, 70.0, "player %d: +10 from the gull once, +5 from each bird" % peer)
