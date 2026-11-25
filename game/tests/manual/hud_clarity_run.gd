extends SceneTree
## Manual two-process check for hud-clarity (ui-shell "The clock follows the host", "Objective while
## building the raft"; survival-meters "Bleeding time on every peer"). It boots the real game shell
## on each side:
##   godot --headless --path game -s res://tests/manual/hud_clarity_run.gd -- --mode=host --port=7800
##   godot --headless --path game -s res://tests/manual/hud_clarity_run.gd -- --mode=client --port=7800
## The host (Yuni) starts the run once the client (Papo) is in the lobby. Then:
## 1. The host puts the one clock at 14:00 on day 2. Papo checks his clock row reads "Día 2", "6h" or
##    "5h" (the clock runs) and "Mediodía", with the moon mark; the host checks its own row the same.
## 2. Yuni drops 6 driftwood into the raft site. Papo, carrying nothing, checks his objective row moves
##    from "Arma la balsa: 0/6 madera" to "Arma la balsa: 0/2 cámaras".
## 3. A bite makes Papo bleed on the host. Papo checks "Sangrando" shows with its time bar near full,
##    and that the bar drains with the host's time left (lower 3 s later, matching his synced time).
## 4. The host puts Yuni beside the raft site and Papo up by the hut. Papo's arrow points south-west
##    at the site from his own view; the host's shows none, its site in view.
## 5. The host builds the raft at about 14:00 with the sandbar's patrol boat out. Both rows read
##    "Espera la noche pa' zarpar", and Papo's arrow now points at the raft.
## 6. The host puts the clock at 21:00. Both rows read the sandbar's launch line, "Zarpa pa'l cayo".
## Each check prints "HUDC PASS|FAIL <mode>: <what> | <detail>", and a failed check makes the run quit
## non-zero. Compiled before the autoloads exist, so it names no project class.

const SHELL_PATH: String = "res://scenes/shell/game_shell.tscn"
const FLOW_RUN: int = 3
const HOST_ID: int = 1
const BLEEDING: int = 1
const DEADLINE_S: float = 240.0
## 14:00 on the one clock, day 2.
const AFTERNOON_S: float = 240.0
## 21:00 on the one clock.
const NIGHT_S: float = 450.0
## Papo by the hut, from the raft site: the site is out of his view to the south-west.
const BY_THE_HUT: Vector2 = Vector2(300.0, -220.0)
const WAIT_LINE: String = "Espera la noche pa' zarpar"
const LAUNCH_LINE: String = "Zarpa pa'l cayo"

var mode: String = ""
var port: int = 7800
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
	var settings_path: String = "user://hud_clarity_run_%s.cfg" % mode
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
	print("HUDC hud_clarity_run mode %s, port %d, pid %d" % [mode, port, OS.get_process_id()])
	if mode == "host":
		await _host()
	elif mode == "client":
		await _client()
	else:
		_check("known mode", false, mode)
	_finish()


func _clock_row(hud: Node) -> Array[String]:
	var clock: Object = hud.get("clock")
	return [str((clock.get("day_label") as Label).text), str((clock.get("left_label") as Label).text), str((hud.get("phase_label") as Label).text)] as Array[String]


func _objective(hud: Node) -> String:
	var row: Object = hud.get("objective_row")
	return str((row.get("label") as Label).text) if (row as CanvasItem).visible else ""


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
	if not await _wait_for("both bodies", func() -> bool: return shell.get("flow") == FLOW_RUN and (session.call("peer_ids") as Array).size() == 2, 30.0):
		return
	await _seconds(3.0)
	var client_id: int = 0
	for peer_id: int in session.call("peer_ids"):
		if peer_id != HOST_ID:
			client_id = peer_id
	var yuni: Node = session.call("body", HOST_ID)
	var papo: Node = session.call("body", client_id)
	var hud: Node = shell.get("hud")
	# 1. The clock at 14:00 on day 2; the sky's change sends it to Papo.
	var sky: Object = root.get_node("/root/WeatherManager").get("sky")
	var state: Dictionary = sky.call("to_state")
	state["time_of_day_s"] = AFTERNOON_S
	state["day"] = 2
	_check("the host's sky took 14:00 on day 2", sky.call("apply_state", state) == true)
	await _seconds(0.5)
	var row: Array[String] = _clock_row(hud)
	_check("the host's clock row", row[0] == "Día 2" and row[1] in ["6h", "5h"] and row[2] == "Mediodía", str(row))
	print("HUDC step 1: the clock at 14:00 on day 2")
	await _seconds(4.0)
	# 2. Yuni drops 6 driftwood into the raft site.
	(yuni.get("inventory") as Object).call("add", &"driftwood", 6)
	var site: Node = session.get_node_or_null("RaftSite")
	if not _check("the level's raft site", site != null):
		return
	site.call("deposit", yuni)
	_check("the site holds 6 driftwood on the host", int((site.get("deposited") as Dictionary).get(&"driftwood", 0)) == 6)
	var yuni_moved := func() -> bool: return _objective(hud) == "Arma la balsa: 0/2 cámaras"
	_check("Yuni's own row moved on", await _wait_for("Yuni's row", yuni_moved, 2.0), _objective(hud))
	print("HUDC step 2: Yuni deposited 6 driftwood")
	await _seconds(4.0)
	# 3. Papo bleeds on the host.
	var papo_meters: Object = papo.get("meters")
	papo_meters.call("set_status", BLEEDING, true)
	_check("Papo's bleeding time starts full on the host", float(papo_meters.get("bleeding_left_s")) > 119.0, str(papo_meters.get("bleeding_left_s")))
	print("HUDC step 3: Papo bleeds")
	await _seconds(8.0)
	_check("the time ran down on the host", float(papo_meters.get("bleeding_left_s")) < 115.0, str(papo_meters.get("bleeding_left_s")))
	# 4. Yuni beside the site, Papo up by the hut.
	var at_site: Vector2 = (site as Node2D).global_position
	(yuni as Node2D).global_position = at_site + Vector2(24.0, 0.0)
	(yuni.get("camera") as Camera2D).reset_smoothing()
	(papo as Node2D).global_position = at_site + BY_THE_HUT
	print("HUDC step 4: Yuni at the site, Papo by the hut")
	await _seconds(1.0)
	var arrow: Object = hud.get("site_arrow")
	_check("the host's arrow is away, its site in view", arrow.call("shown") == false)
	await _seconds(5.0)
	# 5. The raft built by day, the patrol boat out.
	var inputs: Dictionary = (site.get("recipe") as Resource).get("inputs")
	var deposited: Dictionary = site.get("deposited")
	for id: Variant in inputs:
		deposited[id] = inputs[id]
	site.call("work", 1.0)
	await _seconds(0.5)
	_check("the raft is built on the host", session.get_node_or_null("Raft") != null)
	var waits := func() -> bool: return _objective(hud) == WAIT_LINE
	_check("the host's row waits for the dark", await _wait_for("the wait line", waits, 3.0), _objective(hud))
	print("HUDC step 5: the raft built by day")
	await _seconds(6.0)
	# 6. Night.
	state = sky.call("to_state")
	state["time_of_day_s"] = NIGHT_S
	_check("the host's sky took 21:00", sky.call("apply_state", state) == true)
	var launches := func() -> bool: return _objective(hud) == LAUNCH_LINE
	_check("the host's row says to set off", await _wait_for("the launch line", launches, 3.0), _objective(hud))
	print("HUDC step 6: night")
	# The client needs the last state before the host goes away.
	await _seconds(6.0)


func _client() -> void:
	shell.call("_join", "127.0.0.1", port)
	if not await _wait_for("the run", func() -> bool: return shell.get("flow") == FLOW_RUN, 120.0):
		return
	var session: Node = shell.get("session")
	var me: int = session.multiplayer.get_unique_id()
	if not await _wait_for("both bodies", func() -> bool: return session.call("body", me) != null and session.call("body", HOST_ID) != null, 30.0):
		return
	var own: Node = session.call("body", me)
	var hud: Node = shell.get("hud")
	# 1. The host's clock.
	var clock_ok := func() -> bool:
		var row: Array[String] = _clock_row(hud)
		return row[0] == "Día 2" and row[1] in ["6h", "5h"] and row[2] == "Mediodía"
	_check("Papo's clock row follows the host's", await _wait_for("Día 2 at 14:00", clock_ok, 30.0), str(_clock_row(hud)))
	_check("the moon mark: time to dark", (hud.get("clock") as Object).get("counts_to_dawn") == false)
	# 2. The host's deposit.
	_check("Papo's row before the deposit", _objective(hud) == "Arma la balsa: 0/6 madera", _objective(hud))
	var moved := func() -> bool: return _objective(hud) == "Arma la balsa: 0/2 cámaras"
	_check("Papo's row follows the host's deposit", await _wait_for("0/2 cámaras", moved, 30.0), _objective(hud))
	# 3. Papo bleeds: the row and its bar.
	var own_meters: Object = own.get("meters")
	var meters_hud: Object = hud.get("meters")
	var bleeds := func() -> bool: return (int(own_meters.get("status_flags")) & (1 << BLEEDING)) != 0
	if not await _wait_for("Papo's bite", bleeds, 30.0):
		return
	await _seconds(0.5)
	var row: Object = meters_hud.call("status_row", &"bleeding")
	_check("Sangrando shows on Papo's screen", (row as CanvasItem).visible)
	var first: float = row.call("fill_ratio")
	_check("its bar starts near full", first > 0.95, str(first))
	await _seconds(3.0)
	var second: float = row.call("fill_ratio")
	var expected: float = float(own_meters.get("bleeding_left_s")) / 120.0
	_check("the bar drains with the host's time", second < first and absf(second - expected) < 0.02, "%.3f then %.3f, synced %.3f" % [first, second, expected])
	# 4. Papo by the hut: his own arrow points south-west at the site.
	var arrow: Object = hud.get("site_arrow")
	var points := func() -> bool: return arrow.call("shown") == true and arrow.call("direction") == Vector2i(-1, 1)
	_check("Papo's arrow points south-west at the site", await _wait_for("Papo's arrow", points, 20.0), "%s %s" % [arrow.call("shown"), arrow.call("direction")])
	# 5. The raft built by day.
	var waits := func() -> bool: return _objective(hud) == WAIT_LINE
	_check("Papo's row waits for the dark", await _wait_for("the wait line", waits, 30.0), _objective(hud))
	_check("the raft is built on Papo's side", session.get_node_or_null("Raft") != null)
	var raft_arrow := func() -> bool: return arrow.call("shown") == true and arrow.call("site") == session.get_node_or_null("Raft")
	_check("Papo's arrow points at the raft", await _wait_for("the raft's arrow", raft_arrow, 5.0))
	# 6. Night: the sandbar's launch line.
	var launches := func() -> bool: return _objective(hud) == LAUNCH_LINE
	_check("Papo's row says to set off at night", await _wait_for("the launch line", launches, 30.0), _objective(hud))


func _check(label: String, ok: bool, detail: String = "") -> bool:
	if ok:
		passes += 1
	else:
		fails += 1
	print("HUDC %s %s: %s%s" % ["PASS" if ok else "FAIL", mode, label, (" | " + detail) if not detail.is_empty() else ""])
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
	print("HUDC done %s: %d passed, %d failed" % [mode, passes, fails])
	shell.call("back_to_title")
	quit(1 if fails > 0 else 0)
