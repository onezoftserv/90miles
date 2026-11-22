extends GutTest
## survival-meters "HUD bars": six Spanish-labelled bars in the committed pixel font, Salud first,
## following one SurvivalMeters node, and the sunstroke blur for that player only; ui-shell "HUD
## layout" and "Readable HUD and menu text" (hud-window-kit design D4): each row a label column, a
## 40x7 bar box at a fixed x and the value, the label stepping orange and alert red and never pulsing,
## the window inside (4,4) to (136,90).

const HUD_SCENE := "res://scenes/ui/meters_hud.tscn"
const FONT_PATH := "res://assets/fonts/PressStart2P-Regular.ttf"
const M := DataEnums.Meter
const ORDER: Array[DataEnums.Meter] = [M.HEALTH, M.THIRST, M.HUNGER, M.HEAT, M.ENERGY, M.MORALE]
const LABELS: Array[String] = ["Salud", "Sed", "Hambre", "Calor", "Energía", "Ánimo"]
const RAMPS: Array[String] = ["health", "thirst", "hunger", "heat", "energy", "morale"]
const WINDOW_BUDGET: Rect2 = Rect2(4.0, 4.0, 132.0, 86.0)

var hud: MetersHud


func before_each() -> void:
	var packed := load(HUD_SCENE) as PackedScene
	hud = packed.instantiate() as MetersHud
	add_child_autofree(hud)


func _meters() -> SurvivalMeters:
	var meters := SurvivalMeters.new()
	add_child_autofree(meters)
	return meters


func test_six_bars_in_order_with_spanish_labels() -> void:
	var bars := hud.bars()
	assert_eq(bars.size(), 6)
	for i: int in bars.size():
		assert_eq(bars[i].meter, ORDER[i], "bar %d meter" % i)
		assert_eq(bars[i].label.text, LABELS[i], "bar %d label" % i)


func test_labels_use_the_committed_pixel_font_at_8_px() -> void:
	for bar: MeterBar in hud.bars():
		var font := bar.label.get_theme_font(&"font")
		assert_not_null(font)
		if font != null:
			assert_eq(font.resource_path, FONT_PATH, bar.label.text)
		assert_eq(bar.label.get_theme_font_size(&"font_size"), 8, bar.label.text)


func test_bars_run_from_0_to_100() -> void:
	for bar: MeterBar in hud.bars():
		assert_eq(bar.bar.min_value, 0.0)
		assert_eq(bar.bar.max_value, 100.0)


func test_bars_follow_the_meters() -> void:
	var meters := _meters()
	hud.bind(meters)
	assert_eq(hud.bar_for(M.THIRST).bar.value, 100.0)
	meters.thirst = 40.0
	assert_eq(hud.bar_for(M.THIRST).bar.value, 40.0)


func test_heat_fills_up_as_it_rises() -> void:
	var meters := _meters()
	hud.bind(meters)
	assert_eq(hud.bar_for(M.HEAT).fill_ratio(), 0.0)
	meters.heat = 75.0
	assert_eq(hud.bar_for(M.HEAT).fill_ratio(), 0.75)


func test_binding_shows_the_current_values() -> void:
	var meters := _meters()
	meters.morale = 12.0
	meters.energy = 64.0
	hud.bind(meters)
	assert_eq(hud.bar_for(M.MORALE).bar.value, 12.0)
	assert_eq(hud.bar_for(M.ENERGY).bar.value, 64.0)


func test_client_shows_the_host_value_set_on_its_node() -> void:
	# A client never ticks its meters; the synchronizer writes the host's values straight in.
	var meters := _meters()
	hud.bind(meters)
	meters.set_value(M.THIRST, 40.0)
	assert_eq(hud.bar_for(M.THIRST).bar.value, 40.0)


func test_only_the_bound_players_sunstroke_blurs_the_screen() -> void:
	var player_a := _meters()
	var teammate_b := _meters()
	hud.bind(player_a)
	assert_false(hud.blurred())
	teammate_b.sunstroke = true
	assert_false(hud.blurred(), "B's sunstroke is not on A's screen")
	player_a.sunstroke = true
	assert_true(hud.blurred())
	player_a.sunstroke = false
	assert_false(hud.blurred())


func test_binding_a_player_already_in_sunstroke_blurs_at_once() -> void:
	var meters := _meters()
	meters.sunstroke = true
	hud.bind(meters)
	assert_true(hud.blurred())


func test_rebinding_stops_following_the_old_node() -> void:
	var old := _meters()
	var current := _meters()
	hud.bind(old)
	hud.bind(current)
	old.thirst = 10.0
	old.sunstroke = true
	assert_eq(hud.bar_for(M.THIRST).bar.value, 100.0)
	assert_false(hud.blurred())


func test_panel_fits_in_the_top_left_corner_of_640x360() -> void:
	await wait_process_frames(2)
	var rect := hud.panel_rect()
	assert_gte(rect.position.x, 0.0)
	assert_gte(rect.position.y, 0.0)
	assert_lte(rect.end.x, 160.0, "at most a quarter of the width")
	assert_lte(rect.end.y, 90.0, "at most a quarter of the height")
	assert_true(WINDOW_BUDGET.encloses(rect), "inside (4,4)-(136,90), left of the note label at x 140: %s" % rect)


# --- status-sync: the bleeding tag --------------------------------------------------------------

func test_the_bleeding_tag_shows_only_while_the_player_bleeds() -> void:
	var meters := _meters()
	hud.bind(meters)
	var tag := hud.bleeding_tag()
	assert_not_null(tag)
	if tag == null:
		return
	assert_false(tag.visible, "no tag while not bleeding")
	meters.set_status(DataEnums.Status.BLEEDING, true)
	assert_true(tag.visible)
	assert_eq(tag.text, "Sangrando")
	meters.set_status(DataEnums.Status.POISON, true)
	meters.set_status(DataEnums.Status.BLEEDING, false)
	assert_false(tag.visible, "another status shows no bleeding tag")


func test_binding_a_bleeding_player_shows_the_tag_at_once() -> void:
	var meters := _meters()
	meters.set_status(DataEnums.Status.BLEEDING, true)
	hud.bind(meters)
	assert_true(hud.bleeding_tag().visible)


func test_the_bleeding_tag_is_red_under_the_bars_in_the_pixel_font() -> void:
	var tag := hud.bleeding_tag()
	var health := hud.bar_for(M.HEALTH)
	assert_same(tag.get_parent(), health.get_parent(), "in the bars panel")
	assert_gt(tag.get_index(), health.get_index(), "under the last bar")
	var color := tag.get_theme_color(&"font_color")
	assert_gt(color.r, 0.7, "red")
	assert_lt(color.g, 0.4)
	assert_lt(color.b, 0.4)
	var font := tag.get_theme_font(&"font")
	assert_not_null(font)
	if font != null:
		assert_eq(font.resource_path, FONT_PATH)
	assert_eq(tag.get_theme_font_size(&"font_size"), 8)


func test_the_panel_still_fits_the_corner_while_bleeding() -> void:
	var meters := _meters()
	meters.set_status(DataEnums.Status.BLEEDING, true)
	hud.bind(meters)
	await wait_process_frames(2)
	var rect := hud.panel_rect()
	assert_lte(rect.end.x, 160.0, "at most a quarter of the width")
	assert_lte(rect.end.y, 90.0, "at most a quarter of the height")
	assert_true(WINDOW_BUDGET.encloses(rect), "with Sangrando still inside (4,4)-(136,90): %s" % rect)


func test_rebinding_stops_following_the_old_nodes_statuses() -> void:
	var old := _meters()
	var current := _meters()
	hud.bind(old)
	hud.bind(current)
	old.set_status(DataEnums.Status.BLEEDING, true)
	assert_false(hud.bleeding_tag().visible)


func test_hud_ignores_the_mouse() -> void:
	assert_eq(hud.mouse_filter, Control.MOUSE_FILTER_IGNORE)


# --- hud-window-kit: the strict grid, the steps and the ramps (design D4) -------------------------

func test_each_row_is_label_then_bar_box_then_value_on_a_fixed_grid() -> void:
	await wait_process_frames(2)
	var first_box_x: float = -1.0
	for bar: MeterBar in hud.bars():
		var label := bar.label.get_global_rect()
		var box := bar.box.get_global_rect()
		var value := bar.value_label.get_global_rect()
		assert_eq(label.size.x, 56.0, "%s: a 56 px label column" % bar.label_text)
		assert_eq(box.size, Vector2(40.0, 7.0), "%s: a 40x7 bar box" % bar.label_text)
		assert_eq(bar.bar.size, MeterBar.FILL_SIZE, "%s: a 38x5 fill area" % bar.label_text)
		assert_lte(label.end.x, box.position.x, "%s: the label left of its bar" % bar.label_text)
		assert_lte(box.end.x, value.position.x, "%s: the value right of it" % bar.label_text)
		assert_false(label.intersects(box), "%s: no label pixel on the bar" % bar.label_text)
		if first_box_x < 0.0:
			first_box_x = box.position.x
		assert_eq(box.position.x, first_box_x, "%s: every bar at the same x" % bar.label_text)


func test_each_bar_fills_from_its_ramp_over_its_darkest_step() -> void:
	var bars := hud.bars()
	var tuning: HurtCueTuning = HurtCues.tuning()
	for i: int in bars.size():
		var bar: MeterBar = bars[i]
		var fill := bar.bar.get_theme_stylebox(&"fill") as StyleBoxTexture
		assert_not_null(fill, bar.label_text)
		if fill == null:
			continue
		assert_eq(fill.texture.resource_path, "res://assets/art/ui/ramp_%s.png" % RAMPS[i], bar.label_text)
		var strip: Image = fill.texture.get_image()
		assert_true(strip.get_pixel(0, 1).is_equal_approx(bar.fill_color), "%s: fill_color is the ramp's base" % bar.label_text)
		var empty := bar.bar.get_theme_stylebox(&"background") as StyleBoxFlat
		assert_true(empty.bg_color.is_equal_approx(bar.empty_color), bar.label_text)
		var float_color: Color = tuning.meter_colors.get(bar.meter, Color.MAGENTA)
		assert_true(float_color.is_equal_approx(bar.fill_color), "%s: the floats' colour is the ramp's base" % bar.label_text)


func test_labels_step_orange_then_alert_red_and_never_pulse() -> void:
	var meters := _meters()
	hud.bind(meters)
	var thirst := hud.bar_for(M.THIRST)
	assert_true(thirst.label_color().is_equal_approx(HudStyle.CREAM), "calm above 50")
	meters.thirst = 50.0
	assert_true(thirst.label_color().is_equal_approx(HudStyle.ORANGE), "warning at 50")
	assert_false(thirst.pulsing)
	meters.thirst = 20.0
	assert_true(thirst.label_color().is_equal_approx(HudStyle.ALERT), "critical at 25 or less")
	assert_true(thirst.pulsing)
	thirst._process(0.25)
	assert_true(thirst.label_color().is_equal_approx(HudStyle.ALERT), "the label never pulses")
	assert_false(thirst.outline_color().is_equal_approx(HudStyle.OUTLINE), "the outline pulses")
	assert_false(thirst.value_label.get_theme_color(&"font_color").is_equal_approx(HudStyle.CREAM), "the value pulses")
	meters.thirst = 30.0
	assert_false(thirst.pulsing)
	assert_true(thirst.outline_color().is_equal_approx(HudStyle.OUTLINE), "steady again")
	var heat := hud.bar_for(M.HEAT)
	meters.heat = 60.0
	assert_true(heat.label_color().is_equal_approx(HudStyle.ORANGE), "heat warns at 50 or more")
	meters.heat = 80.0
	assert_true(heat.label_color().is_equal_approx(HudStyle.ALERT), "and is critical at 75")


func test_a_sliver_is_a_shade_column_and_a_half_pixel_rounds_up() -> void:
	var meters := _meters()
	hud.bind(meters)
	var thirst := hud.bar_for(M.THIRST)
	meters.thirst = 1.0
	var edge: Array = thirst.edge_column()
	assert_eq(edge[0], 0.0, "0.38 px: one shade column at x 0")
	assert_eq(thirst.full_columns(), 0)
	meters.thirst = 50.0
	assert_eq(thirst.edge_column()[0], -1.0, "19 px: whole columns only")
	assert_eq(thirst.full_columns(), 19)
	meters.thirst = 99.0
	assert_eq(thirst.edge_column()[0], -1.0, "37.62 px: the engine rounds up")
	assert_eq(thirst.full_columns(), 38)


func test_the_heat_bar_marks_75() -> void:
	var heat := hud.bar_for(M.HEAT)
	var tick := heat.bar.get_node(^"Tick") as ColorRect
	assert_true(tick.visible)
	assert_eq(tick.position.x, 28.0, "75 of 100 on 38 px")
	assert_true(tick.color.is_equal_approx(HudStyle.ALERT))
	assert_false((hud.bar_for(M.THIRST).bar.get_node(^"Tick") as ColorRect).visible, "heat only")


func test_solo_meters_read_salud_first_and_step_with_one_player() -> void:
	NetManager.start_solo()
	var session := (load("res://scenes/net/coop_session.tscn") as PackedScene).instantiate() as CoopSession
	add_child_autofree(session)
	session.start()
	var body := session.body(1)
	body.player_input.enabled = false
	hud.bind(body.meters)
	assert_eq(hud.bars()[0].label.text, "Salud", "Salud first")
	body.meters.thirst = 40.0
	body.meters.heat = 60.0
	for bar: MeterBar in hud.bars():
		var stepped: bool = bar.meter in [M.THIRST, M.HEAT]
		var expected: Color = HudStyle.ORANGE if stepped else HudStyle.CREAM
		assert_true(bar.label_color().is_equal_approx(expected), "%s's label colour" % bar.label_text)
	NetManager.leave()
