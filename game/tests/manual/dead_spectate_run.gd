extends SceneTree
## Manual two-process check for dead-spectate (ui-shell "Spectating on every peer"). It boots the
## real game shell on each side, because the coop playground builds no run HUD:
##   godot --headless --path game -s res://tests/manual/dead_spectate_run.gd -- --mode=host --port=7787
##   godot --headless --path game -s res://tests/manual/dead_spectate_run.gd -- --mode=client --port=7787
## The host (Yuni) starts the run once the client (Papo) is in the lobby, then kills Papo's player
## through the meters, the same hook the GUT tests use. Papo checks that his world view's current
## camera is Yuni's body camera, that his line reads "Mirando a: Yuni  [A] [D] Cambiar" and that his
## meters panel shows Yuni's meters. A while later the host kills Yuni, and both must reach the run
## summary. Each check prints "SPECTATE PASS|FAIL <what> | <detail>", and a failed check makes the
## run quit non-zero. Compiled before the autoloads exist, so it names no project class.

const SHELL_PATH: String = "res://scenes/shell/game_shell.tscn"
const FLOW_RUN: int = 3
const FLOW_SUMMARY: int = 4
const HOST_ID: int = 1
const DEADLINE_S: float = 300.0
## How long the host waits after Papo dies before it kills Yuni: Papo checks his view meanwhile.
const WATCH_WINDOW_S: float = 10.0
const LINE: String = "Mirando a: Yuni  [A] [D] Cambiar"

var mode: String = ""
var port: int = 7787
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
	var settings_path: String = "user://dead_spectate_run_%s.cfg" % mode
	var config := ConfigFile.new()
	config.set_value("player", "name", "Papo" if mode == "client" else "Yuni")
	config.set_value("display", "fullscreen", false)
	config.set_value("display", "ui_scale", 2)
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
	print("SPECTATE dead_spectate_run mode %s, port %d, pid %d" % [mode, port, OS.get_process_id()])
	if mode == "host":
		await _host()
	elif mode == "client":
		await _client()
	else:
		_check("known mode", false, mode)
	_finish()


func _host() -> void:
	shell.set("port", port)
	shell.call("start_host")
	var session: Node = shell.get("session")
	if not _check("start_host opened port %d" % port, session != null and not (session.multiplayer.multiplayer_peer is OfflineMultiplayerPeer)):
		return
	if not await _wait_for("Papo in the lobby", func() -> bool: return (session.get("roster") as Dictionary).size() > 1, 120.0):
		return
	await _seconds(1.0)
	_check("begin_run started the run", session.call("begin_run") == true)
	if not await _wait_for("the run", func() -> bool: return shell.get("flow") == FLOW_RUN, 10.0):
		return
	if not await _wait_for("both bodies", func() -> bool: return (session.call("peer_ids") as Array).size() == 2, 30.0):
		return
	await _seconds(2.0)
	var client_id: int = 0
	for peer_id: int in session.call("peer_ids"):
		if peer_id != HOST_ID:
			client_id = peer_id
	var own: Node = session.call("body", HOST_ID)
	(session.call("body", client_id).get("meters") as Object).set("dead", true)
	print("SPECTATE set Papo's player dead on the host")
	await _seconds(1.0)
	_check("the run goes on while Yuni lives", shell.get("flow") == FLOW_RUN)
	var hud: Node = shell.get("hud")
	_check("the living host watches nobody", not (hud.get("spectate") as Object).call("active"))
	_check("the host's view stays on Yuni", (shell.get("world_viewport") as Viewport).get_camera_2d() == own.get("camera"))
	await _seconds(WATCH_WINDOW_S)
	(own.get("meters") as Object).set("dead", true)
	print("SPECTATE set Yuni's player dead on the host")
	await _wait_for("the host's summary", func() -> bool: return shell.get("flow") == FLOW_SUMMARY, 10.0)
	_check("the host reached the run summary", shell.get("flow") == FLOW_SUMMARY)
	# The client needs the last state before the host goes away.
	await _seconds(3.0)


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
	_check("the living client watches nobody", not ((shell.get("hud") as Node).get("spectate") as Object).call("active"))
	if not await _wait_for("Papo's death", func() -> bool: return (own.get("meters") as Object).get("dead"), 60.0):
		return
	var hud: Node = shell.get("hud")
	var spectate: Object = hud.get("spectate")
	if not await _wait_for("watching", func() -> bool: return spectate.call("active"), 5.0):
		return
	await _seconds(0.5)
	var viewport: Viewport = shell.get("world_viewport")
	_check("Papo watches Yuni's body", spectate.call("watched") == yuni)
	_check("the world view's current camera is Yuni's", viewport.get_camera_2d() == yuni.get("camera"), str(viewport.get_camera_2d().get_parent().name) if viewport.get_camera_2d() != null else "none")
	_check("Papo's own camera is off", not (own.get("camera") as Camera2D).enabled)
	var panel: Control = hud.get("watching_panel")
	var line: String = (hud.get("watching_label") as Label).text
	_check("the line shows", panel.visible)
	_check("the line reads '%s'" % LINE, line == LINE, line)
	_check("the meters panel shows Yuni's meters", (hud.get("meters") as Object).call("shown") == yuni.get("meters"))
	_check("the strip is hidden", not (hud.get("strip") as Control).visible)
	_check("the run goes on while Yuni lives", shell.get("flow") == FLOW_RUN)
	await _wait_for("the client's summary", func() -> bool: return shell.get("flow") == FLOW_SUMMARY, 60.0)
	_check("the client reached the run summary when Yuni died", shell.get("flow") == FLOW_SUMMARY)


func _check(label: String, ok: bool, detail: String = "") -> bool:
	if ok:
		passes += 1
	else:
		fails += 1
	print("SPECTATE %s %s: %s%s" % ["PASS" if ok else "FAIL", mode, label, (" | " + detail) if not detail.is_empty() else ""])
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
	print("SPECTATE done %s: %d passed, %d failed" % [mode, passes, fails])
	shell.call("back_to_title")
	quit(1 if fails > 0 else 0)
