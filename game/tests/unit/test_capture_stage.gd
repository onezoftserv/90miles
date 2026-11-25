extends GutTest
## art-guardacostas groups 7 and 8 (design.md D9, D10, D11; specs "Capture staging", "Capture advance
## cue"), with exactly 1 player offline (the game shell on the real sandbar) and with a host plus a client
## over ENet on localhost (NetHarness).
## - On `scene_started` the bars slide in over 0.5 s; `RunHud.set_staged` hides the meters, phase,
##   weather, teammates, strip, prompt, marks, floats, chips and call windows and keeps the scene panel;
##   input stays open; the camera eases to the docked boat and its landing; it all goes back at the end.
## - With no boat in sight the camera stays.
## - The panel is 440 px wide at x 100, its bottom at y 330, with a 36×36 portrait frame; Rodríguez's
##   lines show his portrait, a plea the pleader's own figure.
## - The arrow and "[E]" show once the line is revealed, blinking, on the host and in solo; a client sees
##   the drain bar over the hold of the Spanish text.

const SHELL_SCENE: PackedScene = preload("res://scenes/shell/game_shell.tscn")
const HUD_SCENE: PackedScene = preload("res://scenes/ui/run_hud.tscn")
const ISLAND_SCENE: PackedScene = preload("res://scenes/levels/sandbar_island.tscn")
const TILE: float = 16.0
const TIMEOUT_S: float = 6.0
var settings_path: String = UserTmp.path("test_capture_stage_settings.cfg")

var shell: GameShell
var session: CoopSession
var body: PlayerBody
var keeper: CaptureScene
var patrol: PatrolData
var net: NetHarness = null
var huds: Array[RunHud] = []


func before_each() -> void:
	NetManager.start_solo()
	WeatherManager.stop()
	WeatherManager.sky.start_at(0.0)
	WeatherManager.sky.weather.rolls_enabled = false
	patrol = (GameState.content.get_entry(&"creatures", &"patrol_boat") as CreatureData).patrol
	huds.clear()


func after_each() -> void:
	for hud: RunHud in huds:
		if is_instance_valid(hud):
			hud.queue_free()
	huds.clear()
	if net != null:
		net.teardown()
		net = null
	WeatherManager.sky.weather.rolls_enabled = true
	WeatherManager.sky.start_at(0.0)
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


# The solo run's boat docked by a spot on land, its squad ashore.
func _land_squad() -> Creature:
	var spawner := session.get_node(NodePath(SandbarIsland.CREATURES_NAME)) as CreatureSpawner
	spawner.world.weather_override = GameState.content.get_entry(&"weather", &"calm") as WeatherData
	var boat: Creature = spawner.creatures(&"patrol_boat")[0]
	var brain := boat.brain as PatrolRoute
	brain.set_clock(patrol.horizon_warning_s + 10.0)
	boat.advance(0.0)
	brain.spot(body, &"sight")
	body.global_position = Vector2(2.5, 2.5) * TILE
	body.stealth_state = MovementStep.Stealth.SUBMERGED
	for i: int in 100:
		if boat.squad_state == PatrolRoute.Squad.ASHORE:
			break
		boat.advance(0.1)
	assert_eq(boat.squad_state, PatrolRoute.Squad.ASHORE)
	return boat


func _capture() -> void:
	CaptureRules.capture(body, body, patrol)
	keeper.on_captured(body, null)
	await wait_process_frames(2)


# Spec "A solo player's capture is staged".
func test_a_solo_players_capture_is_staged_and_the_hud_comes_back() -> void:
	_start()
	await wait_physics_frames(2)
	var boat := _land_squad()
	var hud: RunHud = shell.hud
	var stage: CaptureStage = hud.capture_stage
	assert_not_null(stage, "the HUD stages the scene")
	assert_eq(stage.bars_in, 0.0)
	await _capture()
	assert_true(keeper.playing)
	assert_true(stage.staged)
	assert_true(hud.staged)
	stage.bars_in = 0.0
	stage.tick(0.25)
	assert_almost_eq(stage.bars_in, 0.5, 0.0001, "half in at 0.25 s")
	stage.tick(0.25)
	assert_eq(stage.bars_in, 1.0, "in after 0.5 s")
	assert_eq(stage.bar_rects()[0], Rect2(0.0, 0.0, 640.0, 28.0))
	assert_eq(stage.bar_rects()[1], Rect2(0.0, 332.0, 640.0, 28.0))
	for node_name: StringName in RunHud.STAGED_HIDDEN:
		var node := hud.get_node_or_null(NodePath(node_name)) as CanvasItem
		if node != null:
			assert_true(hud.is_staged_hidden(node), "%s is hidden" % node_name)
	assert_false(hud.is_staged_hidden(hud.scene_panel), "the scene panel stays")
	hud.scene_panel.step(0.0)
	assert_true(hud.scene_panel.visible)
	assert_false(hud.screen_shown, "input stays open")
	# The view frames the docked boat and its landing.
	var expected: Vector2 = CaptureStage.framing_offset(session, body)
	var landing: Vector2 = IslandLayout.cell_center(boat.landing)
	assert_eq(expected, (((boat.global_position + landing) / 2.0) + Vector2(0.0, CaptureStage.FRAME_LIFT_PX) - body.global_position).round(), "the boat and its landing, in the open middle")
	stage.tick(1.0)
	assert_eq(body.camera.offset, expected, "eased onto it")
	# The end: everything back.
	while keeper.playing:
		keeper.skip()
	await wait_process_frames(3)
	assert_false(stage.staged)
	assert_false(hud.staged)
	for node_name: StringName in RunHud.STAGED_HIDDEN:
		var node := hud.get_node_or_null(NodePath(node_name)) as CanvasItem
		if node != null:
			assert_false(hud.is_staged_hidden(node), "%s is back" % node_name)
	stage.tick(1.0)
	assert_eq(stage.bars_in, 0.0, "the bars slid out")
	assert_eq(body.camera.offset, Vector2.ZERO, "the camera is back on the player")


func test_with_no_boat_in_sight_the_view_stays() -> void:
	_start()
	await wait_physics_frames(2)
	var spawner := session.get_node(NodePath(SandbarIsland.CREATURES_NAME)) as CreatureSpawner
	var boat: Creature = spawner.creatures(&"patrol_boat")[0]
	(boat.brain as PatrolRoute).set_clock(1.0)
	boat.advance(0.0)
	assert_false(PatrolRoute.is_in_sight_state(boat.state_id), "the boat is on the horizon")
	assert_eq(CaptureStage.framing_offset(session, body), Vector2.ZERO)
	await _capture()
	shell.hud.capture_stage.tick(1.0)
	assert_eq(body.camera.offset, Vector2.ZERO)


# Spec "Capture staging" (the panel), "Capture advance cue" (the 1-player test).
func test_a_solo_capture_shows_rodriguezs_portrait_then_the_arrow_and_interact_skips() -> void:
	_start()
	await wait_physics_frames(2)
	await _capture()
	var panel: ScenePanel = shell.hud.scene_panel
	panel.step(0.0)
	assert_true(panel.visible)
	assert_eq(panel.card_rect().position.x, 100.0)
	assert_eq(panel.card_rect().size.x, 440.0)
	assert_eq(panel.card_rect().end.y, 330.0, "its bottom at y 330")
	assert_eq(panel.frame_rect().size, Vector2(36.0, 36.0))
	assert_eq(panel.portrait_rect().size, Vector2(32.0, 32.0))
	assert_true(panel.frame_rect().encloses(panel.portrait_rect()))
	assert_eq(panel.shown_name(), "El Capitán Rodríguez")
	var rodriguez := GameState.content.get_entry(&"npcs", &"rodriguez") as NpcData
	assert_not_null(rodriguez.portrait, "Rodríguez has a portrait")
	assert_eq(panel.shown_portrait(), rodriguez.portrait, "his portrait")
	assert_eq(rodriguez.portrait.get_size(), Vector2(32.0, 32.0))
	panel.elapsed_s = 0.0
	panel.step(0.0)
	assert_false(panel.arrow_shown(), "no arrow while the line reveals")
	panel.step(60.0)
	assert_eq(panel.revealed_chars(), panel.shown_text().length())
	# A whole blink cycle past the reveal: on for 0.3 s, off for 0.2 s.
	var revealed_at: float = ceilf(panel.shown_text().length() / 40.0 / 0.5) * 0.5
	panel.elapsed_s = revealed_at + 0.1
	panel.step(0.0)
	assert_true(panel.arrow_shown(), "the arrow once it is all shown")
	assert_true(panel.key_shown())
	assert_eq(panel.key_text(), "[E]")
	panel.elapsed_s = revealed_at + 0.4
	panel.step(0.0)
	assert_false(panel.arrow_shown(), "blinking off")
	assert_true(panel.key_shown(), "the key stays")
	var text_bottom: float = panel.card_rect().position.y + ScenePanel.PADDING.y + ScenePanel.LINE_HEIGHT * (ScenePanel.wrap_count(panel.shown_text()) + 1) + 2.0
	assert_gte(panel.key_rect().position.y, text_bottom, "the key sits under the text, not on it")
	assert_gte(panel.arrow_rect().position.y, text_bottom, "and the arrow")
	assert_eq(panel.arrow_tint(), HudStyle.OUTLINE, "dark on the light card")
	assert_false(panel.drain_shown(), "no drain bar where a press skips")
	var serial: int = keeper.current_serial
	var press := InputEventAction.new()
	press.action = &"interact"
	press.pressed = true
	Input.parse_input_event(press)
	await wait_process_frames(2)
	var release := InputEventAction.new()
	release.action = &"interact"
	release.pressed = false
	Input.parse_input_event(release)
	assert_eq(keeper.current_serial, serial + 1, "interact shows the next line")


func test_every_line_of_la_captura_fits_7_rows_at_the_new_width() -> void:
	assert_eq(ScenePanel.TEXT_WIDTH, 392.0, "49 glyphs")
	var scene := GameState.content.get_entry(&"dialogue", &"beat_la_captura") as DialogueData
	for entry: DialogueStateData in scene.states:
		for line: DialogueLineData in entry.lines:
			for text: String in [line.text_es, line.text_en]:
				assert_lte(ScenePanel.wrap_count(text), ScenePanel.MAX_LINES, "%s fits: %s" % [line.id, text])


func test_a_pleas_portrait_is_the_pleaders_figure_in_their_slot_colours() -> void:
	var slot0: Texture2D = ScenePanel.player_portrait(0)
	var slot1: Texture2D = ScenePanel.player_portrait(1)
	assert_not_null(slot0)
	assert_eq(slot0.get_size(), Vector2(32.0, 32.0))
	assert_same(ScenePanel.player_portrait(0), slot0, "cached")
	var ramps: Image = ArtTuning.standard().player_ramps.get_image()
	var key: Dictionary = {}
	for shade: int in PaletteSwap.SHADES:
		key[ramps.get_pixel(shade, PaletteSwap.KEY_ROW).to_html(false)] = true
	var image: Image = slot0.get_image()
	var keyed: int = 0
	for y: int in image.get_height():
		for x: int in image.get_width():
			var color: Color = image.get_pixel(x, y)
			if color.a > 0.0 and key.has(color.to_html(false)):
				keyed += 1
	assert_eq(keyed, 0, "the key ramp is swapped to the slot's colours")
	assert_ne(slot0.get_image().get_data(), slot1.get_image().get_data(), "another slot, other colours")


# --- host plus client (spec "Capture advance cue") ------------------------------------------------------

func _setup(for_session: CoopSession) -> void:
	var island := ISLAND_SCENE.instantiate() as SandbarIsland
	island.with_creatures = false
	for_session.get_parent().add_child(island)
	for_session.terrain = island.terrain
	for_session.climate = island.climate
	for_session.spawn_points = island.spawn_points(false)
	island.furnish(for_session)
	var travel := IslandTravel.new()
	travel.name = "Travel"
	for_session.add_child(travel)
	travel.setup(for_session, island)


func _hud(for_session: CoopSession, peer: int) -> RunHud:
	var hud := HUD_SCENE.instantiate() as RunHud
	add_child(hud)
	huds.append(hud)
	hud.bind(for_session, peer, false)
	return hud


func test_the_host_sees_the_arrow_and_a_client_the_drain_bar_over_the_spanish_hold() -> void:
	net = NetHarness.new(self)
	var host := net.add_host(_setup)
	var client := await net.join(_setup)
	assert_not_null(client)
	assert_true(await net.settle())
	net.silence_input()
	var id: int = net.peer_id(client)
	var host_hud := _hud(host, CoopSession.HOST_ID)
	var client_hud := _hud(client, id)
	client.locale = "en"
	client_hud.scene_panel.locale = "en"
	var leader := host.body(CoopSession.HOST_ID)
	for body_here: PlayerBody in [host.body(CoopSession.HOST_ID), host.body(id)]:
		CaptureRules.capture(body_here, leader, patrol)
	CaptureScene.of(host).queue_check()
	var playing := func() -> bool: return CaptureScene.of(client).playing and CaptureScene.of(client).current_serial > 0
	assert_true(await wait_until(playing, TIMEOUT_S), "the scene plays on the client")
	var host_panel: ScenePanel = host_hud.scene_panel
	var client_panel: ScenePanel = client_hud.scene_panel
	host_panel.step(0.0)
	client_panel.step(0.0)
	host_panel.elapsed_s = 60.0
	client_panel.elapsed_s = 0.0
	host_panel.step(0.0)
	client_panel.step(0.0)
	assert_true(host_panel.key_shown(), "the host can skip: the arrow's key")
	assert_false(host_panel.drain_shown())
	assert_false(client_panel.arrow_shown(), "a client cannot skip: no arrow")
	assert_false(client_panel.key_shown())
	assert_true(client_panel.drain_shown(), "the drain bar")
	var spanish: String = CaptureScene.of(client).current_text("es")
	assert_almost_eq(client_panel.hold_s(), CaptureScene.hold_s(spanish), 0.0001, "over the Spanish text's hold")
	assert_ne(client_panel.shown_text(), spanish, "while the client reads English")
	assert_almost_eq(client_panel.drain_fraction(), 1.0, 0.0001)
	client_panel.step(client_panel.hold_s() / 2.0)
	assert_almost_eq(client_panel.drain_fraction(), 0.5, 0.01, "half drained halfway through")
	assert_true(CaptureScene.of(client).playing)


# Spec "Each peer names its own loss" (art-guardacostas D13, task 9.3): a host with a lighter and a client
# with nothing that lights fire are caught together; after landing only the host's notice names it.
func test_only_the_host_whose_lighter_was_taken_is_told_so() -> void:
	net = NetHarness.new(self)
	var host := net.add_host(_setup)
	var client := await net.join(_setup)
	assert_not_null(client)
	assert_true(await net.settle())
	net.silence_input()
	var id: int = net.peer_id(client)
	var host_hud := _hud(host, CoopSession.HOST_ID)
	var client_hud := _hud(client, id)
	var mine := host.body(CoopSession.HOST_ID)
	mine.meters.morale = 40.0
	mine.inventory.add(&"lighter", 1)
	host.body(id).inventory.add(&"coco", 1)
	var client_shown: Array[PackedStringArray] = []
	CaptureScene.of(client).confiscation_shown.connect(func(ids: PackedStringArray) -> void: client_shown.append(ids))
	for caught: PlayerBody in [mine, host.body(id)]:
		CaptureRules.capture(caught, mine, patrol)
	CaptureScene.of(host).queue_check()
	assert_true(await wait_until(func() -> bool: return CaptureScene.of(host).playing, TIMEOUT_S), "the scene plays")
	var guard: int = 0
	while CaptureScene.of(host).playing and guard < 40:
		CaptureScene.of(host).skip()
		guard += 1
	assert_true(await wait_until(func() -> bool: return not CaptureScene.of(client).playing, TIMEOUT_S), "the scene ended on the client")
	await wait_seconds(0.5)
	assert_eq(mine.inventory.count_id(&"lighter"), 0, "the lighter was taken")
	assert_eq(CaptureScene.of(host).last_report.get(CoopSession.HOST_ID, PackedStringArray()), PackedStringArray(["lighter"]))
	assert_false(CaptureScene.of(host).last_report.has(id), "the client lost nothing")
	assert_eq(host_hud.notice.shown_text(), "Te quitaron: Fosforera", "the host is told")
	assert_eq(client_shown.size(), 0, "the client is told nothing")
	assert_false(client_hud.notice.shown_text().begins_with("Te quitaron"))
