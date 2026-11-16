extends SceneTree
## Manual two-process check for damage-feedback (survival-meters "Hurt cue on the body", "Change
## floats over the body"; ui-shell "Hit flash at the screen edges", "Drain glow on the health bar").
## It boots the real game shell on each side:
##   godot --headless --path game -s res://tests/manual/damage_feedback_run.gd -- --mode=host --port=7793
##   godot --headless --path game -s res://tests/manual/damage_feedback_run.gd -- --mode=client --port=7793
## The host (Yuni) starts the run once the client (Papo) is in the lobby. Then, step by step:
## 1. A crab's pinch on Papo (host meters). Papo checks his edges flashed, his own body blinks and his
##    Salud bar shows the lost part; the host checks Papo's body blinks on its screen and its own
##    edges did not flash.
## 2. A pinch on Yuni. Papo checks Yuni's body blinks on his screen and his edges did not flash.
## 3. Yuni drinks a coconut. Papo checks "+15 Sed" floats over Yuni.
## 4. Papo's thirst empties, so his health drains. Papo checks his Salud frame glows and that the
##    drain neither blinks him nor flashes his edges; then the host gives the thirst back.
## Each check prints "DAMAGE PASS|FAIL <mode>: <what> | <detail>", and a failed check makes the run
## quit non-zero. Compiled before the autoloads exist, so it names no project class.

const SHELL_PATH: String = "res://scenes/shell/game_shell.tscn"
const FLOW_RUN: int = 3
const HOST_ID: int = 1
const HEALTH: int = 6
const THIRST: int = 1
const DEADLINE_S: float = 300.0
## Each step's own time: the host waits this long between steps while Papo checks.
const STEP_S: float = 4.0

var mode: String = ""
var port: int = 7793
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
	var settings_path: String = "user://damage_feedback_run_%s.cfg" % mode
	var config := ConfigFile.new()
	config.set_value("player", "name", "Papo" if mode == "client" else "Yuni")
	config.set_value("display", "fullscreen", false)
	config.set_value("display", "ui_scale", 2)
	config.set_value("display", "pixel_filter", 0)
	config.set_value("display", "reduce_flashes", false)
	config.save(settings_path)
	shell = (load(SHELL_PATH) as PackedScene).instantiate()
	shell.set("settings_path", settings_path)
	root.add_child(shell)
	create_timer(DEADLINE_S).timeout.connect(_on_deadline)
	_main()


func _main() -> void:
	await process_frame
	await process_frame
	print("DAMAGE damage_feedback_run mode %s, port %d, pid %d" % [mode, port, OS.get_process_id()])
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
	var own_meters_hud: Object = hud.get("meters")
	var flashes_before: int = own_meters_hud.call("flashes_started")
	# 1. Papo is pinched.
	(papo.get("meters") as Object).call("harm", 5.0, &"land_crab")
	print("DAMAGE step 1: a crab pinched Papo")
	await process_frame
	await process_frame
	_check("Papo's body blinks on the host", ((papo.get_node("Look") as Object).call("hurt_blink") as Object).call("active"))
	_check("the host's own edges did not flash for Papo", own_meters_hud.call("flashes_started") == flashes_before)
	await _seconds(STEP_S)
	# 2. Yuni is pinched.
	(yuni.get("meters") as Object).call("harm", 5.0, &"land_crab")
	print("DAMAGE step 2: a crab pinched Yuni")
	await process_frame
	await process_frame
	_check("the host's own edges flash for Yuni", own_meters_hud.call("flashes_started") == flashes_before + 1)
	await _seconds(STEP_S)
	# 3. Yuni drinks a coconut.
	var meters: Object = yuni.get("meters")
	meters.set("thirst", 50.0)
	meters.set("hunger", 50.0)
	await _seconds(1.5)
	var inventory: Object = yuni.get("inventory")
	inventory.call("add", &"knife", 1)
	inventory.call("add", &"coco", 1)
	var coco: int = -1
	var slots: Array = inventory.get("slots")
	for i: int in slots.size():
		if (slots[i] as Object).get("item_id") == &"coco":
			coco = i
	_check("Yuni drinks the coconut", session.call("use_for", HOST_ID, coco, 0, 0) == true)
	print("DAMAGE step 3: Yuni drank a coconut")
	await _seconds(STEP_S)
	# 4. Papo's thirst empties: his health drains.
	(papo.get("meters") as Object).set("thirst", 0.0)
	print("DAMAGE step 4: Papo's thirst emptied")
	await _seconds(STEP_S)
	(papo.get("meters") as Object).set("thirst", 100.0)
	print("DAMAGE step 4 over: Papo drinks again")
	# The client needs the last state before the host goes away.
	await _seconds(4.0)


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
	var hud: Node = shell.get("hud")
	var meters_hud: Object = hud.get("meters")
	var floats: Object = hud.get("floats")
	var own_meters: Object = own.get("meters")
	var yuni_meters: Object = yuni.get("meters")
	# 1. Papo's own hit.
	if not await _wait_for("Papo's pinch", func() -> bool: return float(own_meters.get("health")) < 100.0, 60.0):
		return
	await process_frame
	await process_frame
	_check("Papo's edges flash", int(meters_hud.call("flashes_started")) == 1, str(meters_hud.call("flashes_started")))
	_check("Papo's own body blinks", ((own.get_node("Look") as Object).call("hurt_blink") as Object).call("active"))
	_check("Papo's Salud bar shows the lost part", (meters_hud.call("bar_for", HEALTH) as Object).call("lost_range") != Vector2.ZERO)
	_check("no number floats over Papo", (floats.call("texts_over", own) as PackedStringArray).is_empty())
	# 2. Yuni's hit on Yuni's body only.
	if not await _wait_for("Yuni's pinch", func() -> bool: return float(yuni_meters.get("health")) < 100.0, 30.0):
		return
	await process_frame
	await process_frame
	_check("Yuni's body blinks on Papo's screen", ((yuni.get_node("Look") as Object).call("hurt_blink") as Object).call("active"))
	_check("Papo's edges did not flash for Yuni", int(meters_hud.call("flashes_started")) == 1)
	# 3. Yuni's coconut floats over Yuni.
	var floated := func() -> bool: return (floats.call("texts_over", yuni) as PackedStringArray).has("+15 Sed")
	_check("'+15 Sed' floats over Yuni on Papo's screen", await _wait_for("the coconut's float", floated, 30.0))
	# 4. Papo's drain.
	if not await _wait_for("Papo's thirst at 0", func() -> bool: return float(own_meters.get("thirst")) <= 0.0, 30.0):
		return
	var flashes: int = meters_hud.call("flashes_started")
	var bar: Object = meters_hud.call("bar_for", HEALTH)
	var glowed := func() -> bool: return bar.call("glowing")
	_check("Papo's Salud frame glows while he drains", await _wait_for("the drain glow", glowed, 5.0))
	var blinked: bool = false
	for i: int in 60:
		await process_frame
		blinked = blinked or ((own.get_node("Look") as Object).call("hurt_blink") as Object).call("active")
	_check("the drain does not blink Papo", not blinked)
	_check("nor flash his edges", int(meters_hud.call("flashes_started")) == flashes)
	await _wait_for("the drain's end", func() -> bool: return float(own_meters.get("thirst")) > 50.0, 30.0)


func _check(label: String, ok: bool, detail: String = "") -> bool:
	if ok:
		passes += 1
	else:
		fails += 1
	print("DAMAGE %s %s: %s%s" % ["PASS" if ok else "FAIL", mode, label, (" | " + detail) if not detail.is_empty() else ""])
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
	print("DAMAGE done %s: %d passed, %d failed" % [mode, passes, fails])
	shell.call("back_to_title")
	quit(1 if fails > 0 else 0)
