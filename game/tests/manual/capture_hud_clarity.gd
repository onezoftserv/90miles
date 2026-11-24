extends Node
## Manual capture for hud-clarity tasks 0.2 and 8.3, run windowed (it needs a real renderer, so never
## headless and never in CI). It starts a solo sandbar run at 09:00 with the weather held calm, sets
## each scene up by hand and saves what the window shows. It reads only nodes that exist before and
## after the change (and finds the new ones by name), so one script frames "before" and "after" the
## same way:
##   godot --path game res://tests/manual/capture_hud_clarity.tscn -- --out=<dir> [--scale=3]
## Writes <dir>/first_frame.png (the whole window on the first settled frame), top_band.png (the top
## 72 px rows), meters_bleeding.png (the meters window 60 s into a bite), sunstroke.png (the whole
## window at heat 100), and, where the pieces exist, arrow.png (the player far east of the raft site),
## hut_note.png (the hut note read) and night_built.png (the top band at night with the raft built).

const SHELL_SCENE: PackedScene = preload("res://scenes/shell/game_shell.tscn")
const SETTINGS_PATH: String = "user://capture_hud_clarity.cfg"
const MAX_SCALE: int = 4
const SETTLE_FRAMES: int = 30
## weather-daynight: 0 s is 06:00 and one in-game hour is 30 s, so 90 s is 09:00 and 450 s is 21:00.
const MORNING_S: float = 90.0
const NIGHT_S: float = 450.0
## The rows and the meters window, in base pixels (the window is 640×360 at 1×).
const TOP_BAND: Rect2i = Rect2i(0, 0, 640, 72)
const METERS_WINDOW: Rect2i = Rect2i(0, 0, 144, 96)
## How far from the raft site the arrow capture stands, in pixels (out of view to the east).
const ARROW_OFFSET: Vector2 = Vector2(420.0, -40.0)
const BLEED_WAIT_S: float = 60.0

var _out_dir: String = ""
var _scale: int = 1
var _shell: GameShell
var _body: PlayerBody


func _ready() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			_out_dir = arg.trim_prefix("--out=")
		elif arg.begins_with("--scale="):
			_scale = arg.trim_prefix("--scale=").to_int()
	if _out_dir.is_empty() or DisplayServer.get_name() == "headless" or _scale < 1 or _scale > MAX_SCALE:
		push_error("capture_hud_clarity: run windowed and pass --out=<dir> and optionally --scale=1..%d" % MAX_SCALE)
		get_tree().quit(1)
		return
	DirAccess.make_dir_recursive_absolute(_out_dir)
	_write_settings()
	_shell = SHELL_SCENE.instantiate() as GameShell
	_shell.settings_path = SETTINGS_PATH
	add_child(_shell)
	await _frames(5)
	_shell.start_solo()
	WeatherManager.sky.weather.rolls_enabled = false
	WeatherManager.sky.start_at(MORNING_S)
	_body = _shell.session.body(CoopSession.HOST_ID)
	_body.player_input.enabled = false
	await _place(IslandLayout.cell_center(_shell.island.built.solo_spawn))
	await _save("first_frame.png")
	await _save("top_band.png", TOP_BAND)
	await _capture_bleeding()
	await _capture_sunstroke()
	await _capture_arrow()
	await _capture_hut_note()
	await _capture_night_built()
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


func _place(at: Vector2) -> void:
	_body.global_position = at
	_body.camera.reset_smoothing()
	await _frames(SETTLE_FRAMES)


# Saves the window, or only `crop` (in base pixels) of it.
func _save(file_name: String, crop: Rect2i = Rect2i()) -> void:
	await RenderingServer.frame_post_draw
	var window_size := DisplayFit.window_size(_scale)
	var image := get_viewport().get_texture().get_image()
	if image.get_size() != window_size:
		image.resize(window_size.x, window_size.y, Image.INTERPOLATE_NEAREST)
	if crop.has_area():
		image = image.get_region(Rect2i(crop.position * _scale, crop.size * _scale))
	var path := _out_dir.path_join(file_name)
	print("capture_hud_clarity: %s (%s)" % [path, error_string(image.save_png(path))])


# A bite 60 s ago: "Sangrando" (with its time bar half drained, after the change).
func _capture_bleeding() -> void:
	var meters := _body.meters
	meters.set_status(DataEnums.Status.BLEEDING, true)
	for i: int in int(BLEED_WAIT_S):
		meters.tick(1.0, MeterContext.new())
	await _frames(SETTLE_FRAMES)
	await _save("meters_bleeding.png", METERS_WINDOW)
	meters.set_status(DataEnums.Status.BLEEDING, false)
	meters.health = SurvivalMeters.MAX_VALUE


# Heat at 100: the sunstroke blur ("Insolación" with its cooling bar full, after the change).
func _capture_sunstroke() -> void:
	var meters := _body.meters
	meters.heat = meters.tuning.sunstroke_at
	meters.sunstroke = true
	await _frames(SETTLE_FRAMES)
	await _save("sunstroke.png")
	await _save("sunstroke_meters.png", METERS_WINDOW)
	meters.heat = 0.0
	meters.sunstroke = false
	await _frames(2)


# Far east of the raft site: the arrow on the frame's left edge points west (after the change only).
func _capture_arrow() -> void:
	var site := _shell.session.get_node_or_null(^"RaftSite") as Node2D
	if site == null or _shell.hud.get_node_or_null(^"SiteArrow") == null:
		return
	await _place(site.global_position + ARROW_OFFSET)
	await _save("arrow.png")


# The hut note read with E (after the change only: the sandbar had no sign there before).
func _capture_hut_note() -> void:
	var note := _hut_note()
	if note == null:
		return
	await _place(note.global_position + Vector2(0.0, 12.0))
	_body.intent = MoveIntent.create(Vector2.ZERO, false, false, true)
	await get_tree().physics_frame
	await get_tree().physics_frame
	_body.intent = MoveIntent.new()
	await _frames(SETTLE_FRAMES)
	await _save("hut_note.png")
	_shell.hud.sign_note.close()
	await _frames(2)


# At 21:00 with the raft built: the top band says to set off (after the change, "Zarpa pa'l cayo").
func _capture_night_built() -> void:
	var site := _shell.session.get_node_or_null(^"RaftSite") as BuildSite
	if site == null or _shell.hud.get_node_or_null(^"ObjectiveRow") == null:
		return
	for id: StringName in site.recipe.inputs:
		site.deposited[id] = site.recipe.inputs[id]
	for tag: int in site.recipe.input_tags:
		site.tags_deposited[tag] = site.recipe.input_tags[tag]
	site.work(1.0)
	WeatherManager.sky.start_at(NIGHT_S)
	await _place(IslandLayout.cell_center(_shell.island.built.solo_spawn))
	await _save("night_built.png", TOP_BAND)


# The sandbar's one sign, if it has one (it had none before the change).
func _hut_note() -> IslandSign:
	for child: Node in _shell.session.get_children():
		if child is IslandSign:
			return child as IslandSign
	return null
