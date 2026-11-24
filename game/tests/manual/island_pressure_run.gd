extends SceneTree
## Manual measured run for island-pressure task 6.2 (design D9): a scripted solo player plays the real
## game shell, offline, from the title to the run summary, with the policy fixed in design.md D9:
##
## 1. Gather the next missing stage's inputs, the nearest first, and pick up the hut's knife.
## 2. Work by holding the raft site.
## 3. When energy reaches 0, climb a palm with coconuts (out of the gulls' nests first), eat at once out
##    of the gulls' sight, and repeat until energy is at least 20 or no palm has coconuts.
## 4. Drink a coconut whenever thirst drops below 30.
## 5. Cool off at midday: at heat 80 or more, stand in the hut's shade until heat is below 30.
## 6. Once the raft is built, top up the same way, then stand in the hut's shade until the launch
##    warning the HUD would show is gone.
## 7. Launch. At sea a quiet crossing plan (a printed hook: the crossing is not what is measured). On
##    the coast cay the same wait (out of the light, by the bench), then launch again.
##
## Headless, faster than real time, with the game's own clock and calm weather pinned:
##   godot --headless --fixed-fps 60 --path game -s res://tests/manual/island_pressure_run.gd
##
## Prints "PRESSBOT snapshot ..." every 30 s of game time and "PRESSBOT PASS|FAIL <what>" for each
## target: midday seen on the sandbar, the sandbar's minimum thirst under 50, the launch at 20:00 or
## later, alive at the summary and no engine or script error. Compiled before the autoloads exist, so
## it names no project class: duck typing, with the project's scripts loaded at run time.

const SHELL_PATH: String = "res://scenes/shell/game_shell.tscn"
const PLAN_PATH: String = "res://scripts/crossing/crossing_plan.gd"
const INTENT_PATH: String = "res://scripts/player/move_intent.gd"
const SIGHT_PATH: String = "res://scripts/stealth/launch_sight.gd"
const TERRAIN_PATH: String = "res://scripts/player/terrain_query.gd"
const FLOW_RUN: int = 3
const FLOW_SUMMARY: int = 4
const SANDBAR: StringName = &"sandbar"
const COAST: StringName = &"coast_cay"
const TILE: float = 16.0
const NIGHT_START_S: float = 420.0
const SNAPSHOT_S: float = 30.0
const LOW_THIRST: float = 30.0
const HOT: float = 80.0
const COOL: float = 30.0
const FED: float = 20.0
const GULL_SAFE_TILES: float = 9.5
const CROSSING_S: float = 75.0
const AT_PX: float = 3.0
const DEADLINE_S: float = 2400.0


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
var shell: Node = null
var session: Node = null
var body: Node2D = null
var sky: Object = null
var land: AStarGrid2D = null
var passes: int = 0
var fails: int = 0
var done: bool = false
var activity: String = "start"
var game_s: float = 0.0
var min_thirst_sandbar: float = 100.0
var midday_seen: bool = false
var launch_clock: String = ""
var launch_time_of_day_s: float = -1.0
var launch_day: int = 0
var arrivals: PackedStringArray = []
var alive_at_end: bool = false
var coconuts_eaten: int = 0
var stolen: int = 0


func _init() -> void:
	OS.add_logger(collector)


func _initialize() -> void:
	var settings_path: String = "user://island_pressure_run.cfg"
	var config := ConfigFile.new()
	config.set_value("player", "name", "Yuni")
	config.set_value("display", "fullscreen", false)
	config.save(settings_path)
	shell = (load(SHELL_PATH) as PackedScene).instantiate()
	shell.set("settings_path", settings_path)
	root.add_child(shell)
	_main()


func _main() -> void:
	await process_frame
	await process_frame
	print("PRESSBOT island_pressure_run, pid %d" % OS.get_process_id())
	shell.get("screen").emit_signal("solo_requested")
	if not await _wait_for("the run", _in_run, 30.0):
		_report_and_quit()
		return
	session = shell.get("session")
	body = session.call("body", 1)
	body.get("player_input").set("enabled", false)
	sky = root.get_node("/root/WeatherManager").get("sky")
	sky.get("weather").set("rolls_enabled", false)
	sky.get("weather").call("start_weather", &"calm")
	print("PRESSBOT set calm weather pinned (no rolls)")
	_watch()
	await _sandbar()
	if not done and _left():
		await _cross()
	if not done and _island_id() == COAST:
		await _coast()
		if not done and _left():
			await _cross()
	if not done:
		await _wait_for("the summary", func() -> bool: return shell.get("flow") == FLOW_SUMMARY, 120.0)
	_report_and_quit()


# --- the targets --------------------------------------------------------------------------------

func _report_and_quit() -> void:
	if done:
		return
	done = true
	print("PRESSBOT timeline: launched from the sandbar at %s (day %d); arrivals %s; run %.0f s of game time; coconuts eaten %d, stolen %d" % [launch_clock, launch_day, arrivals, game_s, coconuts_eaten, stolen])
	_check("midday seen on the sandbar", midday_seen)
	_check("the sandbar's minimum thirst is under 50", min_thirst_sandbar < 50.0, "%.1f" % min_thirst_sandbar)
	_check("launched from the sandbar at 20:00 or later", launch_day > 1 or launch_time_of_day_s >= NIGHT_START_S, launch_clock)
	_check("alive at the summary", alive_at_end and shell.get("flow") == FLOW_SUMMARY)
	var errors: PackedStringArray = collector.error_list()
	for text: String in errors:
		print("PRESSBOT engine error: ", text)
	_check("no engine or script errors logged", errors.is_empty(), "%d error(s)" % errors.size())
	print("PRESSBOT summary: %d passed, %d failed" % [passes, fails])
	quit(0 if fails == 0 else 1)


func _check(label: String, ok: bool, detail: String = "") -> bool:
	if ok:
		passes += 1
	else:
		fails += 1
	print("PRESSBOT %s %s%s" % ["PASS" if ok else "FAIL", label, (" | " + detail) if not detail.is_empty() else ""])
	return ok


# Every physics frame: the game time, the sandbar's stats and a snapshot every 30 s.
func _watch() -> void:
	var next_snapshot: float = 0.0
	while not done:
		await physics_frame
		var delta: float = 1.0 / Engine.physics_ticks_per_second
		game_s += delta
		if game_s > DEADLINE_S:
			_check("finished within %d s of game time" % int(DEADLINE_S), false)
			_report_and_quit()
			return
		if not is_instance_valid(body):
			continue
		var meters: Object = body.get("meters")
		if not meters.get("dead"):
			alive_at_end = true
		else:
			alive_at_end = false
		if _island_id() == SANDBAR and not _left():
			min_thirst_sandbar = minf(min_thirst_sandbar, float(meters.get("thirst")))
			if sky.get("clock").call("is_midday"):
				midday_seen = true
		if game_s >= next_snapshot:
			next_snapshot += SNAPSHOT_S
			print("PRESSBOT snapshot %4.0fs day %d %s on %s: Salud %.0f Sed %.0f Hambre %.0f Calor %.0f Energia %.0f Animo %.0f | %s" % [game_s, int(sky.get("clock").get("day")), _clock_text(), _island_id(), meters.get("health"), meters.get("thirst"), meters.get("hunger"), meters.get("heat"), meters.get("energy"), meters.get("morale"), activity])


# --- the sandbar --------------------------------------------------------------------------------

func _sandbar() -> void:
	_build_land()
	activity = "knife"
	await _pick_up_nearest([&"knife"])
	while not done and _site() != null:
		if await _needs():
			continue
		if float(body.get("meters").get("energy")) <= 0.000001:
			_check("energy for the raft", false, "no energy and no coconut left at %s, work %.0f s of 120" % [_clock_text(), float(_site().call("progress")) * 120.0])
			_report_and_quit()
			return
		var site := _site()
		var missing: Dictionary = site.call("stage_missing_items")
		var wanted: Array[StringName] = []
		for id: StringName in missing:
			if _carried(id) < int(missing[id]):
				wanted.append(id)
		if not wanted.is_empty():
			activity = "gather %s" % [str(wanted)]
			if not await _pick_up_nearest(wanted):
				activity = "waiting for %s" % [str(wanted)]
				await _seconds(5.0)
			continue
		activity = "work stage %d" % (int(site.call("stage_index")) + 1)
		await _work()
	if done:
		return
	_check("the raft is built", _raft() != null, _clock_text())
	await _wait_and_launch()
	launch_clock = _clock_text()
	launch_time_of_day_s = float(sky.get("clock").get("time_of_day_s"))
	launch_day = int(sky.get("clock").get("day"))
	_check("the raft launched from the sandbar", _left(), launch_clock)


# The interruptions every step checks first: thirst, out of energy, the midday heat. True when one
# was handled (the caller looks again).
func _needs() -> bool:
	var meters: Object = body.get("meters")
	if float(meters.get("thirst")) < LOW_THIRST and _coconut_left():
		activity = "drink"
		await _eat_coconut()
		return true
	if float(meters.get("energy")) <= 0.000001 and _coconut_left():
		activity = "eat"
		while float(meters.get("energy")) < FED and _coconut_left() and not done:
			if not await _eat_coconut():
				break
		return true
	if float(meters.get("heat")) >= HOT and sky.get("clock").call("is_midday"):
		activity = "cool off"
		await _cool_off()
		return true
	return false


# Holds the site until it is built, the work stops (a stage's inputs are missing) or a need comes.
func _work() -> void:
	var site := _site()
	if site == null:
		return
	if not await _walk_to(site.global_position):
		return
	_intent(Vector2.ZERO, true)
	var last: float = float(site.call("progress"))
	var still_s: float = 0.0
	while not done:
		await physics_frame
		site = _site()
		if site == null:
			break
		var meters: Object = body.get("meters")
		if float(meters.get("energy")) <= 0.000001 or float(meters.get("thirst")) < LOW_THIRST:
			break
		if float(meters.get("heat")) >= HOT and sky.get("clock").call("is_midday"):
			break
		var now: float = float(site.call("progress"))
		still_s = still_s + 1.0 / Engine.physics_ticks_per_second if is_equal_approx(now, last) else 0.0
		last = now
		if still_s >= 0.5:
			break
	_intent(Vector2.ZERO, false)
	await physics_frame


# Once built: top up, then wait in the hut's shade until the launch at the raft would not be seen, and
# launch.
func _wait_and_launch() -> void:
	var raft := _raft()
	while not done and raft != null:
		var meters: Object = body.get("meters")
		if float(meters.get("energy")) < FED and _coconut_left():
			activity = "top up"
			await _eat_coconut()
			continue
		if await _needs():
			continue
		if _seen_at(raft.global_position):
			activity = "wait in the shade for the night"
			if not _in_shade():
				await _walk_to(_shade_spot())
			await _seconds(1.0)
			continue
		activity = "launch"
		if not await _walk_to(raft.global_position):
			continue
		if _seen_at(raft.global_position):
			continue
		_intent(Vector2.ZERO, true)
		await _seconds(1.3)
		_intent(Vector2.ZERO, false)
		await physics_frame
		if _left():
			return
	return


# --- at sea and on the cay ----------------------------------------------------------------------

func _cross() -> void:
	activity = "crossing"
	var crossings: Array = shell.get("crossings")
	if not crossings.is_empty():
		crossings[0].set("plan", (load(PLAN_PATH) as Script).call("create", CROSSING_S))
		print("PRESSBOT set a quiet %d s crossing" % int(CROSSING_S))
	var from: StringName = _island_id()
	await _wait_for("the crossing's end", func() -> bool: return shell.get("flow") == FLOW_SUMMARY or (_island_id() != from and _on_land()), CROSSING_S + 60.0)
	if shell.get("flow") != FLOW_SUMMARY:
		session = shell.get("session")
		body = session.call("body", 1)
		body.get("player_input").set("enabled", false)
		arrivals.append("%s at %s (day %d)" % [_island_id(), _clock_text(), int(sky.get("clock").get("day"))])


func _coast() -> void:
	_build_land()
	var raft := _raft()
	if not _check("a beached raft on the coast cay", raft != null):
		return
	while not done and not _left():
		if await _needs():
			continue
		if _seen_at(raft.global_position):
			activity = "wait out of the light"
			await _walk_to(_bench_or_shade())
			await _seconds(1.0)
			continue
		activity = "launch from the cay"
		if not await _walk_to(raft.global_position):
			await _seconds(1.0)
			continue
		if _seen_at(raft.global_position):
			continue
		_intent(Vector2.ZERO, true)
		await _seconds(1.3)
		_intent(Vector2.ZERO, false)
		await physics_frame


# --- coconuts, shade and walking ----------------------------------------------------------------

func _coconut_left() -> bool:
	return _carried(&"coco") > 0 or _palm_with_coconuts() != null


# One coconut eaten: carried, or climbed for (non-nest palms first) and eaten out of the gulls' sight.
func _eat_coconut() -> bool:
	if _carried(&"coco") == 0:
		var palm := _palm_with_coconuts()
		if palm == null:
			return false
		if not await _walk_to(palm.global_position):
			return false
		_intent(Vector2.ZERO, true)
		await _seconds(float(palm.get("hold_s")) + 0.2)
		_intent(Vector2.ZERO, false)
		await physics_frame
		if _carried(&"coco") == 0:
			return false
		if not _gull_safe(body.global_position):
			await _walk_to(_safe_spot())
	if _carried(&"coco") == 0:
		stolen += 1
		return false
	var slot: int = _slot_of(&"coco")
	if not session.call("use_for", 1, slot, 0, 0):
		return false
	coconuts_eaten += 1
	await _seconds(2.0)
	return true


func _cool_off() -> void:
	await _walk_to(_shade_spot())
	while not done and float(body.get("meters").get("heat")) >= COOL:
		await _seconds(1.0)


func _seen_at(point: Vector2) -> bool:
	return (load(SIGHT_PATH) as Script).call("seen_in", session, point) != null


func _palm_with_coconuts() -> Node2D:
	var island: Node = shell.get("island")
	var palms: Node = island.get_node_or_null(^"Palms")
	if palms == null:
		return null
	var nests: Array = (island.get("layout") as Resource).get("nest_palms")
	var best: Node2D = null
	var best_score: float = INF
	for i: int in palms.get_child_count():
		var palm := palms.get_child(i) as Node2D
		if int(palm.get("coconuts")) <= 0:
			continue
		var score: float = body.global_position.distance_to(palm.global_position) + (100000.0 if nests.has(i) else 0.0)
		if score < best_score:
			best = palm
			best_score = score
	return best


func _gull_safe(at: Vector2) -> bool:
	var island: Node = shell.get("island")
	var palms: Node = island.get_node_or_null(^"Palms")
	var nests: Array = (island.get("layout") as Resource).get("nest_palms")
	for i: int in nests:
		if palms != null and i < palms.get_child_count() and at.distance_to((palms.get_child(i) as Node2D).global_position) <= GULL_SAFE_TILES * TILE:
			return false
	return true


func _safe_spot() -> Vector2:
	return _nearest_cell(func(cell: Vector2i) -> bool: return _gull_safe(_center(cell)))


func _shade_spot() -> Vector2:
	var hut: Array = _built().get("hut_cells")
	return _nearest_cell(func(cell: Vector2i) -> bool: return hut.has(cell) and session.get("terrain").call("is_shaded", cell))


func _bench_or_shade() -> Vector2:
	var bench: Vector2i = _built().get("workbench")
	if bench.x >= 0:
		return _nearest_cell(func(cell: Vector2i) -> bool: return cell.distance_to(bench) <= 1.5 and cell != bench)
	return _shade_spot()


func _in_shade() -> bool:
	return session.get("terrain").call("is_shaded", _cell(body.global_position))


# The land cell nearest the player by walking for which `fits` holds (breadth first), else here.
func _nearest_cell(fits: Callable) -> Vector2:
	var start: Vector2i = _cell(body.global_position)
	var seen: Dictionary = {start: true}
	var queue: Array[Vector2i] = [start]
	while not queue.is_empty():
		var cell: Vector2i = queue.pop_front()
		if fits.call(cell):
			return _center(cell)
		for step: Vector2i in [Vector2i.RIGHT, Vector2i.LEFT, Vector2i.DOWN, Vector2i.UP]:
			var next: Vector2i = cell + step
			if seen.has(next) or not land.is_in_boundsv(next) or land.is_point_solid(next):
				continue
			seen[next] = true
			queue.append(next)
	return body.global_position


func _pick_up_nearest(ids: Array[StringName]) -> bool:
	var best: Node2D = null
	for node: Node in session.get("pickups").get_children():
		var item := node as Node2D
		if item == null or item.is_queued_for_deletion() or not ids.has(item.get("item_id")):
			continue
		if best == null or body.global_position.distance_to(item.global_position) < body.global_position.distance_to(best.global_position):
			best = item
	if best == null:
		return false
	var id: StringName = best.get("item_id")
	var before: int = _carried(id)
	if not await _walk_to(best.global_position):
		return false
	_intent(Vector2.ZERO, true)
	await _seconds(0.1)
	_intent(Vector2.ZERO, false)
	await _seconds(0.1)
	return _carried(id) > before


func _walk_to(goal: Vector2) -> bool:
	var path: Array[Vector2i] = land.get_id_path(_cell(body.global_position), _cell(goal))
	var points: Array[Vector2] = []
	for i: int in range(1, path.size() - 1):
		points.append(_center(path[i]))
	points.append(goal)
	var budget: int = maxi(240, ceili(body.global_position.distance_to(goal) * 8.0))
	for point: Vector2 in points:
		while body.global_position.distance_to(point) > AT_PX:
			_intent((point - body.global_position).normalized(), false)
			await physics_frame
			budget -= 1
			if budget <= 0 or done:
				_intent(Vector2.ZERO, false)
				return false
	_intent(Vector2.ZERO, false)
	await physics_frame
	return true


func _intent(direction: Vector2, interact: bool) -> void:
	if is_instance_valid(body):
		body.set("intent", (load(INTENT_PATH) as Script).call("create", direction, false, false, interact))


func _seconds(seconds: float) -> void:
	for i: int in ceili(seconds * Engine.physics_ticks_per_second):
		await physics_frame


func _wait_for(what: String, ready: Callable, timeout_s: float) -> bool:
	for i: int in ceili(timeout_s * Engine.physics_ticks_per_second):
		if ready.call():
			return true
		await physics_frame
	return _check("in time: %s" % what, false, "%.0f s" % timeout_s)


# --- reading the game ---------------------------------------------------------------------------

func _in_run() -> bool:
	if shell.get("flow") != FLOW_RUN or shell.get("session") == null:
		return false
	return shell.get("session").call("body", 1) != null


func _built() -> Object:
	return shell.get("island").get("built")


func _build_land() -> void:
	var built: Object = _built()
	var size: Vector2i = built.get("size")
	var terrain: Object = built.get("terrain")
	var query: Script = load(TERRAIN_PATH) as Script
	land = AStarGrid2D.new()
	land.region = Rect2i(Vector2i.ZERO, size)
	land.cell_size = Vector2.ONE
	land.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	land.update()
	for y: int in size.y:
		for x: int in size.x:
			land.set_point_solid(Vector2i(x, y), query.call("is_water", terrain.call("terrain_at", Vector2i(x, y))))


func _island_id() -> StringName:
	var island: Node = shell.get("island") if shell != null else null
	return (island.get("layout") as Resource).get("id") if island != null else &""


func _site() -> Node2D:
	var site := session.get_node_or_null(^"RaftSite") as Node2D
	return site if site != null and not site.is_queued_for_deletion() and not site.get("built") else null


func _raft() -> Node2D:
	var raft := session.get_node_or_null(^"Raft") as Node2D
	return raft if raft != null and not raft.is_queued_for_deletion() else null


func _left() -> bool:
	return is_instance_valid(session) and session.call("has_left", 1) == true


func _on_land() -> bool:
	var current: Node = shell.get("session")
	if current == null:
		return false
	var mine: Node = current.call("body", 1)
	return mine != null and not mine.get("left_island") and not current.call("has_left", 1)


func _carried(id: StringName) -> int:
	return int(body.get("inventory").call("count_id", id))


func _slot_of(id: StringName) -> int:
	var slots: Array = body.get("inventory").get("slots")
	for i: int in slots.size():
		if slots[i].get("item_id") == id:
			return i
	return -1


func _clock_text() -> String:
	var clock: Object = sky.get("clock")
	return "%02d:%02d" % [int(clock.call("hour")), int(clock.call("minute"))]


func _cell(at: Vector2) -> Vector2i:
	return Vector2i(floori(at.x / TILE), floori(at.y / TILE))


func _center(cell: Vector2i) -> Vector2:
	return (Vector2(cell) + Vector2(0.5, 0.5)) * TILE
