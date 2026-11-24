extends Node
## Manual captures of the menus for run-menu and menu-clarity (their tasks' capture steps), run
## windowed, because headless draws nothing:
##   godot --path game res://tests/manual/capture_menus.tscn -- --out=<dir> [--only=<a,b>]
## <dir> defaults to the repository's docs/menu-clarity/after/. The game shell starts at 1x
## (640x360) with its own settings file in user://; each shot is the whole 640x360 picture enlarged
## ×2 with nearest filtering. The machine's LAN addresses are replaced by an example so the
## pictures can be shared. Shots (names are stable across runs, so before/after pairs line up):
##   menu_title, menu_settings, menu_credits, menu_join, menu_join_failed, menu_lobby_host,
##   menu_pause_solo, menu_summary_death.
## The solo run is started through the shell; its player is killed with a thirst hit by a hook.

const SHELL_SCENE: PackedScene = preload("res://scenes/shell/game_shell.tscn")
const BASE: Vector2i = Vector2i(640, 360)
const SCALE: int = 2
const EXAMPLE_ADDRESS: String = "192.168.1.70"
const WATCHDOG_S: float = 90.0
const RUN_WAIT_S: float = 15.0

var out_dir: String = ""
var only: PackedStringArray = []
var shell: GameShell


func _ready() -> void:
	out_dir = ProjectSettings.globalize_path("res://").path_join("../docs/menu-clarity/after").simplify_path()
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out_dir = arg.trim_prefix("--out=")
		elif arg.begins_with("--only="):
			only = arg.trim_prefix("--only=").split(",", false)
	DirAccess.make_dir_recursive_absolute(out_dir)
	get_tree().create_timer(WATCHDOG_S).timeout.connect(func() -> void:
		push_error("capture_menus: the watchdog fired")
		get_tree().quit(2))
	var settings_path: String = "user://capture_menus.cfg"
	var config := ConfigFile.new()
	config.set_value("player", "name", "Yuni")
	config.set_value("player", "name_asked", true)
	config.set_value("display", "fullscreen", false)
	config.set_value("display", "ui_scale", 1)
	config.set_value("display", "pixel_filter", 0)
	config.save(settings_path)
	shell = SHELL_SCENE.instantiate() as GameShell
	shell.settings_path = settings_path
	add_child(shell)
	await _frames(20)
	await _menus()
	await _run()
	if shell.flow == GameShell.Flow.RUN or shell.session != null:
		shell.back_to_title()
	await _frames(2)
	print("capture_menus: done, pictures in %s" % out_dir)
	get_tree().quit()


func _menus() -> void:
	await _shot("menu_title")
	shell.show_settings()
	await _frames(10)
	await _shot("menu_settings")
	shell.show_credits()
	await _frames(10)
	await _shot("menu_credits")
	shell.show_title()
	await _frames(4)
	shell.show_join()
	await _frames(10)
	await _shot("menu_join")
	var join := shell.screen as JoinScreen
	if join != null:
		join.address_field.text = EXAMPLE_ADDRESS + ":7777"
		join.show_failed()
		await _frames(6)
		await _shot("menu_join_failed")
	shell.back_to_title()
	await _frames(4)
	shell.port = 0
	shell.start_host()
	await _frames(20)
	var lobby := shell.screen as LobbyScreen
	if lobby != null:
		if not lobby.addresses.text.is_empty():
			lobby.addresses.text = "Tu IP: %s" % EXAMPLE_ADDRESS
		await _frames(4)
		await _shot("menu_lobby_host")
	shell.back_to_title()
	await _frames(6)


func _run() -> void:
	if not (_wanted("menu_pause_solo") or _wanted("menu_summary_death")):
		return
	shell.start_solo()
	var deadline: int = Time.get_ticks_msec() + int(RUN_WAIT_S * 1000.0)
	while (shell.flow != GameShell.Flow.RUN or shell.hud == null) and Time.get_ticks_msec() < deadline:
		await _frames(1)
	if shell.flow != GameShell.Flow.RUN:
		push_error("capture_menus: the solo run did not start")
		return
	await _frames(30)
	shell.hud.pause_menu.open()
	await _frames(6)
	await _shot("menu_pause_solo")
	shell.hud.pause_menu.resume()
	await _frames(6)
	var body: PlayerBody = shell.session.body(multiplayer.get_unique_id())
	body.meters.harm(1000.0, &"thirst")
	deadline = Time.get_ticks_msec() + int(RUN_WAIT_S * 1000.0)
	while shell.flow != GameShell.Flow.SUMMARY and Time.get_ticks_msec() < deadline:
		await _frames(1)
	await _frames(10)
	await _shot("menu_summary_death")


func _wanted(file: String) -> bool:
	return only.is_empty() or only.has(file)


func _frames(count: int) -> void:
	for i: int in count:
		await get_tree().process_frame


func _shot(file: String) -> void:
	if not _wanted(file):
		return
	await RenderingServer.frame_post_draw
	var image: Image = get_viewport().get_texture().get_image()
	image.convert(Image.FORMAT_RGBA8)
	if image.get_size() != BASE:
		image.resize(BASE.x, BASE.y, Image.INTERPOLATE_NEAREST)
	image.resize(BASE.x * SCALE, BASE.y * SCALE, Image.INTERPOLATE_NEAREST)
	var path: String = out_dir.path_join(file + ".png")
	var err: Error = image.save_png(path)
	if err != OK:
		push_error("capture_menus: could not write %s (%d)" % [path, err])
	else:
		print("capture_menus: wrote %s" % path)
