extends GutTest
## damage-feedback design D8: every number of the hit, drain and change cues is data in
## hurt_cue_tuning.tres, and the float colours stay equal to the HUD bars' fill colours.

const METERS_HUD: PackedScene = preload("res://scenes/ui/meters_hud.tscn")

var tuning: HurtCueTuning


func before_each() -> void:
	tuning = HurtCues.tuning()


func test_the_tuning_loads_from_its_resource() -> void:
	assert_not_null(tuning)
	assert_eq(tuning.resource_path, HurtCues.TUNING_PATH)


func test_the_watch_numbers() -> void:
	assert_eq(tuning.change_margin, 3.0, "a change at least 3 past the steady one is at once")
	assert_eq(tuning.steady_forget_s, 1.0)


func test_the_body_blink() -> void:
	assert_eq(tuning.blink_s, 0.6)
	assert_eq(tuning.blink_hz, 10.0)


func test_the_edge_flash() -> void:
	assert_eq(tuning.flash_s, 0.4)
	assert_eq(tuning.flash_floor, 0.5, "the smallest hit is still plain")
	assert_eq(tuning.big_hit, 25.0)
	assert_eq(tuning.flash_alpha, 0.45)
	assert_almost_eq(tuning.flash_min_gap_s, 0.33, 0.0001, "at most three flashes a second")
	assert_eq(tuning.edge_px, 24.0)


func test_the_bar_slices_shake_and_glow() -> void:
	assert_eq(tuning.loss_hold_s, 0.4)
	assert_eq(tuning.loss_drain_s, 0.5)
	assert_eq(tuning.shake_px, 1.0)
	assert_eq(tuning.shake_s, 0.2)
	assert_eq(tuning.glow_linger_s, 1.0)
	assert_eq(tuning.gain_hold_s, 0.6)
	assert_eq(tuning.gain_fade_s, 0.4)


func test_the_floats() -> void:
	assert_eq(tuning.float_s, 1.0)
	assert_eq(tuning.float_rise_px, 12.0)
	assert_eq(tuning.float_stack_px, 9.0)


func test_float_colours_match_the_bars() -> void:
	var hud := METERS_HUD.instantiate() as MetersHud
	add_child_autofree(hud)
	for bar: MeterBar in hud.bars():
		assert_true(tuning.meter_colors.has(bar.meter), "a colour for %s" % bar.label_text)
		assert_eq(tuning.meter_colors.get(bar.meter), bar.fill_color, "%s's colour" % bar.label_text)
