extends GutTest
## survival-meters "HUD bars": six Spanish-labelled bars in the committed pixel font, following
## one SurvivalMeters node, and the sunstroke blur for that player only.

const HUD_SCENE := "res://scenes/ui/meters_hud.tscn"
const FONT_PATH := "res://assets/fonts/PressStart2P-Regular.ttf"
const M := DataEnums.Meter
const ORDER: Array[DataEnums.Meter] = [M.THIRST, M.HUNGER, M.HEAT, M.ENERGY, M.MORALE, M.HEALTH]
const LABELS: Array[String] = ["Sed", "Hambre", "Calor", "Energía", "Ánimo", "Salud"]

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


func test_rebinding_stops_following_the_old_nodes_statuses() -> void:
	var old := _meters()
	var current := _meters()
	hud.bind(old)
	hud.bind(current)
	old.set_status(DataEnums.Status.BLEEDING, true)
	assert_false(hud.bleeding_tag().visible)


func test_hud_ignores_the_mouse() -> void:
	assert_eq(hud.mouse_filter, Control.MOUSE_FILTER_IGNORE)
