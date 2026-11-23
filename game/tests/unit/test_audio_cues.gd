extends GutTest
## sound-pass design D5: the pure rules RunSounds plays by. Each reads values a peer already has and
## answers whether a cue plays or at what level; none of them touches the game. 1 player, offline.

var bank: SoundBank


func before_each() -> void:
	bank = load(SoundBank.STANDARD_PATH) as SoundBank


# --- low thirst (audio "Low-thirst cue") -----------------------------------------------------------

func test_low_thirst_plays_on_the_fall_to_the_step_and_not_again_below_it() -> void:
	var cue := ThresholdCue.new(25.0, 30.0)
	assert_false(cue.observe(26.0), "the first value only seeds")
	assert_true(cue.observe(25.0), "the fall to 25 plays")
	assert_false(cue.observe(10.0), "not again further down")
	assert_false(cue.observe(28.0), "not re-armed below 30")
	assert_false(cue.observe(25.0))
	assert_false(cue.observe(40.0), "a coconut to 40 re-arms it")
	assert_true(cue.observe(25.0), "the next fall plays again")


func test_low_thirst_seeded_low_waits_for_a_rise_above_the_rearm() -> void:
	var cue := ThresholdCue.new(25.0, 30.0)
	assert_false(cue.observe(20.0), "a joiner already thirsty is not warned")
	assert_false(cue.observe(12.0))
	assert_false(cue.observe(29.0))
	assert_false(cue.observe(25.0), "not armed until it has been above 30")
	assert_false(cue.observe(31.0))
	assert_true(cue.observe(24.0))


func test_low_thirst_reset_seeds_again() -> void:
	var cue := ThresholdCue.new(25.0, 30.0)
	cue.observe(50.0)
	cue.reset()
	assert_false(cue.observe(10.0), "a new body's first value only seeds")


# --- pick-up (audio "Pick-up cue") ------------------------------------------------------------------

func test_a_gain_plays_and_the_first_bag_only_seeds() -> void:
	var gain := InventoryGain.new()
	assert_false(gain.observe({&"driftwood": 2}), "a joiner's bag is seeded silently")
	assert_true(gain.observe({&"driftwood": 3}), "one more driftwood")
	assert_true(gain.observe({&"driftwood": 3, &"coconut": 1}), "a new item")


func test_losses_moves_and_spent_uses_do_not_play() -> void:
	var gain := InventoryGain.new()
	gain.observe({&"driftwood": 3, &"coconut": 1})
	assert_false(gain.observe({&"driftwood": 3, &"coconut": 1}), "the same bag (a use spent leaves counts as they are)")
	assert_false(gain.observe({&"driftwood": 1, &"coconut": 1}), "two used in a craft")
	assert_false(gain.observe({&"driftwood": 1}), "the coconut eaten")
	assert_true(gain.observe({&"driftwood": 0, &"rope": 1}), "a craft's output counts")


func test_counts_add_every_slot_of_an_id() -> void:
	var inventory := Inventory.new()
	inventory.slots[0].item_id = &"driftwood"
	inventory.slots[0].count = 4
	inventory.slots[1].item_id = &"knife"
	inventory.slots[1].count = 1
	inventory.slots[1].uses_left = 3
	inventory.slots[2].item_id = &"driftwood"
	inventory.slots[2].count = 2
	assert_eq(InventoryGain.counts(inventory), {&"driftwood": 6, &"knife": 1} as Dictionary[StringName, int])
	inventory.free()


# --- raft hits and loudhailer calls (audio "Raft hit and arrival", "Loudhailer") --------------------

func test_a_change_watch_reports_changes_after_the_first_value() -> void:
	var watch := ChangeWatch.new()
	assert_eq(watch.observe(7, 100.0), 0.0, "the first value of a vessel only seeds")
	assert_eq(watch.observe(7, 100.0), 0.0, "an equal resync is no change")
	assert_eq(watch.observe(7, 85.0), -15.0, "a rock takes 15")
	assert_eq(watch.observe(7, 90.0), 5.0, "a mend is a rise")
	assert_eq(watch.observe(8, 60.0), 0.0, "a new vessel (a board after a break) only seeds")


func test_a_change_watch_forgets_keys_no_longer_seen() -> void:
	var watch := ChangeWatch.new()
	watch.observe(1, 3.0)
	watch.observe(2, 5.0)
	watch.keep_only([2])
	assert_eq(watch.observe(1, 4.0), 0.0, "a forgotten boat seeds again")
	assert_eq(watch.observe(2, 6.0), 1.0, "a kept one goes on")
	watch.reset()
	assert_eq(watch.observe(2, 9.0), 0.0)


# --- the patrol motor (audio "The patrol motor swells…", "…follows the boat in sight") --------------

func test_the_horizon_warning_swells_from_low_to_high() -> void:
	var at_5: float = PatrolSwell.level(PatrolRoute.State.HORIZON, 5.0, 20.0, 99.0, bank)
	var at_15: float = PatrolSwell.level(PatrolRoute.State.HORIZON, 15.0, 20.0, 99.0, bank)
	assert_gt(at_15, at_5, "louder at 15 s than at 5 s")
	assert_almost_eq(PatrolSwell.level(PatrolRoute.State.HORIZON, 0.0, 20.0, 99.0, bank), db_to_linear(bank.motor_low_db), 0.0001)
	assert_almost_eq(PatrolSwell.level(PatrolRoute.State.HORIZON, 20.0, 20.0, 99.0, bank), db_to_linear(bank.motor_high_db), 0.0001)
	assert_almost_eq(linear_to_db(PatrolSwell.level(PatrolRoute.State.HORIZON, 10.0, 20.0, 0.0, bank)), (bank.motor_low_db + bank.motor_high_db) / 2.0, 0.01, "steady in dB: half way at half time")


func test_the_warning_length_is_the_boats_own() -> void:
	assert_almost_eq(PatrolSwell.level(PatrolRoute.State.HORIZON, 15.0, 30.0, 0.0, bank), PatrolSwell.level(PatrolRoute.State.HORIZON, 10.0, 20.0, 0.0, bank), 0.0001, "half way through a 30 s warning sounds like half way through a 20 s one")


func test_a_boat_in_sight_follows_its_distance() -> void:
	for state: int in [PatrolRoute.State.LAP, PatrolRoute.State.ALERT_LOCK, PatrolRoute.State.ALERT_SEARCH, PatrolRoute.State.CHASE]:
		assert_almost_eq(PatrolSwell.level(state, 0.0, 20.0, 2.0, bank), db_to_linear(bank.motor_high_db), 0.0001, "near: loudest")
		assert_almost_eq(PatrolSwell.level(state, 0.0, 20.0, bank.motor_far_tiles, bank), db_to_linear(bank.motor_far_db), 0.0001, "far level at the far distance")
		var mid: float = PatrolSwell.level(state, 0.0, 20.0, (bank.motor_near_tiles + bank.motor_far_tiles) / 2.0, bank)
		assert_between(mid, db_to_linear(bank.motor_far_db), db_to_linear(bank.motor_high_db))
		assert_eq(PatrolSwell.level(state, 0.0, 20.0, bank.motor_far_tiles * 2.0 + 1.0, bank), 0.0, "silent beyond twice the far distance")


func test_an_away_or_docked_boat_is_silent() -> void:
	assert_eq(PatrolSwell.level(PatrolRoute.State.AWAY, 5.0, 20.0, 0.0, bank), 0.0)
	assert_eq(PatrolSwell.level(PatrolRoute.State.DOCKED, 5.0, 20.0, 0.0, bank), 0.0)


func test_no_warning_length_is_silent_rather_than_a_division_by_zero() -> void:
	assert_eq(PatrolSwell.level(PatrolRoute.State.HORIZON, 5.0, 0.0, 0.0, bank), 0.0)


# --- ambience (audio "Ambience follows place, time and weather") ------------------------------------

func test_an_island_day_is_the_sea_alone() -> void:
	var levels: Dictionary[StringName, float] = RunAmbience.levels(false, DataEnums.DayPhase.DAY, false, bank)
	assert_eq(levels, {&"sea": bank.sea_island, &"wind": 0.0, &"night": 0.0} as Dictionary[StringName, float])


func test_an_island_night_adds_the_night() -> void:
	var levels: Dictionary[StringName, float] = RunAmbience.levels(false, DataEnums.DayPhase.NIGHT, false, bank)
	assert_eq(levels[&"night"], bank.night_level)
	assert_eq(levels[&"sea"], bank.sea_island)
	assert_eq(RunAmbience.levels(false, DataEnums.DayPhase.DUSK, false, bank)[&"night"], 0.0, "dusk is not night")


func test_a_crossing_is_louder_sea_and_wind_and_no_insects() -> void:
	var levels: Dictionary[StringName, float] = RunAmbience.levels(true, DataEnums.DayPhase.NIGHT, false, bank)
	assert_eq(levels, {&"sea": bank.sea_crossing, &"wind": bank.wind_crossing, &"night": 0.0} as Dictionary[StringName, float])


func test_a_squall_raises_the_wind_on_an_island_and_at_sea() -> void:
	assert_eq(RunAmbience.levels(false, DataEnums.DayPhase.DAY, true, bank)[&"wind"], bank.wind_squall)
	assert_eq(RunAmbience.levels(true, DataEnums.DayPhase.DAY, true, bank)[&"wind"], bank.wind_squall)


func test_a_squall_is_any_weather_the_bank_lists() -> void:
	assert_true(RunAmbience.is_squall(&"squall", bank))
	assert_false(RunAmbience.is_squall(&"calm", bank))
	assert_false(RunAmbience.is_squall(&"", bank))
