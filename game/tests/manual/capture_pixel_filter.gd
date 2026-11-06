extends Node
## Manual check for ui-shell "Pixel filter", run windowed (it needs a real renderer, so never
## headless and never in CI). It starts a solo run on the dev island at 2×, waits, and saves
## what the window shows plus a close-up of the player:
##   godot --path game res://tests/manual/capture_pixel_filter.tscn -- --filter=sharp --out=<dir>
##   godot --path game res://tests/manual/capture_pixel_filter.tscn -- --filter=smooth --out=<dir>
## Writes <dir>/pixel_filter_<filter>.png and <dir>/pixel_filter_<filter>_player.png. With
## --settings it saves the settings screen instead, as <dir>/pixel_filter_<filter>_settings.png.

const SHELL_SCENE: PackedScene = preload("res://scenes/shell/game_shell.tscn")
const SETTINGS_PATH: String = "user://capture_pixel_filter.cfg"
const SCALE: int = 2
const SETTLE_FRAMES: int = 45
## The player close-up: a square of the base picture around the player, enlarged.
const CLOSE_UP_BASE_PX: int = 48
const CLOSE_UP_ZOOM: int = 3

var _filter: String = "sharp"
var _out_dir: String = ""
var _settings_screen: bool = false


func _ready() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--filter="):
			_filter = arg.trim_prefix("--filter=")
		elif arg.begins_with("--out="):
			_out_dir = arg.trim_prefix("--out=")
		elif arg == "--settings":
			_settings_screen = true
	if _out_dir.is_empty() or not (_filter == "sharp" or _filter == "smooth"):
		push_error("capture_pixel_filter: pass --filter=sharp|smooth and --out=<dir>")
		get_tree().quit(1)
		return
	_write_settings()
	var shell := SHELL_SCENE.instantiate() as GameShell
	shell.settings_path = SETTINGS_PATH
	add_child(shell)
	await _frames(5)
	if _settings_screen:
		shell.show_settings()
		await _frames(SETTLE_FRAMES)
		_save_window("pixel_filter_%s_settings.png" % _filter)
		get_tree().quit()
		return
	shell.start_solo()
	for peer_id: int in shell.session.peer_ids():
		shell.session.body(peer_id).player_input.enabled = false
	await _frames(SETTLE_FRAMES)
	_save(shell)
	get_tree().quit()


func _write_settings() -> void:
	var config := ConfigFile.new()
	config.set_value("player", "name", "Yuni")
	config.set_value("display", "fullscreen", false)
	config.set_value("display", "ui_scale", SCALE)
	config.set_value("display", "pixel_filter", 1 if _filter == "smooth" else 0)
	config.save(SETTINGS_PATH)


func _frames(count: int) -> void:
	for i: int in count:
		await get_tree().process_frame


# The root picture is the base size in Sharp (the window enlarges it, nearest) and the window
# size in Smooth; both are saved at the window size.
func _save(shell: GameShell) -> void:
	var window_size := DisplayFit.window_size(SCALE)
	var image := _save_window("pixel_filter_%s.png" % _filter)
	var player := shell.session.body(shell.session.peer_ids()[0])
	var centre := Vector2i(player.get_global_transform_with_canvas().origin) * SCALE
	var side := CLOSE_UP_BASE_PX * SCALE
	var corner := (centre - Vector2i(side, side) / 2).clamp(Vector2i.ZERO, window_size - Vector2i(side, side))
	var close_up := image.get_region(Rect2i(corner, Vector2i(side, side)))
	close_up.resize(side * CLOSE_UP_ZOOM, side * CLOSE_UP_ZOOM, Image.INTERPOLATE_NEAREST)
	close_up.save_png(_out_dir.path_join("pixel_filter_%s_player.png" % _filter))


func _save_window(file_name: String) -> Image:
	var window_size := DisplayFit.window_size(SCALE)
	var image := get_viewport().get_texture().get_image()
	if image.get_size() != window_size:
		image.resize(window_size.x, window_size.y, Image.INTERPOLATE_NEAREST)
	var path := _out_dir.path_join(file_name)
	var saved := image.save_png(path)
	print("capture_pixel_filter: %s -> %s (%s)" % [_filter, path, error_string(saved)])
	return image
