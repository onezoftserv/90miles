extends GutTest
## endings-progression "Cause of death on the run summary" and "Run summary totals", through the
## shell with exactly 1 player offline (solo is the offline peer) and with teammates added to the
## session directly. The run seed is pinned to 0 so the lines are known.

const SHELL_SCENE: PackedScene = preload("res://scenes/shell/game_shell.tscn")
const SUMMARY_SCENE: PackedScene = preload("res://scenes/shell/summary_screen.tscn")
var settings_path: String = UserTmp.path("test_run_summary_settings.cfg")

var now_s: float = 0.0
var _lines: DeathLines


func before_each() -> void:
	now_s = 0.0
	_lines = DeathLines.from_catalog(GameState.content)
	NetManager.start_solo()
	WeatherManager.stop()
	WeatherManager.sky.start_at(0.0)


func after_each() -> void:
	WeatherManager.stop()
	NetManager.leave()
	if FileAccess.file_exists(settings_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(settings_path))


# A solo run with run seed 0 and a clock the test sets.
func _shell() -> GameShell:
	var shell := SHELL_SCENE.instantiate() as GameShell
	shell.settings_path = settings_path
	shell.clock = func() -> float: return now_s
	shell.seed_source = func() -> int: return 0
	add_child_autofree(shell)
	(shell.screen as TitleScreen).solo_requested.emit()
	shell.session.body(1).player_input.enabled = false
	return shell


# Thirst 0 and 2 health: dead of thirst after one second, at once (a last stand of 0 s).
func _kill(body: PlayerBody) -> void:
	body.meters.solo = true
	body.meters.thirst = 0.0
	body.meters.health = 2.0
	body.meters.tick(1.0, MeterContext.new())
	# island-pressure: a solo player on land gets a 12 s last stand before dying of thirst.
	body.meters.tick(12.0, MeterContext.new())


func _line_text(cause: StringName, nth: int = 0) -> String:
	return DeathLines.text(_lines.line_for(cause, 0, nth))


func _entry(player_name: String, dead: bool) -> Dictionary:
	var entry: Dictionary = {
		"name": player_name, "dead": dead, "cause": &"thirst" if dead else &"",
		"cause_label": "sed" if dead else "", "line": "x".repeat(120) if dead else "",
		"line_id": &"death_thirst_1" if dead else &"", "peer": 1,
	}
	if not dead:
		entry["route"] = "Balsa"
	return entry


func _screen_with(entries: Array[Dictionary]) -> SummaryScreen:
	var screen := SUMMARY_SCENE.instantiate() as SummaryScreen
	add_child_autofree(screen)
	var made := RunSummary.new()
	made.entries = entries
	screen.show_summary(made)
	return screen


func test_a_solo_death_by_thirst() -> void:
	var shell := _shell()
	now_s = 180.0
	_kill(shell.session.body(1))
	assert_eq(shell.flow, GameShell.Flow.SUMMARY)
	var summary := shell.screen as SummaryScreen
	assert_eq(summary.rows(), ["Balsero: Murió (sed)"] as Array[String])
	assert_eq(summary.one_liners(), [_line_text(&"thirst")] as Array[String])
	assert_ne(summary.one_liners()[0], "")
	var entry: Dictionary = summary.summary.entries[0]
	assert_eq(entry["cause"], &"thirst")
	assert_eq(entry["line_id"], &"death_thirst_1")
	assert_eq(summary.tips(), [""] as Array[String])
	assert_false(summary.row(0).tip.visible)


func test_the_totals_of_a_first_day_on_the_sandbar() -> void:
	var shell := _shell()
	now_s = 180.0
	_kill(shell.session.body(1))
	var summary := shell.screen as SummaryScreen
	assert_eq(summary.islands.text, "Islas: 1")
	assert_eq(summary.days.text, "Días: 1")
	assert_eq(summary.run_length.text, "3:00")
	# endings-progression "Run summary totals": nothing to count yet, so neither line shows.
	assert_false(summary.companions.visible, "no Compañeros line")
	assert_false(summary.texts.visible, "no Textos line")
	assert_false(summary.extras.visible)


func test_every_players_fate_in_co_op() -> void:
	var shell := _shell()
	shell.session._add_player(7)
	shell.session.roster[7] = "Dayana"
	shell.session._add_player(8)
	shell.session.roster[8] = "Papo"
	shell.session._remove_player(8)
	var dayana := shell.session.body(7).meters
	dayana.solo = false
	dayana.harm(100.0, &"reef_shark")
	dayana.tick(90.0, MeterContext.new())
	assert_true(dayana.dead)
	assert_eq(shell.flow, GameShell.Flow.RUN, "the host is still alive")
	_kill(shell.session.body(1))
	assert_eq(shell.flow, GameShell.Flow.SUMMARY)
	var summary := shell.screen as SummaryScreen
	assert_eq(summary.rows(), [
		"Balsero: Murió (sed)", "Dayana: Murió (Tiburón de arrecife)", "Papo: Murió (desconexión)",
	] as Array[String])
	var causes: Array[StringName] = []
	var ids: Array[StringName] = []
	var peers: Array[int] = []
	for entry: Dictionary in summary.summary.entries:
		causes.append(entry["cause"])
		ids.append(entry["line_id"])
		peers.append(entry["peer"])
	assert_eq(causes, [&"thirst", &"reef_shark", &"removed"] as Array[StringName])
	assert_eq(ids, [&"death_thirst_1", &"death_reef_shark_1", &"death_removed_1"] as Array[StringName])
	assert_eq(peers, [1, 7, 0] as Array[int])


func test_two_players_with_one_cause_get_different_lines() -> void:
	var shell := _shell()
	shell.session._add_player(7)
	_kill(shell.session.body(7))
	assert_eq(shell.flow, GameShell.Flow.RUN, "the host is still alive")
	_kill(shell.session.body(1))
	var entries: Array[Dictionary] = (shell.screen as SummaryScreen).summary.entries
	assert_eq(entries[0]["line_id"], &"death_thirst_1")
	assert_eq(entries[0]["peer"], 1)
	assert_eq(entries[1]["line_id"], &"death_thirst_2")
	assert_eq(entries[1]["peer"], 7)


func test_a_survivor_row() -> void:
	var screen := _screen_with([_entry("Balsero", false)] as Array[Dictionary])
	assert_eq(screen.rows()[0], "Balsero: Sobrevivió (se fue en: Balsa)")
	assert_false(screen.row(0).line.visible)
	assert_eq(screen.one_liners()[0], "")


func test_every_row_has_a_hidden_tip_slot() -> void:
	var screen := _screen_with([_entry("Balsero", true), _entry("Papo", false)] as Array[Dictionary])
	for index: int in 2:
		var tip := screen.row(index).get_node("Tip") as Label
		assert_not_null(tip, "row %d has a Tip" % index)
		assert_false(tip.visible)
		assert_eq(tip.text, "")
	screen.row(0).set_tip("Bebe antes de que la sed llegue a 0.")
	assert_true(screen.row(0).tip.visible)
	assert_eq(screen.tips()[0], "Bebe antes de que la sed llegue a 0.")
	screen.row(0).set_tip("")
	assert_false(screen.row(0).tip.visible)


func test_four_players_with_tips_fit_the_screen() -> void:
	var entries: Array[Dictionary] = []
	for player_name: String in ["Balsero", "Dayana", "Papo", "Yuni"]:
		entries.append(_entry(player_name, true))
	var screen := _screen_with(entries)
	for index: int in 4:
		screen.row(index).set_tip("y".repeat(120))
	await wait_frames(2)
	# menu-clarity design D4: the card is centred and its inset stops growing at 200 px.
	assert_eq(screen.panel.get_rect().size.x, 576.0)
	assert_almost_eq(screen.panel.get_rect().get_center(), Vector2(320.0, 180.0), Vector2(1.0, 1.0))
	assert_true(Rect2(0.0, 0.0, 640.0, 360.0).encloses(screen.panel.get_rect()))
	assert_eq(screen.scroll.custom_minimum_size.y, SummaryScreen.INSET_CAP_PX, "capped, then it scrolls")
	assert_true(screen.row(0).get_parent().get_parent() is ScrollContainer, "the rows scroll")


func test_the_hud_goes_when_the_summary_shows() -> void:
	var shell := _shell()
	var old: RunHud = shell.hud
	assert_not_null(old)
	_kill(shell.session.body(1))
	assert_null(shell.hud)
	await wait_frames(2)
	assert_false(is_instance_valid(old), "its pause menu goes with it")
	assert_false(get_tree().paused)


func test_two_islands_on_day_2_after_the_coast_cay() -> void:
	var shell := _shell()
	shell.travel.travel(&"coast_cay")
	await wait_process_frames(2)
	WeatherManager.sky.clock.set_time(500.0, 2)
	_kill(shell.session.body(1))
	var summary := shell.screen as SummaryScreen
	assert_eq(summary.islands.text, "Islas: 2")
	assert_eq(summary.days.text, "Días: 2")


func test_the_entry_keys_are_the_contract() -> void:
	var shell := _shell()
	_kill(shell.session.body(1))
	var keys: Array = (shell.screen as SummaryScreen).summary.entries[0].keys()
	keys.sort()
	assert_eq(keys, ["cause", "cause_label", "dead", "line", "line_id", "name", "peer"])



# menu-clarity design D4: the inset is as tall as its rows once they are laid out, so a wrapped
# one-liner is never cut.
func test_the_inset_fits_a_wrapped_one_liner() -> void:
	var entry := _entry("Balsero", true)
	entry["line"] = "Una sed más larga que el Período Especial, y eso es mucho decir. " + "Y más."
	var screen := _screen_with([entry] as Array[Dictionary])
	await wait_frames(3)
	var rows := screen.row(0).get_parent() as Control
	var border: float = screen.scroll.get_theme_stylebox(&"panel").get_minimum_size().y
	assert_gt(border, 0.0, "the inset has a border")
	assert_gte(screen.scroll.size.y - border, rows.get_combined_minimum_size().y - 0.5, "the inset shows every row line inside its border")
	assert_almost_eq(screen.scroll.size.y, rows.get_combined_minimum_size().y + border, 1.0, "and no more")
	assert_true(screen.row(0).line.get_line_count() >= 2, "the line wrapped")
