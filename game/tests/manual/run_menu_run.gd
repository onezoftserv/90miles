extends SceneTree
## Manual two-process check for run-menu (coop-networking "Pause", ui-shell "Run menu" and
## "Abandoning a run"; tasks 5.2). It boots the real game shell on each side, through NetManager and
## ENet on UDP 7801:
##   godot --headless --path game -s res://tests/manual/run_menu_run.gd -- --mode=host --port=7801
##   godot --headless --path game -s res://tests/manual/run_menu_run.gd -- --mode=client --port=7801
## Papo (the client) walks east, opens his run menu with the pause key as the game's input does, and
## checks that nothing pauses and his own intent stands still. The host (Yuni) checks that its clock
## and run go on and that its copy of Papo stands still while his menu is open. Papo then confirms
## "Abandonar" and checks he is on the title, offline; the host checks its HUD lists Papo as
## "Desconectado". The two sides meet through a file both processes share (user://, the same
## project). Each check prints "RUNMENU PASS|FAIL <what>", and a failed check makes the run quit
## non-zero; the launcher also reads both logs for engine errors. Compiled before the autoloads
## exist, so it names no project class.

const SHELL_PATH: String = "res://scenes/shell/game_shell.tscn"
const STATE_PATH: String = "user://run_menu_run_state.cfg"
const FLOW_TITLE: int = 0
const FLOW_RUN: int = 3
const HOST_ID: int = 1
const DEADLINE_S: float = 240.0

var mode: String = ""
var port: int = 7801
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
	var settings_path: String = "user://run_menu_run_%s.cfg" % mode
	var config := ConfigFile.new()
	config.set_value("player", "name", "Papo" if mode == "client" else "Yuni")
	config.set_value("player", "name_asked", true)
	config.set_value("display", "fullscreen", false)
	config.set_value("display", "ui_scale", 2)
	config.set_value("display", "pixel_filter", 0)
	config.save(settings_path)
	if mode == "host" and FileAccess.file_exists(STATE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(STATE_PATH))
	shell = (load(SHELL_PATH) as PackedScene).instantiate()
	shell.set("settings_path", settings_path)
	root.add_child(shell)
	create_timer(DEADLINE_S).timeout.connect(_on_deadline)
	_main()


func _main() -> void:
	await process_frame
	await process_frame
	print("RUNMENU run_menu_run mode %s, port %d, pid %d" % [mode, port, OS.get_process_id()])
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
	if not await _wait_for("both bodies", func() -> bool: return (session.call("peer_ids") as Array).size() == 2, 30.0):
		return
	var papo_id: int = _other_peer(session)
	var papo: Node2D = session.call("body", papo_id)
	if not await _wait_for("Papo walking east", func() -> bool: return (papo.get("velocity") as Vector2).x > 0.0, 30.0):
		return
	if not await _wait_for("Papo's menu open", func() -> bool: return _state() == "menu_open", 30.0):
		return
	var weather: Node = root.get_node(^"WeatherManager")
	var clock_at: float = weather.call("time_of_day_s")
	await _seconds(0.5)
	var held_at: Vector2 = papo.position
	await _seconds(1.0)
	_check("the host is not paused", not paused)
	_check("the host's clock goes on", weather.call("time_of_day_s") > clock_at, "%.2f then %.2f" % [clock_at, weather.call("time_of_day_s")])
	_check("Papo stands still on the host", papo.position.distance_to(held_at) < 0.5, "moved %.2f px" % papo.position.distance_to(held_at))
	_write_state("host_checked")
	var hud: Node = shell.get("hud")
	var dropped := func() -> bool:
		hud.call("refresh")
		for row: String in hud.call("teammate_rows"):
			if row.begins_with("Papo ") and row.ends_with("Desconectado"):
				return true
		return false
	await _wait_for("the HUD listing Papo as Desconectado", dropped, 30.0)
	_check("the host's run goes on", shell.get("flow") == FLOW_RUN)


func _client() -> void:
	shell.call("_join", "127.0.0.1", port)
	if not await _wait_for("the run", func() -> bool: return shell.get("flow") == FLOW_RUN and shell.get("hud") != null, 120.0):
		return
	var session: Node = shell.get("session")
	var me: int = session.multiplayer.get_unique_id()
	if not await _wait_for("both bodies", func() -> bool: return session.call("body", me) != null and session.call("body", HOST_ID) != null, 30.0):
		return
	var body: Node2D = session.call("body", me)
	Input.action_press(&"move_right")
	await _seconds(1.0)
	var menu: CanvasLayer = (shell.get("hud") as Node).get("pause_menu")
	var press := InputEventAction.new()
	press.action = &"pause"
	press.pressed = true
	Input.parse_input_event(press)
	var release := InputEventAction.new()
	release.action = &"pause"
	release.pressed = false
	Input.parse_input_event(release)
	if not await _wait_for("the run menu open from the pause key", func() -> bool: return menu.visible, 5.0):
		return
	_check("its tab reads Menú", (menu.get("title") as Label).text == "Menú")
	_check("it says La partida sigue.", (menu.get("line") as Label).visible)
	_check("nothing pauses", not paused)
	_write_state("menu_open")
	await _seconds(0.5)
	var intent: Object = body.get("intent")
	_check("Papo's own intent stands still", intent.get("direction") == Vector2.ZERO)
	if not await _wait_for("the host's check", func() -> bool: return _state() == "host_checked", 30.0):
		return
	Input.action_release(&"move_right")
	menu.call("ask_abandon")
	var box: Node = menu.get("view")
	_check("the question reads ¿Abandonar el viaje?", (box.get("question") as Label).text == "¿Abandonar el viaje?")
	_check("Cancelar has the focus", (box.get("cancel_button") as Button).has_focus())
	(box.get("confirm_button") as Button).pressed.emit()
	if not await _wait_for("the title", func() -> bool: return shell.get("flow") == FLOW_TITLE, 10.0):
		return
	_check("offline", shell.multiplayer.multiplayer_peer is OfflineMultiplayerPeer)
	_check("not paused", not paused)
	# The host needs a moment to mark Papo dropped before this process quits.
	await _seconds(3.0)


func _state() -> String:
	var config := ConfigFile.new()
	if config.load(STATE_PATH) != OK:
		return ""
	return config.get_value("run", "state", "")


func _write_state(value: String) -> void:
	var config := ConfigFile.new()
	config.set_value("run", "state", value)
	config.save(STATE_PATH)


func _other_peer(session: Node) -> int:
	for peer_id: int in session.call("peer_ids"):
		if peer_id != HOST_ID:
			return peer_id
	return 0


func _check(label: String, ok: bool, detail: String = "") -> bool:
	if ok:
		passes += 1
	else:
		fails += 1
	print("RUNMENU %s %s: %s%s" % ["PASS" if ok else "FAIL", mode, label, (" | " + detail) if not detail.is_empty() else ""])
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
	print("RUNMENU done %s: %d passed, %d failed" % [mode, passes, fails])
	if shell.get("flow") != FLOW_TITLE:
		shell.call("back_to_title")
	# Freed before quitting, so the exit reports no leaked nodes or resources.
	shell.free()
	await process_frame
	await process_frame
	quit(1 if fails > 0 else 0)
