extends GutTest
## survival-meters: the shipped tuning holds the spec's numbers, one test per number. The numbers
## are provisional (openspec change survival-meters, proposal.md): when the playtest retunes one,
## change it here, in the spec and in docs/GAME_DESIGN.md §4 together.

const TUNING_PATH := "res://resources/survival_tuning.tres"
## Per-minute rates are stored per real second.
const PER_MIN: float = 1.0 / 60.0

var tuning: SurvivalTuning


func before_all() -> void:
	tuning = load(TUNING_PATH) as SurvivalTuning


func test_tuning_file_loads_as_survival_tuning() -> void:
	assert_not_null(tuning, "%s is a SurvivalTuning" % TUNING_PATH)


func test_thirst_drains_6_per_min_at_rest() -> void:
	assert_almost_eq(tuning.thirst_per_s, 6.0 * PER_MIN, 1e-6)


func test_thirst_doubles_in_direct_sun() -> void:
	assert_eq(tuning.thirst_sun_factor, 2.0)


func test_thirst_triples_while_swimming() -> void:
	assert_eq(tuning.thirst_swim_factor, 3.0)


func test_thirst_halves_at_night() -> void:
	assert_eq(tuning.thirst_night_factor, 0.5)


func test_empty_thirst_drains_2_health_per_s() -> void:
	assert_eq(tuning.dry_health_per_s, 2.0)


func test_hunger_drains_3_per_min() -> void:
	assert_almost_eq(tuning.hunger_per_s, 3.0 * PER_MIN, 1e-6)


func test_hunger_doubles_while_crafting_or_swimming() -> void:
	assert_eq(tuning.hunger_work_factor, 2.0)


func test_empty_hunger_caps_energy_at_50() -> void:
	assert_eq(tuning.starving_energy_cap, 50.0)


func test_heat_rises_45_per_min_in_midday_sun() -> void:
	assert_almost_eq(tuning.heat_rise_per_s, 45.0 * PER_MIN, 1e-6)


func test_heat_falls_45_per_min_out_of_the_midday_sun() -> void:
	assert_almost_eq(tuning.heat_fall_per_s, 45.0 * PER_MIN, 1e-6)


func test_sunstroke_starts_at_heat_100() -> void:
	assert_eq(tuning.sunstroke_at, 100.0)


func test_sunstroke_ends_below_heat_60() -> void:
	assert_eq(tuning.sunstroke_ends_below, 60.0)


func test_sunstroke_cuts_speed_by_40_percent() -> void:
	assert_almost_eq(tuning.sunstroke_speed_factor, 0.6, 1e-6)


func test_a_meal_gives_10_energy() -> void:
	assert_eq(tuning.meal_energy, 10.0)


func test_a_night_of_sleep_gives_50_energy() -> void:
	assert_eq(tuning.sleep_energy, 50.0)


func test_morale_drains_5_per_min_alone_at_night() -> void:
	assert_almost_eq(tuning.morale_alone_night_per_s, 5.0 * PER_MIN, 1e-6)


func test_morale_restores_2_per_min_with_company() -> void:
	assert_almost_eq(tuning.morale_company_per_s, 2.0 * PER_MIN, 1e-6)


func test_company_means_a_teammate_within_5_tiles() -> void:
	assert_eq(tuning.company_radius_tiles, 5.0)


func test_an_allys_death_costs_30_morale() -> void:
	assert_eq(tuning.morale_ally_died, -30.0)


func test_a_squall_costs_10_morale() -> void:
	assert_eq(tuning.morale_squall, -10.0)


func test_a_fire_lit_gives_5_morale() -> void:
	assert_eq(tuning.morale_fire_lit, 5.0)


func test_a_song_gives_15_morale() -> void:
	assert_eq(tuning.morale_song, 15.0)


func test_a_found_text_gives_10_morale() -> void:
	assert_eq(tuning.morale_text_read, 10.0)


func test_hallucinations_start_below_morale_20() -> void:
	assert_eq(tuning.hallucinate_below, 20.0)


func test_downed_lasts_90_s() -> void:
	assert_eq(tuning.downed_s, 90.0)


func test_revive_stands_up_at_30_health() -> void:
	assert_eq(tuning.revive_health, 30.0)


func test_solo_last_stand_is_0_s_before_downed_timer_bonuses() -> void:
	assert_eq(tuning.solo_last_stand_s, 0.0)
