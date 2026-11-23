extends GutTest
## guardacostas-capture, group 9 (design.md §9 and §10, specs "The capture scene", "Persuasion check",
## "Capture outcome", "Release at the next island"), with exactly 1 player, offline: a capture plays
## `la_captura` at once. Its lines address the one player in the singular, the act is formal, a second
## capture opens with "¿otra vez?", the outcome's lines and effects run (the release, the return, the
## car return), a player with no background fails the check, a Médico at 65 talks their way out, the
## player is out of play while it plays, and the speaker on a tie is the higher morale, then the
## earlier join. A downed teammate taken along is test_capture_net.gd's (it needs a second player).

const SHELL_SCENE: PackedScene = preload("res://scenes/shell/game_shell.tscn")
const FOTO: ItemData = preload("res://tests/fixtures/content/items/foto_test.tres")
var settings_path: String = UserTmp.path("test_capture_scene_settings.cfg")
const COAST: StringName = &"coast_cay"
const SANDBAR: StringName = &"sandbar"
const CONTRACTIONS: Array[String] = ["pa'", "'tá", "'toy", "na'", "to'", "saca'o", "pasa'o"]

var shell: GameShell
var session: CoopSession
var body: PlayerBody
var keeper: CaptureScene
var patrol: PatrolData
var lines: Array[StringName] = []
var texts: Array[String] = []
var speakers: Array[String] = []


func before_each() -> void:
	NetManager.start_solo()
	WeatherManager.stop()
	WeatherManager.sky.start_at(0.0)
	FixtureIslands.put_in()
	lines = []
	texts = []
	speakers = []
	patrol = (GameState.content.get_entry(&"creatures", &"patrol_boat") as CreatureData).patrol


func after_each() -> void:
	FixtureIslands.take_out()
	WeatherManager.stop()
	NetManager.leave()
	if FileAccess.file_exists(settings_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(settings_path))


func _start() -> void:
	shell = SHELL_SCENE.instantiate() as GameShell
	shell.settings_path = settings_path
	add_child_autofree(shell)
	(shell.screen as TitleScreen).solo_requested.emit()
	session = shell.session
	body = session.body(CoopSession.HOST_ID)
	body.player_input.enabled = false
	keeper = CaptureScene.of(session)
	keeper.line_changed.connect(func() -> void:
		lines.append(keeper.current_line_id)
		texts.append(keeper.current_text("es"))
		speakers.append(keeper.current_speaker_name("es")))


func _go(id: StringName) -> void:
	shell.travel.travel(id)
	await wait_process_frames(2)


# A soldier's capture of the solo player: the whole party, so the scene begins.
func _capture() -> void:
	CaptureRules.capture(body, body, patrol)
	keeper.on_captured(body, null)
	await wait_process_frames(2)


# Plays the scene to its end, line by line (the host may skip).
func _play_out() -> void:
	var guard: int = 0
	while keeper.playing and guard < 40:
		keeper.skip()
		guard += 1
	await wait_process_frames(3)


func _is_contracted(text: String) -> bool:
	for contraction: String in CONTRACTIONS:
		if text.contains(contraction):
			return true
	return false


# --- the lines ------------------------------------------------------------------------------------

# Spec "Alone with the captain".
func test_alone_the_captain_speaks_in_the_singular_reads_the_act_formally_and_ends_with_the_outcome() -> void:
	_start()
	await _capture()
	assert_true(keeper.playing, "la_captura plays at once")
	await _play_out()
	assert_gt(lines.size(), 3)
	assert_eq(lines[0], &"captura_open_1", "the singular opening")
	for id: StringName in lines:
		assert_false(String(id).contains("plural"), "%s addresses one player" % id)
	assert_true(lines.has(&"captura_act_singular_acta"), "the act")
	var act: String = texts[lines.find(&"captura_act_singular_acta")]
	assert_false(_is_contracted(act), "read in formal Spanish: %s" % act)
	var cuban: bool = false
	for i: int in texts.size():
		if not String(lines[i]).ends_with("_acta") and _is_contracted(texts[i]):
			cuban = true
	assert_true(cuban, "in person he speaks Cuban")
	assert_eq(speakers[0], "El Capitán Rodríguez")
	assert_eq(lines.back(), &"captura_return_acta", "the scene ends with the outcome's lines")


# --- the check and the outcomes -------------------------------------------------------------------

# Spec "No background, no way out": morale 90 and no background restarts the previous island.
func test_no_background_fails_the_check_and_restarts_the_previous_island() -> void:
	_start()
	body.meters.morale = 90.0
	await _go(COAST)
	await _capture()
	await _play_out()
	assert_false(lines.has(&"captura_plea_medico_singular"))
	assert_false(lines.has(&"captura_plea_maestro_singular"))
	assert_true(lines.has(&"captura_return_singular"))
	assert_eq(shell.island.layout.id, SANDBAR, "back to the previous island")
	assert_false(body.captive)
	assert_false(body.left_island, "in play again")


# Spec "Solo capture fails": island 3, a Pescador at morale 40 with a knife, 3 rope, a lighter and the
# Foto restarts island 2 with the knife, the rope and the Foto, without the lighter.
func test_solo_capture_on_island_3_fails_and_restarts_island_2_without_the_lighter() -> void:
	_start()
	await _go(&"chain_b")
	await _go(&"chain_c")
	assert_eq(shell.travel.islands_reached, 3)
	body.meters.morale = 40.0
	body.inventory.register(FOTO)
	body.inventory.add(&"knife", 1)
	body.inventory.add(&"rope", 3)
	body.inventory.add(&"lighter", 1)
	body.inventory.add(&"foto_test", 1)
	await _capture()
	await _play_out()
	assert_eq(shell.island.layout.id, &"chain_b", "island 2")
	assert_eq(body.inventory.count_id(&"knife"), 1)
	assert_eq(body.inventory.count_id(&"rope"), 3)
	assert_eq(body.inventory.count_id(&"foto_test"), 1, "the keepsake")
	assert_eq(body.inventory.count_id(&"lighter"), 0, "no fire sources")
	assert_eq(shell.travel.islands_reached, 3, "nothing counted twice")
	assert_true(session.run_record.has_flag(&"captura_previa"))


# Spec "Solo Médico talks their way out": released on the coast cay, keeping everything.
func test_a_solo_medico_at_65_talks_their_way_out_onto_the_coast_cay() -> void:
	_start()
	FixtureBackgrounds.give(body, &"medico")
	body.meters.morale = 65.0
	body.inventory.add(&"lighter", 1)
	body.inventory.add(&"rope", 3)
	await _capture()
	await _play_out()
	assert_true(lines.has(&"captura_plea_medico_singular"), "the Médico's plea")
	assert_eq(speakers[lines.find(&"captura_plea_medico_singular")], session.player_name(CoopSession.HOST_ID), "said by the player")
	assert_true(lines.has(&"captura_release_singular_acta"))
	assert_eq(shell.island.layout.id, COAST, "released on the next island")
	assert_eq(body.position, IslandLayout.cell_center(shell.island.built.landing_cells()[0]), "its first landing cell")
	assert_eq(body.inventory.count_id(&"lighter"), 1, "a release keeps every item")
	assert_eq(body.inventory.count_id(&"rope"), 3)
	assert_null(session.get_node_or_null("Raft"), "no vessel beached")
	assert_eq(shell.travel.islands_reached, 2)


func test_a_maestro_below_60_fails_and_one_at_60_passes() -> void:
	_start()
	FixtureBackgrounds.give(body, &"maestro")
	body.meters.morale = 59.0
	await _capture()
	await _play_out()
	assert_true(lines.has(&"captura_return_singular"), "59 fails")
	assert_eq(shell.island.layout.id, SANDBAR)
	lines.clear()
	texts.clear()
	speakers.clear()
	body.meters.morale = 60.0
	await _capture()
	await _play_out()
	assert_true(lines.has(&"captura_plea_maestro_singular"), "60 passes")
	assert_eq(shell.island.layout.id, COAST)


# Spec "Released from the last island": the coast cay names no next island, so the run ends.
func test_a_release_from_the_coast_cay_ends_the_run() -> void:
	_start()
	await _go(COAST)
	FixtureBackgrounds.give(body, &"medico")
	body.meters.morale = 65.0
	await _capture()
	await _play_out()
	assert_true(lines.has(&"captura_release_singular_acta"))
	assert_eq(shell.flow, GameShell.Flow.SUMMARY, "the run summary shows")


# Spec "The car went down".
func test_after_the_almendron_the_car_lines_play_and_almendron_hundido_is_set() -> void:
	_start()
	session.run_record.set_flag(&"almendron_a_bordo")
	await _capture()
	await _play_out()
	assert_true(lines.has(&"captura_car_singular"))
	assert_true(lines.has(&"captura_car_acta"))
	assert_lt(lines.find(&"captura_car_acta"), lines.find(&"captura_return_singular"), "before the return's lines")
	assert_true(session.run_record.has_flag(&"almendron_hundido"))
	assert_eq(shell.island.layout.id, SANDBAR, "returned")


# Spec "Caught again".
func test_a_second_capture_opens_with_otra_vez() -> void:
	_start()
	await _capture()
	await _play_out()
	assert_eq(lines[0], &"captura_open_1")
	lines.clear()
	texts.clear()
	speakers.clear()
	await _capture()
	await _play_out()
	assert_eq(lines[0], &"captura_open_again", "¿Tú otra vez?")
	assert_true(texts[0].contains("otra vez"))


# --- out of play ----------------------------------------------------------------------------------

func test_the_player_is_out_of_play_while_the_scene_plays() -> void:
	_start()
	await _capture()
	assert_true(keeper.playing)
	assert_true(body.left_island, "out of play")
	assert_false(body.visible)
	assert_eq(shell.travel.check(), IslandTravel.Outcome.PLAYING, "nothing else moves the party meanwhile")
	assert_eq(shell.flow, GameShell.Flow.RUN)
	# The scene holds each line for its reveal at 40 chars/s plus 2 s.
	var text: String = keeper.current_text("es")
	assert_almost_eq(CaptureScene.hold_s(text), text.length() / 40.0 + 2.0, 0.000001)
	await _play_out()
	assert_false(keeper.playing)
	assert_false(body.left_island)


# --- the speaker ----------------------------------------------------------------------------------

func test_on_a_tie_the_higher_morale_speaks_then_the_earlier_join() -> void:
	var first := preload("res://scenes/player/player.tscn").instantiate() as PlayerBody
	var second := preload("res://scenes/player/player.tscn").instantiate() as PlayerBody
	add_child_autofree(first)
	add_child_autofree(second)
	first.meters.morale = 70.0
	second.meters.morale = 80.0
	assert_eq(CaptureScene.pick_speaker([first, second] as Array[PlayerBody]), second, "the higher morale")
	second.meters.morale = 70.0
	assert_eq(CaptureScene.pick_speaker([first, second] as Array[PlayerBody]), first, "then the earlier join")


# --- the panel ------------------------------------------------------------------------------------

func test_the_panel_shows_the_speaker_and_reveals_the_line_at_40_chars_per_second() -> void:
	_start()
	var panel := shell.hud.get_node_or_null(^"ScenePanel") as ScenePanel
	assert_not_null(panel, "the HUD holds the scene panel")
	panel.step(0.0)
	assert_false(panel.visible, "hidden until a scene plays")
	await _capture()
	panel.step(0.0)
	assert_true(panel.visible)
	assert_eq(panel.shown_name(), "El Capitán Rodríguez")
	assert_eq(panel.shown_text(), keeper.current_text("es"))
	# The panel's own frames ran while the test waited: count from now.
	panel.elapsed_s = 0.0
	panel.step(0.0)
	assert_eq(panel.revealed_chars(), 0)
	panel.step(0.5)
	assert_eq(panel.revealed_chars(), 20, "40 chars/s")
	panel.step(60.0)
	assert_eq(panel.revealed_chars(), panel.shown_text().length(), "all of it in the end")
	var view := Rect2(Vector2.ZERO, Vector2(640.0, 360.0))
	assert_true(view.encloses(panel.card_rect()), "the card fits the 640×360 view: %s" % panel.card_rect())
	# The card grows with the wrapped text: every line of the scene sits inside it.
	while keeper.playing:
		panel.step(0.0)
		var wrapped: int = ScenePanel.wrap_count(panel.shown_text())
		assert_gte(panel.card_rect().size.y, ScenePanel.LINE_HEIGHT * (wrapped + 1), "%d lines inside the card" % wrapped)
		assert_true(view.encloses(panel.card_rect()))
		keeper.skip()
	await _capture()
	await _play_out()
	panel.step(0.0)
	assert_false(panel.visible, "gone when the scene ends")


func test_every_line_of_la_captura_fits_the_panel_in_both_languages() -> void:
	var scene := GameState.content.get_entry(&"dialogue", &"beat_la_captura") as DialogueData
	for entry: DialogueStateData in scene.states:
		for line: DialogueLineData in entry.lines:
			for text: String in [line.text_es, line.text_en]:
				assert_lte(ScenePanel.wrap_count(text), ScenePanel.MAX_LINES, "%s fits: %s" % [line.id, text])
