extends GutTest
## crossing "Beat lanes and sides": every rock, debris and flotsam beat names a lane, every shark
## pass a side; the old two-value form rides the line and a shark in it comes from the west.

const K := CrossingBeat.Kind


func test_the_old_form_round_trips_as_two_values() -> void:
	var beat := CrossingBeat.create(30.0, K.ROCK)
	assert_eq(beat.to_array(), [30.0, int(K.ROCK)])
	var back := CrossingBeat.from_array([30.0, int(K.ROCK)])
	assert_not_null(back)
	assert_eq(back.lane, 0, "an old-form rock rides the line")
	assert_eq(back.extra, 0)


func test_an_old_form_shark_comes_from_the_west() -> void:
	var back := CrossingBeat.from_array([12.0, int(K.SHARK_PASS)])
	assert_eq(back.side(), CrossingBeat.Side.WEST)


func test_the_four_value_form_round_trips() -> void:
	for beat: CrossingBeat in [
		CrossingBeat.create(20.0, K.DEBRIS, -3),
		CrossingBeat.create(40.0, K.FLOTSAM, 4, 2),
		CrossingBeat.create(25.0, K.SHARK_PASS, 0, CrossingBeat.Side.EAST),
		CrossingBeat.create(71.0, K.ROCK, 8),
	]:
		var back := CrossingBeat.from_array(beat.to_array())
		assert_not_null(back, str(beat.to_array()))
		assert_eq(back.to_array(), beat.to_array())
	assert_eq(CrossingBeat.from_array([25.0, int(K.SHARK_PASS), 0, 1]).side(), CrossingBeat.Side.EAST)


func test_malformed_beats_are_refused() -> void:
	assert_null(CrossingBeat.from_array([30.0, int(K.ROCK), 11, 0]), "a lane past 10")
	assert_null(CrossingBeat.from_array([30.0, int(K.ROCK), -11, 0]), "a lane past -10")
	assert_null(CrossingBeat.from_array([30.0, int(K.SHARK_PASS), 0, 2]), "a side other than 0 or 1")
	assert_null(CrossingBeat.from_array([30.0, int(K.FLOTSAM), 3, 7], 7), "a piece outside the table")
	assert_null(CrossingBeat.from_array([30.0, int(K.FLOTSAM), 3, -1]), "a negative piece")
	assert_null(CrossingBeat.from_array([30.0, int(K.ROCK), 2, 1]), "a rock with an extra")
	assert_null(CrossingBeat.from_array([30.0, int(K.SQUALL), 2, 0]), "a squall in a lane")
	assert_null(CrossingBeat.from_array([30.0, 99]), "an unknown kind")
	assert_null(CrossingBeat.from_array([30.0, int(K.ROCK), 2]), "three values")
	assert_null(CrossingBeat.from_array([30.0, int(K.ROCK), 2.5, 0]), "a fractional lane")
	assert_null(CrossingBeat.from_array("rock"))


func test_a_plan_checks_flotsam_against_the_tuning_table() -> void:
	var pieces: int = CrossingTuning.standard().flotsam_items.size()
	assert_not_null(CrossingPlan.from_array([60.0, [[40.0, int(K.FLOTSAM), 3, pieces - 1]]]))
	assert_null(CrossingPlan.from_array([60.0, [[40.0, int(K.FLOTSAM), 3, pieces]]]))


func test_solo_old_form_rock_rides_the_line_and_hits_as_before() -> void:
	var crossing := CrossingRig.make(self, &"raft", 1, 100.0, 60.0, [CrossingRig.beat(30.0, K.ROCK)])
	CrossingRig.run(crossing, 29.9)
	assert_eq(crossing.integrity.value, 100.0)
	CrossingRig.run(crossing, 0.2)
	assert_eq(crossing.integrity.value, 60.0, "the old-form rock was in lane 0 and the idle raft took it")


func test_the_standard_tuning_holds_every_new_number() -> void:
	var tuning := CrossingTuning.standard()
	assert_eq(tuning.hazard_lead_s, 5.0)
	assert_eq(tuning.shark_lead_s, 5.0)
	assert_eq(tuning.paddle_tiles_per_s, 1.5)
	assert_eq(tuning.paddle_crew_tiles_per_s, 2.25)
	assert_eq(tuning.pull_back_tiles_per_s, 0.5)
	assert_eq(tuning.max_offset_tiles, 6.0)
	assert_eq(tuning.rock_width_tiles, 2.0)
	assert_eq(tuning.debris_width_tiles, 1.0)
	assert_eq(tuning.vessel_width_tiles, 4.0)
	assert_eq(tuning.debris_hit, 5.0)
	assert_eq(tuning.leak_drain_per_s, 0.5)
	assert_eq(tuning.plug_hold_s, 2.0)
	assert_eq(tuning.max_leaks, 3)
	assert_eq(tuning.plank_repair, 10.0)
	assert_eq(tuning.rock_cut_health, 15.0)
	assert_eq(tuning.debris_cut_health, 5.0)
	assert_eq(tuning.grab_hold_s, 0.3)
	assert_eq(tuning.shoo_hold_s, 1.0)
	assert_eq([tuning.shoo_priority, tuning.pull_priority, tuning.grab_priority, tuning.plug_priority], [4, 3, 2, 1])
	assert_eq(tuning.squall_blow_s, 15.0)
	assert_eq(tuning.blow_paddle_factor, 0.5)
	assert_eq(tuning.pre_squall_window_s, 10.0)
	assert_eq(tuning.pre_squall_s, Vector2(4, 8))
	assert_eq(tuning.pre_squall_min_hit_s, 16.0)
	assert_eq([tuning.calm_start_s, tuning.first_beat_spread_s, tuning.target_gap_s, tuning.gap_jitter_s], [6.0, 3.0, 7.5, 1.5])
	assert_eq([tuning.max_gap_s, tuning.min_gap_s, tuning.rider_gap_factor, tuning.reef_before_end_s], [9.0, 3.0, 0.9, 4.0])
	assert_eq([tuning.reef_half_gap_tiles, tuning.reef_gap_lane_max, tuning.hazard_lane_max], [5, 3, 4])
	assert_eq(tuning.flotsam_lanes, Vector2i(2, 5))
	var coast: int = DataEnums.DistanceBand.COAST
	assert_eq([tuning.rock_weight[coast], tuning.debris_weight[coast], tuning.flotsam_weight[coast]], [0.12, 0.2, 0.68])
	assert_eq(tuning.flotsam_items.size(), tuning.flotsam_weights.size(), "one weight per piece")
	assert_true(tuning.flotsam_items.has(CrossingTuning.PLANK_ID))
	for id: StringName in tuning.flotsam_items:
		if id != CrossingTuning.PLANK_ID:
			assert_not_null(GameState.content.get_entry(&"items", id), "flotsam %s is an item" % id)
