extends Node
## Manual capture for guardacostas-capture task 12.2, run windowed (it needs a real renderer, so never
## headless and never in CI). A solo sandbar run by day: the patrol boat docks for a player spotted on
## the sand, its dinghy rows in and the squad lands; the player stands on the beach beside the landing
## and the window is saved with the soldiers, the dinghy and the landing call in view:
## art-guardacostas adds the dinghy halfway in, the camera on the landing for a moment:
##   godot --path game res://tests/manual/capture_squad.tscn -- --out=<dir> [--scale=2]
## Writes <dir>/squad_rowing_in.png and <dir>/squad_ashore.png.

const SHELL_SCENE: PackedScene = preload("res://scenes/shell/game_shell.tscn")
const SETTINGS_PATH: String = "user://capture_squad.cfg"
const DEFAULT_SCALE: int = 2
const MAX_SCALE: int = 4
const SETTLE_FRAMES: int = 30
const TILE: float = 16.0

var _out_dir: String = ""
var _scale: int = DEFAULT_SCALE


func _ready() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			_out_dir = arg.trim_prefix("--out=")
		elif arg.begins_with("--scale="):
			_scale = arg.trim_prefix("--scale=").to_int()
	if _out_dir.is_empty() or DisplayServer.get_name() == "headless" or _scale < 1 or _scale > MAX_SCALE:
		push_error("capture_squad: run windowed and pass --out=<dir> and optionally --scale=1..%d" % MAX_SCALE)
		get_tree().quit(1)
		return
	var config := ConfigFile.new()
	config.set_value("player", "name", "Yuni")
	config.set_value("display", "fullscreen", false)
	config.set_value("display", "ui_scale", _scale)
	config.set_value("display", "pixel_filter", 0)
	config.save(SETTINGS_PATH)
	var shell := SHELL_SCENE.instantiate() as GameShell
	shell.settings_path = SETTINGS_PATH
	add_child(shell)
	(shell.screen as TitleScreen).solo_requested.emit()
	await _frames(SETTLE_FRAMES)
	WeatherManager.sky.weather.rolls_enabled = false
	WeatherManager.sky.start_at(100.0)
	var session := shell.session
	var body := session.body(CoopSession.HOST_ID)
	body.player_input.enabled = false
	var spawner := session.get_node(NodePath(SandbarIsland.CREATURES_NAME)) as CreatureSpawner
	spawner.apply_phase(WeatherManager.phase())
	var boat: Creature = spawner.creatures(&"patrol_boat")[0]
	var brain := boat.brain as PatrolRoute
	brain.set_clock(boat.data.patrol.horizon_warning_s + 30.0)
	boat.advance(0.0)
	brain.spot(body, &"sight")
	# The player out of sight in the water while the squad lands, then on the beach beside it, hidden.
	body.global_position = Vector2(2.5, 2.5) * TILE
	body.stealth_state = MovementStep.Stealth.SUBMERGED
	var rowing_saved: bool = false
	for i: int in 400:
		if boat.squad_state == PatrolRoute.Squad.ASHORE:
			break
		await get_tree().physics_frame
		if not rowing_saved and boat.dinghy_t > 0.4 and boat.dinghy_t < 0.7:
			rowing_saved = true
			var waiting: Vector2 = body.global_position
			# The camera on the dinghy, the player held just north of it.
			body.global_position = (boat.get_node(^"SquadLook") as SquadLook).dinghy_px + Vector2(0.0, -2.0 * TILE)
			body.camera.reset_smoothing()
			await _frames(3)
			await _save("squad_rowing_in.png")
			body.global_position = waiting
	await _frames(20)
	for soldier: Creature in brain.soldiers:
		soldier.set_physics_process(false)
	boat.set_physics_process(false)
	body.global_position = IslandLayout.cell_center(boat.landing) + Vector2(0.0, -3.0 * TILE)
	await _frames(SETTLE_FRAMES)
	print("capture_squad: %d soldiers ashore, dinghy %s at %s, %d call(s) shown" % [brain.soldiers.size(),
		(boat.get_node(^"SquadLook") as SquadLook).dinghy_visible, boat.landing, (boat.get_node(^"SquadLook") as SquadLook).calls_shown])
	await _save("squad_ashore.png")
	get_tree().quit(0)


func _save(file_name: String) -> void:
	await RenderingServer.frame_post_draw
	var window_size := DisplayFit.window_size(_scale)
	var image := get_viewport().get_texture().get_image()
	if image.get_size() != window_size:
		image.resize(window_size.x, window_size.y, Image.INTERPOLATE_NEAREST)
	var path := _out_dir.path_join(file_name)
	print("capture_squad: %s (%s)" % [path, error_string(image.save_png(path))])


func _frames(count: int) -> void:
	for i: int in count:
		await get_tree().process_frame
