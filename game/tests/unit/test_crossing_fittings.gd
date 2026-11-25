extends GutTest
## island-stop crossing "Raft maximum and fittings at sea", "Defensas at sea", "Toldo at sea", "Vessel
## look on the crossing" (a fitted raft's share) and the crossing's half of "Fittings ride with the
## raft", with exactly 1 player, offline, on hand-written plans:
## - a nailed raft sails at 90 of 120 and a plank stops at 120;
## - the defensas take three quarters of a rock or a debris, never of a squall;
## - the toldo keeps a midday rider's heat at 0 and halves their thirst;
## - only a raft takes fittings;
## - the result, the snapshot and a joiner's restored crossing carry the maximum and the fittings.

const K := CrossingBeat.Kind
const CLAVAZON: StringName = &"raft_clavazon"
const DEFENSAS: StringName = &"raft_defensas"
const TOLDO: StringName = &"raft_toldo"
## 11:00 on the clock, which reads 06:00 at dawn: midday.
const ELEVEN_S: float = 150.0


func before_each() -> void:
	WeatherManager.stop()
	WeatherManager.sky.start_at(0.0)


func after_each() -> void:
	WeatherManager.stop()
	FixtureRoutes.take_out()


func _fit(ids: Array) -> Array[StringName]:
	var fitted: Array[StringName] = []
	fitted.assign(ids)
	return fitted


func _east_edge(crossing: Crossing, body: PlayerBody) -> void:
	var deck := crossing.deck_rect()
	body.global_position = Vector2(deck.end.x - 1.0, deck.get_center().y)


func _plank_index() -> int:
	return CrossingTuning.standard().flotsam_items.find(CrossingTuning.PLANK_ID)


# The rider aboard for `seconds` with the meters ticking, as the host's physics frame ticks them.
func _ride_with_meters(crossing: Crossing, seconds: float) -> void:
	var body := crossing.body_of(1)
	for i: int in roundi(seconds / CrossingRig.STEP_S):
		crossing.advance(CrossingRig.STEP_S)
		body.advance(CrossingRig.STEP_S)
		body._tick_meters(CrossingRig.STEP_S)


# A 75 s midday crossing in calm weather (heat gain ×2) for a rider at thirst 80 and heat 0.
func _midday_crossing(fitted: Array[StringName]) -> PlayerBody:
	WeatherManager.sky.start_at(ELEVEN_S)
	var crossing := CrossingRig.make(self, &"raft", 1, 100.0, 75.0, [], fitted)
	var body := crossing.body_of(1)
	body.climate = WeatherManager.sky.climate
	body.meters.set_value(DataEnums.Meter.THIRST, 80.0)
	body.meters.set_value(DataEnums.Meter.HEAT, 0.0)
	assert_true(body.climate.midday, "11:00 is midday")
	_ride_with_meters(crossing, 75.0)
	return body


func test_solo_launches_a_nailed_raft() -> void:
	var crossing := CrossingRig.make(self, &"raft", 1, 90.0, 60.0, [CrossingRig.beat(10.0, K.SQUALL)], _fit([CLAVAZON]))
	assert_eq(crossing.fittings, _fit([CLAVAZON]))
	assert_eq(crossing.integrity.value, 90.0)
	assert_eq(crossing.integrity.maximum, 120.0, "100 and the clavazón's 20")
	crossing.tie(1)
	CrossingRig.run(crossing, 11.0)
	assert_eq(crossing.integrity.value, 60.0, "a tied squall takes its 30")
	assert_eq(crossing.integrity.maximum, 120.0)


func test_a_plank_stops_at_the_maximum() -> void:
	var beats: Array[RefCounted] = [CrossingBeat.create(20.0, K.FLOTSAM, 3, _plank_index())]
	var crossing := CrossingRig.make(self, &"raft", 1, 115.0, 60.0, beats, _fit([CLAVAZON]))
	var body := crossing.body_of(1)
	_east_edge(crossing, body)
	CrossingRig.run(crossing, 19.8)
	CrossingRig.hold(crossing, body, 0.5)
	CrossingRig.release(crossing, body)
	assert_eq(crossing.integrity.value, 120.0, "115 + 10, no higher than 120")


func test_the_look_follows_a_fitted_rafts_maximum() -> void:
	var bare := CrossingRig.make(self, &"raft", 1, 70.0, 60.0)
	var nailed := CrossingRig.make(self, &"raft", 1, 70.0, 60.0, [], _fit([CLAVAZON]))
	assert_eq(StructureArt.vessel_frame(bare.integrity.value, bare.integrity.maximum), StructureArt.RAFT_WHOLE, "70 of 100")
	assert_eq(StructureArt.vessel_frame(nailed.integrity.value, nailed.integrity.maximum), StructureArt.RAFT_WORN, "70 of 120")
	await wait_process_frames(2)
	var deck := nailed.get_node_or_null(^"Deck") as Sprite2D
	assert_not_null(deck)
	if deck != null:
		assert_eq(deck.get(&"frame_name"), StructureArt.RAFT_WORN, "the deck is drawn worn")


func test_solo_rock_on_the_defensas() -> void:
	var crossing := CrossingRig.make(self, &"raft", 1, 100.0, 60.0, [CrossingBeat.create(30.0, K.ROCK, 0)], _fit([DEFENSAS]))
	assert_eq(crossing.hazard_factor(), 0.75)
	CrossingRig.run(crossing, 30.0)
	assert_eq(crossing.integrity.value, 70.0, "three quarters of 40")


func test_a_squall_is_unchanged_on_the_defensas() -> void:
	var crossing := CrossingRig.make(self, &"raft", 1, 100.0, 60.0, [CrossingRig.beat(10.0, K.SQUALL)], _fit([DEFENSAS]))
	crossing.tie(1)
	CrossingRig.run(crossing, 11.0)
	assert_eq(crossing.integrity.value, 70.0)


func test_debris_on_the_defensas() -> void:
	var crossing := CrossingRig.make(self, &"raft", 1, 100.0, 60.0, [CrossingBeat.create(20.0, K.DEBRIS, 1)], _fit([DEFENSAS]))
	CrossingRig.run(crossing, 20.0)
	assert_eq(crossing.integrity.value, 96.25, "three quarters of 5")
	assert_eq(crossing.leaks.count_on(0), 1, "the leak still opens")


func test_a_bare_raft_takes_the_whole_rock() -> void:
	var crossing := CrossingRig.make(self, &"raft", 1, 100.0, 60.0, [CrossingBeat.create(30.0, K.ROCK, 0)])
	assert_eq(crossing.hazard_factor(), 1.0)
	CrossingRig.run(crossing, 30.0)
	assert_eq(crossing.integrity.value, 60.0)


func test_solo_midday_crossing_under_the_toldo() -> void:
	var body := _midday_crossing(_fit([TOLDO]))
	assert_almost_eq(body.meters.heat, 0.0, 0.001, "heat stays at 0 in the shade")
	assert_almost_eq(body.meters.thirst, 72.5, 0.05, "6/min with no sun factor over 75 s")
	assert_false(body.meters.sunstroke)


func test_the_same_crossing_without_the_toldo() -> void:
	var body := _midday_crossing(_fit([]))
	assert_almost_eq(body.meters.thirst, 65.0, 0.05, "twice as fast in the sun")
	assert_true(body.meters.sunstroke, "heat reached 100 before the end")


func test_the_toldo_shades_only_the_deck() -> void:
	var crossing := CrossingRig.make(self, &"raft", 1, 100.0, 60.0, [], _fit([TOLDO]))
	assert_true(crossing.deck_shaded())
	var cell := Vector2i((crossing.deck_center() / Crossing.TILE_PX).floor())
	assert_true(crossing.sea.is_shaded(cell), "the deck's cells")
	assert_false(crossing.sea.is_shaded(cell + Vector2i(0, 4)), "not the sea round it")


func test_a_sunk_toldo_shades_nothing() -> void:
	var crossing := CrossingRig.make(self, &"raft", 1, 30.0, 60.0, [CrossingBeat.create(20.0, K.ROCK, 0)], _fit([TOLDO]))
	CrossingRig.run(crossing, 20.0)
	assert_true(crossing.integrity.broken)
	var cell := Vector2i((crossing.deck_center() / Crossing.TILE_PX).floor())
	assert_false(crossing.sea.is_shaded(cell))
	assert_false(crossing.deck_shaded())


func test_only_a_raft_takes_fittings() -> void:
	FixtureRoutes.put_in()
	var board := CrossingRig.make(self, &"test_board", 1, 0.0, 60.0, [], _fit([CLAVAZON, DEFENSAS, TOLDO]))
	assert_eq(board.fittings, _fit([]), "a board takes none")
	assert_eq(board.hazard_factor(), 1.0)
	var car := CrossingRig.make(self, &"test_car", 1, 160.0, 60.0, [], _fit([CLAVAZON]))
	assert_eq(car.fittings, _fit([]), "nor the car")
	assert_eq(car.integrity.maximum, 160.0)
	var swim := CrossingRig.make(self, &"binoculars_swim", 1, 0.0, 60.0, [], _fit([TOLDO]))
	assert_eq(swim.fittings, _fit([]), "nor swimmers")


func test_unknown_fittings_are_dropped() -> void:
	var crossing := CrossingRig.make(self, &"raft", 1, 100.0, 60.0, [], _fit([&"raft_mend", &"nonsense", CLAVAZON, CLAVAZON]))
	assert_eq(crossing.fittings, _fit([CLAVAZON]), "only fittings, each once")


func test_the_result_carries_the_maximum_and_the_fittings() -> void:
	var crossing := CrossingRig.make(self, &"raft", 1, 90.0, 10.0, [], _fit([CLAVAZON, TOLDO]))
	CrossingRig.run(crossing, 10.0)
	assert_true(crossing.finished)
	assert_eq(crossing.result.maximum, 120.0)
	assert_eq(crossing.result.fittings, _fit([CLAVAZON, TOLDO]))
	var copy := CrossingResult.from_dict(crossing.result.to_dict())
	assert_not_null(copy)
	if copy != null:
		assert_eq(copy.maximum, 120.0)
		assert_eq(copy.fittings, _fit([CLAVAZON, TOLDO]), "and it travels")


func test_an_older_result_still_reads() -> void:
	var data := {"route_id": "raft", "integrity": 70.0, "broken": false, "drift": 0.0, "riders": {}}
	var read := CrossingResult.from_dict(data)
	assert_not_null(read)
	if read != null:
		assert_eq(read.fittings, _fit([]))
		assert_eq(read.maximum, 0.0)


func test_a_joiner_restores_the_fittings_from_the_snapshot() -> void:
	var crossing := CrossingRig.make(self, &"raft", 1, 90.0, 60.0, [], _fit([CLAVAZON, TOLDO]))
	CrossingRig.run(crossing, 5.0)
	var data := CrossingSnapshot.of(crossing).to_dict()
	assert_eq(data.get("fittings"), ["raft_clavazon", "raft_toldo"], "plain strings")
	var snapshot := CrossingSnapshot.from_dict(data)
	assert_not_null(snapshot)
	if snapshot == null:
		return
	var joiner := CrossingRig.make_session(self, 1)
	var restored := Crossing.restore(joiner, snapshot)
	assert_not_null(restored)
	if restored == null:
		return
	assert_eq(restored.fittings, _fit([CLAVAZON, TOLDO]))
	assert_eq(restored.integrity.maximum, 120.0)
	assert_eq(restored.integrity.value, 90.0)
	assert_true(restored.deck_shaded(), "the joiner's deck is shaded too")


func test_a_snapshot_without_fittings_is_refused() -> void:
	var crossing := CrossingRig.make(self, &"raft", 1, 90.0, 60.0)
	var data := CrossingSnapshot.of(crossing).to_dict()
	data.erase("fittings")
	assert_null(CrossingSnapshot.from_dict(data))
	data["fittings"] = "raft_toldo"
	assert_null(CrossingSnapshot.from_dict(data), "a list, not a string")
