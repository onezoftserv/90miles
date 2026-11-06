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
	assert_eq(thirst.label.get_parent(), thirst.bar, "the label sits inside the bar")
	session.body(1).meters.thirst = 30.0
	assert_false(thirst.pulsing)


func test_solo_hud() -> void:
	var hud := _hud(_session(), true)
	assert_true(hud.meters.visible)
	assert_eq(hud.phase_label.text, "Día")
	assert_false(hud.teammates_panel.visible, "no teammate list in solo")
	assert_null(hud.wheel, "no quick-chat wheel in solo")


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
