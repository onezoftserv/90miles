extends GutTest
## island-stop, crossing "Raft maximum and fittings at sea", "Defensas at sea", "Toldo at sea",
## "Fittings ride with the raft" and "Vessel look on the crossing" (modified), with exactly 1 player,
## offline: a nailed raft enters at 90 of 120 and a plank stops at 120; the defensas take a quarter
## off rocks and debris, never off a squall or a shark; the toldo makes the deck shade, so a midday
## crossing brings no sunstroke; the result carries the maximum and fittings, a broken raft loses
## them, and the sturdiest raft keeps its own; the look reads the share of the maximum; and only a
## raft takes fittings.

const K := CrossingBeat.Kind
const CLAVAZON: StringName = &"raft_clavazon"
const DEFENSAS: StringName = &"raft_defensas"
const TOLDO: StringName = &"raft_toldo"
## 11:00 is five hours after the 6:00 dawn, at 30 s an hour.
const ELEVEN_S: float = 5.0 * DayClock.HOUR_S


func after_each() -> void:
	WeatherManager.stop()
	FixtureRoutes.take_out()


func _raft(at: float, top: float, fittings: Array[StringName]) -> RaftRecord:
	var record := RaftRecord.bare(at, top)
	record.fittings = fittings
	return record


func _east_edge(crossing: Crossing, body: PlayerBody) -> void:
	var deck := crossing.deck_rect()
	body.global_position = Vector2(deck.end.x - 1.0, deck.get_center().y)


# --- the maximum --------------------------------------------------------------------------------

func test_solo_launches_a_nailed_raft() -> void:
	var raft := _raft(90.0, 120.0, [CLAVAZON] as Array[StringName])
	var crossing := CrossingRig.make(self, &"raft", 1, raft.integrity, 60.0, [CrossingRig.beat(30.0, K.SQUALL)], raft)
	assert_eq(crossing.integrity.value, 90.0, "the crossing starts at 90")
	assert_eq(crossing.integrity.maximum, 120.0, "of 120")
	crossing.tie(1)
	CrossingRig.run(crossing, 31.0)
	assert_eq(crossing.integrity.value, 60.0, "a squall takes 30")
	assert_eq(crossing.rider_state(1), Crossing.Rider.TIED)


func test_a_plank_stops_at_the_maximum() -> void:
	var tuning := CrossingTuning.standard()
	var piece: int = tuning.flotsam_items.find(CrossingTuning.PLANK_ID)
	var raft := _raft(115.0, 120.0, [CLAVAZON] as Array[StringName])
	var crossing := CrossingRig.make(self, &"raft", 1, raft.integrity, 60.0, [CrossingBeat.create(20.0, K.FLOTSAM, 3, piece)], raft)
	var body := crossing.body_of(1)
	_east_edge(crossing, body)
	CrossingRig.run(crossing, 19.8)
	CrossingRig.hold(crossing, body, 0.5)
	CrossingRig.release(crossing, body)
	assert_true(crossing.taken.has(0), "the plank is lashed on")
	assert_eq(crossing.integrity.value, 120.0, "at 120 of 120, not 125")


func test_a_bare_raft_keeps_the_routes_maximum() -> void:
	var crossing := CrossingRig.make(self, &"raft", 1, 70.0, 60.0, [], RaftRecord.bare(70.0))
	assert_eq(crossing.integrity.maximum, 100.0)


func test_only_a_raft_takes_fittings() -> void:
	var raft := _raft(90.0, 120.0, [CLAVAZON, DEFENSAS, TOLDO] as Array[StringName])
	var swim := CrossingRig.make(self, &"binoculars_swim", 1, 0.0, 60.0, [], raft)
	assert_null(swim.fitted, "swimmers have no raft")
	assert_false(swim.integrity.has_integrity())
	FixtureRoutes.put_in()
	var board := CrossingRig.make(self, &"test_board", 1, 0.0, 60.0, [], raft)
	assert_null(board.fitted, "a board takes no fittings")
	var car := CrossingRig.make(self, &"test_car", 1, 0.0, 60.0, [], raft)
	assert_null(car.fitted, "the car takes no fittings")
	assert_eq(car.integrity.maximum, 160.0, "the car keeps its own 160")


# --- the defensas -------------------------------------------------------------------------------

func test_solo_rock_on_the_defensas() -> void:
	var raft := _raft(100.0, 100.0, [DEFENSAS] as Array[StringName])
	var crossing := CrossingRig.make(self, &"raft", 1, 100.0, 60.0, [CrossingRig.beat(30.0, K.ROCK)], raft)
	CrossingRig.run(crossing, 31.0)
	assert_eq(crossing.integrity.value, 70.0, "three quarters of 40")


func test_a_rock_on_a_bare_raft_is_unchanged() -> void:
	var crossing := CrossingRig.make(self, &"raft", 1, 100.0, 60.0, [CrossingRig.beat(30.0, K.ROCK)], RaftRecord.bare(100.0))
	CrossingRig.run(crossing, 31.0)
	assert_eq(crossing.integrity.value, 60.0)


func test_a_squall_is_unchanged() -> void:
	var raft := _raft(100.0, 100.0, [DEFENSAS] as Array[StringName])
	var crossing := CrossingRig.make(self, &"raft", 1, 100.0, 60.0, [CrossingRig.beat(30.0, K.SQUALL)], raft)
	crossing.tie(1)
	CrossingRig.run(crossing, 31.0)
	assert_eq(crossing.integrity.value, 70.0)


func test_debris_on_the_defensas() -> void:
	var raft := _raft(100.0, 100.0, [DEFENSAS] as Array[StringName])
	var crossing := CrossingRig.make(self, &"raft", 1, 100.0, 60.0, [CrossingBeat.create(20.0, K.DEBRIS, 1)], raft)
	CrossingRig.run(crossing, 20.0)
	assert_almost_eq(crossing.integrity.value, 96.25, 0.0001, "three quarters of 5")
	assert_eq(crossing.leaks.count_on(0), 1, "the leak still opens")


func test_a_shark_hit_is_unchanged() -> void:
	var raft := _raft(100.0, 100.0, [DEFENSAS] as Array[StringName])
	var crossing := CrossingRig.make(self, &"raft", 1, 100.0, 60.0, [], raft)
	crossing.hit_vessel(crossing.tuning.shark_hit, true)
	assert_eq(crossing.integrity.value, 100.0 - crossing.tuning.shark_hit)


# --- the toldo ----------------------------------------------------------------------------------

# A solo 75 s crossing launched at 11:00 in calm weather, the player at thirst 80 and heat 0.
func _midday(raft: RaftRecord) -> Crossing:
	WeatherManager.sky.start_at(ELEVEN_S)
	var session := CrossingRig.make_session(self, 1)
	var body := session.body(1)
	body.climate = WeatherManager.sky.climate
	body.meters.thirst = 80.0
	body.meters.heat = 0.0
	return CrossingRig.launch_on(session, &"raft", [1] as Array[int], 100.0, 75.0, [], raft)


func test_solo_midday_crossing_under_the_toldo() -> void:
	var crossing := _midday(_raft(100.0, 100.0, [TOLDO] as Array[StringName]))
	var body := crossing.body_of(1)
	assert_true(WeatherManager.sky.climate.midday, "11:00 is midday")
	assert_true(crossing.sea.is_shaded(body.cell()), "the deck is shade")
	var sunstroke: bool = false
	for i: int in 750:
		CrossingRig.run(crossing, 0.1)
		body._tick_meters(0.1)
		sunstroke = sunstroke or body.meters.sunstroke
	assert_true(crossing.finished)
	assert_eq(crossing.rider_state(1), Crossing.Rider.ABOARD, "aboard the whole crossing")
	assert_almost_eq(body.meters.heat, 0.0, 0.0001, "no heat under the toldo")
	assert_almost_eq(body.meters.thirst, 72.5, 0.01)
	assert_false(sunstroke)


func test_the_same_crossing_without_the_toldo() -> void:
	var crossing := _midday(RaftRecord.bare(100.0))
	var body := crossing.body_of(1)
	assert_false(crossing.sea.is_shaded(body.cell()))
	var sunstroke: bool = false
	for i: int in 750:
		CrossingRig.run(crossing, 0.1)
		body._tick_meters(0.1)
		sunstroke = sunstroke or body.meters.sunstroke
	assert_almost_eq(body.meters.thirst, 65.0, 0.01)
	assert_true(sunstroke, "heat reached 100 before the end")


# --- the result ---------------------------------------------------------------------------------

func test_the_result_carries_the_maximum_and_fittings() -> void:
	var raft := _raft(100.0, 100.0, [TOLDO] as Array[StringName])
	var crossing := CrossingRig.make(self, &"raft", 1, 100.0, 20.0, [CrossingRig.beat(10.0, K.SQUALL)], raft)
	crossing.tie(1)
	CrossingRig.run(crossing, 20.0)
	assert_true(crossing.finished)
	var result := crossing.result
	assert_eq(result.integrity, 70.0)
	assert_eq(result.maximum, 100.0)
	assert_eq(result.fittings, [TOLDO] as Array[StringName])
	var back := CrossingResult.from_dict(bytes_to_var(var_to_bytes(result.to_dict())))
	assert_eq(back.maximum, 100.0, "the maximum travels")
	assert_eq(back.fittings, [TOLDO] as Array[StringName], "the fittings travel")
	var beached := back.raft_record()
	assert_eq([beached.integrity, beached.maximum, beached.fittings], [70.0, 100.0, [TOLDO] as Array[StringName]])


func test_a_broken_raft_loses_its_fittings() -> void:
	var raft := _raft(30.0, 120.0, [CLAVAZON] as Array[StringName])
	var crossing := CrossingRig.make(self, &"raft", 1, 30.0, 40.0, [CrossingRig.beat(10.0, K.SQUALL)], raft)
	CrossingRig.run(crossing, 40.0)
	assert_true(crossing.result.broken)
	assert_eq(crossing.result.fittings, [] as Array[StringName], "no fittings on a broken raft")
	assert_null(crossing.result.raft_record(), "nothing is beached")


func test_the_sturdiest_raft_keeps_its_own_fittings() -> void:
	var travel := IslandTravel.new()
	autofree(travel)
	var toldo := CrossingResult.new()
	toldo.route_id = &"raft"
	toldo.integrity = 80.0
	toldo.maximum = 100.0
	toldo.fittings = [TOLDO] as Array[StringName]
	var nailed := CrossingResult.new()
	nailed.route_id = &"raft"
	nailed.integrity = 60.0
	nailed.maximum = 120.0
	nailed.fittings = [CLAVAZON] as Array[StringName]
	travel._results = [nailed, toldo] as Array[CrossingResult]
	var beached := travel._beached_raft()
	assert_eq(beached.integrity, 80.0)
	assert_eq(beached.maximum, 100.0)
	assert_eq(beached.fittings, [TOLDO] as Array[StringName], "the toldo and no clavazón")


func test_a_forged_record_is_refused_or_cleaned() -> void:
	assert_null(RaftRecord.from_dict(3.0))
	assert_null(RaftRecord.from_dict({"integrity": NAN, "max": 100.0, "fittings": []}))
	assert_null(RaftRecord.from_dict({"integrity": 50.0, "max": 0.0, "fittings": []}))
	assert_null(RaftRecord.from_dict({"integrity": 50.0, "max": 100.0}))
	var cleaned := RaftRecord.from_dict({"integrity": 500.0, "max": 120.0, "fittings": ["raft_toldo", "raft_toldo", "raft_mend", "no_such", 7]})
	assert_eq(cleaned.integrity, 120.0, "clamped to the maximum")
	assert_eq(cleaned.fittings, [TOLDO] as Array[StringName], "only known fittings, each once; a mend is no fitting")


# --- the look -----------------------------------------------------------------------------------

func test_the_look_follows_a_fitted_rafts_maximum() -> void:
	var bare := CrossingRig.make(self, &"raft", 1, 70.0, 60.0, [], RaftRecord.bare(70.0))
	var nailed := CrossingRig.make(self, &"raft", 1, 70.0, 60.0, [], _raft(70.0, 120.0, [CLAVAZON] as Array[StringName]))
	await wait_frames(2)
	assert_eq((bare.get_node("Deck") as CrossingDeck).frame_name, StructureArt.RAFT_WHOLE, "70 of 100 is whole")
	assert_eq((nailed.get_node("Deck") as CrossingDeck).frame_name, StructureArt.RAFT_WORN, "70 of 120 is worn")


func test_the_deck_draws_the_fittings() -> void:
	var raft := _raft(90.0, 120.0, [CLAVAZON, DEFENSAS, TOLDO] as Array[StringName])
	var crossing := CrossingRig.make(self, &"raft", 1, 90.0, 60.0, [], raft)
	await wait_frames(2)
	var deck := crossing.get_node("Deck") as CrossingDeck
	var fittings := RaftFittingsLook.of(deck)
	assert_true(fittings.visible)
	assert_eq(fittings.shown().size(), 3, "nails, tubes and toldo")
	var bare := CrossingRig.make(self, &"raft", 1, 90.0, 60.0, [], RaftRecord.bare(90.0))
	await wait_frames(2)
	assert_false(RaftFittingsLook.of(bare.get_node("Deck") as CrossingDeck).visible, "a bare raft draws none")


func test_drawing_the_fittings_changes_nothing_at_sea() -> void:
	var beats: Array[RefCounted] = [CrossingRig.beat(10.0, K.ROCK), CrossingRig.beat(20.0, K.SQUALL)]
	var raft := _raft(100.0, 120.0, [CLAVAZON, DEFENSAS, TOLDO] as Array[StringName])
	var drawn := CrossingRig.make(self, &"raft", 1, 100.0, 30.0, beats, raft)
	var undrawn := CrossingRig.make(self, &"raft", 1, 100.0, 30.0, beats, raft)
	undrawn.get_node("Deck").free()
	drawn.tie(1)
	undrawn.tie(1)
	CrossingRig.run(drawn, 30.0)
	CrossingRig.run(undrawn, 30.0)
	assert_eq(drawn.integrity.value, undrawn.integrity.value)
	assert_eq(drawn.integrity.value, 40.0, "100 - 30 (rock on the defensas) - 30 (squall)")
