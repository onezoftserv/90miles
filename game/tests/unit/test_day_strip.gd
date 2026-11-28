extends GutTest
## hud-clarity, ui-shell "Clock strip", "Time left before dark" and "Phase words": the strip's
## parts and marker, the time left and its colour, and the phase word for every stretch of the day.
## Pure: in-game hh:mm is (hh - 6) * 30 s + mm / 2 s after dawn.

const TEXT_PATH: String = "res://resources/hud_text.tres"

var text: HudText


func before_all() -> void:
	text = load(TEXT_PATH) as HudText


# Seconds since dawn of the in-game time hh:mm.
func _at(hours: int, minutes: int) -> float:
	return fposmod(float(hours - DayClock.DAWN_HOUR) * DayClock.HOUR_S + float(minutes) / 2.0, DayClock.DAY_S)


func test_the_times_used_here() -> void:
	assert_eq(_at(6, 0), 0.0)
	assert_eq(_at(9, 0), 90.0)
	assert_eq(_at(18, 30), 375.0)
	assert_eq(_at(5, 40), 710.0)


func test_the_parts_cover_the_strip_in_order() -> void:
	var parts := DayStrip.parts()
	var keys: Array[StringName] = []
	var x: int = 0
	for part: DayStrip.Part in parts:
		keys.append(part.key)
		assert_eq(part.from_px, x, "%s starts where the last part ended" % part.key)
		assert_gt(part.to_px, part.from_px, "%s has width" % part.key)
		x = part.to_px
	assert_eq(x, DayStrip.STRIP_PX, "the parts fill the strip")
	assert_eq(keys, [&"dawn", &"day", &"midday", &"day", &"dusk", &"night"] as Array[StringName])


func test_the_part_edges() -> void:
	# 54 px for 720 s: dawn ends at 60 s (4 px), midday runs 120-300 s (9-22 px), dusk starts at
	# 360 s (27 px) and night at 420 s (31 px).
	var edges: Array[int] = []
	for part: DayStrip.Part in DayStrip.parts():
		edges.append(part.to_px)
	assert_eq(edges, [4, 9, 22, 27, 31, 54] as Array[int])


func test_the_marker_stands_at_the_time() -> void:
	assert_eq(DayStrip.marker_px(_at(6, 0)), 0)
	assert_eq(DayStrip.marker_px(_at(9, 0)), 6, "an eighth of 54 px, floored")
	assert_eq(DayStrip.marker_px(_at(18, 0)), 27)
	assert_eq(DayStrip.marker_px(_at(5, 59)), 53, "the last column")


func test_the_time_left() -> void:
	assert_eq(DayStrip.left_text(_at(9, 0), text, "es"), "11h")
	assert_eq(DayStrip.left_text(_at(6, 0), text, "es"), "14h", "dawn: fourteen hours to dark")
	assert_eq(DayStrip.left_text(_at(14, 0), text, "es"), "6h")
	assert_eq(DayStrip.left_text(_at(18, 30), text, "es"), "2h", "rounded up")
	assert_eq(DayStrip.left_text(_at(19, 0), text, "es"), "1h")
	assert_eq(DayStrip.left_text(_at(19, 20), text, "es"), "40m", "under an hour: minutes")
	assert_eq(DayStrip.left_text(_at(20, 0), text, "es"), "10h", "night counts to dawn")
	assert_eq(DayStrip.left_text(_at(5, 40), text, "es"), "20m")
	assert_eq(DayStrip.left_text(_at(5, 40), text, "en"), "20m")


func test_the_marks_and_the_warning() -> void:
	assert_false(DayStrip.counts_to_dawn(_at(9, 0)), "by day the moon mark: time to dark")
	assert_true(DayStrip.counts_to_dawn(_at(21, 0)), "at night the sun mark: time to dawn")
	assert_true(DayStrip.counts_to_dawn(_at(5, 40)))
	assert_false(DayStrip.is_warning(_at(17, 59)), "cream before dusk")
	assert_true(DayStrip.is_warning(_at(18, 0)), "orange from dusk")
	assert_true(DayStrip.is_warning(_at(18, 30)))
	assert_false(DayStrip.is_warning(_at(20, 0)), "cream again at night")
	assert_false(DayStrip.is_warning(_at(5, 40)))


func test_the_phase_words() -> void:
	var expected: Dictionary[String, String] = {
		"06:00": "Amanecer", "07:59": "Amanecer", "08:00": "Mañana", "09:59": "Mañana",
		"10:00": "Mediodía", "15:59": "Mediodía", "16:00": "Tarde", "17:00": "Tarde", "17:59": "Tarde",
		"18:00": "Atardecer", "19:59": "Atardecer", "20:00": "Noche", "05:40": "Noche",
	}
	for time: String in expected:
		var parts := time.split(":")
		var t: float = _at(parts[0].to_int(), parts[1].to_int())
		assert_eq(text.clock_word(DayStrip.phase_key(t)), expected[time], time)
	assert_eq(text.clock_word(DayStrip.phase_key(_at(17, 0)), "en"), "Afternoon")
	assert_eq(text.clock_word(DayStrip.phase_key(_at(9, 0)), "en"), "Morning")


func test_run_hud_phase_name_tells_morning_from_afternoon() -> void:
	var climate := ClimateState.new()
	climate.phase = DataEnums.DayPhase.DAY
	climate.time_of_day_s = _at(9, 0)
	assert_eq(RunHud.phase_name(climate), "Mañana")
	climate.time_of_day_s = _at(17, 0)
	assert_eq(RunHud.phase_name(climate), "Tarde")
	assert_eq(RunHud.phase_name(climate, "en"), "Afternoon")
	climate.midday = true
	climate.time_of_day_s = _at(12, 0)
	assert_eq(RunHud.phase_name(climate), "Mediodía")
	climate.midday = false
	climate.phase = DataEnums.DayPhase.NIGHT
	assert_eq(RunHud.phase_name(climate), "Noche")
	climate.phase = DataEnums.DayPhase.DAWN
	assert_eq(RunHud.phase_name(climate), "Amanecer")
	climate.phase = DataEnums.DayPhase.DUSK
	assert_eq(RunHud.phase_name(climate), "Atardecer")


func test_the_sky_writes_the_time_and_the_day_into_the_climate() -> void:
	var sky := WorldSky.from_catalog(GameState.content)
	sky.start_at(_at(9, 0))
	assert_eq(sky.climate.time_of_day_s, 90.0)
	assert_eq(sky.climate.day, 1)
	sky.advance(DayClock.DAY_S)
	assert_eq(sky.climate.day, 2, "a day later")
	assert_almost_eq(sky.climate.time_of_day_s, 90.0, 0.001)
