extends GutTest
## hud-clarity, ui-shell "HUD layout" ("The top band holds together", "The longest teammate block")
## and secret-cay "Needle on the carrier's HUD", with exactly 1 player, offline (and a host with three
## clients for the teammate list): the needle sits at (384,20)-(408,44); with a squall, the compass,
## the longest objective lines in both languages and the note label all on show, the top band's
## pieces overlap none of each other, the teammate list's place, nor crossing-gameplay's strip and line.

const SESSION_SCENE: PackedScene = preload("res://scenes/net/coop_session.tscn")
const HUD_SCENE: PackedScene = preload("res://scenes/ui/run_hud.tscn")
const NEEDLE_RECT: Rect2 = Rect2(384.0, 20.0, 24.0, 24.0)
## crossing-gameplay #75's CrossingHud.STRIP_RECT and LINE_RECT, copied as constants so this test runs
## whether or not that change has landed.
const CROSSING_STRIP: Rect2 = Rect2(220.0, 68.0, 200.0, 12.0)
const CROSSING_LINE: Rect2 = Rect2(160.0, 81.0, 320.0, 10.0)
## The teammate list's column.
const TEAMMATES: Rect2 = Rect2(502.0, 4.0, 134.0, 86.0)
const NOTE_LABEL: Rect2 = Rect2(140.0, 46.0, 360.0, 20.0)

var session: CoopSession
var hud: RunHud


func before_each() -> void:
	NetManager.start_solo()
	WeatherManager.stop()
	WeatherManager.sky.weather.rolls_enabled = false
	WeatherManager.sky.start_at(200.0)
	session = SESSION_SCENE.instantiate() as CoopSession
	session.local_name = "Yuni"
	add_child_autofree(session)
	session.start()
	session.climate = WeatherManager.sky.climate
	session.body(1).player_input.enabled = false
	hud = HUD_SCENE.instantiate() as RunHud
	add_child_autofree(hud)
	hud.bind(session, 1, true)


func after_each() -> void:
	WeatherManager.stop()
	NetManager.leave()


func _carry_compass() -> void:
	session.body(1).inventory.add(&"brujula_rota", 1)
	hud.needle.step(0.1)


func test_the_needle_sits_under_the_weather_window() -> void:
	_carry_compass()
	assert_true(hud.needle.visible)
	assert_eq(hud.needle.get_global_rect(), NEEDLE_RECT)
	var phase := (hud.get_node(^"PhasePanel") as Control).get_global_rect()
	assert_false(NEEDLE_RECT.intersects(phase), "clear of the clock row")
	assert_lt(NEEDLE_RECT.end.y, NOTE_LABEL.position.y + 0.5, "above the note label")


func test_the_top_band_holds_together() -> void:
	WeatherManager.sky.weather.start_weather(&"squall")
	WeatherManager.sky.advance(0.01)
	_carry_compass()
	await wait_process_frames(2)
	assert_true(hud.weather_panel.visible, "the squall names itself")
	var text := HudText.load_default()
	var longest: Array[String] = []
	for locale: String in ["es", "en"]:
		var best: String = ""
		for key: StringName in HudText.OBJECTIVE_LINES:
			var line: String = text.objective_line(key, locale)
			if key == &"gather":
				line = line % [6, 6, "cámaras" if locale == "es" else "tubes"]
			elif key == &"work":
				line = line % 100
			if line.length() > best.length():
				best = line
		longest.append(best)
	for line: String in longest:
		hud.objective_row.show_line(line)
		var rects: Dictionary[String, Rect2] = {
			"meters": hud.meters.panel_rect(),
			"clock": (hud.get_node(^"PhasePanel") as Control).get_global_rect(),
			"objective": hud.objective_row.get_global_rect(),
			"weather": hud.weather_panel.get_global_rect(),
			"needle": hud.needle.get_global_rect(),
			"note label": NOTE_LABEL,
		}
		var names: Array = rects.keys()
		for i: int in names.size():
			var a: Rect2 = rects[names[i]]
			for j: int in range(i + 1, names.size()):
				assert_false(a.intersects(rects[names[j]]), "%s %s clear of %s %s (\"%s\")" % [names[i], a, names[j], rects[names[j]], line])
			for other: Rect2 in [TEAMMATES, CROSSING_STRIP, CROSSING_LINE]:
				assert_false(a.intersects(other), "%s clear of %s" % [names[i], other])
