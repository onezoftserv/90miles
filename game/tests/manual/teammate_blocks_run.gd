extends SceneTree
## Manual two-process check for hud-window-kit's teammate blocks (ui-shell "HUD layout", "Teammate
## state word"; design D7, owner answer B1). It boots the real game shell on each side:
##   godot --headless --path game -s res://tests/manual/teammate_blocks_run.gd -- --mode=host --port=7797
##   godot --headless --path game -s res://tests/manual/teammate_blocks_run.gd -- --mode=client --port=7797
## Run the host without --headless and pass --shot=<file.png> to save its top-right corner at x3.
## The host (Yuni) starts the run once the client ("Ñico de la Loma1", 16 characters) is in the lobby.
## 1. Each side finds the other's block: the whole name, the clothing chip, a full health bar, no
##    state word, inside x 502 to 636.
## 2. The host sets Papo's health to 40; both sides see it (his bar on the host, his own Salud row on
##    the client, Salud first).
## 3. The client leaves; the host's block for him reads "Desconectado" in grey.
## Each check prints "BLOCKS PASS|FAIL <mode>: <what> | <detail>", and a failed check makes the run
## quit non-zero. Compiled before the autoloads exist, so it names no project class.

const SHELL_PATH: String = "res://scenes/shell/game_shell.tscn"
const FLOW_RUN: int = 3
const HOST_ID: int = 1
const HEALTH: int = 6
const DEADLINE_S: float = 240.0
const LONG_NAME: String = "Ñico de la Loma1"
const LIST: Rect2 = Rect2(502.0, 4.0, 134.0, 86.0)
const DROPPED_COLOR: Color = Color(0.60784314, 0.67843137, 0.71764706)

var mode: String = ""
var port: int = 7797
var shot: String = ""
var shell: Node
var passes: int = 0
var fails: int = 0
var done: bool = false


func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--mode="):
			mode = arg.trim_prefix("--mode=")
		elif arg.begins_with("--port="):
			port = arg.trim_prefix("--port=").to_int()
		elif arg.begins_with("--shot="):
			shot = arg.trim_prefix("--shot=")
	var settings_path: String = "user://teammate_blocks_run_%s.cfg" % mode
	var config := ConfigFile.new()
	config.set_value("player", "name", LONG_NAME if mode == "client" else "Yuni")
	config.set_value("display", "fullscreen", false)
	config.set_value("display", "ui_scale", 1)
	config.set_value("display", "pixel_filter", 0)
	config.save(settings_path)
	shell = (load(SHELL_PATH) as PackedScene).instantiate()
	shell.set("settings_path", settings_path)
	root.add_child(shell)
	create_timer(DEADLINE_S).timeout.connect(_on_deadline)
	_main()


func _main() -> void:
	await process_frame
	await process_frame
	print("BLOCKS teammate_blocks_run mode %s, port %d, pid %d" % [mode, port, OS.get_process_id()])
	if mode == "host":
		await _host()
	elif mode == "client":
		await _client()
	else:
		_check("known mode", false, mode)
	_finish()


# The block on `hud` whose name is `who`, refreshed now, or null.
func _block(hud: Object, who: String) -> Object:
	hud.call("refresh")
	for block: Object in hud.call("teammate_blocks"):
		if block.get("teammate_name") == who:
			return block
	return null


func _check_block(block: Object, who: String, look_slot: int, hud: Object) -> void:
	if not _check("a block for %s" % who, block != null):
		return
	var name_label: Label = block.get("name_label")
	_check("%s's whole name" % who, name_label.text == who, name_label.text)
	var chip: ColorRect = block.get("chip")
	var expected: Color = block.call("chip_color", look_slot)
	_check("%s's chip is look slot %d's colour" % [who, look_slot], chip.color.is_equal_approx(expected), chip.color.to_html(false))
	_check("%s's bar is full" % who, is_equal_approx((block.get("bar") as ProgressBar).value, 100.0))
	_check("%s has no state word" % who, (block.get("state_label") as Label).text.is_empty())
	var panel: Rect2 = (hud.get("teammates_panel") as Control).get_global_rect()
	_check("the list inside x 502-636", LIST.encloses(panel), str(panel))
	_check("the name inside the list", panel.encloses(name_label.get_global_rect()), str(name_label.get_global_rect()))


func _host() -> void:
	shell.set("port", port)
	shell.call("start_host")
	var session: Node = shell.get("session")
	if not _check("start_host opened port %d" % port, session != null and not (session.multiplayer.multiplayer_peer is OfflineMultiplayerPeer)):
		return
	if not await _wait_for("the client in the lobby", func() -> bool: return (session.get("roster") as Dictionary).size() > 1, 120.0):
		return
	await _seconds(1.0)
	_check("begin_run started the run", session.call("begin_run") == true)
	if not await _wait_for("both bodies", func() -> bool: return shell.get("flow") == FLOW_RUN and (session.call("peer_ids") as Array).size() == 2, 30.0):
		return
	await _seconds(2.0)
	var client_id: int = 0
	for peer_id: int in session.call("peer_ids"):
		if peer_id != HOST_ID:
			client_id = peer_id
	var papo: Node = session.call("body", client_id)
	var hud: Object = shell.get("hud")
	if not await _wait_for("the client's name", func() -> bool: return _block(hud, LONG_NAME) != null, 20.0):
		return
	_check_block(_block(hud, LONG_NAME), LONG_NAME, papo.get("look_slot"), hud)
	# 2. Papo is hurt.
	(papo.get("meters") as Object).set("health", 40.0)
	await process_frame
	_check("the client's bar shows 40", is_equal_approx(((_block(hud, LONG_NAME) as Object).get("bar") as ProgressBar).value, 40.0))
	print("BLOCKS step 2: the client's health is 40")
	if not shot.is_empty() and DisplayServer.get_name() != "headless":
		await _seconds(1.0)
		_save_corner(shot)
	# 3. The client leaves.
	var dropped := func() -> bool:
		var block: Object = _block(hud, LONG_NAME)
		return block != null and block.get("state") == "Desconectado"
	if await _wait_for("the client dropped", dropped, 60.0):
		var word: Label = (_block(hud, LONG_NAME) as Object).get("state_label")
		_check("Desconectado in grey", word.get_theme_color(&"font_color").is_equal_approx(DROPPED_COLOR))
		_check("Desconectado inside the list", (hud.get("teammates_panel") as Control).get_global_rect().encloses(word.get_global_rect()))
		if not shot.is_empty() and DisplayServer.get_name() != "headless":
			await _seconds(0.5)
			_save_corner(shot.get_basename() + "_dropped.png")


func _client() -> void:
	shell.call("_join", "127.0.0.1", port)
	if not await _wait_for("the run", func() -> bool: return shell.get("flow") == FLOW_RUN, 120.0):
		return
	var session: Node = shell.get("session")
	var me: int = session.multiplayer.get_unique_id()
	if not await _wait_for("both bodies", func() -> bool: return session.call("body", me) != null and session.call("body", HOST_ID) != null, 30.0):
		return
	var own: Node = session.call("body", me)
	var yuni: Node = session.call("body", HOST_ID)
	var hud: Object = shell.get("hud")
	if not await _wait_for("Yuni's block", func() -> bool: return _block(hud, "Yuni") != null, 20.0):
		return
	_check_block(_block(hud, "Yuni"), "Yuni", yuni.get("look_slot"), hud)
	_check("no block for the local player", _block(hud, LONG_NAME) == null)
	# 2. The host hurts us.
	var meters: Object = own.get("meters")
	if not await _wait_for("our health at 40", func() -> bool: return is_equal_approx(float(meters.get("health")), 40.0), 30.0):
		return
	var meters_hud: Object = hud.get("meters")
	var first: Object = (meters_hud.call("bars") as Array)[0]
	_check("Salud is the first row", first.get("meter") == HEALTH)
	await process_frame
	_check("our Salud row shows 40", is_equal_approx((first.get("bar") as ProgressBar).value, 40.0))
	await _seconds(3.0)
	print("BLOCKS step 3: the client leaves")


func _save_corner(path: String) -> void:
	var image: Image = root.get_texture().get_image()
	var scale: float = float(image.get_width()) / 640.0
	var crop := Rect2i(Vector2i(roundi(472.0 * scale), 0), Vector2i(roundi(168.0 * scale), roundi(96.0 * scale)))
	var corner: Image = image.get_region(crop)
	corner.resize(168 * 3, 96 * 3, Image.INTERPOLATE_NEAREST)
	_check("saved %s" % path, corner.save_png(path) == OK, path)


func _check(label: String, ok: bool, detail: String = "") -> bool:
	if ok:
		passes += 1
	else:
		fails += 1
	print("BLOCKS %s %s: %s%s" % ["PASS" if ok else "FAIL", mode, label, (" | " + detail) if not detail.is_empty() else ""])
	return ok


func _wait_for(what: String, ready: Callable, timeout_s: float) -> bool:
	var hz: int = Engine.physics_ticks_per_second
	for i: int in ceili(timeout_s * hz):
		if ready.call():
			return true
		await physics_frame
	return _check("%s within %.0f s" % [what, timeout_s], false)


func _seconds(seconds: float) -> void:
	for i: int in ceili(seconds * Engine.physics_ticks_per_second):
		await physics_frame


func _on_deadline() -> void:
	if not done:
		_check("finished before the %d s deadline" % int(DEADLINE_S), false)
		_finish()


func _finish() -> void:
	if done:
		return
	done = true
	print("BLOCKS done %s: %d passed, %d failed" % [mode, passes, fails])
	shell.call("back_to_title")
	quit(1 if fails > 0 else 0)
