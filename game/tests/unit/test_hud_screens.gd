extends GutTest
## inventory-hud "Screens take input first" (Run summary, Host lost): with the run summary shown
## (solo, offline, after a real raft crossing ends) and with the host-lost screen shown (NetHarness,
## the host goes away), the slot keys, F and E change nothing and send nothing, the strip and the
## prompt are hidden, and the HUD reads no freed body: GUT fails a test on any engine or script
## error, and the HUD is ticked by hand and by real frames after the bodies are gone.

const SHELL_SCENE: PackedScene = preload("res://scenes/shell/game_shell.tscn")
const ISLAND_SCENE: PackedScene = preload("res://scenes/levels/sandbar_island.tscn")
const HUD_SCENE: PackedScene = preload("res://scenes/ui/run_hud.tscn")
const SETTINGS_PATH: String = "user://test_hud_screens_settings.cfg"
const STEP_S: float = 0.1
const TIMEOUT_S: float = 5.0
const CROSSING_S: float = 60.0
const HOLD_S: float = 2.5

var net: NetHarness
var islands: Array[SandbarIsland] = []
# Freed before the sessions they read.
var huds: Array[Node] = []


func before_each() -> void:
	NetManager.start_solo()
	WeatherManager.stop()
	WeatherManager.sky.start_at(0.0)


func after_each() -> void:
	for keycode: Key in [KEY_F, KEY_E]:
		_key(keycode, false)
	for hud: Node in huds:
		if is_instance_valid(hud):
			hud.free()
	huds.clear()
	if net != null:
		net.teardown()
		net = null
	for island: SandbarIsland in islands:
		if is_instance_valid(island):
			island.free()
	islands.clear()
	WeatherManager.stop()
	NetManager.leave()
	if FileAccess.file_exists(SETTINGS_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SETTINGS_PATH))


func _key(keycode: Key, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = keycode
	event.keycode = keycode
	event.pressed = pressed
	Input.parse_input_event(event)
	Input.flush_buffered_events()


# Every HUD piece that reads input or a body, for `seconds` in 0.1 s steps, and the local body from
# the keyboard while it is there, as the host would step it.
func _tick(hud: RunHud, seconds: float) -> void:
	for i: int in roundi(seconds / STEP_S):
		var body := hud.strip.body
		if is_instance_valid(body) and body.multiplayer.is_server():
			body.player_input._physics_process(STEP_S)
			body.net._physics_process(STEP_S)
		hud._process(STEP_S)
		hud.strip._process(STEP_S)
		hud.prompt.tick(STEP_S)
		hud.craft_list._process(STEP_S)
		hud.marks._process(STEP_S)


# Presses 3, holds F, then presses E, the HUD ticked throughout.
func _press_3_f_and_e(hud: RunHud) -> void:
	_key(KEY_3, true)
	_tick(hud, STEP_S)
	_key(KEY_3, false)
	_key(KEY_F, true)
	_tick(hud, HOLD_S)
	_key(KEY_F, false)
	_key(KEY_E, true)
	_tick(hud, STEP_S)
	_key(KEY_E, false)
	_tick(hud, STEP_S)


func _assert_hidden_and_silent(hud: RunHud, where: String) -> void:
	assert_true(hud.screen_shown, "the HUD knows the screen is up %s" % where)
	assert_false(hud.strip.visible, "no strip %s" % where)
	assert_false(hud.prompt.visible, "no prompt %s" % where)
	assert_false(hud.craft_list.is_open(), "no crafting list %s" % where)
	assert_signal_emit_count(hud.strip, "use_sent", 0, "F sent nothing %s" % where)
	assert_signal_emit_count(hud.craft_list, "craft_sent", 0, "E sent nothing %s" % where)
	assert_eq(get_errors().size(), 0, "no error from reading a gone body %s" % where)


# --- the run summary -----------------------------------------------------------------------------

func test_under_the_run_summary_the_hud_takes_no_input() -> void:
	var shell := SHELL_SCENE.instantiate() as GameShell
	shell.settings_path = SETTINGS_PATH
	add_child_autofree(shell)
	(shell.screen as TitleScreen).solo_requested.emit()
	var session := shell.session
	var body := session.body(CoopSession.HOST_ID)
	var site := session.get_node(^"RaftSite") as BuildSite
	body.global_position = site.global_position
	body.inventory.add(&"driftwood", 6)
	body.inventory.add(&"inner_tube", 2)
	body.inventory.add(&"rope", 3)
	site.deposit(body)
	site.work(1.0)
	(session.get_node(^"Raft") as Raft).interactable.interacted.emit(body)
	assert_eq(shell.crossings.size(), 1, "the raft left")
	var crossing := shell.crossings[0] as Crossing
	crossing.plan = CrossingPlan.create(CROSSING_S)
	CrossingRig.run(crossing, CROSSING_S + 1.0)
	assert_eq(shell.flow, GameShell.Flow.SUMMARY, "the crossing ended and the summary shows")
	var hud := shell.hud
	assert_not_null(hud, "the HUD stays up under the summary")
	body.meters.thirst = 50.0
	body.inventory.add(&"rain_cup", 1)
	body.inventory.add(&"coco", 1)
	var wood := session.spawn_pickup(&"driftwood", 1, body.global_position)
	var before: Array = body.inventory.to_net()
	var selected: int = hud.strip.selected
	watch_signals(hud.strip)
	watch_signals(hud.craft_list)
	_press_3_f_and_e(hud)
	assert_eq(hud.strip.selected, selected, "3 selects nothing")
	assert_eq(body.inventory.to_net(), before, "nothing was used or picked up")
	assert_eq(body.meters.thirst, 50.0, "nothing was drunk")
	assert_true(is_instance_valid(wood) and wood.interactable.enabled, "E picked nothing up")
	_assert_hidden_and_silent(hud, "under the run summary")
	# Real frames, so the launched raft and the used-up site are freed before the shell is.
	await wait_physics_frames(2)
	assert_eq(get_errors().size(), 0, "no error on the frames after")


# --- host lost -----------------------------------------------------------------------------------

func _setup(session: CoopSession) -> void:
	var island := ISLAND_SCENE.instantiate() as SandbarIsland
	add_child(island)
	islands.append(island)
	session.terrain = island.terrain
	session.spawn_points = island.spawn_points(false)
	island.with_creatures = false
	island.furnish(session)


func test_under_the_host_lost_screen_the_hud_takes_no_input_and_reads_no_freed_body() -> void:
	net = NetHarness.new(self)
	var host := net.add_host(_setup)
	var client := await net.join(_setup)
	assert_not_null(client)
	if client == null:
		return
	net.silence_input()
	var me: int = net.peer_id(client)
	var hud := HUD_SCENE.instantiate() as RunHud
	add_child(hud)
	huds.append(hud)
	hud.bind(client, me, false)
	# The shell's _on_host_lost: the HUD hears of the screen before the run is freed.
	client.host_lost.connect(func() -> void: hud.set_screen_shown(true))
	host.body(me).inventory.add(&"rain_cup", 1)
	host.body(me).inventory.add(&"rope", 1)
	var mine := net.own_body(client)
	var mirrored := func() -> bool: return mine.inventory.count_id(&"rope") == 1
	assert_true(await wait_until(mirrored, TIMEOUT_S), "the client's strip has the host's inventory")
	var site := client.get_node(^"RaftSite") as BuildSite
	mine.global_position = site.global_position
	_tick(hud, STEP_S)
	assert_true(hud.strip.visible, "the strip shows while the host is there")
	assert_true(hud.prompt.visible, "and the prompt over the raft site")
	var selected: int = hud.strip.selected
	watch_signals(hud.strip)
	watch_signals(hud.craft_list)
	watch_signals(client)
	net.drop(host)
	assert_true(await wait_until(func() -> bool: return hud.screen_shown, TIMEOUT_S), "the host went away")
	assert_signal_emitted(client, "host_lost")
	# Real frames: the bodies are freed while the HUD runs.
	await wait_physics_frames(3)
	assert_false(is_instance_valid(mine), "the client's body is gone")
	_press_3_f_and_e(hud)
	await wait_physics_frames(2)
	assert_eq(hud.strip.selected, selected, "3 selects nothing")
	assert_eq(hud.marks.mark_rects().size(), 0, "no marks over gone bodies")
	_assert_hidden_and_silent(hud, "under the host-lost screen")
