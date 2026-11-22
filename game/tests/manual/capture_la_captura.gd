extends Node
## Manual capture for guardacostas-capture task 9.2, run windowed (it needs a real renderer, so never
## headless and never in CI). A solo sandbar run: the player is captured, `la_captura` plays, the host
## skips to the longest line of the scene, and after 300 frames (its whole line revealed) the window is
## saved, so the scene panel's text can be checked against the 640×360 view by eye:
##   godot --path game res://tests/manual/capture_la_captura.tscn -- --out=<dir> [--scale=2]
## Writes <dir>/la_captura_panel.png.

const SHELL_SCENE: PackedScene = preload("res://scenes/shell/game_shell.tscn")
const SETTINGS_PATH: String = "user://capture_la_captura.cfg"
const DEFAULT_SCALE: int = 2
const MAX_SCALE: int = 4
const SETTLE_FRAMES: int = 30
const RUN_FRAMES: int = 300

var _out_dir: String = ""
var _scale: int = DEFAULT_SCALE


func _ready() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			_out_dir = arg.trim_prefix("--out=")
		elif arg.begins_with("--scale="):
			_scale = arg.trim_prefix("--scale=").to_int()
	if _out_dir.is_empty() or DisplayServer.get_name() == "headless" or _scale < 1 or _scale > MAX_SCALE:
		push_error("capture_la_captura: run windowed and pass --out=<dir> and optionally --scale=1..%d" % MAX_SCALE)
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
	var body := shell.session.body(CoopSession.HOST_ID)
	body.player_input.enabled = false
	var patrol := (GameState.content.get_entry(&"creatures", &"patrol_boat") as CreatureData).patrol
	var keeper := CaptureScene.of(shell.session)
	CaptureRules.capture(body, body, patrol)
	keeper.on_captured(body, null)
	await _frames(2)
	# Skip to the longest line the scene holds.
	var longest_serial: int = 0
	var longest: int = 0
	var seen: Array[String] = []
	while keeper.playing and seen.size() < 20:
		var text: String = keeper.current_text("es")
		seen.append(text)
		if text.length() > longest:
			longest = text.length()
			longest_serial = keeper.current_serial
		keeper.skip()
	print("capture_la_captura: %d lines, the longest %d chars (line %d)" % [seen.size(), longest, longest_serial])
	CaptureRules.capture(body, body, patrol)
	keeper.on_captured(body, null)
	await _frames(2)
	while keeper.playing and keeper.current_serial < longest_serial:
		keeper.skip()
	await _frames(RUN_FRAMES)
	var panel := shell.hud.scene_panel
	print("capture_la_captura: card %s inside %s: %s, revealed %d of %d" % [panel.card_rect(), Rect2(0, 0, 640, 360),
		Rect2(0, 0, 640, 360).encloses(panel.card_rect()), panel.revealed_chars(), panel.shown_text().length()])
	await RenderingServer.frame_post_draw
	var window_size := DisplayFit.window_size(_scale)
	var image := get_viewport().get_texture().get_image()
	if image.get_size() != window_size:
		image.resize(window_size.x, window_size.y, Image.INTERPOLATE_NEAREST)
	var path := _out_dir.path_join("la_captura_panel.png")
	print("capture_la_captura: %s (%s)" % [path, error_string(image.save_png(path))])
	get_tree().quit(0)


func _frames(count: int) -> void:
	for i: int in count:
		await get_tree().process_frame
