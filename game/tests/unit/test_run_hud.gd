extends GutTest
## ui-shell "HUD layout" and coop-networking "No quick chat in solo": meters top-left with the
## label inside the bar and a critical pulse, the day phase, teammates top-right in co-op only,
## name tags over teammates, and no quick-chat wheel in solo.

const SESSION_SCENE: PackedScene = preload("res://scenes/net/coop_session.tscn")
const HUD_SCENE: PackedScene = preload("res://scenes/ui/run_hud.tscn")
const M := DataEnums.Meter


func before_each() -> void:
	NetManager.start_solo()


func _session(extra: Array[int] = []) -> CoopSession:
	var session := SESSION_SCENE.instantiate() as CoopSession
	session.local_name = "Yuni"
	add_child_autofree(session)
	session.start()
	for peer_id: int in extra:
		session._add_player(peer_id)
		session.roster[peer_id] = "Papo"
	for peer_id: int in session.peer_ids():
		session.body(peer_id).player_input.enabled = false
	return session


func _hud(session: CoopSession, solo: bool) -> RunHud:
	var hud := HUD_SCENE.instantiate() as RunHud
	add_child_autofree(hud)
	hud.bind(session, 1, solo)
	return hud


func test_critical_thresholds() -> void:
	assert_true(MeterBar.is_critical(M.THIRST, 25.0))
	assert_false(MeterBar.is_critical(M.THIRST, 25.5))
	assert_true(MeterBar.is_critical(M.HEALTH, 3.0))
	assert_true(MeterBar.is_critical(M.HEAT, 75.0), "heat is critical when high")
	assert_false(MeterBar.is_critical(M.HEAT, 20.0))


func test_critical_thirst() -> void:
	var session := _session()
	var hud := _hud(session, true)
	var thirst := hud.meters.bar_for(M.THIRST)
	session.body(1).meters.thirst = 20.0
	assert_true(thirst.pulsing)
	assert_eq(thirst.value_label.text, "20")
	await wait_process_frames(2)
	assert_lt(thirst.label.get_global_rect().end.x, thirst.box.get_global_rect().position.x + 0.5, "the label sits left of the bar")
	assert_true(thirst.label_color().is_equal_approx(HudStyle.ALERT), "a steady alert red")
	session.body(1).meters.thirst = 30.0
	assert_false(thirst.pulsing)


func test_solo_hud() -> void:
	var hud := _hud(_session(), true)
	assert_true(hud.meters.visible)
	assert_eq(hud.phase_label.text, "Día")
	assert_false(hud.teammates_panel.visible, "no teammate list in solo")
	assert_null(hud.wheel, "no quick-chat wheel in solo")


func test_solo_never_drops_and_has_no_teammate_rows() -> void:
	# ui-shell "Teammate state word", 1 player offline: nobody to drop, no rows, no word.
	var session := _session()
	var hud := _hud(session, true)
	hud.refresh()
	assert_false(session.is_dropped(CoopSession.HOST_ID))
	assert_false(session.body(CoopSession.HOST_ID).net.net_dropped)
	assert_false(hud.teammates_panel.visible)
	assert_eq(hud.teammate_rows(), [] as Array[String])


func test_the_phase_names() -> void:
	var climate := ClimateState.new()
	climate.phase = DataEnums.DayPhase.DAY
	climate.midday = true
	assert_eq(RunHud.phase_name(climate), "Mediodía")
	climate.phase = DataEnums.DayPhase.NIGHT
	assert_eq(RunHud.phase_name(climate), "Noche")
	climate.phase = DataEnums.DayPhase.DAWN
	assert_eq(RunHud.phase_name(climate), "Amanecer")
	climate.phase = DataEnums.DayPhase.DUSK
	assert_eq(RunHud.phase_name(climate), "Atardecer")


func test_teammate_down() -> void:
	var session := _session([7] as Array[int])
	var hud := _hud(session, false)
	var papo := session.body(7)
	papo.meters.health = 0.0
	papo.set_downed(true)
	hud.refresh()
	assert_true(hud.teammates_panel.visible)
	assert_eq(hud.teammate_rows(), ["Papo 0 Caído"] as Array[String])
	var tag := papo.get_node_or_null(^"NameTag") as NameTag
	assert_not_null(tag, "a name tag over the teammate")
	if tag != null:
		tag.refresh()
		assert_eq(tag.label.text, "Papo")
		assert_true(tag.visible, "shown while health is not full")
	assert_null(session.body(1).get_node_or_null(^"NameTag"), "none over the local player")


func test_a_healthy_teammate_has_no_tag_showing() -> void:
	var session := _session([7] as Array[int])
	_hud(session, false)
	var tag := session.body(7).get_node(^"NameTag") as NameTag
	tag.refresh()
	assert_false(tag.visible)


func test_state_words() -> void:
	var session := _session([7] as Array[int])
	var papo := session.body(7)
	assert_eq(RunHud.state_word(papo, false), "")
	assert_eq(RunHud.state_word(papo, true), "Desconectado")
	papo.meters.dead = true
	assert_eq(RunHud.state_word(papo, false), "Muerto")


func test_co_op_has_the_wheel() -> void:
	var hud := _hud(_session([7] as Array[int]), false)
	assert_not_null(hud.wheel)


func test_no_quick_chat_in_solo() -> void:
	var session := _session()
	var hud := _hud(session, true)
	watch_signals(session)
	Input.action_press(QuickChatWheel.ACTION)
	for node: Node in hud.get_children():
		if node.has_method(&"_process"):
			node.call(&"_process", 0.0)
	Input.action_release(QuickChatWheel.ACTION)
	assert_signal_not_emitted(session, "quick_chat_shown")
	assert_null(session.body(1).get_node_or_null(^"SpeechBubble"))


func test_the_hud_has_a_pause_menu_on_its_session() -> void:
	var session := _session()
	var hud := _hud(session, true)
	assert_eq(hud.pause_menu.session, session)


func test_a_late_name_reaches_the_tag() -> void:
	# A peer spawned before its join request arrived is tagged with the fallback, then renamed.
	var session := _session([7] as Array[int])
	session.roster.erase(7)
	_hud(session, false)
	var tag := session.body(7).get_node(^"NameTag") as NameTag
	assert_eq(tag.label.text, GameSettings.DEFAULT_NAME)
	session.roster[7] = "Papo"
	session.roster_updated.emit()
	assert_eq(tag.label.text, "Papo")


func test_a_reclaimed_body_becomes_the_local_player() -> void:
	# This peer (9) rejoined: the body it spawned with as peer 7 is handed to it.
	var session := _session([7] as Array[int])
	var hud := HUD_SCENE.instantiate() as RunHud
	add_child_autofree(hud)
	hud.bind(session, 9, false)
	var reclaimed := session.body(7)
	assert_not_null(reclaimed.get_node_or_null(^"NameTag"), "tagged while it was someone else's")
	session._rebind_body(7, 9)
	assert_null(reclaimed.get_node_or_null(^"NameTag"), "no tag over your own player")
	assert_eq(hud.meters.shown(), reclaimed.meters, "its meters fill the meters panel")


# --- hud-window-kit: the teammate blocks (design D7, owner answer B1) -----------------------------

const LIST_BOUNDS: Rect2 = Rect2(502.0, 4.0, 134.0, 86.0)


func _crew() -> Array:
	var session := _session([5, 6, 7] as Array[int])
	session.roster[5] = "Dayana"
	session.roster[6] = "Maximiliano Pérez"
	session.roster[7] = "Papo"
	return [session, _hud(session, false)]


func test_the_list_is_right_anchored_inside_x_502_to_636() -> void:
	var pair := _crew()
	var session: CoopSession = pair[0]
	var hud: RunHud = pair[1]
	session.roster[6] = "Ñico de la Loma1"
	assert_eq(session.roster[6].length(), 16, "the longest name a player may have")
	session._dropped[6] = CoopSession.DISCONNECT_DOWNED_S
	session.body(7).meters.health = 0.0
	session.body(7).set_downed(true)
	hud.refresh()
	await wait_process_frames(2)
	var panel := hud.teammates_panel.get_global_rect()
	assert_eq(panel.end.x, 636.0, "its right edge on 636")
	assert_true(LIST_BOUNDS.encloses(panel), "three teammates inside x 502-636 and y 4-90: %s" % panel)
	var phase := (hud.get_node(^"PhasePanel") as Control).get_global_rect()
	assert_false(panel.intersects(phase), "clear of the day phase")
	assert_false(panel.intersects(Rect2(SignNote.POSITION, Vector2(SignNote.WIDTH, 200.0))), "clear of the sign note's place")
	var blocks := hud.teammate_blocks()
	assert_eq(blocks.size(), 3)
	var long := blocks[1]
	assert_eq(long.name_label.text, "Ñico de la Loma1", "the whole name")
	assert_true(panel.encloses(long.name_label.get_global_rect()), "the 16-glyph name fits")
	assert_eq(long.state_label.text, "Desconectado")
	assert_true(panel.encloses(long.state_label.get_global_rect()), "Desconectado fits")


func test_state_words_take_their_colours() -> void:
	var pair := _crew()
	var session: CoopSession = pair[0]
	var hud: RunHud = pair[1]
	session._dropped[6] = CoopSession.DISCONNECT_DOWNED_S
	session.body(7).meters.health = 0.0
	session.body(7).set_downed(true)
	session.body(5).meters.dead = true
	hud.refresh()
	var blocks := hud.teammate_blocks()
	assert_eq(blocks[0].state_label.text, "Muerto")
	assert_eq(blocks[0].state_label.theme_type_variation, &"AlertLabel")
	assert_eq(blocks[1].state_label.text, "Desconectado")
	assert_true(blocks[1].state_label.get_theme_color(&"font_color").is_equal_approx(TeammateBlock.DROPPED_COLOR))
	assert_eq(blocks[2].state_label.text, "Caído")
	assert_eq(blocks[2].state_label.theme_type_variation, &"AlertLabel")
	assert_eq(hud.teammate_rows(), ["Dayana 100 Muerto", "Maximiliano Pérez 100 Desconectado", "Papo 0 Caído"] as Array[String])


func test_each_block_shows_its_chip_and_health() -> void:
	var pair := _crew()
	var session: CoopSession = pair[0]
	var hud: RunHud = pair[1]
	session.body(5).meters.health = 40.0
	session.body(7).meters.health = 1.0
	hud.refresh()
	var blocks := hud.teammate_blocks()
	var others: Array[int] = [5, 6, 7]
	for i: int in blocks.size():
		var slot: int = session.body(others[i]).look_slot
		assert_true(blocks[i].chip.color.is_equal_approx(TeammateBlock.chip_color(slot)), "block %d's chip is look slot %d's base" % [i, slot])
	assert_eq(blocks[0].bar.value, 40.0)
	assert_gte(roundi(blocks[2].bar.value / 100.0 * blocks[2].bar.size.x), 1, "1 health still fills a pixel")
	assert_true(TeammateBlock.chip_color(0).is_equal_approx(Color("#5b6ee1")), "slot 0's base shade")


func test_solo_has_no_teammate_block() -> void:
	var hud := _hud(_session(), true)
	hud.refresh()
	assert_false(hud.teammates_panel.visible)
	assert_eq(hud.teammate_blocks().size(), 0, "one player, offline: no block")


func test_a_host_alone_shows_no_empty_list() -> void:
	var hud := _hud(_session(), false)
	hud.refresh()
	assert_false(hud.teammates_panel.visible, "no teammate yet: no empty window in the corner")


## art-mood-pass D5: the weather's own window right of the day phase, shown only while the weather
## is not clear, on a solo run.
const WEATHER_BAND_TOP: float = 4.0
const WEATHER_BAND_BOTTOM: float = 18.0
## hud-window-kit's teammate column and the crossing HUD's band (constants until they land).
const KIT_TEAMMATE_LEFT: float = 502.0
const CROSSING_BAND: Rect2 = Rect2(0.0, 68.0, 640.0, 22.0)


func _solo_in(weather_id: StringName, locale: String = "es") -> RunHud:
	WeatherManager.stop()
	WeatherManager.sky.start_at(200.0)
	var session := _session()
	session.locale = locale
	session.climate = WeatherManager.sky.climate
	var hud := _hud(session, true)
	WeatherManager.sky.weather.start_weather(weather_id)
	hud.refresh()
	return hud


func after_each() -> void:
	WeatherManager.stop()
	WeatherManager.sky.start_at(200.0)


func test_a_solo_squall_names_itself_beside_the_phase() -> void:
	var hud := _solo_in(&"squall")
	var panel := hud.get_node_or_null(^"WeatherPanel") as PanelContainer
	assert_not_null(panel, "a WeatherPanel")
	if panel == null:
		return
	assert_true(panel.visible, "shown in a squall")
	assert_eq(hud.weather_label.text, "Turbonada")
	assert_eq(panel.mouse_filter, Control.MOUSE_FILTER_IGNORE)


func test_an_english_session_reads_squall() -> void:
	var hud := _solo_in(&"squall", "en")
	assert_eq(hud.weather_label.text, "Squall")


func test_calm_shows_no_weather() -> void:
	var hud := _solo_in(&"calm")
	var panel := hud.get_node_or_null(^"WeatherPanel") as PanelContainer
	assert_not_null(panel)
	if panel != null:
		assert_false(panel.visible, "calm is clear: nothing to name")


func test_the_weather_window_fits_its_band_and_clears_every_other_window() -> void:
	var hud := _solo_in(&"squall")
	await wait_process_frames(2)
	var panel := hud.get_node_or_null(^"WeatherPanel") as Control
	assert_not_null(panel)
	if panel == null:
		return
	var rect := panel.get_global_rect()
	assert_true(rect.position.y >= WEATHER_BAND_TOP and rect.end.y <= WEATHER_BAND_BOTTOM, "inside y 4-18: %s" % rect)
	assert_true(rect.encloses((hud.weather_label as Control).get_global_rect()), "Turbonada fits its window")
	# The meters' root fills the screen; its window is its Panel.
	for path: NodePath in [^"PhasePanel", ^"TeammatesPanel", ^"Needle", ^"NoteLabel", ^"Meters/Panel"]:
		var other_rect := (hud.get_node(path) as Control).get_global_rect()
		assert_false(rect.intersects(other_rect), "clear of %s %s" % [path, other_rect])
	assert_false(rect.intersects(hud.sign_note.card_rect()), "clear of the sign note's card")
	assert_false(rect.intersects(Rect2(SignNote.POSITION, Vector2(SignNote.WIDTH, 200.0))), "and of its place")
	assert_lt(rect.end.x, KIT_TEAMMATE_LEFT, "left of the kit's teammate column")
	assert_false(rect.intersects(CROSSING_BAND), "above the crossing HUD's band")

