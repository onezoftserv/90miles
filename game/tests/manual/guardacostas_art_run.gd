extends SceneTree
## Manual two-process run for art-guardacostas task 6.3: a host and a client play the sandbar at night over
## ENet on UDP port 7803, and each checks what its own session draws of the coast guard. Run the host
## first, then the client, both headless (nothing here reads pixels):
##   godot --headless --path game -s res://tests/manual/guardacostas_art_run.gd -- --mode=host
##   godot --headless --path game -s res://tests/manual/guardacostas_art_run.gd -- --mode=client
## The host opens the lobby, starts the run once the client is in, sets the night clock and, once the
## client crouches (its "ready"), spots the client's player on open sand: the boat docks, its dinghy rows
## in and the squad of three lands. Each peer then checks its own drawing: the launch's sprite at the docked
## boat, the dinghy's DinghyLook beached on the landing cell, three soldier figures in three different
## looks (each GuardacostasArt's look for its node name), and the squad's call in a HUD call window. The
## client lets go of crouch when it is done. Then (art-guardacostas task 9.3) the host, holding a
## fosforera, and the client, holding only a coconut, are caught together: `la_captura` plays staged on
## both (the client sees the drain bar and no arrow), and after landing only the host's notice reads
## "Te quitaron: Fosforera". The client crouches again when it has checked, and the host waits for that
## before it leaves. Each check prints
## "GAARTRUN PASS|FAIL <what> | <detail>", the run quits non-zero on a fail, and "GAARTRUN engine error"
## lines list anything the engine or a script logged. Compiled before the autoloads exist, so it names no
## project class: duck typing throughout.

const SHELL_PATH: String = "res://scenes/shell/game_shell.tscn"
const ART_PATH: String = "res://assets/art/creatures/guardacostas_art.tres"
const RULES_PATH: String = "res://scripts/stealth/capture_rules.gd"
const NOTICE: String = "Te quitaron: Fosforera"
const PORT: int = 7803
const FLOW_RUN: int = 3
const TILE: float = 16.0
const BEACH: int = 3
const NIGHT_START_S: float = 430.0
const DEADLINE_S: float = 300.0
const DOCKED: int = 6
const ASHORE: int = 2
const CLIENT_NAME: String = "Papo"


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
var art: Resource = null
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
	var settings_path: String = "user://guardacostas_art_run_%s.cfg" % mode
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
	art = load(ART_PATH)
	create_timer(DEADLINE_S).timeout.connect(_on_deadline)
	_main()


func _main() -> void:
	await process_frame
	await process_frame
	print("GAARTRUN guardacostas_art_run mode %s, pid %d" % [mode, OS.get_process_id()])
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


func _check(label: String, ok: bool, detail: String = "") -> bool:
	if ok:
		passes += 1
	else:
		fails += 1
	print("GAARTRUN %s %s: %s%s" % ["PASS" if ok else "FAIL", mode, label, (" | " + detail) if not detail.is_empty() else ""])
	return ok


func _note(text: String) -> void:
	print("GAARTRUN note %s: %s" % [mode, text])


func _hooked(text: String) -> void:
	print("GAARTRUN set %s: %s" % [mode, text])


func _frames(count: int) -> void:
	for i: int in count:
		await physics_frame


func _seconds(seconds: float) -> void:
	await _frames(ceili(seconds * physics_hz))


func _wait_for(what: String, ready: Callable, timeout_s: float) -> bool:
	_note("waiting for %s (up to %.0f s)" % [what, timeout_s])
	for i: int in ceili(timeout_s * physics_hz):
		if ready.call():
			return true
		await physics_frame
	_check("timed out after %.0f s waiting for %s" % [timeout_s, what], false)
	return false


func _night() -> void:
	var sky: Object = root.get_node(^"WeatherManager").get("sky")
	sky.call("start_at", NIGHT_START_S)
	(sky.get("weather") as Object).set("rolls_enabled", false)
	_hooked("night clock to %.0f s, weather rolls off" % NIGHT_START_S)


func _refresh() -> bool:
	if shell.get("flow") != FLOW_RUN or shell.get("session") == null or shell.get("hud") == null or shell.get("island") == null:
		return false
	session = shell.get("session")
	island = shell.get("island")
	hud = shell.get("hud")
	return true


func _my_body() -> Node2D:
	return session.call("body", session.multiplayer.get_unique_id()) as Node2D


func _body_of(peer: int) -> Node2D:
	return session.call("body", peer) as Node2D


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


# What this peer draws of the docked boat, its dinghy and its squad, and its call windows.
func _check_drawing(who: String) -> void:
	var boat: Node2D = _boat()
	var patrol_look: Object = boat.get_node(^"PatrolLook")
	patrol_look.call("step", 0.0)
	var hull: Node = patrol_look.get("hull")
	_check("%s: the launch's sprite shows at the docked boat" % who, hull != null and bool(hull.get("visible")) and int(boat.get("state_id")) == DOCKED)
	var squad: Object = boat.get_node(^"SquadLook")
	squad.call("step", 0.0)
	var dinghy: Node2D = squad.get("dinghy")
	var landing: Vector2 = _center(boat.get("landing"))
	_check("%s: the dinghy lies beached on the landing cell" % who, dinghy != null and bool(dinghy.get("visible")) and dinghy.call("animation") == &"beached" and dinghy.global_position.is_equal_approx(landing), "%s at %s" % [dinghy.call("animation") if dinghy != null else "none", dinghy.global_position if dinghy != null else Vector2.ZERO])
	var looks: Array[StringName] = []
	var matched: bool = true
	for soldier: Node2D in _creatures(&"shore_soldier"):
		var look: Object = soldier.get_node(^"SquadLook")
		look.call("step", 0.0)
		var shown: Resource = look.get("soldier_look")
		var sprite: Node = look.get("soldier_sprite")
		if shown == null or sprite == null:
			matched = false
			continue
		looks.append(shown.get("id"))
		matched = matched and shown == art.call("soldier_look", String(soldier.name))
	var distinct: bool = looks.size() == 3 and looks[0] != looks[1] and looks[1] != looks[2] and looks[0] != looks[2]
	_check("%s: three soldier figures in three looks, each its node name's" % who, matched and distinct, ", ".join(looks))
	var windows: Object = hud.get("call_windows")
	var texts: PackedStringArray = []
	for i: int in int(windows.call("count")):
		texts.append(String(windows.call("text_of", i)))
	var calls_shown: int = int(windows.get("calls_shown"))
	_check("%s: the coast guard's calls showed in HUD call windows" % who, calls_shown >= 1, "%d shown; on show now: %s" % [calls_shown, " / ".join(texts)])


func _host() -> void:
	shell.call("start_host")
	session = shell.get("session")
	if not _check("start_host opened port %d" % PORT, session != null and not (session.multiplayer.multiplayer_peer is OfflineMultiplayerPeer)):
		return
	if not await _wait_for("the client in the lobby", func() -> bool: return (session.get("roster") as Dictionary).size() > 1, 120.0):
		return
	await _seconds(1.0)
	_check("begin_run started the run", session.call("begin_run") == true)
	if not await _wait_for("the run on the sandbar", func() -> bool: return _refresh() and _my_body() != null and _boat() != null, 30.0):
		return
	for peer: int in session.call("peer_ids"):
		if peer != 1:
			client_peer = peer
	_night()
	session.get_node(^"Creatures").call("apply_phase", root.get_node(^"WeatherManager").call("phase"))
	if not await _wait_for("the client ready (crouching)", func() -> bool: return bool(((_body_of(client_peer) as Object).get("intent") as Object).get("crouch")), 120.0):
		return
	var boat: Node2D = _boat()
	var brain: Object = boat.get("brain")
	var patrol: Object = (boat.get("data") as Object).get("patrol")
	brain.call("set_clock", float(patrol.get("horizon_warning_s")) + 10.0)
	boat.call("advance", 0.0)
	_my_body().global_position = _hut()
	var client_body: Node2D = _body_of(client_peer)
	client_body.global_position = _sand_near(boat.position)
	brain.call("spot", client_body, &"sight")
	_hooked("the boat 10 s into its lap spots the client's player on the sand nearest it; the host's player in the hut")
	if not await _wait_for("the squad ashore", func() -> bool: return int(boat.get("squad_state")) == ASHORE and _creatures(&"shore_soldier").size() == 3, 30.0):
		return
	await _frames(20)
	_check_drawing("host")
	await _wait_for("the client done (crouch released)", func() -> bool: return not bool(((_body_of(client_peer) as Object).get("intent") as Object).get("crouch")), 90.0)
	await _seconds(1.0)
	await _host_confiscation()


# 2. Both caught: the host holding a fosforera, the client a coconut. Only the host is told of a loss.
func _host_confiscation() -> void:
	var me: Node2D = _my_body()
	var them: Node2D = _body_of(client_peer)
	(me.get("meters") as Object).set("morale", 40.0)
	(me.get("inventory") as Object).call("add", &"lighter", 1)
	(them.get("inventory") as Object).call("add", &"coco", 1)
	_hooked("the host's player holds a fosforera at 40 morale; the client's a coconut")
	var keeper: Object = session.get_node(^"CaptureScene")
	var patrol: Object = ((_boat().get("data") as Object).get("patrol"))
	var rules: Script = load(RULES_PATH)
	for caught: Node2D in [me, them]:
		rules.call("capture", caught, me, patrol)
	keeper.call("queue_check")
	_hooked("both players captured (CaptureRules.capture), the whole-party check queued")
	if not await _wait_for("la_captura on the host", func() -> bool: return bool(keeper.get("playing")), 20.0):
		return
	await _frames(30)
	var stage: Object = hud.get("capture_stage")
	_check("host: the scene is staged (bars in, HUD hidden)", bool(stage.get("staged")) and bool(hud.get("staged")))
	var panel: Object = hud.get("scene_panel")
	_check("host: Rodríguez's portrait and no drain bar", panel.call("shown_portrait") != null and not bool(panel.call("drain_shown")))
	await _seconds(3.0)
	for i: int in 40:
		if not bool(keeper.get("playing")):
			break
		keeper.call("skip")
		await _frames(2)
	if not await _wait_for("the scene over and the party landed", func() -> bool: return _refresh() and not bool(keeper.get("playing")) and not bool(_my_body().get("left_island")), 30.0):
		return
	await _seconds(1.0)
	var notice: String = String((hud.get("notice") as Object).call("shown_text"))
	_check("host: the notice names the fosforera taken", notice == NOTICE, notice)
	_check("host: the fosforera is gone", int((_my_body().get("inventory") as Object).call("count_id", &"lighter")) == 0)
	await _wait_for("the client done again (crouching)", func() -> bool: return _body_of(client_peer) != null and bool(((_body_of(client_peer) as Object).get("intent") as Object).get("crouch")), 90.0)
	await _seconds(1.0)


func _client() -> void:
	shell.call("_join", "127.0.0.1", PORT)
	if not await _wait_for("the run", func() -> bool: return _refresh() and _my_body() != null and _boat() != null, 120.0):
		return
	_check("the client joined and entered the run", true)
	_night()
	Input.action_press(&"crouch")
	_hooked("crouch held (the host reads it as the client's ready)")
	if not await _wait_for("the squad ashore with the dinghy beached", func() -> bool: return _boat() != null and int(_boat().get("squad_state")) == ASHORE and float(_boat().get("dinghy_t")) >= 1.0 and _creatures(&"shore_soldier").size() == 3, 90.0):
		return
	await _frames(20)
	_check_drawing("client")
	Input.action_release(&"crouch")
	_hooked("crouch released (done)")
	# 2. Both caught: the client sees the staged scene with the drain bar, and no loss of its own.
	var keeper: Object = session.get_node(^"CaptureScene")
	if not await _wait_for("la_captura on the client", func() -> bool: return bool(keeper.get("playing")) and int(keeper.get("current_serial")) > 0, 60.0):
		return
	await _frames(30)
	var panel: Object = hud.get("scene_panel")
	_check("client: the scene is staged (bars in, HUD hidden)", bool((hud.get("capture_stage") as Object).get("staged")) and bool(hud.get("staged")))
	_check("client: a drain bar and no arrow (only the host skips)", bool(panel.call("drain_shown")) and not bool(panel.call("arrow_shown")) and not bool(panel.call("key_shown")))
	_check("client: the drain runs over the Spanish line's hold", absf(float(panel.call("hold_s")) - float(load("res://scripts/stealth/capture_scene.gd").call("hold_s", String(keeper.call("current_text", "es"))))) < 0.001)
	if not await _wait_for("the scene over and my player landed", func() -> bool: return _refresh() and not bool(keeper.get("playing")) and _my_body() != null and not bool(_my_body().get("left_island")), 90.0):
		return
	await _seconds(2.0)
	var notice: String = String((hud.get("notice") as Object).call("shown_text"))
	_check("client: no confiscation notice (nothing taken from me)", not notice.begins_with("Te quitaron"), notice)
	_check("client: my coconut is still mine", int((_my_body().get("inventory") as Object).call("count_id", &"coco")) == 1)
	Input.action_press(&"crouch")
	_hooked("crouch held again (done)")
	await _seconds(2.0)


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
		print("GAARTRUN engine error: ", text)
	for text: String in warnings:
		print("GAARTRUN engine warning: ", text)
	_check("no engine or script errors logged (%s)" % mode, errors.is_empty(), "%d error(s), %d warning(s)" % [errors.size(), warnings.size()])
	print("GAARTRUN summary %s: %d passed, %d failed" % [mode, passes, fails])
	quit(0 if fails == 0 else 1)
