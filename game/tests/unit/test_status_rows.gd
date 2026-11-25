extends GutTest
## hud-clarity, survival-meters "HUD bars", "Bleeding tag on the HUD", "Bleeding time on every peer",
## "Sunstroke tag on the HUD" and "Sunstroke cooling bar", with exactly 1 player, offline: the rows
## read Salud, Sed, Hambre, Energía, Ánimo, Calor; Calor is a thermometer with zone tints and notches
## at 50 and 75; "Insolación" and "Sangrando" rows show with an icon and a time bar while they apply;
## the window with both stays inside (4,4)-(136,90). The bleeding time is a synced meter property.

const METERS_SCENE: PackedScene = preload("res://scenes/ui/meters_hud.tscn")
const PLAYER_SCENE: PackedScene = preload("res://scenes/player/player.tscn")
const CORNER: Rect2 = Rect2(4.0, 4.0, 132.0, 86.0)
const M := DataEnums.Meter

var meters: SurvivalMeters
var hud: MetersHud


func before_each() -> void:
	meters = SurvivalMeters.new()
	meters.solo = true
	add_child_autofree(meters)
	hud = METERS_SCENE.instantiate() as MetersHud
	add_child_autofree(hud)
	hud.bind(meters)


func _tick(seconds: float) -> void:
	var context := MeterContext.new()
	var left: float = seconds
	while left > 0.0:
		var step: float = minf(left, 1.0)
		meters.tick(step, context)
		left -= step


# --- the bleeding time -------------------------------------------------------------------------------

func test_the_bleeding_time_counts_down_on_the_host() -> void:
	assert_eq(meters.bleeding_left_s, 0.0, "nothing while not bleeding")
	meters.set_status(DataEnums.Status.BLEEDING, true)
	assert_eq(meters.bleeding_left_s, meters.tuning.bleeding_s, "a bite starts the full time")
	_tick(60.0)
	assert_almost_eq(meters.bleeding_left_s, meters.tuning.bleeding_s - 60.0, 0.01)
	meters.set_status(DataEnums.Status.BLEEDING, true)
	assert_eq(meters.bleeding_left_s, meters.tuning.bleeding_s, "a new wound fills it again")
	_tick(meters.tuning.bleeding_s + 1.0)
	assert_false(meters.has_status(DataEnums.Status.BLEEDING), "the bleeding ended")
	assert_eq(meters.bleeding_left_s, 0.0, "0 after the end")


func test_a_cure_zeroes_the_bleeding_time() -> void:
	meters.set_status(DataEnums.Status.BLEEDING, true)
	meters.set_status(DataEnums.Status.BLEEDING, false)
	assert_eq(meters.bleeding_left_s, 0.0)


func test_the_player_replicates_the_bleeding_time() -> void:
	var player := PLAYER_SCENE.instantiate()
	autofree(player)
	var found: bool = false
	for node: Node in player.find_children("*", "MultiplayerSynchronizer", true, false):
		var config := (node as MultiplayerSynchronizer).replication_config
		for path: NodePath in config.get_properties():
			if String(path) == "SurvivalMeters:bleeding_left_s":
				found = true
				assert_eq(config.property_get_replication_mode(path), SceneReplicationConfig.REPLICATION_MODE_ALWAYS)
				assert_true(config.property_get_spawn(path), "sent on spawn")
	assert_true(found, "SurvivalMeters:bleeding_left_s is synced")


# --- the rows ----------------------------------------------------------------------------------------

func test_the_rows_read_with_calor_last() -> void:
	var words: Array[String] = []
	for bar: MeterBar in hud.bars():
		words.append(bar.label.text)
	assert_eq(words, ["Salud", "Sed", "Hambre", "Energía", "Ánimo", "Calor"] as Array[String])


func test_calor_is_a_thermometer() -> void:
	var heat := hud.bar_for(M.HEAT)
	meters.heat = 2.0
	await wait_process_frames(1)
	assert_eq(heat.zones.size(), 3, "three zone tints")
	var tints := heat.zone_rects()
	assert_eq(tints.size(), 3)
	# The track holds the three tints from left to right, below 50, 50 to 75 and 75 up; no plain
	# empty colour shows at heat 2.
	assert_almost_eq(tints[0].position.x, 0.0, 0.01)
	assert_almost_eq(tints[1].position.x, 19.0, 0.01, "50% of 38 px")
	assert_almost_eq(tints[2].position.x, 28.0, 0.51, "75% of 38 px")
	assert_almost_eq(tints[2].end.x, 38.0, 0.01)
	assert_eq(heat.empty_shown(), false, "the zones replace the plain empty colour")
	var notches := heat.notch_xs()
	assert_eq(notches.size(), 2, "notches at 50 and 75")
	var other := hud.bar_for(M.THIRST)
	assert_eq(other.zones.size(), 0, "only Calor has zones")
	assert_eq(other.notch_xs().size(), 0)


func test_insolacion_shows_with_the_blur_and_its_cooling_bar() -> void:
	var row := hud.status_row(&"sunstroke")
	assert_not_null(row)
	assert_false(row.visible, "no row while cool")
	meters.heat = 100.0
	meters.sunstroke = true
	await wait_process_frames(1)
	assert_true(hud.blurred())
	assert_true(row.visible, "Insolación shows with the blur")
	assert_eq(row.word.text, "Insolación")
	assert_almost_eq(row.fill_ratio(), 1.0, 0.01, "full at 100")
	meters.heat = 80.0
	await wait_process_frames(1)
	assert_almost_eq(row.fill_ratio(), 0.5, 0.01, "half at 80")
	meters.heat = 59.0
	meters.sunstroke = false
	await wait_process_frames(1)
	assert_false(row.visible, "gone below 60")


func test_sangrando_shows_with_its_icon_and_time_bar() -> void:
	var row := hud.status_row(&"bleeding")
	assert_not_null(row)
	meters.set_status(DataEnums.Status.BLEEDING, true)
	await wait_process_frames(1)
	assert_true(row.visible)
	assert_eq(row.word.text, "Sangrando")
	assert_eq(hud.bleeding_tag(), row.word, "the old tag is the row's word")
	assert_not_null(row.icon.texture, "a drop icon")
	assert_almost_eq(row.fill_ratio(), 1.0, 0.01)
	_tick(60.0)
	await wait_process_frames(1)
	assert_almost_eq(row.fill_ratio(), 0.5, 0.01, "half after 60 of 120 s")
	meters.set_status(DataEnums.Status.BLEEDING, true)
	await wait_process_frames(1)
	assert_almost_eq(row.fill_ratio(), 1.0, 0.01, "full again after a new bite")


func test_insolacion_sits_above_sangrando() -> void:
	var sun := hud.status_row(&"sunstroke")
	var blood := hud.status_row(&"bleeding")
	assert_lt(sun.get_index(), blood.get_index())


func test_both_rows_stay_in_the_corner() -> void:
	meters.heat = 100.0
	meters.sunstroke = true
	meters.set_status(DataEnums.Status.BLEEDING, true)
	await wait_process_frames(3)
	var rect := hud.panel_rect()
	assert_true(CORNER.encloses(rect), "the meters window %s lies inside (4,4)-(136,90)" % rect)
	assert_lt(rect.end.x, 140.0, "left of the note label")
	assert_eq(hud.bars()[0].label.text, "Salud", "Salud first")
	for row: StatusRow in [hud.status_row(&"sunstroke"), hud.status_row(&"bleeding")]:
		assert_true(rect.encloses(row.get_global_rect()), "%s inside the window" % row.word.text)
		assert_true(row.get_global_rect().encloses(row.bar_box.get_global_rect()), "its bar inside the row")
