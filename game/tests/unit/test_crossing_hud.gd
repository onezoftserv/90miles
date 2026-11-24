extends GutTest
## crossing "Crossing HUD and telegraphs" with exactly 1 player, offline: the strip shows the vessel
## at the elapsed share and its integrity out of the route's, the squall's two lines come 30 s and
## 10 s before its hit, a fin's line names its side, a leak's line shows as it opens, the HUD sits
## clear of the sign note's place, and only the crossing's riders see it.

const K := CrossingBeat.Kind
const SETTINGS_NAME: String = "test_crossing_hud_settings.cfg"


func _hud(crossing: Crossing) -> CrossingHud:
	return crossing.get_node_or_null("Hud") as CrossingHud


func test_solo_reads_the_strip() -> void:
	var crossing := CrossingRig.make(self, &"raft", 1, 100.0, 60.0, [CrossingRig.beat(5.0, K.SQUALL)])
	var body := crossing.body_of(1)
	CrossingRig.hold(crossing, body, 1.0)
	CrossingRig.release(crossing, body)
	CrossingRig.run(crossing, 30.0 - crossing.elapsed_s)
	var hud := _hud(crossing)
	assert_not_null(hud, "the crossing has its HUD")
	hud.local_peer = 1
	assert_almost_eq(hud.progress(), 0.5, 0.01, "the raft halfway")
	assert_eq(hud.integrity_text("es"), "Balsa 70/100")
	assert_eq(hud.integrity_text("en"), "Raft 70/100")


func test_the_squall_counts_down() -> void:
	var crossing := CrossingRig.make(self, &"raft", 1, 100.0, 90.0, [CrossingRig.beat(70.0, K.SQUALL)])
	var hud := _hud(crossing)
	hud.local_peer = 1
	CrossingRig.run(crossing, 39.9)
	assert_eq(hud.current_line(), "")
	CrossingRig.run(crossing, 0.2)
	assert_eq(hud.current_line(), "La raya negra viene pa'cá.")
	CrossingRig.run(crossing, 20.0)
	assert_eq(hud.current_line(), "¡Amárrate, que ahí viene!")
	CrossingRig.run(crossing, 4.0)
	assert_eq(hud.current_line(), "", "each line stays up 3 s")


func test_a_fin_and_a_leak_are_called_out() -> void:
	var beats: Array[RefCounted] = [CrossingBeat.create(30.0, K.SHARK_PASS, 0, CrossingBeat.Side.WEST), CrossingBeat.create(40.0, K.DEBRIS, 0)]
	var crossing := CrossingRig.make(self, &"raft", 1, 100.0, 60.0, beats)
	var hud := _hud(crossing)
	hud.local_peer = 1
	CrossingRig.run(crossing, 25.1)
	await wait_process_frames(2)
	assert_eq(hud.current_line(), "¡Aleta! Por la izquierda.")
	CrossingRig.run(crossing, 40.1 - crossing.elapsed_s)
	await wait_process_frames(2)
	assert_eq(hud.current_line(), "¡Un hueco! Tápalo.")


func test_the_hud_sits_clear_of_the_sign_note() -> void:
	var crossing := CrossingRig.make(self, &"raft", 1, 100.0, 60.0)
	var hud := _hud(crossing)
	var sign_note := Rect2(200.0, 22.0, 240.0, 38.0)
	assert_false(CrossingHud.STRIP_RECT.intersects(sign_note), "the strip")
	assert_false(CrossingHud.LINE_RECT.intersects(sign_note), "the line")
	assert_false(CrossingHud.STRIP_RECT.intersects(Rect2(140.0, 46.0, 360.0, 20.0)), "and the cay note label")
	assert_eq(hud.layer, CrossingHud.LAYER)


func test_only_the_crossings_riders_see_it() -> void:
	var crossing := CrossingRig.make(self, &"raft", 1, 100.0, 60.0)
	var hud := _hud(crossing)
	hud.local_peer = 1
	await wait_process_frames(2)
	assert_true((hud.get_node("Strip") as Control).visible, "the rider sees it")
	hud.local_peer = 7
	await wait_process_frames(2)
	assert_false((hud.get_node("Strip") as Control).visible, "someone still on the island does not")


func test_a_swimmer_reads_a_nado() -> void:
	var crossing := CrossingRig.make(self, &"binoculars_swim", 1, 0.0, 60.0)
	var hud := _hud(crossing)
	hud.local_peer = 1
	assert_eq(hud.integrity_text("es"), "A nado")


# --- the HUD window kit (hud-window-kit D14, task 3.4) -----------------------------------------------

func test_the_strip_and_line_are_kit_windows() -> void:
	var crossing := CrossingRig.make(self, &"raft", 1, 100.0, 90.0, [CrossingRig.beat(70.0, K.SQUALL)])
	var hud := _hud(crossing)
	hud.local_peer = 1
	var strip := hud.get_node("Strip") as PanelContainer
	var line := hud.get_node("LinePanel") as PanelContainer
	assert_eq(strip.theme_type_variation, &"HudPanel", "the strip is a HudPanel window")
	assert_eq(line.theme_type_variation, &"HudPanelThin", "the line a HudPanelThin row")
	assert_eq(CrossingHud.LINE_RECT.size.y, 10.0, "a 10 px row")
	assert_true(strip.is_in_group(RunHud.OUTSIDE_PANEL_GROUP) and line.is_in_group(RunHud.OUTSIDE_PANEL_GROUP))
	await wait_process_frames(2)
	assert_false(line.visible, "no empty row while nothing is said")
	CrossingRig.run(crossing, 40.1)
	await wait_process_frames(2)
	assert_true(line.visible, "the row shows with the squall's line")
	assert_eq(line.get_global_rect(), CrossingHud.LINE_RECT, "a 10 px row where the HUD puts it")
	assert_eq(strip.get_global_rect(), CrossingHud.STRIP_RECT, "and the strip's window keeps its rect")
	assert_false(strip.get_global_rect().intersects(line.get_global_rect()), "the two do not overlap")


func test_the_track_and_marker_are_palette_colours() -> void:
	var palette: PackedStringArray = []
	var file := FileAccess.open("res://assets/art/palette/master_palette.gpl", FileAccess.READ)
	while not file.eof_reached():
		var parts := file.get_line().strip_edges().split(" ", false)
		if parts.size() >= 3 and parts[0].is_valid_int():
			palette.append(Color8(parts[0].to_int(), parts[1].to_int(), parts[2].split("\t")[0].to_int()).to_html(false))
	for colour: Color in [CrossingHud.TRACK_AHEAD, CrossingHud.TRACK_DONE, HudStyle.SUN, HudStyle.OUTLINE]:
		assert_true(palette.has(colour.to_html(false)), "%s is a master palette colour" % colour.to_html(false))


func test_the_integrity_steps_at_half_and_a_quarter() -> void:
	var crossing := CrossingRig.make(self, &"raft", 1, 100.0, 60.0)
	var hud := _hud(crossing)
	hud.local_peer = 1
	assert_eq(hud.integrity_color(), HudStyle.CREAM, "cream when whole")
	crossing.integrity.value = 51.0
	assert_eq(hud.integrity_color(), HudStyle.CREAM)
	crossing.integrity.value = 50.0
	assert_eq(hud.integrity_color(), HudStyle.ORANGE, "orange at half")
	crossing.integrity.value = 25.0
	assert_eq(hud.integrity_color(), HudStyle.ALERT, "alert at a quarter")


func test_the_strip_stays_between_the_meters_and_the_teammates() -> void:
	for rect: Rect2 in [CrossingHud.STRIP_RECT, CrossingHud.LINE_RECT]:
		assert_gte(rect.position.x, 137.0, "clear of the meters (x 136 and less)")
		assert_lte(rect.end.x, 501.0, "clear of the teammate list (x 502 and more)")


func test_solo_run_hud_counts_the_crossing_strip() -> void:
	NetManager.start_solo()
	WeatherManager.stop()
	WeatherManager.sky.start_at(0.0)
	var shell := (preload("res://scenes/shell/game_shell.tscn") as PackedScene).instantiate() as GameShell
	shell.settings_path = UserTmp.path(SETTINGS_NAME)
	add_child_autofree(shell)
	(shell.screen as TitleScreen).solo_requested.emit()
	var body := shell.session.body(1)
	body.player_input.enabled = false
	var site := shell.session.get_node("RaftSite") as BuildSite
	body.global_position = site.global_position
	body.inventory.add(&"driftwood", 6)
	body.inventory.add(&"inner_tube", 2)
	body.inventory.add(&"rope", 3)
	site.deposit(body)
	site.work(1.0)
	(shell.session.get_node("Raft") as Raft).interactable.interacted.emit(body)
	var crossing := shell.crossings[0] as Crossing
	crossing.plan = CrossingPlan.create(60.0, [])
	await wait_process_frames(3)
	var run_hud := shell.hud as RunHud
	assert_not_null(run_hud)
	if run_hud != null:
		var strip_rect: Rect2 = (crossing.get_node("Hud/Strip") as Control).get_global_rect()
		assert_true(run_hud.panel_rects().has(strip_rect), "the prompt keeps clear of the strip %s in %s" % [strip_rect, run_hud.panel_rects()])
		assert_eq(strip_rect, CrossingHud.STRIP_RECT, "the strip keeps its rect in the kit's window")
	WeatherManager.stop()
	NetManager.leave()
	if FileAccess.file_exists(UserTmp.path(SETTINGS_NAME)):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(UserTmp.path(SETTINGS_NAME)))


func test_the_integrity_text_is_never_cut() -> void:
	FixtureRoutes.put_in()
	for route_id: StringName in [&"raft", &"test_car"]:
		var top: float = float((GameState.content.get_entry(&"routes", route_id) as RouteData).vessel_integrity)
		var crossing := CrossingRig.make(self, route_id, 1, top, 60.0)
		var hud := _hud(crossing)
		hud.local_peer = 1
		await wait_process_frames(2)
		var label := hud.get_node("Integrity") as Label
		var text_px: float = HudStyle.GLYPH_PX * label.text.length()
		assert_gte(label.size.x, text_px, "%s: \"%s\" fits its label" % [route_id, label.text])
		assert_gte(hud.track_rect().position.x, CrossingHud.LABEL_INSET_PX + text_px, "and the track starts after it")
		assert_gte(hud.track_rect().size.x, CrossingHud.TRACK_MIN_PX, "with room for the track")
	FixtureRoutes.take_out()
