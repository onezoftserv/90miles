extends SceneTree
## Manual host-and-client run for vessel-car-board task 8.1: two Godot processes playing the real
## game shell over UDP port 7785 (other sessions share the machine, so never 7777). The host starts
## the `test_board` fixture route for both riders through a dev hook; a squall dumps both riders, each
## climbs back onto their own board by holding interact, and both land on the coast cay 10-20 tiles
## apart, on the same cells in both processes. Headless, host first:
##   godot --headless --path game -s res://tests/manual/board_run.gd -- --mode=host
##   godot --headless --path game -s res://tests/manual/board_run.gd -- --mode=client
## Each check prints "BOARDRUN PASS|FAIL <what> | <detail>", and the run quits non-zero on a fail or
## on any engine or script error logged. What a player cannot reach by playing (the fixture route,
## its rigged boards, the trade wind, a squall at 3 s) is set through the GUT tests' hooks and
## printed as "BOARDRUN set <what>". Compiled before the autoloads exist, so it names no project
## class: duck typing, with the project's scripts loaded at run time.

const SHELL_PATH: String = "res://scenes/shell/game_shell.tscn"
const FIXTURES_PATH: String = "res://tests/helpers/fixture_routes.gd"
const PLAN_PATH: String = "res://scripts/crossing/crossing_plan.gd"
const BEAT_PATH: String = "res://scripts/crossing/crossing_beat.gd"
const PORT: int = 7785
const FLOW_RUN: int = 3
const ROUTE: StringName = &"test_board"
const COAST: StringName = &"coast_cay"
## Crossing.Rider
const ABOARD: int = 0
const IN_WATER: int = 2
## DataEnums.Terrain.BEACH
const BEACH: int = 3
const CROSSING_S: float = 20.0
const SQUALL_AT_S: float = 3.0
const BOARD_START: float = 60.0
const AFTER_SQUALL: float = 30.0
const TILE: float = 16.0
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
	var settings_path: String = "user://board_run_%s.cfg" % mode
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
	print("BOARDRUN board_run mode %s, pid %d, port %d" % [mode, OS.get_process_id(), PORT])
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
	print("BOARDRUN %s %s: %s%s" % ["PASS" if ok else "FAIL", mode, label, (" | " + detail) if not detail.is_empty() else ""])
	return ok


func _hooked(text: String) -> void:
	print("BOARDRUN set %s" % text)


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


# Every peer: the fixture route in the catalog's cache and on offer, as the board's route would be.
func _offer_board() -> void:
	(load(FIXTURES_PATH) as Script).call("put_in")
	var routes: Node = session.get_node(^"Routes")
	var route: Object = root.get_node(^"GameState").get("content").call("get_entry", &"routes", ROUTE)
	(routes.get("offered") as Array).append(route)
	(routes.get("discovered") as Dictionary)[ROUTE] = true
	_hooked("the %s fixture route offered here" % ROUTE)


func _me() -> int:
	return session.multiplayer.get_unique_id()


func _body(peer: int) -> Node2D:
	return session.call("body", peer) as Node2D


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
	# A lambda captures locals by value, so the client's peer lives in an array.
	var found: Array[int] = [0]
	var spawned := func() -> bool:
		for peer: int in session.call("peer_ids"):
			if peer != _me():
				found[0] = peer
		return found[0] != 0 and _body(found[0]) != null
	if not await _wait_for("the client's body here", spawned, 20.0):
		return
	var other: int = found[0]
	_offer_board()
	# The client offers the route once it is in the run; give it time to.
	await _seconds(4.0)
	var host_body := _body(_me())
	for index: int in 2:
		var rider := _body(_me() if index == 0 else other)
		rider.global_position = host_body.global_position + Vector2(6.0 * index, 0.0)
		rider.get("inventory").call("add", &"tarp", 1)
	_hooked("a rigged board (tarp) each, standing together")
	session.get("climate").set("weather_id", &"trade_wind")
	_hooked("trade wind")
	if not _check("the board route starts for both", session.call("start_route_for", _me(), ROUTE) == true):
		return
	var crossings: Array = shell.get("crossings")
	if not _check("the shell launched the crossing", not crossings.is_empty()):
		return
	var crossing: Node = crossings[0]
	var squall: int = ((load(BEAT_PATH) as Script).get_script_constant_map()["Kind"] as Dictionary)["SQUALL"]
	var beats: Array[RefCounted] = [(load(BEAT_PATH) as Script).call("create", SQUALL_AT_S, squall)]
	crossing.set("plan", (load(PLAN_PATH) as Script).call("create", CROSSING_S, beats))
	_hooked("the host's plan: %d s with a squall at %d s" % [int(CROSSING_S), int(SQUALL_AT_S)])
	_check("each rider spent their own board", _body(_me()).get("inventory").call("count_id", &"tarp") == 0 and _body(other).get("inventory").call("count_id", &"tarp") == 0)
	await _ride(crossing, other)
	await _arrive(other)


# --- the client ---------------------------------------------------------------------------------

func _client() -> void:
	shell.call("_join", "127.0.0.1", PORT)
	if not await _wait_run(120.0):
		return
	_check("joined 127.0.0.1:%d and in the run" % PORT, not session.multiplayer.is_server())
	_offer_board()
	var launched := func() -> bool:
		var crossings: Array = shell.get("crossings")
		return not crossings.is_empty() and crossings[0].get("plan") != null
	if not await _wait_for("the host's board route to launch the crossing here", launched, 120.0):
		return
	await _ride(shell.get("crossings")[0], 1)
	await _arrive(1)


# --- both ---------------------------------------------------------------------------------------

func _board(crossing: Node, peer: int) -> Object:
	return (crossing.get("boards") as Dictionary).get(peer)


func _state(crossing: Node, peer: int) -> int:
	return crossing.call("rider_state", peer)


func _ride(crossing: Node, other: int) -> void:
	var me: int = _me()
	# The shell frees the crossing as the party travels on, so the end is heard, not polled.
	var ended: Array[bool] = [false]
	crossing.connect(&"ended", func(_result: Object) -> void: ended[0] = true)
	_check("one board each", (crossing.get("boards") as Dictionary).size() == 2 and _board(crossing, me) != null and _board(crossing, other) != null)
	_check("both aboard boards at %d" % int(BOARD_START), _state(crossing, me) == ABOARD and _state(crossing, other) == ABOARD \
			and _board(crossing, me).get("value") == BOARD_START and _board(crossing, other).get("value") == BOARD_START)
	await _seconds(0.2)
	var look: Node = crossing.get_node(^"Boards")
	_check("both boards drawn", look.call("sprite_for", me) != null and look.call("sprite_for", other) != null)
	if not await _wait_for("the squall to throw me in", func() -> bool: return _state(crossing, me) == IN_WATER, 15.0):
		return
	await _wait_for("the other rider in the water too", func() -> bool: return _state(crossing, other) == IN_WATER, 3.0)
	_check("the squall hit both boards to %d" % int(AFTER_SQUALL), _board(crossing, me).get("value") == AFTER_SQUALL and _board(crossing, other).get("value") == AFTER_SQUALL,
			"%s and %s" % [_board(crossing, me).get("value"), _board(crossing, other).get("value")])
	Input.action_press(&"interact")
	var climbed: bool = await _wait_for("me back on my board after the 3 s hold", func() -> bool: return _state(crossing, me) == ABOARD, 10.0)
	Input.action_release(&"interact")
	_check("I climbed back onto my own board", climbed)
	_check("the other climbed back onto theirs", await _wait_for("the other back aboard", func() -> bool: return _state(crossing, other) == ABOARD, 10.0))
	_check("the crossing ended", await _wait_for("the crossing to end", func() -> bool: return ended[0], CROSSING_S + 10.0))


func _arrive(other: int) -> void:
	var landed := func() -> bool:
		var island: Node = shell.get("island")
		if island == null or (island.get("layout") as Resource).get("id") != COAST:
			return false
		var mine := _body(_me())
		var theirs := _body(other)
		return mine != null and theirs != null and not mine.get("left_island") and not theirs.get("left_island")
	if not _check("both landed on the coast cay", await _wait_for("both riders on the coast cay", landed, 40.0)):
		return
	await _seconds(0.5)
	var built: Object = shell.get("island").get("built")
	var cells: Dictionary = {}
	for peer: int in [1, _me() if _me() != 1 else other]:
		cells[peer] = Vector2i((_body(peer).position / TILE).floor())
	print("BOARDRUN cells %s" % [cells])
	var host_cell: Vector2i = cells[1]
	var client_cell: Vector2i = cells[_me() if _me() != 1 else other]
	var terrain: Dictionary = built.get("terrain").get("cells")
	_check("the first rider on the first landing cell", host_cell == (built.call("landing_cells") as Array)[0], "%s" % host_cell)
	_check("both on the beach", terrain.get(host_cell) == BEACH and terrain.get(client_cell) == BEACH)
	var apart: float = Vector2(host_cell - client_cell).length()
	_check("10-20 tiles apart", apart >= 10.0 and apart <= 20.0, "%.1f tiles" % apart)
	_check("no raft beached from boards", session.get_node_or_null(^"Raft") == null)


func _report_and_quit() -> void:
	if done:
		return
	done = true
	var errors: PackedStringArray = collector.error_list()
	for text: String in errors:
		print("BOARDRUN engine error: ", text)
	_check("no engine or script errors logged", errors.is_empty(), "%d error(s)" % errors.size())
	print("BOARDRUN summary %s: %d passed, %d failed" % [mode, passes, fails])
	quit(0 if fails == 0 else 1)
