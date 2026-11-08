extends GutTest
## inventory-hud "Refused uses" (On the crossing) and design D11, with exactly 1 player, offline:
## the owner chose to refuse items at sea (2026-11-08), matching the host, which refuses every use
## from a rider for the whole crossing. During a real raft crossing the selected rain cup's line
## names no "[F]", F shows "En plena travesía no se puede.", nothing is sent and the cup stays.
## The run goes through the game shell, so the island's routes mark the player as departed; the
## crossing is advanced with CrossingRig, and the strip's `_process` by hand in 0.1 s steps.

const SHELL_SCENE: PackedScene = preload("res://scenes/shell/game_shell.tscn")
const SETTINGS_PATH: String = "user://test_use_on_crossing_settings.cfg"
const STEP_S: float = 0.1
const AT_SEA_LINE: String = "En plena travesía no se puede."


func before_each() -> void:
	NetManager.start_solo()
	WeatherManager.stop()
	WeatherManager.sky.start_at(0.0)


func after_each() -> void:
	_f(false)
	Input.action_release(InventoryStrip.USE_ACTION)
	WeatherManager.stop()
	NetManager.leave()
	if FileAccess.file_exists(SETTINGS_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SETTINGS_PATH))


# A solo shell run with the raft built and launched on a calm 60 s crossing.
func _launch() -> Array:
	var shell := SHELL_SCENE.instantiate() as GameShell
	shell.settings_path = SETTINGS_PATH
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
	crossing.plan = CrossingPlan.create(60.0)
	return [shell, crossing]


func _f(pressed: bool) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = KEY_F
	event.keycode = KEY_F
	event.pressed = pressed
	Input.parse_input_event(event)
	Input.flush_buffered_events()


func _hold(hud: RunHud, seconds: float) -> void:
	for i: int in roundi(seconds / STEP_S):
		hud.strip._process(STEP_S)


func test_at_sea_the_rain_cup_is_refused_and_stays() -> void:
	var launched := _launch()
	var shell := launched[0] as GameShell
	var crossing := launched[1] as Crossing
	var body := shell.session.body(1)
	CrossingRig.run(crossing, 5.0)
	assert_eq(crossing.rider_state(1), Crossing.Rider.ABOARD, "under way")
	assert_true(shell.session.has_left(1), "the player left the island by raft")
	assert_false(body.left_island, "and is still in play: the crossing has not ended")
	body.meters.thirst = 50.0
	body.inventory.add(&"rain_cup", 1)
	var hud := shell.hud
	watch_signals(hud.strip)
	hud.strip.select(0)
	_hold(hud, STEP_S)
	assert_true(hud.strip.visible, "the strip stays at sea")
	assert_eq(hud.strip.item_line.text, "Vaso de agua de lluvia", "the line names no [F] and no verb")
	_f(true)
	_hold(hud, 1.5)
	assert_eq(hud.notice.shown_text(), AT_SEA_LINE)
	assert_signal_emit_count(hud.strip, "use_sent", 0, "nothing is sent")
	assert_eq(body.inventory.count_id(&"rain_cup"), 1, "the cup stays")
	assert_eq(body.meters.thirst, 50.0)
	assert_false(shell.session.use_for(1, 0, 0, 0), "the host refuses a rider too, as it does today")


func test_back_on_land_the_line_names_f_again() -> void:
	var launched := _launch()
	var shell := launched[0] as GameShell
	var body := shell.session.body(1)
	body.inventory.add(&"rain_cup", 1)
	var hud := shell.hud
	hud.strip.select(0)
	_hold(hud, STEP_S)
	assert_eq(hud.strip.item_line.text, "Vaso de agua de lluvia", "at sea from the moment the raft leaves")
	var routes := shell.session.get_node(^"Routes") as IslandRoutes
	routes.departed.erase(1)
	_hold(hud, STEP_S)
	assert_eq(hud.strip.item_line.text, "Vaso de agua de lluvia · [F] Beber", "on land the key and verb come back")
