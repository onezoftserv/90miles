extends SceneTree
## Manual two-process run for island-generator task 8.4: a host and a client cross from a test copy
## of the coast cay (whose next island is `reef_traps`) to a generated reef over ENet on UDP port 7791,
## and each prints the island it built. Run the host first, then the client (both headless):
##   godot --headless --path game -s res://tests/manual/reef_run.gd -- --mode=host
##   godot --headless --path game -s res://tests/manual/reef_run.gd -- --mode=client
## The host opens the lobby, starts the run once the client is in it, lands both players on the test
## coast cay as island 2 and then ends the party's raft crossing there on both peers (a CrossingResult
## sent the way the shell's Crossing.ended handler hands it on), so the host's IslandTravel travels to
## the next island, generated as island 3 from the run seed. Each peer checks it stands on reef_traps_3
## with the hash the host sent, and prints "REEFRUN island <hash>" so the two logs can be compared.
## Each check prints "REEFRUN PASS|FAIL <what>"; the run quits non-zero on a fail. Compiled before the
## autoloads exist, so it names no project class: duck typing and load() throughout.

const SHELL_PATH: String = "res://scenes/shell/game_shell.tscn"
const PORT: int = 7791
const FLOW_RUN: int = 3
const DEADLINE_S: float = 240.0
const TEST_COAST: StringName = &"reef_run_coast"
const REEF_ID: StringName = &"reef_traps_3"
const CROSSING_RESULT_PATH: String = "res://scripts/crossing/crossing_result.gd"


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
var passes: int = 0
var fails: int = 0
var done: bool = false


func _init() -> void:
	OS.add_logger(collector)


func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--mode="):
			mode = arg.trim_prefix("--mode=")
	var settings_path: String = "user://reef_run_%s.cfg" % mode
	var config := ConfigFile.new()
	config.set_value("player", "name", "Papo" if mode == "client" else "Yuni")
	config.set_value("display", "fullscreen", false)
	config.save(settings_path)
	shell = (load(SHELL_PATH) as PackedScene).instantiate()
	shell.set("settings_path", settings_path)
	shell.set("port", PORT)
	root.add_child(shell)
	create_timer(DEADLINE_S).timeout.connect(_on_deadline)
	_main()


func _main() -> void:
	await process_frame
	await process_frame
	_add_test_coast()
	if mode == "host":
		await _host()
	elif mode == "client":
		await _client()
	else:
		_check("known mode", false, mode)
	_report_and_quit()


# Both processes: the test coast cay is the real one with the reef as its next island, put in the
# catalog's cache as the GUT tests do.
func _add_test_coast() -> void:
	var content: Object = root.get_node(^"GameState").get("content")
	var coast: Resource = (content.call("get_entry", &"islands", &"coast_cay") as Resource).duplicate()
	coast.set("id", TEST_COAST)
	coast.set("next_island", &"reef_traps")
	(content.get("_cache") as Dictionary)["islands/%s" % TEST_COAST] = coast


func _host() -> void:
	shell.call("start_host")
	session = shell.get("session")
	if not await _wait_for("the client in the lobby", func() -> bool: return (session.get("roster") as Dictionary).size() > 1, 120.0):
		return
	await _frames(30)
	_check("begin_run started the run", session.call("begin_run") == true)
	if not await _wait_for("the run", func() -> bool: return _refresh() and _travel() != null, 30.0):
		return
	var arrivals: Dictionary = {}
	for peer: int in session.call("peer_ids"):
		arrivals[peer] = {"health": 100.0, "energy": 100.0}
	session.rpc("travel_to", String(TEST_COAST), 2, "", arrivals, 0.0)
	if not await _wait_for("the test coast cay", func() -> bool: return _island_id() == TEST_COAST, 30.0):
		return
	await _frames(60)
	await _cross_to_the_reef()


func _client() -> void:
	shell.call("_join", "127.0.0.1", PORT)
	if not await _wait_for("the run", func() -> bool: return _refresh() and _travel() != null, 120.0):
		return
	_check("the client is not the host", not session.multiplayer.is_server())
	if not await _wait_for("the test coast cay", func() -> bool: return _island_id() == TEST_COAST, 60.0):
		return
	await _frames(30)
	await _cross_to_the_reef()


# Every peer ends the party's raft crossing, as the shell's handler does when the crossing scene ends:
# every player rode the raft, kept at 70. The host then travels; each peer checks where it landed.
func _cross_to_the_reef() -> void:
	var result: Object = load(CROSSING_RESULT_PATH).new()
	result.set("route_id", &"raft")
	result.set("integrity", 70.0)
	var riders: Dictionary = result.get("riders")
	for peer: int in session.call("peer_ids"):
		riders[peer] = {"health": 90.0, "energy": 60.0, "aboard": true, "dead": false}
	_travel().call("crossing_ended", result)
	if not await _wait_for("the reef", func() -> bool: return _refresh() and _island_id() == REEF_ID, 60.0):
		return
	await _frames(30)
	var layout: Object = _travel().get("island").get("layout")
	var source: GDScript = load("res://scripts/levels/generation/island_source.gd")
	var island_hash: String = source.call("hash_of", layout)
	var seed: Variant = (session.get("world_state") as Dictionary).get("run_seed")
	print("REEFRUN island %s: %s run seed %s index %d hash %s" % [mode, layout.get("id"), seed, _travel().get("history").call("current_index"), island_hash])
	_check("island 3 of the chain", _travel().get("history").call("current_index") == 3 and _travel().get("history").call("current_id") == &"reef_traps")
	_check("the hash is a hash", source.call("is_digest", island_hash))
	var me: Node2D = session.call("body", session.multiplayer.get_unique_id())
	_check("my player stands on land", me != null and me.visible and not bool(me.get("left_island")))
	_check("the raft is beached", session.get_node_or_null(^"Raft") != null)
	if mode == "client":
		var own: Dictionary = source.call("resolve", &"reef_traps", 3, int(seed))
		_check("the client's own generation matches what it stands on", own.get("island_hash", "") == island_hash)
	await _frames(120)


func _refresh() -> bool:
	if shell.get("flow") != FLOW_RUN or shell.get("session") == null:
		return false
	session = shell.get("session")
	return true


func _travel() -> Object:
	return shell.get("travel")


func _island_id() -> StringName:
	var travel: Object = _travel()
	if travel == null or travel.get("island") == null:
		return &""
	return (travel.get("island").get("layout") as Object).get("id")


func _check(label: String, ok: bool, detail: String = "") -> bool:
	if ok:
		passes += 1
	else:
		fails += 1
	print("REEFRUN %s %s: %s%s" % ["PASS" if ok else "FAIL", mode, label, (" | " + detail) if not detail.is_empty() else ""])
	return ok


func _frames(count: int) -> void:
	for i: int in count:
		await physics_frame


func _wait_for(what: String, ready: Callable, timeout_s: float) -> bool:
	for i: int in ceili(timeout_s * Engine.physics_ticks_per_second):
		if ready.call():
			return true
		await physics_frame
	_check("timed out after %.0f s waiting for %s" % [timeout_s, what], false)
	return false


func _on_deadline() -> void:
	if not done:
		_check("finished before the deadline", false)
		_report_and_quit()


func _report_and_quit() -> void:
	if done:
		return
	done = true
	for text: String in collector.error_list():
		print("REEFRUN engine error: ", text)
	_check("no engine or script errors logged", collector.error_list().is_empty())
	print("REEFRUN summary %s: %d passed, %d failed" % [mode, passes, fails])
	quit(0 if fails == 0 else 1)
