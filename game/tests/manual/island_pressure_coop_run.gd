extends SceneTree
## Manual host-and-client run for island-pressure task 6.3: two Godot processes playing the real game
## shell over UDP port 7799 (other sessions share the machine, so never 7777).
##
## 1. On the sandbar the client's player holds the raft's first stage while the host's player gathers.
## 2. The host's player brings the rest and both hold the site until the raft is built.
## 3. By day the client asks to launch: the launch is seen, nobody leaves, and both see the boat dock.
## 4. A squall recalls the squad; once it is gone the clock is skipped to 22:00, and a night launch out
##    of the light carries both on a quiet crossing to the coast cay.
##
## Headless, host first:
##   godot --headless --path game -s res://tests/manual/island_pressure_coop_run.gd -- --mode=host
##   godot --headless --path game -s res://tests/manual/island_pressure_coop_run.gd -- --mode=client
##
## Each check prints "PRESSRUN PASS|FAIL <mode>: <what> | <detail>". The run quits non-zero on a fail
## or on any engine or script error logged. What a player cannot reach quickly by playing (items in
## hand, standing at the site, the weather, the clock, a quiet crossing plan) is set through hooks and
## printed as "PRESSRUN set <what>". Compiled before the autoloads exist, so it names no project class:
## duck typing, with the project's scripts loaded at run time.

const SHELL_PATH: String = "res://scenes/shell/game_shell.tscn"
const PLAN_PATH: String = "res://scripts/crossing/crossing_plan.gd"
const INTENT_PATH: String = "res://scripts/player/move_intent.gd"
const PORT: int = 7799
const FLOW_RUN: int = 3
const COAST: StringName = &"coast_cay"
const RAFT_TIME_S: float = 120.0
const STAGE_ONE_S: float = 30.0
const CROSSING_S: float = 20.0
const NIGHT_AT_S: float = 16.0 * 30.0
## PatrolRoute.State.DOCKED and AWAY; PatrolRoute.Squad.NONE.
const DOCKED: int = 6
const AWAY: int = 0
const SQUAD_NONE: int = 0
const DEADLINE_S: float = 420.0


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
	var settings_path: String = "user://island_pressure_coop_run_%s.cfg" % mode
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
	print("PRESSRUN island_pressure_coop_run mode %s, pid %d, port %d" % [mode, OS.get_process_id(), PORT])
	if mode == "host":
		await _host()
	elif mode == "client":
		await _client()
	else:
		_check("a known mode", false, mode)
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
	print("PRESSRUN %s %s: %s%s" % ["PASS" if ok else "FAIL", mode, label, (" | " + detail) if not detail.is_empty() else ""])
	return ok


func _hooked(text: String) -> void:
	print("PRESSRUN set %s" % text)


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


func _site() -> Node2D:
	var site := session.get_node_or_null(^"RaftSite") as Node2D
	return site if site != null and not site.is_queued_for_deletion() and not site.get("built") else null


func _raft() -> Node2D:
	var raft := session.get_node_or_null(^"Raft") as Node2D
	return raft if raft != null and not raft.is_queued_for_deletion() else null


func _work_s() -> float:
	var site := _site()
	return float(site.call("progress")) * RAFT_TIME_S if site != null else -1.0


func _boat() -> Node2D:
	var entities: Node = session.get("entities")
	for node: Node in entities.get_children():
		if node.has_method(&"is_patrol") and node.call("is_patrol") and not node.is_queued_for_deletion():
			return node as Node2D
	return null


func _island_id() -> StringName:
	var island: Node = shell.get("island")
	return (island.get("layout") as Resource).get("id") if island != null else &""


func _hold(held: bool) -> void:
	var body := _body(_me())
	body.set("intent", (load(INTENT_PATH) as Script).call("create", Vector2.ZERO, false, false, held))


func _quiet_input() -> void:
	_body(_me()).get("player_input").set("enabled", false)


func _left(peer: int) -> bool:
	return session.call("has_left", peer) == true


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
	_quiet_input()
	var sky: Object = root.get_node("/root/WeatherManager").get("sky")
	sky.get("weather").set("rolls_enabled", false)
	_hooked("calm weather pinned (no rolls)")
	await _seconds(2.0)
	var site := _site()
	if not _check("the sandbar's raft site is here", site != null):
		return
	# 1. The client's player holds the first stage alone while the host's player is away gathering.
	_body(other).global_position = site.global_position
	_body(other).get("inventory").call("add", &"inner_tube", 2)
	_body(other).get("inventory").call("add", &"rope", 1)
	_body(_me()).global_position = site.global_position + Vector2(20.0 * 16.0, 0.0)
	_hooked("the client's player at the site with 2 tubes and 1 rope; the host's player 20 tiles off")
	var first_done := func() -> bool: return _work_s() >= STAGE_ONE_S - 0.001
	if not _check("the client's hold finished the first stage", await _wait_for("the first stage", first_done, STAGE_ONE_S + 30.0), "%.1f s" % _work_s()):
		return
	await _seconds(1.0)
	_check("and the site waits at its end", absf(_work_s() - STAGE_ONE_S) < 0.01 and int(site.call("stage_index")) == 1, "%.2f s, stage %d" % [_work_s(), int(site.call("stage_index"))])
	var spent: float = 100.0 - float(_body(other).get("meters").get("energy"))
	_check("the client's player paid 30 energy for it", absf(spent - 30.0) < 1.0, "%.1f" % spent)
	_check("the host's player paid nothing", float(_body(_me()).get("meters").get("energy")) > 99.0)
	# 2. The host's player comes back with the rest and both hold until the raft is built.
	_body(_me()).get("inventory").call("add", &"driftwood", 6)
	_body(_me()).get("inventory").call("add", &"rope", 2)
	_body(_me()).global_position = site.global_position
	_hooked("the host's player back at the site with 6 driftwood and 2 rope")
	await _seconds(0.2)
	_hold(true)
	if not _check("both hold until the raft is built", await _wait_for("the raft", func() -> bool: return _raft() != null, 90.0)):
		return
	_hold(false)
	var mine: float = float(_body(_me()).get("meters").get("energy"))
	var theirs: float = float(_body(other).get("meters").get("energy"))
	_check("the two shared the last 90 s of work", absf((100.0 - mine) + (100.0 - theirs) - 120.0) < 3.0, "host %.1f, client %.1f" % [mine, theirs])
	# 3. By day the client asks to launch: seen, refused, and the boat docks.
	var boat := _boat()
	if not _check("the sandbar's patrol boat is here", boat != null):
		return
	_body(_me()).global_position = _raft().global_position
	_body(other).global_position = _raft().global_position + Vector2(6.0, 0.0)
	_hooked("both players beside the built raft, by day")
	if not _check("the boat docks on the client's day launch", await _wait_for("the dock", func() -> bool: return int(boat.get("state_id")) == DOCKED, 30.0)):
		return
	_check("nobody left", not _left(_me()) and not _left(other))
	_check("the raft stays on the beach at 100", _raft() != null and is_equal_approx(float(_raft().get("integrity")), 100.0))
	# 4. A squall recalls the squad; then night, and the launch out of the light.
	sky.get("weather").call("apply", &"squall", 100.0, &"", -1.0)
	session.call("send_sky")
	_hooked("a squall, to recall the squad")
	var gone := func() -> bool: return int(boat.get("squad_state")) == SQUAD_NONE and int(boat.get("state_id")) == AWAY
	if not _check("the squad rowed out and the boat went to port", await _wait_for("the squad gone", gone, 120.0)):
		return
	sky.get("weather").call("apply", &"calm", 100.0, &"", -1.0)
	sky.call("start_at", NIGHT_AT_S)
	session.call("send_sky")
	_hooked("calm again and the clock skipped to 22:00")
	await _seconds(1.0)
	_body(_me()).global_position = _raft().global_position
	_body(other).global_position = _raft().global_position + Vector2(6.0, 0.0)
	if not _check("the night launch carries both", await _wait_for("the night launch", func() -> bool: return _left(_me()) and _left(other), 30.0)):
		return
	var crossings: Array = shell.get("crossings")
	if not _check("the shell launched the crossing", not crossings.is_empty()):
		return
	crossings[0].set("plan", (load(PLAN_PATH) as Script).call("create", CROSSING_S))
	_hooked("a quiet %d s crossing" % int(CROSSING_S))
	var landed := func() -> bool: return _island_id() == COAST and _body(_me()) != null and not _body(_me()).get("left_island")
	_check("on the coast cay", await _wait_for("the coast cay", landed, CROSSING_S + 40.0))


# --- the client ---------------------------------------------------------------------------------

func _client() -> void:
	shell.call("_join", "127.0.0.1", PORT)
	if not await _wait_run(120.0):
		return
	_check("joined 127.0.0.1:%d and in the run" % PORT, not session.multiplayer.is_server())
	_quiet_input()
	var carrying := func() -> bool: return _site() != null and _body(_me()).global_position.distance_to(_site().global_position) < 4.0
	if not await _wait_for("at the site with the first stage's inputs", carrying, 60.0):
		return
	await _seconds(0.5)
	_hold(true)
	var waits := func() -> bool: return _site() != null and int(_site().call("stage_index")) == 1 and absf(_work_s() - STAGE_ONE_S) < 0.01
	if not _check("the client sees the first stage done and the second waiting", await _wait_for("the second stage here", waits, STAGE_ONE_S + 30.0), "%.2f s" % _work_s()):
		return
	if not _check("the client sees the raft built", await _wait_for("the raft here", func() -> bool: return _raft() != null, 90.0)):
		return
	_hold(false)
	var beside := func() -> bool: return _body(_me()).global_position.distance_to(_raft().global_position) < 12.0
	if not await _wait_for("beside the raft", beside, 20.0):
		return
	await _seconds(0.5)
	session.call("start_route", &"raft")
	var boat := _boat()
	if not _check("the client sees the boat", boat != null):
		return
	_check("the client sees the boat dock after its day launch", await _wait_for("the dock here", func() -> bool: return int(boat.get("state_id")) == DOCKED, 30.0))
	_check("and nobody left here", not _left(_me()) and not _left(1))
	var night := func() -> bool: return int(boat.get("squad_state")) == SQUAD_NONE and session.get("climate").get("phase") == 3
	if not await _wait_for("the night here", night, 150.0):
		return
	await _seconds(1.5)
	session.call("start_route", &"raft")
	_check("the client's night launch carries both", await _wait_for("the night launch here", func() -> bool: return _left(_me()) and _left(1), 30.0))
	var landed := func() -> bool: return _island_id() == COAST and _body(_me()) != null and not _body(_me()).get("left_island")
	_check("landed on the coast cay", await _wait_for("the coast cay here", landed, CROSSING_S + 60.0))


func _report_and_quit() -> void:
	if done:
		return
	done = true
	var errors: PackedStringArray = collector.error_list()
	for text: String in errors:
		print("PRESSRUN engine error: ", text)
	_check("no engine or script errors logged", errors.is_empty(), "%d error(s)" % errors.size())
	print("PRESSRUN summary %s: %d passed, %d failed" % [mode, passes, fails])
	quit(0 if fails == 0 else 1)
