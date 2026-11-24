extends SceneTree
## Manual host-and-client run for crossing-gameplay (tasks 4.4 and 9.1): two Godot processes playing
## the real game shell over UDP port 7794 (other sessions share the machine, so never 7777). Both
## ride the sandbar's raft on a hand-written plan: a rock in line at 12 s, debris in line at 20 s
## and the reef line at 26 s. The client paddles east from 8 s to 11.5 s and the rock passes; the
## raft drifts back and takes the debris; the reef line passes. Both processes check the raft's
## lateral position and integrity against what the host has, then land on the coast cay.
## Headless, host first:
##   godot --headless --path game -s res://tests/manual/crossing_gameplay_run.gd -- --mode=host
##   godot --headless --path game -s res://tests/manual/crossing_gameplay_run.gd -- --mode=client
## Each check prints "CGRUN PASS|FAIL <what> | <detail>", and the run quits non-zero on a fail or on
## any engine or script error logged. What a player cannot reach by playing (the plan, where the
## client stands) is set through hooks and printed as "CGRUN set <what>". Compiled before the
## autoloads exist, so it names no project class: duck typing, scripts loaded at run time.

const SHELL_PATH: String = "res://scenes/shell/game_shell.tscn"
const PLAN_PATH: String = "res://scripts/crossing/crossing_plan.gd"
const BEAT_PATH: String = "res://scripts/crossing/crossing_beat.gd"
const PORT: int = 7794
const FLOW_RUN: int = 3
const COAST: StringName = &"coast_cay"
## Crossing.Rider
const ABOARD: int = 0
const CROSSING_S: float = 30.0
const ROCK_AT_S: float = 12.0
const DEBRIS_AT_S: float = 20.0
const REEF_AT_S: float = 26.0
const PADDLE_FROM_S: float = 8.0
const PADDLE_TO_S: float = 11.5
const DEADLINE_S: float = 300.0


class Collector extends Logger:
	var errors: PackedStringArray = []
	var _lock: Mutex = Mutex.new()

	func _log_error(function: String, file: String, line: int, code: String, rationale: String, _editor_notify: bool, error_type: int, _script_backtrace: Array[ScriptBacktrace]) -> void:
		if error_type == ERROR_TYPE_WARNING:
			return
		_lock.lock()
		errors.append("%s:%d (%s) %s %s" % [file, line, function, code, rationale])
		_lock.unlock()

	func _log_message(_message: String, _error: bool) -> void:
		pass

	func error_list() -> PackedStringArray:
		_lock.lock()
		var copy: PackedStringArray = errors.duplicate()
		_lock.unlock()
		return copy


var collector: Collector = Collector.new()
var mode: String = "host"
var shell: Node = null
var session: Node = null
var physics_hz: int = 60
var passes: int = 0
var fails: int = 0
var done: bool = false


func _init() -> void:
	OS.add_logger(collector)


func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--mode="):
			mode = arg.trim_prefix("--mode=")
	physics_hz = Engine.physics_ticks_per_second
	var settings_path: String = "user://crossing_gameplay_run_%s.cfg" % mode
	var config := ConfigFile.new()
	config.set_value("player", "name", "Papo" if mode == "client" else "Yuni")
	config.set_value("display", "fullscreen", false)
	config.save(settings_path)
	shell = (load(SHELL_PATH) as PackedScene).instantiate()
	shell.set("settings_path", settings_path)
	root.add_child(shell)
	create_timer(DEADLINE_S).timeout.connect(_on_deadline)
	_main()


func _main() -> void:
	await process_frame
	await process_frame
	print("CGRUN crossing_gameplay_run mode %s, pid %d, port %d" % [mode, OS.get_process_id(), PORT])
	if mode == "host":
		await _host()
	elif mode == "client":
		await _client()
	else:
		_check("a known mode", false, mode)
	Input.action_release(&"interact")
	_report_and_quit()


func _on_deadline() -> void:
	if done:
		return
	_check("finished before the %d s deadline" % int(DEADLINE_S), false)
	_report_and_quit()


func _check(label: String, ok: bool, detail: String = "") -> bool:
	if ok:
		passes += 1
	else:
		fails += 1
	print("CGRUN %s %s: %s%s" % ["PASS" if ok else "FAIL", mode, label, (" | " + detail) if not detail.is_empty() else ""])
	return ok


func _hooked(text: String) -> void:
	print("CGRUN set %s" % text)


# island-pressure: by day the patrol sees a raft launch. This run is about what follows the launch, so
# the island's patrol boats are taken away before it (a printed hook).
func _clear_patrol() -> void:
	var boats: Array = (load("res://scripts/stealth/launch_sight.gd") as Script).call("boats_of", session)
	for boat: Node in boats:
		boat.get_parent().remove_child(boat)
		boat.queue_free()
	_hooked("the island's %d patrol boat(s) taken away, so the day launch is not seen" % boats.size())


func _seconds(seconds: float) -> void:
	for i: int in ceili(seconds * physics_hz):
		await physics_frame


func _wait_for(what: String, ready: Callable, timeout_s: float) -> bool:
	for i: int in ceili(timeout_s * physics_hz):
		if ready.call():
			return true
		await physics_frame
	return _check("in time: %s" % what, false, "%.0f s" % timeout_s)


func _wait_run(timeout_s: float) -> bool:
	var ready := func() -> bool:
		if shell.get("flow") != FLOW_RUN or shell.get("session") == null:
			return false
		session = shell.get("session")
		return session.call("body", session.multiplayer.get_unique_id()) != null
	return await _wait_for("the run", ready, timeout_s)


func _me() -> int:
	return session.multiplayer.get_unique_id()


func _body(peer: int) -> Node2D:
	return session.call("body", peer) as Node2D


func _kind(name: String) -> int:
	return ((load(BEAT_PATH) as Script).get_script_constant_map()["Kind"] as Dictionary)[name]


func _beat(at_s: float, kind: String, lane: int) -> RefCounted:
	return (load(BEAT_PATH) as Script).call("create", at_s, _kind(kind), lane, 0)


# --- the host -----------------------------------------------------------------------------------

func _host() -> void:
	shell.set("port", PORT)
	shell.call("start_host")
	session = shell.get("session")
	if not _check("start_host opened port %d" % PORT, session != null and not (session.multiplayer.multiplayer_peer is OfflineMultiplayerPeer)):
		return
	if not await _wait_for("a client in the lobby", func() -> bool: return (session.get("roster") as Dictionary).size() > 1, 120.0):
		return
	await _seconds(1.0)
	_check("begin_run started the run", session.call("begin_run") == true)
	if not await _wait_run(10.0):
		return
	var found: Array[int] = [0]
	var spawned := func() -> bool:
		for peer: int in session.call("peer_ids"):
			if peer != _me():
				found[0] = peer
		return found[0] != 0 and _body(found[0]) != null
	if not await _wait_for("the client's body here", spawned, 20.0):
		return
	var other: int = found[0]
	await _seconds(3.0)
	var site: Node2D = session.get_node(^"RaftSite")
	var builder := _body(_me())
	for peer: int in [_me(), other]:
		_body(peer).global_position = site.global_position
	builder.get("inventory").call("add", &"driftwood", 6)
	builder.get("inventory").call("add", &"inner_tube", 2)
	builder.get("inventory").call("add", &"rope", 3)
	site.call("deposit", builder)
	site.call("work", 1.0)
	_hooked("the raft built, both beside it")
	_clear_patrol()
	if not _check("the raft leaves with both", session.call("start_route_for", _me(), &"raft") == true):
		return
	var crossings: Array = shell.get("crossings")
	if not _check("the shell launched the crossing", not crossings.is_empty()):
		return
	var crossing: Node = crossings[0]
	var beats: Array[RefCounted] = [
		_beat(ROCK_AT_S, "ROCK", 0), _beat(DEBRIS_AT_S, "DEBRIS", 0),
		_beat(REEF_AT_S, "ROCK", -3), _beat(REEF_AT_S, "ROCK", 7),
	]
	crossing.set("plan", (load(PLAN_PATH) as Script).call("create", CROSSING_S, beats))
	_hooked("the host's plan: %d s, a rock in line at %d s, debris at %d s, the reef line at %d s" % [int(CROSSING_S), int(ROCK_AT_S), int(DEBRIS_AT_S), int(REEF_AT_S)])
	var deck: Rect2 = crossing.call("deck_rect")
	_body(other).global_position = Vector2(deck.end.x - 4.0, deck.get_center().y)
	_body(_me()).global_position = Vector2(deck.position.x + 20.0, deck.get_center().y)
	_hooked("the client at the east paddle, the host in the middle")
	await _ride(crossing, true)
	await _arrive(other)


# --- the client ---------------------------------------------------------------------------------

func _client() -> void:
	shell.call("_join", "127.0.0.1", PORT)
	if not await _wait_run(120.0):
		return
	_check("joined 127.0.0.1:%d and in the run" % PORT, not session.multiplayer.is_server())
	var launched := func() -> bool:
		var crossings: Array = shell.get("crossings")
		return not crossings.is_empty() and crossings[0].get("plan") != null
	if not await _wait_for("the host's raft to launch the crossing here", launched, 120.0):
		return
	var crossing: Node = shell.get("crossings")[0]
	await _wait_for("the crossing under way", func() -> bool: return float(crossing.get("elapsed_s")) > 1.0, 10.0)
	await _ride(crossing, false)
	await _arrive(1)


# --- both ---------------------------------------------------------------------------------------

func _ride(crossing: Node, is_host: bool) -> void:
	var ended: Array[bool] = [false]
	crossing.connect(&"ended", func(_result: Object) -> void: ended[0] = true)
	var integrity: Object = crossing.get("integrity")
	var steer: Object = crossing.get("steer")
	_check("both aboard a raft at 100", crossing.call("rider_state", _me()) == ABOARD and integrity.get("value") == 100.0)
	await _wait_for("%d s into the crossing" % int(PADDLE_FROM_S), func() -> bool: return float(crossing.get("elapsed_s")) >= PADDLE_FROM_S, 20.0)
	if not is_host:
		Input.action_press(&"interact")
		await _wait_for("%.1f s" % PADDLE_TO_S, func() -> bool: return float(crossing.get("elapsed_s")) >= PADDLE_TO_S, 10.0)
		Input.action_release(&"interact")
	else:
		await _wait_for("%.1f s" % PADDLE_TO_S, func() -> bool: return float(crossing.get("elapsed_s")) >= PADDLE_TO_S, 10.0)
	var position: float = steer.get("position")
	_check("the raft paddled east of the rock's lane", position > 3.5, "%.2f tiles" % position)
	await _wait_for("past the rock", func() -> bool: return float(crossing.get("elapsed_s")) >= ROCK_AT_S + 0.5, 10.0)
	_check("the rock passed: the raft at 100", integrity.get("value") == 100.0, "%.1f" % integrity.get("value"))
	await _wait_for("past the debris", func() -> bool: return float(crossing.get("elapsed_s")) >= DEBRIS_AT_S + 1.0, 15.0)
	_check("the raft drifted back and took the debris", absf(float(integrity.get("value")) - 95.0) < 0.5, "%.1f" % integrity.get("value"))
	_check("the current pulled it back toward the line", float(steer.get("position")) < 1.5, "%.2f tiles" % steer.get("position"))
	await _wait_for("past the reef line", func() -> bool: return float(crossing.get("elapsed_s")) >= REEF_AT_S + 1.0, 15.0)
	_check("the reef line passed: still at 95", absf(float(integrity.get("value")) - 95.0) < 0.5, "%.1f" % integrity.get("value"))
	print("CGRUN %s at %.1f s: position %.2f, integrity %.1f" % [mode, crossing.get("elapsed_s"), steer.get("position"), integrity.get("value")])
	_check("the crossing ended", await _wait_for("the crossing to end", func() -> bool: return ended[0], CROSSING_S + 10.0))


func _arrive(other: int) -> void:
	var landed := func() -> bool:
		var island: Node = shell.get("island")
		if island == null or (island.get("layout") as Resource).get("id") != COAST:
			return false
		var mine := _body(_me())
		var theirs := _body(other)
		return mine != null and theirs != null and not mine.get("left_island") and not theirs.get("left_island")
	_check("both landed on the coast cay", await _wait_for("both riders on the coast cay", landed, 40.0))


func _report_and_quit() -> void:
	if done:
		return
	done = true
	var errors: PackedStringArray = collector.error_list()
	for text: String in errors:
		print("CGRUN engine error: ", text)
	_check("no engine or script errors logged", errors.is_empty(), "%d error(s)" % errors.size())
	print("CGRUN summary %s: %d passed, %d failed" % [mode, passes, fails])
	quit(0 if fails == 0 else 1)
