extends SceneTree
## Manual two-process check for coop-rematch (coop-networking "Rematch with the same party"). It
## boots the real game shell on each side, through NetManager and ENet:
##   godot --headless --path game -s res://tests/manual/coop_rematch_run.gd -- --mode=host --port=7792
##   godot --headless --path game -s res://tests/manual/coop_rematch_run.gd -- --mode=client --port=7792
## The host (Yuni) starts the run once the client (Papo) is in the lobby, kills both players through
## the meters (the hook the GUT tests use), picks "Otra vez" on its summary and starts the new run
## once Papo is back in its lobby. While each run is on, the host writes its seed and its pick-up and
## creature counts to a file both processes share (user://, the same project), and Papo compares his
## own with them. Papo checks his summary's note, his new lobby, that his peer id and connection are
## the same, his kept look slot and the new seed. Each check prints "REMATCH PASS|FAIL <what>", and a
## failed check makes the run quit non-zero; the launcher also reads both logs for engine errors.
## Compiled before the autoloads exist, so it names no project class.

const SHELL_PATH: String = "res://scenes/shell/game_shell.tscn"
const STATE_PATH: String = "user://coop_rematch_run_state.cfg"
const FLOW_LOBBY: int = 2
const FLOW_RUN: int = 3
const FLOW_SUMMARY: int = 4
const HOST_ID: int = 1
const DEADLINE_S: float = 300.0
const WAITING_NOTE: String = "Esperando al anfitrión…"
const ROWS: Array[String] = ["Yuni (anfitrión)", "Papo"]

var mode: String = ""
var port: int = 7792
var shell: Node
var passes: int = 0
var fails: int = 0
var done: bool = false
# Host: which run the state file describes (1 or 2), 0 while no run is on.
var _writing_run: int = 0


func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--mode="):
			mode = arg.trim_prefix("--mode=")
		elif arg.begins_with("--port="):
			port = arg.trim_prefix("--port=").to_int()
	var settings_path: String = "user://coop_rematch_run_%s.cfg" % mode
	var config := ConfigFile.new()
	config.set_value("player", "name", "Papo" if mode == "client" else "Yuni")
	config.set_value("display", "fullscreen", false)
	config.set_value("display", "ui_scale", 2)
	config.set_value("display", "pixel_filter", 0)
	config.save(settings_path)
	if mode == "host" and FileAccess.file_exists(STATE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(STATE_PATH))
	shell = (load(SHELL_PATH) as PackedScene).instantiate()
	shell.set("settings_path", settings_path)
	root.add_child(shell)
	create_timer(DEADLINE_S).timeout.connect(_on_deadline)
	_main()


func _main() -> void:
	await process_frame
	await process_frame
	print("REMATCH coop_rematch_run mode %s, port %d, pid %d" % [mode, port, OS.get_process_id()])
	if mode == "host":
		await _host()
	elif mode == "client":
		await _client()
	else:
		_check("known mode", false, mode)
	_finish()


func _host() -> void:
	shell.set("port", port)
	shell.call("start_host")
	var request: Object = shell.get("_request")
	var session: Node = shell.get("session")
	if not _check("start_host opened port %d" % port, session != null and not (session.multiplayer.multiplayer_peer is OfflineMultiplayerPeer)):
		return
	if not await _wait_for("Papo in the lobby", func() -> bool: return (session.get("roster") as Dictionary).size() > 1, 120.0):
		return
	await _seconds(1.0)
	_check("begin_run started the run", session.call("begin_run") == true)
	if not await _wait_for("both bodies", func() -> bool: return (session.call("peer_ids") as Array).size() == 2, 30.0):
		return
	var papo_id: int = _other_peer(session)
	var papo_look: int = (session.call("body", papo_id) as Node).get("look_slot")
	var old_seed: int = (session.get("world_state") as Dictionary).get("run_seed", 0)
	_write_state(1)
	await _seconds(4.0)
	_writing_run = 0
	for id: int in session.call("peer_ids"):
		((session.call("body", id) as Node).get("meters") as Object).set("dead", true)
	print("REMATCH set both players dead on the host")
	if not await _wait_for("the host's summary", func() -> bool: return shell.get("flow") == FLOW_SUMMARY, 10.0):
		return
	var summary: Node = shell.get("screen")
	var restart: Button = summary.get("restart_button")
	_check("the host's summary offers Otra vez", restart.visible and restart.text == "Otra vez")
	_check("with the focus", restart.has_focus())
	# Papo needs a moment on his summary to check its note.
	await _seconds(3.0)
	restart.pressed.emit()
	print("REMATCH the host picked Otra vez")
	_check("the host's lobby shows", shell.get("flow") == FLOW_LOBBY)
	_check("NetManager was asked for nothing", shell.get("_request") == request)
	session = shell.get("session")
	var back := func() -> bool:
		var lobby: Node = shell.get("screen")
		return lobby != null and lobby.has_method("rows") and lobby.call("rows") == ROWS
	if not await _wait_for("Papo back in the host's lobby", back, 10.0):
		return
	_check("Papo is back under the same peer id", (session.get("roster") as Dictionary).has(papo_id))
	await _seconds(1.0)
	_check("begin_run started the new run", session.call("begin_run") == true)
	if not await _wait_for("both bodies again", func() -> bool: return (session.call("peer_ids") as Array).size() == 2, 30.0):
		return
	_check("Papo keeps his look slot %d" % papo_look, (session.call("body", papo_id) as Node).get("look_slot") == papo_look)
	var new_seed: int = (session.get("world_state") as Dictionary).get("run_seed", 0)
	_check("a new run seed", new_seed != old_seed, "%d then %d" % [old_seed, new_seed])
	_write_state(2)
	await _wait_for("Papo to finish", func() -> bool: return session.multiplayer.get_peers().is_empty(), 60.0)
	_writing_run = 0


func _client() -> void:
	shell.call("_join", "127.0.0.1", port)
	if not await _wait_for("the run", func() -> bool: return shell.get("flow") == FLOW_RUN, 120.0):
		return
	var session: Node = shell.get("session")
	var me: int = session.multiplayer.get_unique_id()
	var connection_id: int = session.multiplayer.multiplayer_peer.get_instance_id()
	if not await _wait_for("both bodies", func() -> bool: return session.call("body", me) != null and session.call("body", HOST_ID) != null, 30.0):
		return
	var look: int = (session.call("body", me) as Node).get("look_slot")
	var old_seed: int = (session.get("world_state") as Dictionary).get("run_seed", 0)
	await _counts_match("the first run", session, old_seed)
	if not await _wait_for("the client's summary", func() -> bool: return shell.get("flow") == FLOW_SUMMARY, 60.0):
		return
	var summary: Node = shell.get("screen")
	_check("no Otra vez on a client's summary", not (summary.get("restart_button") as Button).visible)
	var note: Label = summary.get("note")
	_check("the note reads '%s'" % WAITING_NOTE, note.visible and note.text == WAITING_NOTE, note.text)
	var old_session: int = session.get_instance_id()
	var new_lobby := func() -> bool:
		var now: Node = shell.get("session")
		return shell.get("flow") == FLOW_LOBBY and now != null and now.get_instance_id() != old_session
	if not await _wait_for("the new lobby", new_lobby, 30.0):
		return
	# The host's answer replaces the lobby shown at once, so read the screen each time.
	var listed := func() -> bool:
		var lobby: Node = shell.get("screen")
		return lobby != null and lobby.has_method("rows") and lobby.call("rows") == ROWS
	if not await _wait_for("both names in the new lobby", listed, 10.0):
		return
	session = shell.get("session")
	_check("the same peer id", session.multiplayer.get_unique_id() == me)
	_check("the same connection", session.multiplayer.multiplayer_peer.get_instance_id() == connection_id)
	if not await _wait_for("the new run", func() -> bool: return shell.get("flow") == FLOW_RUN and shell.get("hud") != null, 60.0):
		return
	if not await _wait_for("both bodies again", func() -> bool: return session.call("body", me) != null and session.call("body", HOST_ID) != null, 30.0):
		return
	_check("Papo keeps his look slot %d" % look, (session.call("body", me) as Node).get("look_slot") == look)
	var new_seed: int = (session.get("world_state") as Dictionary).get("run_seed", 0)
	_check("a new run seed", new_seed != old_seed, "%d then %d" % [old_seed, new_seed])
	await _counts_match("the new run", session, new_seed)


# Client: waits until this peer's pick-up and creature counts equal the ones the host wrote for the
# run with `run_seed`.
func _counts_match(what: String, session: Node, run_seed: int) -> void:
	var detail: Array[String] = [""]
	var matched := func() -> bool:
		var state := ConfigFile.new()
		if state.load(STATE_PATH) != OK or state.get_value("run", "seed", -1) != run_seed:
			detail[0] = "no host line for seed %d" % run_seed
			return false
		var pickups: int = (session.get("pickups") as Node).get_child_count()
		var entities: int = (session.get("entities") as Node).get_child_count()
		detail[0] = "pick-ups %d of %d, creatures %d of %d" % [pickups, state.get_value("run", "pickups", -1), entities, state.get_value("run", "entities", -1)]
		return pickups == state.get_value("run", "pickups", -1) and entities == state.get_value("run", "entities", -1)
	var ok: bool = await _wait_for("%s's pick-ups and creatures to match the host's" % what, matched, 15.0)
	if ok:
		_check("%s: the host's pick-ups and creatures" % what, true, detail[0])
	else:
		print("REMATCH last seen: %s" % detail[0])


# Host: keeps the state file current while run `run` is on: its seed and its counts.
func _write_state(run: int) -> void:
	_writing_run = run
	while _writing_run == run and not done:
		var session: Node = shell.get("session")
		if session != null:
			var state := ConfigFile.new()
			state.set_value("run", "number", run)
			state.set_value("run", "seed", (session.get("world_state") as Dictionary).get("run_seed", 0))
			state.set_value("run", "pickups", (session.get("pickups") as Node).get_child_count())
			state.set_value("run", "entities", (session.get("entities") as Node).get_child_count())
			state.save(STATE_PATH)
		await _seconds(0.25)


func _other_peer(session: Node) -> int:
	for peer_id: int in session.call("peer_ids"):
		if peer_id != HOST_ID:
			return peer_id
	return 0


func _check(label: String, ok: bool, detail: String = "") -> bool:
	if ok:
		passes += 1
	else:
		fails += 1
	print("REMATCH %s %s: %s%s" % ["PASS" if ok else "FAIL", mode, label, (" | " + detail) if not detail.is_empty() else ""])
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
	print("REMATCH done %s: %d passed, %d failed" % [mode, passes, fails])
	shell.call("back_to_title")
	quit(1 if fails > 0 else 0)
