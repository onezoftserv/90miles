extends SceneTree
## Manual two-process check for bleeding-and-sabila (survival-meters "Bleeding drains health",
## "Bleeding stops on its own"; crafting-inventory "Sábila on a teammate"; inventory-hud "Who a cure
## goes to"). It boots the real game shell on each side:
##   godot --headless --path game -s res://tests/manual/bleeding_run.gd -- --mode=host --port=7795
##   godot --headless --path game -s res://tests/manual/bleeding_run.gd -- --mode=client --port=7795
## The host (Yuni) starts the run once the client (Papo) is in the lobby. Then:
## 1. A shark's bite on Papo (host meters): 25 and bleeding. Papo's bleeding is shortened to 8 s on
##    the host so the end is seen here (the 120 s is tested on plain meters). Papo checks he bleeds,
##    the "Sangrando" tag shows, he never holds the time, his health falls by the drain, and the
##    bleeding and the tag end. The host checks the drain ran and the bleeding ended.
## 2. Yuni bleeds at 50 health beside Papo, and Papo gets a sábila leaf. Papo selects it, checks his
##    item line names Yuni ("Untar: Yuni"), and holds F. The host checks Yuni stopped bleeding with
##    +5 and Papo's leaf is gone; Papo checks he sees Yuni stop bleeding.
## Each check prints "BLEED PASS|FAIL <mode>: <what> | <detail>", and a failed check makes the run
## quit non-zero. Compiled before the autoloads exist, so it names no project class.

const SHELL_PATH: String = "res://scenes/shell/game_shell.tscn"
const FLOW_RUN: int = 3
const HOST_ID: int = 1
const BLEEDING_BIT: int = 1 << 1
const DEADLINE_S: float = 300.0
const SHORT_BLEED_S: float = 8.0
const USE_ACTION: StringName = &"use_item"

var mode: String = ""
var port: int = 7795
var shell: Node
var passes: int = 0
var fails: int = 0
var done: bool = false


func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--mode="):
			mode = arg.trim_prefix("--mode=")
		elif arg.begins_with("--port="):
			port = arg.trim_prefix("--port=").to_int()
	var settings_path: String = "user://bleeding_run_%s.cfg" % mode
	var config := ConfigFile.new()
	config.set_value("player", "name", "Papo" if mode == "client" else "Yuni")
	config.set_value("display", "fullscreen", false)
	config.set_value("display", "ui_scale", 2)
	config.set_value("display", "pixel_filter", 0)
	config.save(settings_path)
	shell = (load(SHELL_PATH) as PackedScene).instantiate()
	shell.set("settings_path", settings_path)
	root.add_child(shell)
	create_timer(DEADLINE_S).timeout.connect(_on_deadline)
	_main()


func _main() -> void:
	await process_frame
	await process_frame
	print("BLEED bleeding_run mode %s, port %d, pid %d" % [mode, port, OS.get_process_id()])
	if mode == "host":
		await _host()
	elif mode == "client":
		await _client()
	else:
		_check("known mode", false, mode)
	_finish()


func _bleeds(meters: Object) -> bool:
	return (int(meters.get("status_flags")) & BLEEDING_BIT) != 0


func _slot_of(body: Node, item_id: StringName) -> int:
	var slots: Array = (body.get("inventory") as Object).get("slots")
	for i: int in slots.size():
		if (slots[i] as Object).get("item_id") == item_id:
			return i
	return -1


func _host() -> void:
	shell.set("port", port)
	shell.call("start_host")
	var session: Node = shell.get("session")
	if not _check("start_host opened port %d" % port, session != null and not (session.multiplayer.multiplayer_peer is OfflineMultiplayerPeer)):
		return
	if not await _wait_for("Papo in the lobby", func() -> bool: return (session.get("roster") as Dictionary).size() > 1, 120.0):
		return
	await _seconds(1.0)
	_check("begin_run started the run", session.call("begin_run") == true)
	if not await _wait_for("both bodies", func() -> bool: return shell.get("flow") == FLOW_RUN and (session.call("peer_ids") as Array).size() == 2, 30.0):
		return
	await _seconds(3.0)
	var client_id: int = 0
	for peer_id: int in session.call("peer_ids"):
		if peer_id != HOST_ID:
			client_id = peer_id
	var yuni: Node = session.call("body", HOST_ID)
	var papo: Node = session.call("body", client_id)
	var papo_meters: Object = papo.get("meters")
	var yuni_meters: Object = yuni.get("meters")
	# 1. A shark's bite on Papo, with his bleeding shortened to 8 s.
	var tuning: Resource = (papo_meters.get("tuning") as Resource).duplicate()
	tuning.set("bleeding_s", SHORT_BLEED_S)
	papo_meters.set("tuning", tuning)
	papo_meters.call("harm", 25.0, &"reef_shark")
	papo_meters.call("set_status", 1, true)
	print("BLEED step 1: a shark bit Papo")
	_check("Papo bleeds on the host", _bleeds(papo_meters))
	if not await _wait_for("Papo's bleeding to end", func() -> bool: return not _bleeds(papo_meters), SHORT_BLEED_S + 4.0):
		return
	var health: float = papo_meters.get("health")
	_check("the drain ran on the host: about 0.8 in 8 s", health < 74.5 and health > 73.5, str(health))
	await _seconds(3.0)
	# 2. Yuni bleeds beside Papo, who gets a sábila leaf.
	yuni_meters.set("health", 50.0)
	yuni_meters.call("set_status", 1, true)
	(yuni as Node2D).global_position = (papo as Node2D).global_position + Vector2(8.0, 0.0)
	(papo.get("inventory") as Object).call("add", &"aloe", 1)
	print("BLEED step 2: Yuni bleeds beside Papo, who has sábila")
	if not await _wait_for("Papo's sábila on Yuni", func() -> bool: return not _bleeds(yuni_meters), 60.0):
		return
	var yuni_health: float = yuni_meters.get("health")
	_check("Yuni gained 5", yuni_health > 54.0 and yuni_health <= 55.0, str(yuni_health))
	_check("Papo's leaf is gone on the host", _slot_of(papo, &"aloe") == -1)
	_check("Papo's own health did not change", absf(float(papo_meters.get("health")) - health) < 0.5, str(papo_meters.get("health")))
	# The client needs the last state before the host goes away.
	await _seconds(4.0)


func _client() -> void:
	shell.call("_join", "127.0.0.1", port)
	if not await _wait_for("the run", func() -> bool: return shell.get("flow") == FLOW_RUN, 120.0):
		return
	var session: Node = shell.get("session")
	var me: int = session.multiplayer.get_unique_id()
	if not await _wait_for("both bodies", func() -> bool: return session.call("body", me) != null and session.call("body", HOST_ID) != null, 30.0):
		return
	var own: Node = session.call("body", me)
	var yuni: Node = session.call("body", HOST_ID)
	var hud: Node = shell.get("hud")
	var meters_hud: Object = hud.get("meters")
	var strip: Object = hud.get("strip")
	var own_meters: Object = own.get("meters")
	var yuni_meters: Object = yuni.get("meters")
	# 1. Papo bleeds, sees it drain, and sees it end.
	if not await _wait_for("Papo's bite", func() -> bool: return _bleeds(own_meters), 60.0):
		return
	await process_frame
	var tag: Object = meters_hud.call("bleeding_tag")
	_check("the Sangrando tag shows on Papo's screen", tag.get("visible") == true)
	_check("Papo never holds the time, only the bit", float(own_meters.call("status_time_left", 1)) == 0.0)
	_check("Papo's health falls by the drain", await _wait_for("the drain", func() -> bool: return float(own_meters.get("health")) < 74.9, 15.0))
	if not await _wait_for("the bleeding's end", func() -> bool: return not _bleeds(own_meters), 20.0):
		return
	await process_frame
	_check("the Sangrando tag hides when it ends", tag.get("visible") == false)
	# 2. Papo treats Yuni with the use button.
	var ready := func() -> bool:
		return _slot_of(own, &"aloe") >= 0 and _bleeds(yuni_meters) \
			and (own as Node2D).global_position.distance_to((yuni as Node2D).global_position) <= 16.0
	if not await _wait_for("the leaf and Yuni bleeding beside Papo", ready, 30.0):
		return
	strip.call("select", _slot_of(own, &"aloe"))
	await _seconds(0.3)
	var line: String = (strip.get("item_line") as Label).text
	_check("Papo's item line names Yuni", line.contains("Untar: Yuni"), line)
	Input.action_press(USE_ACTION)
	await _seconds(1.5)
	Input.action_release(USE_ACTION)
	_check("Yuni stops bleeding on Papo's screen", await _wait_for("Yuni's cure", func() -> bool: return not _bleeds(yuni_meters), 10.0))
	_check("Papo's leaf is gone", await _wait_for("the leaf to go", func() -> bool: return _slot_of(own, &"aloe") == -1, 10.0))


func _check(label: String, ok: bool, detail: String = "") -> bool:
	if ok:
		passes += 1
	else:
		fails += 1
	print("BLEED %s %s: %s%s" % ["PASS" if ok else "FAIL", mode, label, (" | " + detail) if not detail.is_empty() else ""])
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
	print("BLEED done %s: %d passed, %d failed" % [mode, passes, fails])
	Input.action_release(USE_ACTION)
	shell.call("back_to_title")
	quit(1 if fails > 0 else 0)
