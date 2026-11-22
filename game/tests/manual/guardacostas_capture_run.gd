extends SceneTree
## Manual two-process run for guardacostas-capture task 12.3: a host and a client play the sandbar at
## night over ENet on UDP port 7796, and each prints what it sees. Run the host first, then the client
## (both headless, since nothing here reads pixels):
##   godot --headless --path game -s res://tests/manual/guardacostas_capture_run.gd -- --mode=host
##   godot --headless --path game -s res://tests/manual/guardacostas_capture_run.gd -- --mode=client
## The host opens the lobby on the port and waits for the client; the run starts on the sandbar, the
## clock is set to night, and this script plays, each peer checking what its own session shows:
##   1. the client's player is spotted on open sand: the boat docks, its dinghy rows in and the squad
##      of three lands, seen on both peers;
##   2. a soldier captures the client's player and leads them to the dinghy; with the soldiers held away
##      up the beach, the host's player frees them with a 1 s hold, seen on both peers;
##   3. both players are captured (the whole party): `la_captura` plays on both peers, line for line;
##   4. the scene ends with the return, and the restart lands both players on the sandbar again.
## The client's crouch (held from its first frame) is its "ready" for the host. Each check prints
## "CAPTURERUN PASS|FAIL <what> | <detail>", the run quits non-zero on a fail, and "CAPTURERUN engine
## error" lines list anything the engine or a script logged. Where a step needs what playing cannot reach
## (the night clock, the boat's clock, putting a body on a cell, holding the soldiers away) it is set
## through the same hooks the GUT tests use and printed as "CAPTURERUN set <what>". The restart frees the
## island, so a wait for it compares instance ids, never the freed node. Not named
## capture_*.gd: that is the screenshot tooling's prefix.
## Compiled before the autoloads exist, so it names no project class: duck typing throughout.

const SHELL_PATH: String = "res://scenes/shell/game_shell.tscn"
const RULES_PATH: String = "res://scripts/stealth/capture_rules.gd"
const PORT: int = 7796
const FLOW_RUN: int = 3
const TILE: float = 16.0
const BEACH: int = 3
const NIGHT_START_S: float = 430.0
const DEADLINE_S: float = 600.0
const DOCKED: int = 6
const ASHORE: int = 2
const CLIENT_NAME: String = "Papo"
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
	var settings_path: String = "user://guardacostas_capture_run_%s.cfg" % mode
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
	print("CAPTURERUN guardacostas_capture_run mode %s, pid %d" % [mode, OS.get_process_id()])
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
	print("CAPTURERUN %s %s: %s%s" % ["PASS" if ok else "FAIL", mode, label, (" | " + detail) if not detail.is_empty() else ""])
	return ok


func _note(text: String) -> void:
	print("CAPTURERUN note %s: %s" % [mode, text])


func _hooked(text: String) -> void:
	print("CAPTURERUN set %s: %s" % [mode, text])


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


# --- reading the run -------------------------------------------------------------------------------

func _refresh() -> bool:
	if shell.get("flow") != FLOW_RUN or shell.get("session") == null or shell.get("hud") == null or shell.get("island") == null:
		return false
	session = shell.get("session")
	island = shell.get("island")
	hud = shell.get("hud")
	return true


func _island_id() -> StringName:
	return (island.get("layout") as Object).get("id") if _refresh() else &""


func _my_body() -> Node2D:
	return session.call("body", session.multiplayer.get_unique_id()) as Node2D


func _body_of(peer: int) -> Node2D:
	return session.call("body", peer) as Node2D


func _keeper() -> Object:
	return session.get_node_or_null(^"CaptureScene")


func _creatures(id: StringName) -> Array[Node2D]:
	var found: Array[Node2D] = []
	var names: Array[String] = []
	for node: Node in session.get_node(^"Entities").get_children():
		var data: Object = node.get("data")
		if data != null and data.get("id") == id and not node.is_queued_for_deletion():
			names.append(String(node.name))
	names.sort()
	for creature_name: String in names:
		found.append(session.get_node(^"Entities").get_node(NodePath(creature_name)) as Node2D)
	return found


func _boat() -> Node2D:
	var boats := _creatures(&"patrol_boat")
	return boats[0] if not boats.is_empty() else null


func _center(cell: Vector2i) -> Vector2:
	return (Vector2(cell) + Vector2(0.5, 0.5)) * TILE


# Open beach nearest `near` (session pixels), not shaded.
func _sand_near(near: Vector2) -> Vector2:
	var terrain: Object = island.get("terrain")
	var best: Vector2 = Vector2(-1.0, -1.0)
	for cell: Vector2i in (terrain.get("cells") as Dictionary):
		if int(terrain.call("terrain_at", cell)) != BEACH or bool(terrain.call("is_shaded", cell)):
			continue
		if best.x < 0.0 or _center(cell).distance_to(near) < best.distance_to(near):
			best = _center(cell)
	return best


func _hut() -> Vector2:
	var cells: Array = (island.get("built") as Object).get("hut_cells")
	return _center(cells[cells.size() / 2])


# --- the host ---------------------------------------------------------------------------------------------

func _host() -> void:
	shell.call("start_host")
	session = shell.get("session")
	if not _check("start_host opened port %d and built the session" % PORT, session != null and not (session.multiplayer.multiplayer_peer is OfflineMultiplayerPeer)):
		return
	print("CAPTURERUN host listening %d" % ((session.multiplayer.multiplayer_peer as ENetMultiplayerPeer).host.get_local_port()))
	if not await _wait_for("the client in the lobby", func() -> bool: return (session.get("roster") as Dictionary).size() > 1, LAND_TIMEOUT_S):
		return
	await _seconds(1.0)
	_check("begin_run started the run", session.call("begin_run") == true)
	if not await _wait_for("the run on the sandbar", func() -> bool: return _refresh() and _my_body() != null and _boat() != null, 30.0):
		return
	for peer: int in session.call("peer_ids"):
		if peer != 1:
			client_peer = peer
	_check("host: the client has a body here", _body_of(client_peer) != null, "peer %d" % client_peer)
	var spawner: Object = session.get_node(^"Creatures")
	_night("the squad's flashlights")
	spawner.call("apply_phase", root.get_node(^"WeatherManager").call("phase"))
	if not await _wait_for("the client ready (crouching)", func() -> bool: return bool(((_body_of(client_peer) as Object).get("intent") as Object).get("crouch")), 120.0):
		return
	await _squad_lands()
	await _capture_and_free()
	await _whole_party()


# 1. The client's player spotted on open sand: the boat docks and the squad lands.
func _squad_lands() -> void:
	var boat: Node2D = _boat()
	var brain: Object = boat.get("brain")
	var patrol: Object = (boat.get("data") as Object).get("patrol")
	brain.call("set_clock", float(patrol.get("horizon_warning_s")) + 10.0)
	boat.call("advance", 0.0)
	_hooked("the boat's clock 10 s into its lap")
	var me: Node2D = _my_body()
	me.global_position = _hut()
	_hooked("the host's player put in the hut (roofed: hidden)")
	var client_body: Node2D = _body_of(client_peer)
	client_body.global_position = _sand_near(boat.position)
	_hooked("the client's player put on the open sand nearest the boat")
	brain.call("spot", client_body, &"sight")
	_hooked("the boat's spot of the client's player (PatrolRoute.spot, as a full spot meter calls it)")
	_check("host: the boat docks for a land alert", int(boat.get("state_id")) == DOCKED)
	if not await _wait_for("the squad ashore", func() -> bool: return int(boat.get("squad_state")) == ASHORE, 30.0):
		return
	await _frames(10)
	_check("host: three soldiers stepped ashore", _creatures(&"shore_soldier").size() == 3, "%d" % _creatures(&"shore_soldier").size())
	_check("host: the landing call showed over a soldier", int((boat.get_node(^"SquadLook") as Object).get("calls_shown")) >= 1)


# 2. A soldier captures the client's player and seats them; the host's player frees them.
func _capture_and_free() -> void:
	var boat: Node2D = _boat()
	var client_body: Node2D = _body_of(client_peer)
	var soldier: Node2D = _creatures(&"shore_soldier")[0]
	soldier.position = client_body.global_position + Vector2(-0.5 * TILE, 0.0)
	(soldier.get("brain") as Object).call("spot", soldier, client_body)
	_hooked("a soldier put beside the client's player and spotting them")
	if not await _wait_for("the client's player captured", func() -> bool: return bool(client_body.get("captive")), 20.0):
		return
	_check("host: the client's player is a captive", bool(client_body.get("captive")))
	var brain: Object = boat.get("brain")
	if not await _wait_for("the captive seated in the dinghy", func() -> bool: return (brain.get("seated") as Array).has(client_body), 60.0):
		return
	_check("host: the captive sits in the dinghy on the landing", client_body.global_position.distance_to(_center(boat.get("landing"))) < 1.0)
	var away: Vector2 = _hut()
	for each: Node2D in _creatures(&"shore_soldier"):
		each.set_physics_process(false)
		each.position = away + Vector2(randf_range(-2.0, 2.0), 0.0) * TILE
	_hooked("the soldiers held still by the hut, far from the dinghy")
	_my_body().global_position = client_body.global_position + Vector2(0.6 * TILE, 0.0)
	_hooked("the host's player put beside the captive")
	await _frames(5)
	Input.action_press(&"interact")
	if not await _wait_for("the captive freed", func() -> bool: return not bool(client_body.get("captive")), 5.0):
		Input.action_release(&"interact")
		return
	Input.action_release(&"interact")
	_check("host: the host's 1 s hold freed the client's player", not bool(client_body.get("captive")))
	# The soldiers stay held: the next step catches the whole party itself.
	await _seconds(2.0)


# 3 and 4. Both players captured: la_captura plays on both, then the restart on the sandbar.
func _whole_party() -> void:
	var rules: GDScript = load(RULES_PATH)
	var boat: Node2D = _boat()
	var patrol: Object = (boat.get("data") as Object).get("patrol")
	var before: int = island.get_instance_id()
	for peer: int in session.call("peer_ids"):
		rules.call("capture", _body_of(peer), _body_of(peer), patrol)
	_keeper().call("on_captured", _my_body(), boat)
	_hooked("both players captured (CaptureRules.capture, as a soldier's 2 s touch does)")
	if not await _wait_for("la_captura on the host", func() -> bool: return bool(_keeper().get("playing")), 5.0):
		return
	var lines: Array[String] = []
	var serial: int = 0
	while bool(_keeper().get("playing")):
		if int(_keeper().get("current_serial")) != serial:
			serial = int(_keeper().get("current_serial"))
			lines.append(String(_keeper().get("current_line_id")))
		await physics_frame
	_check("host: la_captura played to its end", lines.size() >= 4, ", ".join(lines))
	_check("host: two players hear the plural", lines.has("captura_open_plural_1"))
	print("CAPTURERUN lines host: %s" % ", ".join(lines))
	if not await _wait_for("the restart", func() -> bool: return _refresh() and island.get_instance_id() != before and _island_id() == &"sandbar", 20.0):
		return
	await _frames(10)
	_check("host: both players landed on the sandbar again", not bool(_my_body().get("left_island")) and not bool(_body_of(client_peer).get("left_island")))
	_check("host: neither is a captive", not bool(_my_body().get("captive")) and not bool(_body_of(client_peer).get("captive")))
	await _seconds(3.0)


# --- the client --------------------------------------------------------------------------------------

func _client() -> void:
	shell.call("_join", "127.0.0.1", PORT)
	if not await _wait_for("the run", func() -> bool: return _refresh() and _my_body() != null and _boat() != null, 120.0):
		_check("the client joined and entered the run", false)
		return
	_check("the client joined and entered the run", true)
	_night("the client's own sky")
	Input.action_press(&"crouch")
	_hooked("crouch held (the host reads it as the client's ready)")
	# 1. The squad lands.
	if not await _wait_for("the squad ashore", func() -> bool: return _boat() != null and int(_boat().get("squad_state")) == ASHORE and _creatures(&"shore_soldier").size() == 3, 90.0):
		return
	await _frames(20)
	_check("client: the dinghy is on the beach and three soldiers are ashore", int(_boat().get("squad_state")) == ASHORE and _creatures(&"shore_soldier").size() == 3)
	var squad_look: Object = _boat().get_node(^"SquadLook")
	_check("client: the dinghy is drawn on the landing", bool(squad_look.get("dinghy_visible")))
	# 2. Captured and freed.
	var me: Node2D = _my_body()
	if not await _wait_for("my player captured", func() -> bool: return bool(_my_body().get("captive")), 60.0):
		return
	await _frames(5)
	_check("client: the rope mark shows over my captive player", bool((hud.get("marks") as Object).call("has_rope", _my_body())))
	if not await _wait_for("my player freed", func() -> bool: return not bool(_my_body().get("captive")), 90.0):
		return
	await _frames(5)
	_check("client: my player stands free again, no rope mark", not bool(_my_body().get("captive")) and not bool((hud.get("marks") as Object).call("has_rope", _my_body())))
	# 3 and 4. The scene, the same lines, then the restart.
	var before: int = island.get_instance_id()
	if not await _wait_for("la_captura on the client", func() -> bool: return bool(_keeper().get("playing")), 60.0):
		return
	_check("client: my player is out of play during the scene", bool(_my_body().get("left_island")))
	var lines: Array[String] = []
	var serial: int = 0
	var panel_ok: bool = true
	while bool(_keeper().get("playing")):
		if int(_keeper().get("current_serial")) != serial and int(_keeper().get("current_serial")) > 0:
			serial = int(_keeper().get("current_serial"))
			lines.append(String(_keeper().get("current_line_id")))
			await _frames(2)
			var panel: Object = hud.get("scene_panel")
			panel_ok = panel_ok and bool(panel.get("visible")) and String(panel.call("shown_text")) == String(_keeper().call("current_text", "es"))
		await physics_frame
	print("CAPTURERUN lines client: %s" % ", ".join(lines))
	_check("client: la_captura played line by line in the scene panel", lines.size() >= 4 and panel_ok, "%d lines" % lines.size())
	_check("client: two players hear the plural", lines.has("captura_open_plural_1"))
	if not await _wait_for("the restart", func() -> bool: return _refresh() and island.get_instance_id() != before and _island_id() == &"sandbar" and not bool(_my_body().get("left_island")), 30.0):
		return
	_check("client: the restart landed my player on the sandbar", _island_id() == &"sandbar" and not bool(_my_body().get("left_island")))
	await _seconds(2.0)


func _finish() -> void:
	if done:
		return
	Input.action_release(&"crouch")
	Input.action_release(&"interact")
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
		print("CAPTURERUN engine error: ", text)
	for text: String in warnings:
		print("CAPTURERUN engine warning: ", text)
	_check("no engine or script errors logged (%s)" % mode, errors.is_empty(), "%d error(s), %d warning(s)" % [errors.size(), warnings.size()])
	print("CAPTURERUN summary %s: %d passed, %d failed" % [mode, passes, fails])
	quit(0 if fails == 0 else 1)
