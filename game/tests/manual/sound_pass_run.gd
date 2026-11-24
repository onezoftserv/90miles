extends SceneTree
## Manual two-process check for sound-pass (audio "Own events are heard only by their player",
## "World events are heard by every peer", "The patrol motor swells over the horizon warning",
## "Loudhailer", "Thunder", "Ambience follows place, time and weather"). It boots the real game shell
## on each side and records every id AudioManager plays and the loudest level each loop is asked for:
##   godot --headless --path game -s res://tests/manual/sound_pass_run.gd -- --mode=host --port=7802
##   godot --headless --path game -s res://tests/manual/sound_pass_run.gd -- --mode=client --port=7802
## The host (Yuni) starts the run once the client (Papo) is in the lobby, then, a few seconds apart:
## 1. Yuni picks up driftwood (host inventory).   2. Papo picks up a coconut.
## 3. A crab pinches Papo.                         4. A crab pinches Yuni.
## 5. The patrol boat enters its horizon warning.  6. The boat, now on its lap, spots Yuni.
## 7. A squall is warned, and sent.                8. The squall breaks, and is sent.
## Each side then checks what it heard. Own events: exactly one pickup and one hurt_hit each, so the
## client never heard Yuni's (the negative check) and the host never heard Papo's. World events,
## heard on both: the sea, the motor, one loudhailer, thunder at the warning and at the break, and the
## wind raised to its squall level. Each check prints "SOUND PASS|FAIL <mode>: <what> | <detail>", and
## a failed check makes the run quit non-zero. Compiled before the autoloads exist, so it names no
## project class.

const SHELL_PATH: String = "res://scenes/shell/game_shell.tscn"
const BANK_PATH: String = "res://resources/sound_bank.tres"
const FLOW_RUN: int = 3
const HOST_ID: int = 1
const DEADLINE_S: float = 300.0
const STEP_S: float = 3.0
const HORIZON_CLOCK_S: float = 12.0

var mode: String = ""
var port: int = 7802
var shell: Node
var bank: Resource
var passes: int = 0
var fails: int = 0
var done: bool = false
var heard: Array[StringName] = []
var loudest: Dictionary = {}


func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--mode="):
			mode = arg.trim_prefix("--mode=")
		elif arg.begins_with("--port="):
			port = arg.trim_prefix("--port=").to_int()
	var settings_path: String = "user://sound_pass_run_%s.cfg" % mode
	var config := ConfigFile.new()
	config.set_value("player", "name", "Papo" if mode == "client" else "Yuni")
	config.set_value("display", "fullscreen", false)
	config.set_value("display", "ui_scale", 2)
	config.save(settings_path)
	bank = load(BANK_PATH)
	shell = (load(SHELL_PATH) as PackedScene).instantiate()
	shell.set("settings_path", settings_path)
	root.add_child(shell)
	create_timer(DEADLINE_S).timeout.connect(_on_deadline)
	_main()


func _main() -> void:
	await process_frame
	await process_frame
	var audio: Node = root.get_node(^"AudioManager")
	audio.connect(&"sfx_played", func(id: StringName) -> void:
		heard.append(id)
		print("SOUND %s heard %s" % [mode, id]))
	physics_frame.connect(_track_loops)
	print("SOUND sound_pass_run mode %s, port %d, pid %d" % [mode, port, OS.get_process_id()])
	if mode == "host":
		await _host()
	elif mode == "client":
		await _client()
	else:
		_check("known mode", false, mode)
	_finish()


func _track_loops() -> void:
	var audio: Node = root.get_node_or_null(^"AudioManager")
	if audio == null:
		return
	for id: StringName in [&"sea", &"wind", &"night", &"patrol_motor"]:
		loudest[id] = maxf(float(loudest.get(id, 0.0)), float(audio.call("loop_target", id)))


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
	var sky: Object = root.get_node(^"WeatherManager").get("sky")
	(sky.get("weather") as Object).set("rolls_enabled", false)
	await _seconds(STEP_S)
	var client_id: int = 0
	for peer_id: int in session.call("peer_ids"):
		if peer_id != HOST_ID:
			client_id = peer_id
	var yuni: Node = session.call("body", HOST_ID)
	var papo: Node = session.call("body", client_id)
	var crab: Object = (root.get_node(^"GameState").get("content") as Object).call("get_entry", &"creatures", &"land_crab")
	(yuni.get("inventory") as Object).call("add", &"driftwood", 1)
	print("SOUND step 1: Yuni picked up driftwood")
	await _seconds(STEP_S)
	(papo.get("inventory") as Object).call("add", &"coco", 1)
	print("SOUND step 2: Papo picked up a coconut")
	await _seconds(STEP_S)
	(papo.get("meters") as Object).call("harm", 5.0, &"land_crab")
	print("SOUND step 3: a crab pinched Papo")
	await _seconds(STEP_S)
	(yuni.get("meters") as Object).call("harm", 5.0, &"land_crab")
	print("SOUND step 4: a crab pinched Yuni")
	await _seconds(STEP_S)
	var boat: Node = _patrol_boat(session)
	if not _check("the run has a patrol boat", boat != null):
		return
	var warning_s: float = float((boat.get("data") as Object).get("patrol").get("horizon_warning_s"))
	(boat.get("brain") as Object).call("set_clock", HORIZON_CLOCK_S)
	boat.call("advance", 0.0)
	print("SOUND step 5: the patrol boat is %.0f s into its %.0f s horizon warning" % [HORIZON_CLOCK_S, warning_s])
	await _seconds(warning_s - HORIZON_CLOCK_S + 1.5)
	_check("the boat is on its lap", boat.call("state_name") == &"LAP", str(boat.call("state_name")))
	(boat.get("brain") as Object).call("spot", yuni, &"sight")
	print("SOUND step 6: the boat spotted Yuni")
	await _seconds(STEP_S)
	var weather: Object = sky.get("weather")
	weather.call("apply", &"calm", 100.0, &"squall", 20.0)
	session.call("send_sky")
	print("SOUND step 7: a squall is warned")
	await _seconds(STEP_S)
	weather.call("apply", &"squall", 60.0, &"", -1.0)
	session.call("send_sky")
	print("SOUND step 8: the squall breaks")
	await _seconds(STEP_S + 1.0)
	_check_heard()
	weather.call("apply", &"calm", 100.0, &"", -1.0)
	session.call("send_sky")
	# The client needs the last state before the host goes away.
	await _seconds(4.0)


func _client() -> void:
	shell.call("_join", "127.0.0.1", port)
	if not await _wait_for("the run", func() -> bool: return shell.get("flow") == FLOW_RUN, 120.0):
		return
	if not await _wait_for("the squall's wind", func() -> bool: return float(loudest.get(&"wind", 0.0)) >= float(bank.get("wind_squall")), 120.0):
		return
	await _seconds(STEP_S)
	_check_heard()


func _check_heard() -> void:
	_check("the sea played", float(loudest.get(&"sea", 0.0)) > 0.0)
	_check("exactly one pickup: its own", heard.count(&"pickup") == 1, str(heard.count(&"pickup")))
	_check("exactly one hurt_hit: its own", heard.count(&"hurt_hit") == 1, str(heard.count(&"hurt_hit")))
	_check("the patrol motor swelled", float(loudest.get(&"patrol_motor", 0.0)) > 0.0, str(loudest.get(&"patrol_motor", 0.0)))
	_check("one loudhailer call", heard.count(&"loudhailer") == 1, str(heard.count(&"loudhailer")))
	_check("thunder at the warning and the break", heard.count(&"thunder") >= 2, str(heard.count(&"thunder")))
	_check("the wind rose to its squall level", float(loudest.get(&"wind", 0.0)) >= float(bank.get("wind_squall")), str(loudest.get(&"wind", 0.0)))
	print("SOUND %s heard, in order: %s" % [mode, heard])


func _patrol_boat(session: Node) -> Node:
	var entities: Node = session.get("entities")
	for node: Node in entities.get_children():
		if node.has_method(&"is_patrol") and node.call("is_patrol"):
			return node
	return null


func _check(label: String, ok: bool, detail: String = "") -> bool:
	if ok:
		passes += 1
	else:
		fails += 1
	print("SOUND %s %s: %s%s" % ["PASS" if ok else "FAIL", mode, label, (" | " + detail) if not detail.is_empty() else ""])
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
	print("SOUND done %s: %d passed, %d failed" % [mode, passes, fails])
	shell.call("back_to_title")
	quit(1 if fails > 0 else 0)
