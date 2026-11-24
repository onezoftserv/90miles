extends GutTest
## art-guardacostas group 1 (design.md D6; spec "Call windows", "Patrol cues", "Capture cues"): the
## loudhailer's lines and the squad's calls show in the HUD's call windows, not in world speech bubbles.
## - Every alert, give-up, landing, spot and leaving line of every patrol, in Spanish and English, wraps to
##   at most 3 rows of 30 glyphs.
## - A call stays max(3, 1 + length / 15) s.
## - A speaker off screen puts the window at the nearest edge with its tail toward the speaker.
## - A window never overlaps a top HUD window or the prompt, and stays above y 326.
## - With exactly 1 player offline on the sandbar at night, the boat's alert shows its Spanish line in a
##   window over the boat, and no SpeechBubble.

const SHELL_SCENE: PackedScene = preload("res://scenes/shell/game_shell.tscn")
const PATROL_DIR: String = "res://resources/creatures"
const NIGHT_S: float = 430.0
var settings_path: String = UserTmp.path("test_call_windows_settings.cfg")

var shell: GameShell = null


func before_each() -> void:
	NetManager.start_solo()
	WeatherManager.stop()
	WeatherManager.sky.start_at(0.0)
	WeatherManager.sky.weather.rolls_enabled = false


func after_each() -> void:
	shell = null
	WeatherManager.sky.weather.rolls_enabled = true
	WeatherManager.sky.start_at(0.0)
	WeatherManager.stop()
	NetManager.leave()
	if FileAccess.file_exists(settings_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(settings_path))


func _patrols() -> Array[PatrolData]:
	var found: Array[PatrolData] = []
	for file: String in DirAccess.get_files_at(PATROL_DIR):
		if not file.ends_with(".tres"):
			continue
		var data := load(PATROL_DIR.path_join(file)) as CreatureData
		if data != null and data.patrol != null:
			found.append(data.patrol)
	return found


func _every_line(patrol: PatrolData) -> PackedStringArray:
	var lines := PackedStringArray()
	for list: PackedStringArray in [
		patrol.alert_lines_es, patrol.alert_lines_en, patrol.give_up_lines_es, patrol.give_up_lines_en,
		patrol.squad_land_lines_es, patrol.squad_land_lines_en, patrol.squad_spot_lines_es,
		patrol.squad_spot_lines_en, patrol.squad_leave_lines_es, patrol.squad_leave_lines_en,
	]:
		lines.append_array(list)
	return lines


# --- the budget -------------------------------------------------------------------------------------

func test_every_shipped_call_fits_3_rows_of_30_glyphs_in_both_languages() -> void:
	var patrols := _patrols()
	assert_gt(patrols.size(), 0, "at least one patrol ships")
	var checked: int = 0
	for patrol: PatrolData in patrols:
		for line: String in _every_line(patrol):
			var rows: PackedStringArray = CallWindows.rows(line)
			assert_lte(rows.size(), CallWindows.MAX_ROWS, "%s: %s" % [line, rows])
			for row: String in rows:
				assert_lte(row.length(), CallWindows.MAX_GLYPHS, row)
			assert_eq(" ".join(rows), line, "wrapping keeps every word")
			checked += 1
	assert_gt(checked, 10, "the lines were found")


func test_rows_wrap_at_word_boundaries() -> void:
	assert_eq(CallWindows.rows("Alto."), PackedStringArray(["Alto."]))
	var rows := CallWindows.rows("The inspection of the cay is under way. Cooperate with the authorities.")
	assert_eq(rows.size(), 3)
	assert_eq(rows[0], "The inspection of the cay is")
	for row: String in rows:
		assert_lte(row.length(), 30)


func test_a_call_stays_1_s_plus_1_s_per_15_characters_and_at_least_3_s() -> void:
	assert_eq(CallWindows.show_s("Alto."), 3.0, "a short call: 3 s")
	assert_eq(CallWindows.show_s("x".repeat(30)), 3.0)
	assert_almost_eq(CallWindows.show_s("x".repeat(60)), 5.0, 0.0001)
	assert_almost_eq(CallWindows.show_s("x".repeat(71)), 1.0 + 71.0 / 15.0, 0.0001)


# --- placement --------------------------------------------------------------------------------------

func test_a_window_sits_over_its_speaker_with_its_tail_down() -> void:
	var size := Vector2(120.0, 20.0)
	var rect: Rect2 = CallWindows.place(Vector2(300.0, 200.0), size, [], [])
	assert_eq(rect.size, size)
	assert_eq(rect.end.y, 200.0 - CallWindows.TAIL_PX, "the bottom 3 px over the speaker's top")
	assert_eq(rect.position.x, 240.0, "centred")
	assert_eq(CallWindows.tail_side(Vector2(300.0, 200.0), rect), CallWindows.Side.BOTTOM)


func test_an_off_screen_speaker_puts_the_window_at_the_nearest_edge_pointing_at_it() -> void:
	var size := Vector2(120.0, 20.0)
	var east: Rect2 = CallWindows.place(Vector2(900.0, 150.0), size, [], [])
	assert_eq(east.end.x, 640.0 - CallWindows.EDGE_PX, "at the right edge")
	assert_eq(CallWindows.tail_side(Vector2(900.0, 150.0), east), CallWindows.Side.RIGHT, "pointing right")
	var west: Rect2 = CallWindows.place(Vector2(-50.0, 150.0), size, [], [])
	assert_eq(west.position.x, CallWindows.EDGE_PX)
	assert_eq(CallWindows.tail_side(Vector2(-50.0, 150.0), west), CallWindows.Side.LEFT)
	var north: Rect2 = CallWindows.place(Vector2(320.0, -80.0), size, [], [])
	assert_eq(north.position.y, CallWindows.EDGE_PX, "at the top edge")
	assert_eq(CallWindows.tail_side(Vector2(320.0, -80.0), north), CallWindows.Side.TOP, "pointing up")
	var south: Rect2 = CallWindows.place(Vector2(320.0, 500.0), size, [], [])
	assert_eq(south.end.y, CallWindows.BOTTOM_Y, "above the bottom band")
	assert_eq(CallWindows.tail_side(Vector2(320.0, 500.0), south), CallWindows.Side.BOTTOM)


func test_a_window_keeps_clear_of_top_windows_the_prompt_and_the_bottom_band() -> void:
	var size := Vector2(200.0, 30.0)
	var meters := Rect2(4.0, 4.0, 130.0, 66.0)
	var phase := Rect2(260.0, 4.0, 120.0, 14.0)
	var prompt := Rect2(250.0, 200.0, 100.0, 12.0)
	# A speaker under the meters: the window moves down under them.
	var under: Rect2 = CallWindows.place(Vector2(60.0, 40.0), size, [meters, phase, prompt], [])
	assert_false(under.intersects(meters), "clear of the meters")
	assert_gte(under.position.y, meters.end.y)
	# A speaker just below the prompt: the window goes up over it.
	var over: Rect2 = CallWindows.place(Vector2(300.0, 240.0), size, [meters, phase, prompt], [])
	assert_false(over.intersects(prompt), "clear of the prompt")
	assert_lte(over.end.y, prompt.position.y)
	# A speaker on the bottom band: the window stays above y 326.
	var low: Rect2 = CallWindows.place(Vector2(320.0, 350.0), size, [], [])
	assert_lte(low.end.y, 326.0)


# A speaker just south of the local player in the middle of the view: the window goes up over the
# player's figure, never on it.
func test_a_window_keeps_clear_of_the_local_players_figure() -> void:
	var size := Vector2(200.0, 30.0)
	var figure := Rect2(312.0, 140.0, 16.0, 40.0)
	var rect: Rect2 = CallWindows.place(Vector2(320.0, 200.0), size, [figure], [])
	assert_false(rect.intersects(figure), "clear of the player")
	assert_lte(rect.end.y, figure.position.y, "over the player, not under")


func test_two_overlapping_windows_stack_the_later_above() -> void:
	var size := Vector2(120.0, 20.0)
	var first: Rect2 = CallWindows.place(Vector2(300.0, 200.0), size, [], [])
	var second: Rect2 = CallWindows.place(Vector2(310.0, 205.0), size, [], [first])
	assert_false(second.intersects(first))
	assert_lte(second.end.y, first.position.y)


# --- in a run ---------------------------------------------------------------------------------------

# Spec "The loudhailer speaks", "Readable at 1x".
func test_a_solo_players_boat_alert_shows_its_spanish_line_in_a_window_over_the_boat() -> void:
	shell = SHELL_SCENE.instantiate() as GameShell
	shell.settings_path = settings_path
	add_child_autofree(shell)
	(shell.screen as TitleScreen).solo_requested.emit()
	var session: CoopSession = shell.session
	var body: PlayerBody = session.body(CoopSession.HOST_ID)
	body.player_input.enabled = false
	await wait_physics_frames(3)
	WeatherManager.stop()
	WeatherManager.sky.start_at(NIGHT_S)
	var spawner := session.get_node(NodePath(SandbarIsland.CREATURES_NAME)) as CreatureSpawner
	spawner.apply_phase(WeatherManager.phase())
	spawner.set_physics_process(false)
	var boat: Creature = spawner.creatures(&"patrol_boat")[0]
	boat.set_physics_process(false)
	var brain := boat.brain as PatrolRoute
	var patrol: PatrolData = boat.data.patrol
	brain.set_clock(patrol.horizon_warning_s + 5.0)
	boat.advance(0.0)
	var look := boat.get_node(^"PatrolLook") as PatrolLook
	look.step(0.0)
	boat.world.spawner = Callable()
	brain.spot(body, &"sight")
	look.step(0.0)
	assert_eq(look.lines_shown, 1)
	var windows: CallWindows = shell.hud.call_windows
	assert_not_null(windows, "the HUD has call windows")
	assert_eq(windows.count(), 1, "one call window")
	assert_eq(windows.speaker_of(0), boat, "over the boat")
	assert_eq(windows.text_of(0), look.last_line)
	assert_true(patrol.alert_lines_es.has(windows.text_of(0)), "a Spanish alert line")
	assert_null(boat.get_node_or_null(NodePath(CoopSession.BUBBLE_NAME)), "no speech bubble over the boat")
	var panel: PanelContainer = windows.panel_of(0)
	assert_eq(panel.theme_type_variation, CallWindows.VARIATION, "the thin dark window")
	assert_false(RunHud.HUD_PANELS.has(panel.theme_type_variation), "not a panel the prompt dodges")
	windows.tick(0.0)
	var rect: Rect2 = windows.rect_of(0)
	assert_true(Rect2(Vector2.ZERO, CallWindows.VIEW).encloses(rect), "inside the view")
	assert_lte(rect.end.y, CallWindows.BOTTOM_Y)
	for other: Rect2 in shell.hud.panel_rects():
		assert_false(rect.intersects(other), "clear of %s" % other)
	windows.tick(2.9)
	assert_eq(windows.count(), 1, "still there at 2.9 s")
	windows.tick(CallWindows.show_s(look.last_line) - 2.9 + 0.05)
	assert_eq(windows.count(), 0, "gone after its time")


func test_a_new_call_from_the_same_speaker_replaces_the_old_one() -> void:
	var windows := CallWindows.new()
	add_child_autofree(windows)
	var speaker := Node2D.new()
	add_child_autofree(speaker)
	speaker.position = Vector2(200.0, 200.0)
	windows.show_call(speaker, "Alto.")
	windows.show_call(speaker, "Coopere con la autoridad.")
	assert_eq(windows.count(), 1)
	assert_eq(windows.text_of(0), "Coopere con la autoridad.")
	var other := Node2D.new()
	add_child_autofree(other)
	other.position = Vector2(205.0, 205.0)
	windows.show_call(other, "Alto.")
	assert_eq(windows.count(), 2)
	windows.tick(0.0)
	assert_false(windows.rect_of(0).intersects(windows.rect_of(1)), "stacked")
	speaker.free()
	windows.tick(0.0)
	assert_eq(windows.count(), 1, "a freed speaker's call goes")
	windows.screen_shown = true
	windows.tick(0.0)
	assert_false(windows.panel_of(0).visible, "nothing shows under a screen")


# The 1-player run: a solo player beside a landing squad sees the call over the soldier and clear of
# their own figure.
func test_a_solo_players_own_figure_is_never_under_a_call_window() -> void:
	shell = SHELL_SCENE.instantiate() as GameShell
	shell.settings_path = settings_path
	add_child_autofree(shell)
	(shell.screen as TitleScreen).solo_requested.emit()
	var body: PlayerBody = shell.session.body(CoopSession.HOST_ID)
	body.player_input.enabled = false
	await wait_physics_frames(3)
	var hud: RunHud = shell.hud
	var figure: Rect2 = hud.local_figure_rect()
	assert_true(figure.has_area(), "the player's figure in the HUD")
	var speaker := Node2D.new()
	add_child_autofree(speaker)
	speaker.global_position = body.get_global_transform_with_canvas().origin + Vector2(4.0, 20.0)
	hud.call_windows.to_hud = func(point: Vector2) -> Vector2: return point
	hud.call_windows.show_call(speaker, "Se procede a la inspección del cayo. Colaboren con la autoridad.")
	hud.call_windows.tick(0.0)
	var rect: Rect2 = hud.call_windows.rect_of(hud.call_windows.count() - 1)
	assert_false(rect.intersects(hud.local_figure_rect()), "the window is clear of the player's figure")
