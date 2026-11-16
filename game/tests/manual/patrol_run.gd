extends SceneTree
## Manual two-process run for guardacostas-stealth task 9.3: a host and a client play the coast cay at night
## over ENet on UDP port 7789, and each prints what it sees. Run the host first, then the client (both
## headless, since nothing here reads pixels):
##   godot --headless --path game -s res://tests/manual/patrol_run.gd -- --mode=host
##   godot --headless --path game -s res://tests/manual/patrol_run.gd -- --mode=client
## The host opens the lobby on the port and waits for the client; the run starts, travels to the coast cay,
## drops the second boat (so one boat is in play), sets night, and plays this script, each peer checking
## what its own HUD and look show:
##   1. the boat's 20 s horizon warning: a light on the HUD band on both peers, gone when the lap starts;
##   2. the client's player is put on open sand in the beam (the boat's clock held by hand): the open eye
##      fills over them on both peers, they are spotted at 2 s, the boat locks on them, the loudhailer
##      calls an alert line on both peers and the beam is on them;
##   3. the client's player (crouching) is put in scrub: hidden, the closed eye, the lock breaks, 20 s of
##      search, the boat gives up with a give-up line on both peers and resumes its lap;
##   4. the client quits and joins again with the boat mid-lap: it draws the boat in place at once.
## The client's crouch (held from its first frame on the cay) is also its "ready" for the host. Each check
## prints "PATROLRUN PASS|FAIL <what> | <detail>", the run quits non-zero on a fail, and "PATROLRUN engine
## error" lines list anything the engine or a script logged. Where a step needs what playing cannot reach (the
## night clock, the boat's clock, putting a body on a cell) it is set through the same hooks the GUT tests
## use and printed as "PATROLRUN set <what>".
## Compiled before the autoloads exist, so it names no project class: duck typing throughout.

const SHELL_PATH: String = "res://scenes/shell/game_shell.tscn"
const PORT: int = 7789
const FLOW_RUN: int = 3
const TILE: float = 16.0
const DEEP: int = 0
const BEACH: int = 3
const SCRUB: int = 7
const NIGHT_START_S: float = 430.0
const DEADLINE_S: float = 600.0
const HORIZON_WARNING_S: float = 20.0
const ALERT_LOCK: int = 3
const ALERT_SEARCH: int = 4
const LAP: int = 2
const HORIZON: int = 1
const CLIENT_NAME: String = "Papo"
const LAPS_TO_TRY: Array[float] = [5.0, 10.0, 15.0, 20.0, 25.0, 30.0, 40.0, 50.0, 60.0, 70.0, 80.0, 90.0]
const LAND_TIMEOUT_S: float = 120.0


class Collector extends Logger:
	var errors: PackedStringArray = []
	var warnings: PackedStringArray = []
	var _lock: Mutex = Mutex.new()

	func _log_error(function: String, file: String, line: int, code: String, rationale: String, _editor_notify: bool, error_type: int, _script_backtrace: Array[ScriptBacktrace]) -> void:
		_lock.lock()
		var text: String = "%s:%d (%s) %s %s" % [file, line, function, code, rationale]
		if error_type == ERROR_TYPE_WARNING:
			warnings.append(text)
		else:
			errors.append(text)
		_lock.unlock()

	func _log_message(_message: String, _error: bool) -> void:
		pass

	func error_list() -> PackedStringArray:
		_lock.lock()
		var copy: PackedStringArray = errors.duplicate()
		_lock.unlock()
		return copy

	func warning_list() -> PackedStringArray:
		_lock.lock()
		var copy: PackedStringArray = warnings.duplicate()
		_lock.unlock()
		return copy


var collector: Collector = Collector.new()
var mode: String = "host"
var shell: Node = null
var session: Node = null
var island: Node2D = null
var hud: Node = null
var passes: int = 0
var fails: int = 0
var done: bool = false
var physics_hz: int = 60
var client_peer: int = 0


func _init() -> void:
	OS.add_logger(collector)


func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--mode="):
			mode = arg.trim_prefix("--mode=")
	physics_hz = Engine.physics_ticks_per_second
	var settings_path: String = "user://patrol_run_%s.cfg" % mode
	var config := ConfigFile.new()
	config.set_value("player", "name", CLIENT_NAME if mode == "client" else "Yuni")
	config.set_value("display", "fullscreen", false)
	config.set_value("display", "ui_scale", 1)
	config.set_value("display", "pixel_filter", 0)
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
	print("PATROLRUN patrol_run mode %s, pid %d" % [mode, OS.get_process_id()])
	if mode == "host":
		await _host()
	elif mode == "client":
		await _client()
	else:
		_check("known mode", false, mode)
	await _finish()


func _on_deadline() -> void:
	if done:
		return
	_check("finished before the %d s deadline" % int(DEADLINE_S), false)
	_report_and_quit()


# --- checks, hooks and time ----------------------------------------------------------------------

func _check(label: String, ok: bool, detail: String = "") -> bool:
	if ok:
		passes += 1
	else:
		fails += 1
	print("PATROLRUN %s %s: %s%s" % ["PASS" if ok else "FAIL", mode, label, (" | " + detail) if not detail.is_empty() else ""])
	return ok


func _note(text: String) -> void:
	print("PATROLRUN note %s: %s" % [mode, text])


func _hooked(text: String) -> void:
	print("PATROLRUN set %s: %s" % [mode, text])


func _frames(count: int) -> void:
	for i: int in count:
		await physics_frame


func _seconds(seconds: float) -> void:
	await _frames(ceili(seconds * physics_hz))


func _wait_for(what: String, ready: Callable, timeout_s: float) -> bool:
	_note("waiting for %s (up to %.0f s)" % [what, timeout_s])
	var started: int = Time.get_ticks_msec()
	for i: int in ceili(timeout_s * physics_hz):
		if ready.call():
			_note("got %s after %.1f s" % [what, (Time.get_ticks_msec() - started) / 1000.0])
			return true
		await physics_frame
	_check("timed out after %.0f s waiting for %s" % [timeout_s, what], false)
	return false


func _sky() -> Object:
	return root.get_node(^"WeatherManager").get("sky")


func _night(why: String) -> void:
	_sky().call("start_at", NIGHT_START_S)
	(_sky().get("weather") as Object).set("rolls_enabled", false)
	_hooked("night clock to %.0f s, weather rolls off (%s)" % [NIGHT_START_S, why])


# --- reading the run ---------------------------------------------------------------------------------

# The run's shell, session, island and HUD (the island changes with a travel), true when they exist.
func _refresh() -> bool:
	if shell.get("flow") != FLOW_RUN or shell.get("session") == null or shell.get("hud") == null or shell.get("island") == null:
		return false
	session = shell.get("session")
	island = shell.get("island")
	hud = shell.get("hud")
	return true


func _on_cay() -> bool:
	return _refresh() and (island.get("layout") as Object).get("id") == &"coast_cay"


func _my_body() -> Node2D:
	return session.call("body", session.multiplayer.get_unique_id()) as Node2D


func _body_of(peer: int) -> Node2D:
	return session.call("body", peer) as Node2D


func _terrain() -> Object:
	return island.get("terrain")


func _kind(cell: Vector2i) -> int:
	return int(_terrain().call("terrain_at", cell))


func _center(cell: Vector2i) -> Vector2:
	return (Vector2(cell) + Vector2(0.5, 0.5)) * TILE


# The patrol boats of the session, by name.
func _boats() -> Array[Node2D]:
	var found: Array[Node2D] = []
	var names: Array[String] = []
	for node: Node in session.get_node(^"Entities").get_children():
		var data: Object = node.get("data")
		if data != null and data.get("id") == &"patrol_boat" and not node.is_queued_for_deletion():
			names.append(String(node.name))
	names.sort()
	for boat_name: String in names:
		found.append(session.get_node(^"Entities").get_node(NodePath(boat_name)) as Node2D)
	return found


func _boat_state(boat: Node2D) -> int:
	return int(boat.get("state_id"))


func _look(boat: Node2D) -> Object:
	return boat.get_node(^"PatrolLook")


func _patrol(boat: Node2D) -> Object:
	return (boat.get("data") as Object).get("patrol")


func _lines(boat: Node2D, name: String) -> PackedStringArray:
	return _patrol(boat).get(name)


# The boat's lap start-to-here error: where the loop puts the boat at its own clock, against where it is.
func _off_the_loop_px(boat: Node2D) -> float:
	var view: Object = boat.call("view")
	var lap_t: float = clampf(float(boat.get("route_t")) - HORIZON_WARNING_S, 0.0, float((view.get("loop") as Object).get("lap_s")))
	return boat.position.distance_to((view.get("loop") as Object).call("pose_px", lap_t))


# How far (degrees) the beam of `boat` is from the line to `point`.
func _beam_error_deg(boat: Node2D, point: Vector2) -> float:
	var aim: float = rad_to_deg((point - boat.position).angle())
	return absf(wrapf(aim - float(boat.get("beam")), -180.0, 180.0))


# Whether the boat's cone, as this peer draws it (its synced light, position and beam), covers `point`.
func _lit(boat: Node2D, point: Vector2) -> bool:
	var light: Object = (boat.call("view") as Object).get("light")
	return bool(boat.get("light_on")) and bool(light.call("is_lit", point / TILE, boat.position / TILE, float(boat.get("beam"))))


# The cells of terrain `kind` (open, unroofed for sand) in reading order.
func _cells_of(kind: int) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	var shaded: Dictionary = _terrain().get("shaded")
	for cell: Vector2i in (_terrain().get("cells") as Dictionary):
		if _kind(cell) == kind and not shaded.has(cell):
			cells.append(cell)
	cells.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return a.y < b.y or (a.y == b.y and a.x < b.x))
	return cells


# Open sand 4 to 8 tiles from the boat that its held light covers, or (-1, -1).
func _lit_sand(boat: Node2D) -> Vector2:
	for cell: Vector2i in _cells_of(BEACH):
		var centre: Vector2 = _center(cell)
		var tiles: float = boat.position.distance_to(centre) / TILE
		if tiles >= 4.0 and tiles <= 8.0 and _lit(boat, centre):
			return centre
	return Vector2(-1.0, -1.0)


# The land cell farthest from `from`: where a player is out of the light.
func _farthest_sand(from: Vector2) -> Vector2:
	var best: Vector2 = Vector2.ZERO
	var best_distance: float = -1.0
	for cell: Vector2i in _cells_of(BEACH):
		var distance: float = from.distance_to(_center(cell))
		if distance > best_distance:
			best_distance = distance
			best = _center(cell)
	return best


# The scrub cell nearest `near`.
func _nearest_scrub(near: Vector2) -> Vector2:
	var best: Vector2 = Vector2(-1.0, -1.0)
	var best_distance: float = INF
	for cell: Vector2i in _cells_of(SCRUB):
		var distance: float = near.distance_to(_center(cell))
		if distance < best_distance:
			best_distance = distance
			best = _center(cell)
	return best


# The boat's clock at `seconds` into its whole loop, settled with a zero-length tick.
func _clock(boat: Node2D, seconds: float) -> void:
	(boat.get("brain") as Object).call("set_clock", seconds)
	boat.call("advance", 0.0)


# --- the host ---------------------------------------------------------------------------------------------

func _host() -> void:
	shell.call("start_host")
	session = shell.get("session")
	if not _check("start_host opened port %d and built the session" % PORT, session != null and not (session.multiplayer.multiplayer_peer is OfflineMultiplayerPeer)):
		return
	print("PATROLRUN host listening %d" % ((session.multiplayer.multiplayer_peer as ENetMultiplayerPeer).host.get_local_port()))
	if not await _wait_for("the client in the lobby", func() -> bool: return (session.get("roster") as Dictionary).size() > 1, LAND_TIMEOUT_S):
		return
	await _seconds(1.0)
	_check("begin_run started the run", session.call("begin_run") == true)
	if not await _wait_for("the run", func() -> bool: return _refresh() and _my_body() != null, 30.0):
		return
	for peer: int in session.call("peer_ids"):
		if peer != 1:
			client_peer = peer
	_check("host: the client has a body here", _body_of(client_peer) != null, "peer %d" % client_peer)
	var arrivals: Dictionary = {}
	for peer: int in session.call("peer_ids"):
		arrivals[peer] = {"health": 100.0, "energy": 100.0}
	session.rpc("travel_to", "coast_cay", arrivals, 100.0)
	_hooked("travelled to the coast cay at once (CoopSession.travel_to over its RPC), for both players")
	if not await _wait_for("both peers on the coast cay", func() -> bool: return _on_cay() and _body_of(client_peer) != null and not _boats().is_empty(), 60.0):
		return
	var spawner: Object = session.get_node(^"Creatures")
	_night("the patrol's light shows at night")
	spawner.call("apply_phase", root.get_node(^"WeatherManager").call("phase"))
	_hooked("the island's creatures told the phase (the spawner's apply_phase, as the clock's phase change does)")
	var boats: Array[Node2D] = _boats()
	_note("the coast cay has %d patrol boat(s) for two players" % boats.size())
	for i: int in range(1, boats.size()):
		(spawner.get("watch").get("boats") as Array).erase(boats[i])
		spawner.call("_remove", boats[i])
	_hooked("the extra boats dropped, so one boat is in play")
	await _frames(10)
	var boat: Node2D = _boats()[0]
	var brain: Object = boat.get("brain")
	var patrol: Object = _patrol(boat)
	_check("host: one patrol boat is in play", _boats().size() == 1)
	# The client's crouch is its ready.
	if not await _wait_for("the client ready (crouching)", func() -> bool: return bool(((_body_of(client_peer) as Object).get("intent") as Object).get("crouch")), 120.0):
		return
	await _horizon(boat, brain)
	await _spot_and_lock(boat, brain, patrol, spawner)
	await _hide_and_give_up(boat, brain, patrol, spawner)
	await _rejoin(boat, brain, patrol)


# 1. The warning: the light on the host's band, then gone when the lap starts.
func _horizon(boat: Node2D, brain: Object) -> void:
	await _seconds(1.0)
	_clock(boat, 2.0)
	_hooked("the boat's clock at 2 s of its 20 s horizon warning")
	await _frames(5)
	var band: Object = hud.get("patrol_horizon")
	_check("host: the boat is on the horizon", _boat_state(boat) == HORIZON)
	_check("host: a light shows on the HUD band", int(band.call("mark_count")) == 1 and not bool(band.call("is_hull", 0)), "%d mark(s)" % int(band.call("mark_count")))
	var rect: Rect2 = band.call("mark_rect", 0)
	_check("host: the light is 3x2 and inside the band", rect.size == Vector2(3.0, 2.0) and rect.position.x >= 0.0 and rect.end.x <= 640.0, "%s" % rect)
	if not await _wait_for("the lap to start", func() -> bool: return _boat_state(boat) == LAP, 25.0):
		return
	await _frames(5)
	_check("host: the light is gone when the lap starts", int(band.call("mark_count")) == 0)
	_check("host: the boat's light is on in its lap at night", bool(boat.get("light_on")))


# 2. Lit on sand, the eye fills, spotted at 2 s, locked, a loudhailer line.
func _spot_and_lock(boat: Node2D, brain: Object, patrol: Object, spawner: Object) -> void:
	spawner.call("set_physics_process", false)
	boat.call("set_physics_process", false)
	var warning: float = float(patrol.get("horizon_warning_s"))
	var held: float = -1.0
	var sand: Vector2 = Vector2(-1.0, -1.0)
	for lap_s: float in LAPS_TO_TRY:
		_clock(boat, warning + lap_s)
		sand = _lit_sand(boat)
		if sand.x >= 0.0:
			held = lap_s
			break
	if not _check("host: the cone reaches open sand on the cay", held >= 0.0):
		return
	_hooked("the boat's clock held at %.0f s of its lap, the client's player put on open sand in the beam, the host's player on the sand farthest from it" % held)
	_body_of(client_peer).global_position = sand
	_body_of(1).global_position = _farthest_sand(boat.position)
	var alerts: Array[int] = [0]
	boat.connect("patrol_alerted", func(_cause: StringName, _at: Vector2) -> void: alerts[0] += 1)
	await _seconds(0.5)
	(_body_of(client_peer).get("spot_meter") as Object).call("clear")
	var band_eye: Object = hud.get("marks")
	var steps: int = 0
	var half_seen: bool = false
	var dt: float = 1.0 / physics_hz
	while steps < physics_hz * 5 and _boat_state(boat) != ALERT_LOCK:
		await physics_frame
		_clock(boat, warning + held)
		spawner.get("watch").call("step", dt)
		steps += 1
		if not half_seen and steps >= physics_hz:
			half_seen = true
			await _seconds(0.3)
			_check("host: the open eye shows over the client's player, about half full, at 1 s", bool(band_eye.call("has_open_eye", _body_of(client_peer))) and absf(float(band_eye.call("eye_fill", _body_of(client_peer))) - 0.5) < 0.15, "fill %.2f" % float(band_eye.call("eye_fill", _body_of(client_peer))))
	_check("host: the client's player is spotted at 2 s of light", absf(steps * dt - 2.0) < 0.1 or half_seen and absf(steps * dt - 2.0) < 0.5, "%.2f s" % (steps * dt))
	_check("host: the boat locks on them and reports once", _boat_state(boat) == ALERT_LOCK and alerts[0] == 1 and brain.get("locked") == _body_of(client_peer), "%d report(s)" % alerts[0])
	boat.call("set_physics_process", true)
	spawner.call("set_physics_process", true)
	await _frames(5)
	_check("host: the beam is on the client's player", _beam_error_deg(boat, _body_of(client_peer).global_position) < 3.0, "%.2f deg" % _beam_error_deg(boat, _body_of(client_peer).global_position))
	var look: Object = _look(boat)
	_check("host: the loudhailer called a formal Spanish alert line", int(look.get("lines_shown")) == 1 and _lines(boat, "alert_lines_es").has(String(look.get("last_line"))), String(look.get("last_line")))


# 3. Into the scrub, crouching: hidden, the lock breaks, 20 s, give up.
func _hide_and_give_up(boat: Node2D, brain: Object, patrol: Object, spawner: Object) -> void:
	await _seconds(3.0)
	_check("host: the lock holds while the player stays visible", _boat_state(boat) == ALERT_LOCK)
	var scrub: Vector2 = _nearest_scrub(_body_of(client_peer).global_position)
	if not _check("host: the cay has scrub to hide in", scrub.x >= 0.0):
		return
	_hooked("the client's (crouching) player put in the nearest scrub")
	_body_of(client_peer).global_position = scrub
	var marks: Object = hud.get("marks")
	if not await _wait_for("the client's player hidden and the lock broken", func() -> bool: return _boat_state(boat) == ALERT_SEARCH, 15.0):
		return
	await _frames(5)
	_check("host: the closed eye shows over the hidden player and the open eye does not", bool(marks.call("has_mark", _body_of(client_peer))) and not bool(marks.call("has_open_eye", _body_of(client_peer))))
	var serial: int = int(boat.get("alert_serial"))
	if not await _wait_for("the boat to give up after its search", func() -> bool: return _boat_state(boat) == LAP and int(boat.get("alert_serial")) == serial + 1, 40.0):
		return
	await _frames(5)
	var look: Object = _look(boat)
	_check("host: the boat resumed its lap and called a give-up line", int(look.get("lines_shown")) == 2 and _lines(boat, "give_up_lines_es").has(String(look.get("last_line"))), String(look.get("last_line")))
	_check("host: the meter is back at 0 and the open eye is gone", float(_body_of(client_peer).get("spot_shown")) == 0.0 and not bool(marks.call("has_open_eye", _body_of(client_peer))))


# 4. The client leaves and comes back with the boat mid-lap.
func _rejoin(boat: Node2D, brain: Object, patrol: Object) -> void:
	# The client does not leave until it has seen the give-up; it then goes, so the run waits for that.
	var left: Callable = func() -> bool:
		var body: Node2D = _body_of(client_peer)
		return body == null or bool(((body as Object).get("net") as Object).get("net_dropped"))
	if not await _wait_for("the client to leave", left, 120.0):
		return
	_clock(boat, float(patrol.get("horizon_warning_s")) + 40.0)
	_hooked("the boat's clock at 40 s of its lap while the client is away")
	# The rejoined client is a new peer: remember its id, so the last wait below waits for that peer to
	# leave (with the old id it would pass at once and the host would quit under the joining client).
	var rejoined: Array[int] = [0]
	var back: Callable = func() -> bool:
		for peer: int in session.call("peer_ids"):
			var body: Node2D = _body_of(peer)
			if peer != 1 and body != null and not bool(((body as Object).get("net") as Object).get("net_dropped")):
				rejoined[0] = peer
				return true
		return false
	if not await _wait_for("the client back", back, 120.0):
		return
	client_peer = rejoined[0]
	_check("host: the client rejoined", true)
	_note("host: boat at %s, clock %.1f s, beam %.1f deg, state %d" % [boat.position, float(boat.get("route_t")), float(boat.get("beam")), _boat_state(boat)])
	# The client checks itself, then leaves for good.
	await _wait_for("the client to leave for good", left, 120.0)


# --- the client ------------------------------------------------------------------------------------------

func _client() -> void:
	shell.call("_join", "127.0.0.1", PORT)
	if not await _wait_for("the run", func() -> bool: return _refresh() and _my_body() != null, 120.0):
		_check("the client joined and entered the run", false)
		return
	_check("the client joined and entered the run", true)
	_check("the client is not the host", not session.multiplayer.is_server())
	if not await _wait_for("the coast cay with the boat", func() -> bool: return _on_cay() and _my_body() != null and _boats().size() >= 1, 120.0):
		return
	_night("the client's own sky, for its own day phase")
	await _seconds(3.0)
	if not await _wait_for("one boat (the host drops the extras)", func() -> bool: return _boats().size() == 1, 30.0):
		return
	Input.action_press(&"crouch")
	_hooked("crouch held (the host reads it as the client's ready)")
	var me: Node2D = _my_body()
	var marks: Object = hud.get("marks")
	var band: Object = hud.get("patrol_horizon")
	# 1. the warning
	if not await _wait_for("the boat's horizon warning", func() -> bool: return _boats().size() == 1 and _boat_state(_boats()[0]) == HORIZON, 120.0):
		return
	var boat: Node2D = _boats()[0]
	await _frames(5)
	_check("client: a light shows on the HUD band for the warning", int(band.call("mark_count")) == 1 and not bool(band.call("is_hull", 0)), "%d mark(s), phase %d" % [int(band.call("mark_count")), int(root.get_node(^"WeatherManager").call("phase"))])
	_check("client: the boat is parked off its lap while on the horizon", not bool(boat.get("light_on")))
	if not await _wait_for("the lap to start", func() -> bool: return _boat_state(boat) == LAP, 40.0):
		return
	await _frames(5)
	_check("client: the light is gone when the lap starts", int(band.call("mark_count")) == 0)
	_check("client: the boat is on its loop, derived from the host's clock", _off_the_loop_px(boat) < 6.0, "%.2f px" % _off_the_loop_px(boat))
	_check("client: the cone is on", bool(boat.get("light_on")) and bool(_look(boat).get("hull_visible")) and bool(((_look(boat).get("light") as Object).get("visible"))))
	# 2. lit, the eye, the lock
	me = _my_body()
	if not await _wait_for("the open eye over my player", func() -> bool: return float(me.get("spot_shown")) > 0.0, 60.0):
		return
	await _frames(3)
	me = _my_body()
	_check("client: the open eye shows over my player while lit", bool(marks.call("has_open_eye", me)) and float(marks.call("eye_fill", me)) > 0.0, "fill %.2f" % float(marks.call("eye_fill", me)))
	_check("client: my player is inside the cone I am shown", _lit(boat, me.global_position))
	if not await _wait_for("the boat to lock on me", func() -> bool: return _boat_state(boat) == ALERT_LOCK, 30.0):
		return
	await _frames(10)
	var look: Object = _look(boat)
	_check("client: the loudhailer called a formal Spanish alert line", int(look.get("lines_shown")) == 1 and _lines(boat, "alert_lines_es").has(String(look.get("last_line"))), String(look.get("last_line")))
	_check("client: the beam is on my player", _beam_error_deg(boat, me.global_position) < 3.0, "%.2f deg" % _beam_error_deg(boat, me.global_position))
	# 3. hidden, the give-up
	if not await _wait_for("the lock to break (I am hidden in scrub)", func() -> bool: return _boat_state(boat) == ALERT_SEARCH, 40.0):
		return
	await _frames(5)
	me = _my_body()
	_check("client: the closed eye shows over my hidden player", bool(marks.call("has_mark", me)) and not bool(marks.call("has_open_eye", me)))
	var serial: int = int(boat.get("alert_serial"))
	if not await _wait_for("the boat to give up", func() -> bool: return _boat_state(boat) == LAP and int(boat.get("alert_serial")) == serial + 1, 60.0):
		return
	await _frames(10)
	_check("client: the boat gave up with a give-up line", int(look.get("lines_shown")) == 2 and _lines(boat, "give_up_lines_es").has(String(look.get("last_line"))), String(look.get("last_line")))
	# 4. quit and rejoin
	Input.action_release(&"crouch")
	_note("client leaves, and joins again in 5 s")
	shell.call("back_to_title")
	await _seconds(5.0)
	shell.call("_join", "127.0.0.1", PORT)
	var first: Array[Dictionary] = []
	var watch_first: Callable = func() -> bool:
		if not _on_cay() or _my_body() == null:
			return false
		var boats: Array[Node2D] = _boats()
		if boats.is_empty():
			return false
		var arrived: Node2D = boats[0]
		var arrived_look: Object = _look(arrived)
		arrived_look.call("step", 0.0)
		first.append({
			"state": _boat_state(arrived),
			"off": _off_the_loop_px(arrived),
			"route_t": float(arrived.get("route_t")),
			"light_on": bool(arrived.get("light_on")),
			"hull": bool(arrived_look.get("hull_visible")),
			"light_visible": bool((arrived_look.get("light") as Object).get("visible")),
			"rotation_error": absf(wrapf(rad_to_deg(float((arrived_look.get("light") as Object).get("rotation"))) - float(arrived.get("beam")), -180.0, 180.0)),
			"lines": int(arrived_look.get("lines_shown")),
			"position": arrived.position,
		})
		return true
	if not await _wait_for("the rejoined client's first view of the boat", watch_first, 120.0):
		_check("client: joined again", false)
		return
	var seen: Dictionary = first[0]
	_check("client: joined again and the boat is in its lap, drawn at once", int(seen["state"]) == LAP and bool(seen["hull"]), "state %d" % int(seen["state"]))
	_check("client: the boat is in place on the loop at the host's clock (40 s of the lap, set while away)", float(seen["off"]) < 6.0 and absf(float(seen["route_t"]) - (HORIZON_WARNING_S + 40.0)) < 10.0, "%.2f px off, clock %.1f s, at %s" % [float(seen["off"]), float(seen["route_t"]), seen["position"]])
	_check("client: the cone is on at the host's aim on the first frame", bool(seen["light_on"]) and bool(seen["light_visible"]) and float(seen["rotation_error"]) < 1.0, "%.2f deg" % float(seen["rotation_error"]))
	_check("client: a joiner calls no line for an alert already past", int(seen["lines"]) == 0)
	await _seconds(2.0)
	shell.call("back_to_title")
	await _seconds(1.0)


# --- the end ---------------------------------------------------------------------------------------------

func _finish() -> void:
	if done:
		return
	Input.action_release(&"crouch")
	if is_instance_valid(shell) and shell.get("flow") != 0:
		shell.call("back_to_title")
	await _frames(4)
	_report_and_quit()


func _report_and_quit() -> void:
	if done:
		return
	done = true
	var errors: PackedStringArray = collector.error_list()
	var warnings: PackedStringArray = collector.warning_list()
	for text: String in errors:
		print("PATROLRUN engine error: ", text)
	for text: String in warnings:
		print("PATROLRUN engine warning: ", text)
	_check("no engine or script errors logged (%s)" % mode, errors.is_empty(), "%d error(s), %d warning(s)" % [errors.size(), warnings.size()])
	print("PATROLRUN summary %s: %d passed, %d failed" % [mode, passes, fails])
	quit(0 if fails == 0 else 1)
