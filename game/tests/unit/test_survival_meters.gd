extends GutTest
## survival-meters "Meter component": six meters 0-100, clamping and change signals. The energy
## API from player-movement keeps working.

const M := DataEnums.Meter
const ALL_METERS: Array[DataEnums.Meter] = [M.THIRST, M.HUNGER, M.HEAT, M.ENERGY, M.MORALE, M.HEALTH]

var meters: SurvivalMeters


func before_each() -> void:
	meters = SurvivalMeters.new()
	add_child_autofree(meters)


func test_fresh_player_is_full_and_cool() -> void:
	assert_eq(meters.thirst, 100.0)
	assert_eq(meters.hunger, 100.0)
	assert_eq(meters.energy, 100.0)
	assert_eq(meters.morale, 100.0)
	assert_eq(meters.health, 100.0)
	assert_eq(meters.heat, 0.0, "heat rises toward sunstroke, so it starts at 0")


func test_fresh_player_has_no_states() -> void:
	assert_false(meters.sunstroke)
	assert_false(meters.hallucinating)
	assert_false(meters.downed)
	assert_false(meters.dead)


func test_value_reads_each_meter_by_enum() -> void:
	meters.thirst = 11.0
	meters.hunger = 22.0
	meters.heat = 33.0
	meters.energy = 44.0
	meters.morale = 55.0
	meters.health = 66.0
	var expected: Array[float] = [11.0, 22.0, 33.0, 44.0, 55.0, 66.0]
	for i: int in ALL_METERS.size():
		assert_eq(meters.value(ALL_METERS[i]), expected[i], "meter %d" % ALL_METERS[i])


func test_every_meter_clamps_to_0_100() -> void:
	for meter: DataEnums.Meter in ALL_METERS:
		meters.set_value(meter, 250.0)
		assert_eq(meters.value(meter), 100.0, "meter %d clamps high" % meter)
		meters.set_value(meter, -5.0)
		assert_eq(meters.value(meter), 0.0, "meter %d clamps low" % meter)


func test_every_meter_emits_meter_changed_with_its_new_value() -> void:
	watch_signals(meters)
	meters.thirst = 40.0
	assert_signal_emitted_with_parameters(meters, "meter_changed", [M.THIRST, 40.0])
	meters.heat = 75.0
	assert_signal_emitted_with_parameters(meters, "meter_changed", [M.HEAT, 75.0])
	meters.health = 12.0
	assert_signal_emitted_with_parameters(meters, "meter_changed", [M.HEALTH, 12.0])


func test_meter_changed_is_not_emitted_when_nothing_changes() -> void:
	watch_signals(meters)
	meters.thirst = 100.0
	meters.heat = -1.0
	assert_signal_not_emitted(meters, "meter_changed")


func test_energy_also_emits_meter_changed() -> void:
	watch_signals(meters)
	meters.spend_energy(10.0)
	assert_signal_emitted_with_parameters(meters, "meter_changed", [M.ENERGY, 90.0])
	assert_signal_emitted_with_parameters(meters, "energy_changed", [90.0])


func test_uses_the_shipped_tuning_by_default() -> void:
	assert_not_null(meters.tuning)
	assert_eq(meters.tuning.resource_path, "res://resources/survival_tuning.tres")


func test_starts_with_full_energy() -> void:
	assert_eq(meters.energy, SurvivalMeters.MAX_ENERGY)
	assert_eq(SurvivalMeters.MAX_ENERGY, 100.0)


func test_spending_lowers_energy_and_returns_what_was_spent() -> void:
	var spent := meters.spend_energy(30.0)
	assert_eq(spent, 30.0)
	assert_eq(meters.energy, 70.0)


func test_energy_clamps_at_zero() -> void:
	meters.energy = 5.0
	var spent := meters.spend_energy(20.0)
	assert_eq(meters.energy, 0.0)
	assert_eq(spent, 5.0, "only what was there is spent")


func test_setting_energy_clamps_to_range() -> void:
	meters.energy = 500.0
	assert_eq(meters.energy, 100.0)
	meters.energy = -3.0
	assert_eq(meters.energy, 0.0)


func test_negative_spend_is_ignored() -> void:
	meters.energy = 40.0
	var spent := meters.spend_energy(-10.0)
	assert_eq(spent, 0.0)
	assert_eq(meters.energy, 40.0)


func test_emits_energy_changed_with_the_new_value() -> void:
	watch_signals(meters)
	meters.spend_energy(25.0)
	assert_signal_emitted_with_parameters(meters, "energy_changed", [75.0])


func test_does_not_emit_when_nothing_changes() -> void:
	meters.energy = 0.0
	watch_signals(meters)
	meters.spend_energy(10.0)
	meters.spend_energy(0.0)
	assert_signal_not_emitted(meters, "energy_changed")


func test_gain_restores_energy_up_to_max() -> void:
	meters.energy = 90.0
	meters.gain_energy(50.0)
	assert_eq(meters.energy, 100.0)
