extends SceneTree
## Manual host-and-client run for island-stop task 2.8: two Godot processes playing the real game
## shell over UDP port 7798 (other sessions share the machine, so never 7777).
##
## 1. On the sandbar, the host builds the raft and wears it to 50.
## 2. The client opens a mend on it through its own request, as its raft list sends it.
## 3. Each player deposits one input and the client's player works it, to 70 on both processes.
## 4. The client fits a toldo on it (island-stop PR 2), which both processes then show.
## 5. Both ride a quiet 20 s crossing with the toldo's shaded deck on both, to the coast cay, where
##    the raft lies at 70 with its toldo on both.
## 6. There the client mends it again to 90.
##
## Headless, host first:
##   godot --headless --path game -s res://tests/manual/island_stop_run.gd -- --mode=host
##   godot --headless --path game -s res://tests/manual/island_stop_run.gd -- --mode=client
##
## Each check prints "STOPRUN PASS|FAIL <what> | <detail>". The run quits non-zero on a fail or on
## any engine or script error logged. What a player cannot reach quickly by playing (a built raft,
## its wear, items in hand, standing at the work point, a quiet crossing plan) is set through hooks
## and printed as "STOPRUN set <what>". Compiled before the autoloads exist, so it names no project
## class: duck typing, with the project's scripts loaded at run time.

const SHELL_PATH: String = "res://scenes/shell/game_shell.tscn"
const PLAN_PATH: String = "res://scripts/crossing/crossing_plan.gd"
const PORT: int = 7798
const FLOW_RUN: int = 3
const COAST: StringName = &"coast_cay"
const MEND: StringName = &"raft_mend"
const TOLDO: StringName = &"raft_toldo"
const WORN: float = 50.0
const CROSSING_S: float = 20.0
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
	var settings_path: String = "user://island_stop_run_%s.cfg" % mode
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
	print("STOPRUN island_stop_run mode %s, pid %d, port %d" % [mode, OS.get_process_id(), PORT])
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
	print("STOPRUN %s %s: %s%s" % ["PASS" if ok else "FAIL", mode, label, (" | " + detail) if not detail.is_empty() else ""])
	return ok


func _hooked(text: String) -> void:
	print("STOPRUN set %s" % text)


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


func _raft() -> Node2D:
	if not is_instance_valid(session):
		return null
	var raft := session.get_node_or_null(^"Raft") as Node2D
	return raft if raft != null and not raft.is_queued_for_deletion() else null


func _integrity_is(value: float) -> bool:
	var raft := _raft()
	return raft != null and is_equal_approx(float(raft.get("integrity")), value)


func _job() -> Node2D:
	var raft := _raft()
	return raft.get("job") as Node2D if raft != null else null


func _island_id() -> StringName:
	var island: Node = shell.get("island")
	return (island.get("layout") as Resource).get("id") if island != null else &""


func _has_toldo() -> bool:
	var raft := _raft()
	return raft != null and (raft.get("fittings") as Array).has(TOLDO)


func _carried(peer: int, id: StringName) -> int:
	var body := _body(peer)
	return body.get("inventory").call("count_id", id) if body != null else 0


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
	await _seconds(2.0)
	# The sandbar's raft, built and worn.
	var site: Node = session.get_node(^"RaftSite")
	var recipe: Resource = site.get("recipe")
	for id: StringName in recipe.get("inputs"):
		(site.get("deposited") as Dictionary)[id] = (recipe.get("inputs") as Dictionary)[id]
	site.call("work", 1.0)
	if not _check("the sandbar's raft is built", _raft() != null):
		return
	_raft().set("integrity", WORN)
	_raft().call("_push_state")
	_hooked("the raft built and worn to %d, pushed to the client" % int(WORN))
	await _mend_here(other, WORN + 20.0, "sandbar")
	if fails > 0:
		return
	await _toldo_here(other)
	if fails > 0:
		return
	# Both ride the raft out on a quiet crossing.
	_body(_me()).global_position = _raft().global_position
	_body(other).global_position = _raft().global_position + Vector2(6.0, 0.0)
	if not _check("the mended raft launches for both", session.call("start_route_for", _me(), &"raft") == true):
		return
	var crossings: Array = shell.get("crossings")
	if not _check("the shell launched the crossing", not crossings.is_empty()):
		return
	crossings[0].set("plan", (load(PLAN_PATH) as Script).call("create", CROSSING_S))
	_hooked("a quiet %d s crossing" % int(CROSSING_S))
	_check("the toldo is aboard and the deck shaded on the host", (crossings[0].get("fittings") as Array).has(TOLDO) and crossings[0].call("deck_shaded") == true)
	if not await _arrive():
		return
	await _seconds(2.0)
	await _mend_here(other, WORN + 40.0, "coast cay")
	# Stay up a while, so the client sees the last mend before this host goes away.
	await _seconds(5.0)


# Host: the client fits the sandbar's tarp with the host's 2 driftwood as a toldo, and the client's
# player works it.
func _toldo_here(other: int) -> void:
	var point: Node2D = _raft().get("work_point")
	_body(_me()).global_position = point.global_position
	_body(other).global_position = point.global_position
	_body(_me()).get("inventory").call("add", &"driftwood", 2)
	_body(other).get("inventory").call("add", &"tarp", 1)
	_hooked("both at the work point, the client with a tarp and the host with 2 driftwood")
	if not await _wait_for("the client's toldo opened here", func() -> bool: return _job() != null, 30.0):
		return
	_check("the client's request opened a toldo", (_job().get("recipe") as Resource).get("id") == TOLDO)
	session.call("deposit_for", _me(), session.get_path_to(_job()))
	var all_in := func() -> bool: return _job() != null and _job().call("inputs_complete") == true
	if not await _wait_for("the toldo's inputs in", all_in, 20.0):
		return
	_body(_me()).get("crafter").call("cancel")
	_check("the raft has its toldo on the host", await _wait_for("the toldo done here", _has_toldo, 40.0))


# Host: both players at the raft's work point, the client's with a rope and the host's with a
# driftwood; the client opens the mend and deposits, the host deposits, and the client's player
# works it to `expected`.
func _mend_here(other: int, expected: float, where: String) -> void:
	var raft := _raft()
	var point: Node2D = raft.get("work_point")
	_body(_me()).global_position = point.global_position
	_body(other).global_position = point.global_position
	_body(_me()).get("inventory").call("add", &"driftwood", 1)
	_body(other).get("inventory").call("add", &"rope", 1)
	_hooked("both at the work point on the %s, the client with a rope and the host with a driftwood" % where)
	if not await _wait_for("the client's mend opened here", func() -> bool: return _job() != null, 30.0):
		return
	_check("the client's request opened a mend on the %s" % where, (_job().get("recipe") as Resource).get("id") == MEND)
	session.call("deposit_for", _me(), session.get_path_to(_job()))
	var all_in := func() -> bool: return _job() != null and _job().call("inputs_complete") == true
	if not await _wait_for("both inputs in", all_in, 20.0):
		return
	_check("the client's rope and the host's driftwood are in", _carried(other, &"rope") == 0 and _carried(_me(), &"driftwood") == 0)
	# Only the client's player works it.
	_body(_me()).get("crafter").call("cancel")
	_check("the mend reaches %d on the host" % int(expected), await _wait_for("the mend done here", _integrity_is.bind(expected), 30.0))
	_check("the job is gone", _job() == null)


func _arrive() -> bool:
	var landed := func() -> bool:
		if _island_id() != COAST:
			return false
		var mine := _body(_me())
		return mine != null and not mine.get("left_island") and _raft() != null
	if not _check("on the coast cay with a beached raft", await _wait_for("the coast cay", landed, CROSSING_S + 40.0)):
		return false
	_check("the beached raft is at %d of 100" % int(WORN + 20.0), _integrity_is(WORN + 20.0) and is_equal_approx(float(_raft().get("max_integrity")), 100.0), "%s" % _raft().get("integrity"))
	_check("the beached raft kept its toldo on the host", _has_toldo())
	return true


# --- the client ---------------------------------------------------------------------------------

func _client() -> void:
	shell.call("_join", "127.0.0.1", PORT)
	if not await _wait_run(120.0):
		return
	_check("joined 127.0.0.1:%d and in the run" % PORT, not session.multiplayer.is_server())
	if not _check("the client sees the worn raft at %d" % int(WORN), await _wait_for("the raft worn here", _integrity_is.bind(WORN), 60.0)):
		return
	await _ask_and_feed(WORN + 20.0, "sandbar")
	if fails > 0:
		return
	await _fit_toldo()
	if fails > 0:
		return
	var launched := func() -> bool:
		var crossings: Array = shell.get("crossings")
		return not crossings.is_empty() and crossings[0].get("plan") != null
	if await _wait_for("the crossing here", launched, 60.0):
		var crossing: Node = shell.get("crossings")[0]
		_check("the client's crossing has the toldo and a shaded deck", (crossing.get("fittings") as Array).has(TOLDO) and crossing.call("deck_shaded") == true)
	var landed := func() -> bool: return _island_id() == COAST and _raft() != null and not _body(_me()).get("left_island")
	if not _check("landed on the coast cay with a beached raft", await _wait_for("the coast cay", landed, CROSSING_S + 60.0)):
		return
	_check("the beached raft is at %d here too" % int(WORN + 20.0), _integrity_is(WORN + 20.0), "%s" % _raft().get("integrity"))
	_check("and has its toldo here too", await _wait_for("the toldo on the beached raft here", _has_toldo, 10.0))
	await _ask_and_feed(WORN + 40.0, "coast cay")


# Client: once the host handed this player a tarp, ask for a toldo and deposit it; the host's 2
# driftwood complete it.
func _fit_toldo() -> void:
	if not await _wait_for("a tarp from the host", func() -> bool: return _carried(_me(), &"tarp") == 1, 60.0):
		return
	await _seconds(0.5)
	session.call("craft", TOLDO, session.get_path_to(_raft()))
	if not _check("the toldo opened here", await _wait_for("the toldo job here", func() -> bool: return _job() != null, 20.0)):
		return
	session.call("deposit", session.get_path_to(_job()))
	_check("the client sees the raft's toldo", await _wait_for("the toldo here", _has_toldo, 40.0))


# Client: once the host handed this player a rope, ask for a mend on the raft as the raft's list
# does, deposit through the job and wait for the host's result here.
func _ask_and_feed(expected: float, where: String) -> void:
	if not await _wait_for("a rope from the host on the %s" % where, func() -> bool: return _carried(_me(), &"rope") == 1, 60.0):
		return
	await _seconds(0.5)
	session.call("craft", MEND, session.get_path_to(_raft()))
	if not _check("the mend opened here on the %s" % where, await _wait_for("the job here", func() -> bool: return _job() != null, 20.0)):
		return
	session.call("deposit", session.get_path_to(_job()))
	_check("the client sees the mend reach %d on the %s" % [int(expected), where], await _wait_for("the mend done here", _integrity_is.bind(expected), 40.0), "%s" % (_raft().get("integrity") if _raft() != null else "no raft"))
	_check("and the job gone here", await _wait_for("the job gone", func() -> bool: return _job() == null, 10.0))


func _report_and_quit() -> void:
	if done:
		return
	done = true
	var errors: PackedStringArray = collector.error_list()
	for text: String in errors:
		print("STOPRUN engine error: ", text)
	_check("no engine or script errors logged", errors.is_empty(), "%d error(s)" % errors.size())
	print("STOPRUN summary %s: %d passed, %d failed" % [mode, passes, fails])
	quit(0 if fails == 0 else 1)
