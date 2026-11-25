extends Node
## Manual capture for guardacostas-capture task 9.2 and art-guardacostas task 9.5. It needs a real
## renderer, so it never runs headless or in CI; run it off-screen. A solo sandbar run by day: the
## patrol boat docks for the player spotted on the sand and its squad lands, then the player is captured
## and `la_captura` plays, staged (the bars, the HUD hidden but the panel, the view framing the docked
## boat and its landing). The host's own pacing is paused so each line is held while its frame is taken:
## line 1 with Rodríguez's portrait and the advance arrow, the act with the arrow, and, after the scene
## restarts the run, the closing notice naming the fosforera taken. A second capture with the Médico's
## background shows the plea with the player's own figure:
##   godot --position -32000,-32000 --resolution 640x360 --path game res://tests/manual/capture_la_captura.tscn -- --out=<dir> [--scale=1]
## Writes <dir>/la_captura_line1.png, la_captura_act.png, la_captura_after.png and la_captura_plea.png.

const SHELL_SCENE: PackedScene = preload("res://scenes/shell/game_shell.tscn")
const SETTINGS_PATH: String = "user://capture_la_captura.cfg"
const DEFAULT_SCALE: int = 1
const MAX_SCALE: int = 4
const SETTLE_FRAMES: int = 30
const TILE: float = 16.0
const ACT_PREFIX: String = "captura_act_"
const PLEA_PREFIX: String = "captura_plea_"

var _out_dir: String = ""
var _scale: int = DEFAULT_SCALE
var _shell: GameShell
var _body: PlayerBody
var _keeper: CaptureScene
var _patrol: PatrolData


func _ready() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			_out_dir = arg.trim_prefix("--out=")
		elif arg.begins_with("--scale="):
			_scale = arg.trim_prefix("--scale=").to_int()
	if _out_dir.is_empty() or DisplayServer.get_name() == "headless" or _scale < 1 or _scale > MAX_SCALE:
		push_error("capture_la_captura: run with a renderer (off-screen) and pass --out=<dir> and optionally --scale=1..%d" % MAX_SCALE)
		get_tree().quit(1)
		return
	var config := ConfigFile.new()
	config.set_value("player", "name", "Yuni")
	config.set_value("display", "fullscreen", false)
	config.set_value("display", "ui_scale", _scale)
	config.set_value("display", "pixel_filter", 0)
	config.save(SETTINGS_PATH)
	_shell = SHELL_SCENE.instantiate() as GameShell
	_shell.settings_path = SETTINGS_PATH
	add_child(_shell)
	(_shell.screen as TitleScreen).solo_requested.emit()
	await _frames(SETTLE_FRAMES)
	WeatherManager.sky.weather.rolls_enabled = false
	WeatherManager.sky.start_at(100.0)
	_body = _shell.session.body(CoopSession.HOST_ID)
	_body.player_input.enabled = false
	_patrol = (GameState.content.get_entry(&"creatures", &"patrol_boat") as CreatureData).patrol
	_keeper = CaptureScene.of(_shell.session)
	await _land_squad()
	# The restart: no background, low morale, a fosforera and a coconut.
	_body.meters.morale = 40.0
	_body.inventory.add(&"lighter", 1)
	_body.inventory.add(&"coco", 1)
	await _capture()
	await _hold_line(func() -> bool: return _keeper.current_serial == 1, "la_captura_line1.png")
	await _hold_line(func() -> bool: return String(_keeper.current_line_id).begins_with(ACT_PREFIX), "la_captura_act.png")
	_keeper.set_physics_process(true)
	while _keeper.playing:
		_keeper.skip()
	await _frames(90)
	print("capture_la_captura: notice '%s'" % _shell.hud.notice.shown_text())
	await _save("la_captura_after.png")
	# The plea: the Médico at 65 morale talks the party out.
	FixtureBackgrounds.give(_body, &"medico")
	_body.meters.morale = 65.0
	await _capture()
	await _hold_line(func() -> bool: return String(_keeper.current_line_id).begins_with(PLEA_PREFIX), "la_captura_plea.png")
	_keeper.set_physics_process(true)
	while _keeper.playing:
		_keeper.skip()
	await _frames(10)
	get_tree().quit(0)


# The boat docks for the player spotted on the sand and its squad lands; the player waits in the water.
func _land_squad() -> void:
	var spawner := _shell.session.get_node(NodePath(SandbarIsland.CREATURES_NAME)) as CreatureSpawner
	spawner.apply_phase(WeatherManager.phase())
	var boat: Creature = spawner.creatures(&"patrol_boat")[0]
	var brain := boat.brain as PatrolRoute
	brain.set_clock(_patrol.horizon_warning_s + 30.0)
	boat.advance(0.0)
	brain.spot(_body, &"sight")
	_body.global_position = Vector2(2.5, 2.5) * TILE
	_body.stealth_state = MovementStep.Stealth.SUBMERGED
	for i: int in 400:
		if boat.squad_state == PatrolRoute.Squad.ASHORE:
			break
		await get_tree().physics_frame
	_body.global_position = IslandLayout.cell_center(boat.landing) + Vector2(0.0, -3.0 * TILE)
	_body.camera.reset_smoothing()
	await _frames(10)


# The whole party caught: the scene starts, the host's pacing paused so a line holds while it is taken.
func _capture() -> void:
	CaptureRules.capture(_body, _body, _patrol)
	_keeper.on_captured(_body, null)
	await _frames(2)
	_keeper.set_physics_process(false)


# Skips to the first line `wanted` accepts, lets it reveal and the camera ease, and saves the window
# while the advance arrow shows.
func _hold_line(wanted: Callable, file_name: String) -> void:
	var guard: int = 0
	while _keeper.playing and not wanted.call() and guard < 40:
		_keeper.skip()
		guard += 1
	if not wanted.call():
		push_error("capture_la_captura: no line for %s" % file_name)
		return
	var panel: ScenePanel = _shell.hud.scene_panel
	# Past the reveal and the camera's ease, just as the arrow blinks on.
	var was_shown: bool = true
	for i: int in 600:
		await get_tree().process_frame
		var shown: bool = panel.arrow_shown()
		if panel.revealed_chars() >= panel.shown_text().length() and shown and not was_shown and i > 60:
			break
		was_shown = shown
	print("capture_la_captura: %s line %s, card %s, arrow %s" % [file_name, _keeper.current_line_id, panel.card_rect(), panel.arrow_shown()])
	await _save(file_name)


func _save(file_name: String) -> void:
	await RenderingServer.frame_post_draw
	var window_size := DisplayFit.window_size(_scale)
	var image := get_viewport().get_texture().get_image()
	if image.get_size() != window_size:
		image.resize(window_size.x, window_size.y, Image.INTERPOLATE_NEAREST)
	var path := _out_dir.path_join(file_name)
	print("capture_la_captura: %s (%s)" % [path, error_string(image.save_png(path))])


func _frames(count: int) -> void:
	for i: int in count:
		await get_tree().process_frame
