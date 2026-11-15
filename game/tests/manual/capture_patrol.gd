extends Node
## Manual capture for guardacostas-stealth task 9.2, run windowed (it needs a real renderer, so never
## headless and never in CI). A solo sandbar run at night: the patrol boat is held in its lap with its
## searchlight on open sand, the player stands in the beam with half a spot meter (the open eye), and the
## window is saved; then the boat is put on the horizon and the HUD band's light is saved:
##   godot --path game res://tests/manual/capture_patrol.tscn -- --out=<dir> [--scale=2]
## Writes <dir>/sandbar_night_beam.png and <dir>/horizon_light_night.png.

const SHELL_SCENE: PackedScene = preload("res://scenes/shell/game_shell.tscn")
const SETTINGS_PATH: String = "user://capture_patrol.cfg"
const DEFAULT_SCALE: int = 2
const MAX_SCALE: int = 4
const SETTLE_FRAMES: int = 30
## weather-daynight: 440.1 s after dawn is Noche.
const NIGHT_S: float = 440.1
const TILE: float = 16.0
const LAPS_TO_TRY: Array[float] = [5.0, 10.0, 15.0, 20.0, 25.0, 30.0, 40.0, 50.0, 60.0, 70.0, 80.0, 90.0]

var _out_dir: String = ""
var _scale: int = DEFAULT_SCALE
var _shell: GameShell
var _body: PlayerBody
var _boat: Creature
var _brain: PatrolRoute
var _patrol: PatrolData


func _ready() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			_out_dir = arg.trim_prefix("--out=")
		elif arg.begins_with("--scale="):
			_scale = arg.trim_prefix("--scale=").to_int()
	if _out_dir.is_empty() or DisplayServer.get_name() == "headless" or _scale < 1 or _scale > MAX_SCALE:
		push_error("capture_patrol: run windowed and pass --out=<dir> and optionally --scale=1..%d" % MAX_SCALE)
		get_tree().quit(1)
		return
	_write_settings()
	_shell = SHELL_SCENE.instantiate() as GameShell
	_shell.settings_path = SETTINGS_PATH
	add_child(_shell)
	await _frames(5)
	_shell.start_solo()
	WeatherManager.sky.weather.rolls_enabled = false
	WeatherManager.sky.start_at(NIGHT_S)
	await _frames(5)
	_body = _shell.session.body(CoopSession.HOST_ID)
	_body.player_input.enabled = false
	var spawner := _shell.session.get_node(NodePath(SandbarIsland.CREATURES_NAME)) as CreatureSpawner
	spawner.apply_phase(WeatherManager.phase())
	spawner.set_physics_process(false)
	_boat = spawner.creatures(&"patrol_boat")[0]
	_boat.set_physics_process(false)
	_brain = _boat.brain as PatrolRoute
	_patrol = _boat.data.patrol
	await _capture_horizon()
	await _capture_beam()
	_shell.back_to_title()
	get_tree().quit()


func _write_settings() -> void:
	var config := ConfigFile.new()
	config.set_value("player", "name", "Yuni")
	config.set_value("display", "fullscreen", false)
	config.set_value("display", "ui_scale", _scale)
	config.set_value("display", "pixel_filter", 0)
	config.save(SETTINGS_PATH)


func _frames(count: int) -> void:
	for i: int in count:
		await get_tree().process_frame


func _hold(clock_s: float) -> void:
	_brain.set_clock(clock_s)
	_boat.advance(0.0)


func _save(file_name: String) -> void:
	await RenderingServer.frame_post_draw
	var window_size := DisplayFit.window_size(_scale)
	var image := get_viewport().get_texture().get_image()
	if image.get_size() != window_size:
		image.resize(window_size.x, window_size.y, Image.INTERPOLATE_NEAREST)
	var path := _out_dir.path_join(file_name)
	print("capture_patrol: %s (%s)" % [path, error_string(image.save_png(path))])


# The boat 5 s into its horizon warning: the light on the HUD band.
func _capture_horizon() -> void:
	_hold(5.0)
	await _frames(SETTLE_FRAMES)
	_hold(5.0)
	await _save("horizon_light_night.png")


# The boat held 20 s into its lap (or the first clock that lights open sand), the player on that sand with
# half a meter: the beam on the sand, the open eye over the player.
func _capture_beam() -> void:
	var terrain: GridTerrain = _shell.island.terrain
	for lap_s: float in LAPS_TO_TRY:
		_hold(_patrol.horizon_warning_s + lap_s)
		var sand: Vector2 = _lit_sand(terrain)
		if sand.x < 0.0:
			continue
		_body.global_position = sand
		_body.camera.reset_smoothing()
		_body.spot_meter.value = 1.0
		for i: int in SETTLE_FRAMES:
			_hold(_patrol.horizon_warning_s + lap_s)
			await get_tree().process_frame
		_hold(_patrol.horizon_warning_s + lap_s)
		await _save("sandbar_night_beam.png")
		return
	push_error("capture_patrol: no clock of the lap lights open sand")


# Open sand (BEACH, no roof) the held light covers, 4 to 8 tiles from the boat, in reading order.
func _lit_sand(terrain: GridTerrain) -> Vector2:
	var cells: Array[Vector2i] = []
	for cell: Vector2i in terrain.cells:
		if terrain.cells[cell] == DataEnums.Terrain.BEACH and not terrain.shaded.has(cell):
			cells.append(cell)
	cells.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return a.y < b.y or (a.y == b.y and a.x < b.x))
	for cell: Vector2i in cells:
		var centre: Vector2 = IslandLayout.cell_center(cell)
		var tiles: float = _boat.position.distance_to(centre) / TILE
		if tiles >= 4.0 and tiles <= 8.0 and _brain.lights(centre):
			return centre
	return Vector2(-1.0, -1.0)
