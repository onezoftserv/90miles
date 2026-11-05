extends GutTest
## player-movement: the energy-only SurvivalMeters component.

var meters: SurvivalMeters


func before_each() -> void:
	meters = SurvivalMeters.new()
	add_child_autofree(meters)


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
