extends Node
## Manual host-and-client check for creature-perch-ride task 5.3 (design.md D10), as two processes
## over ENet. Each builds a session and the sandbar as the net tests do, with the fixture creatures.
## The host launches a crossing for its own player and rolls its creatures as if it left a
## final-family island (the hook that stands in for a final island until one exists), so the
## galleguito lands on the host player's head; then it walks its player across the deck and back.
## The client joins mid-crossing and checks, frame by frame, that it draws the galleguito on the
## host player's head, facing the way it draws that player. Both default to UDP port 7786:
##   godot --headless --path game res://tests/manual/perch_ride_run.tscn -- --mode=host [--port=<n>]
##   godot --headless --path game res://tests/manual/perch_ride_run.tscn -- --mode=client [--port=<n>]
## Each check prints "PERCHRUN PASS|FAIL <what> | <detail>"; a run quits non-zero on a fail.

const ISLAND_SCENE: PackedScene = preload("res://scenes/levels/sandbar_island.tscn")
const SESSION_SCENE: PackedScene = preload("res://scenes/net/coop_session.tscn")
const FIXTURES: String = "res://tests/fixtures/content"
const GULL: StringName = &"galleguito_prueba"
const DEFAULT_PORT: int = 7786
const DEADLINE_S: float = 90.0
## The host walks right for this long, waits, walks back, waits, and so on.
const WALK_S: float = 0.4
const REST_S: float = 1.0
## The client watches this long once the gull is drawn.
const WATCH_S: float = 8.0
## Float slack for "on the head".
const SLACK_PX: float = 0.01

var mode: String = "host"
var port: int = DEFAULT_PORT
var session: CoopSession
var island: SandbarIsland
var crossing: Crossing
var passes: int = 0
var fails: int = 0
var _elapsed_s: float = 0.0
var _done: bool = false
# Client: what the frame-by-frame watch saw.
var _watching: bool = false
var _gull_look: CreatureLook = null
var _rider: PlayerBody = null
var _frames: int = 0
var _off_head: int = 0
var _worst_px: float = 0.0
var _faced: Dictionary[int, bool] = {}
var _mismatched_facing: int = 0


func _ready() -> void:
	# Last of every frame, so the client's watch reads the frame as drawn.
	process_priority = 1000
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--mode="):
			mode = arg.trim_prefix("--mode=")
		elif arg.begins_with("--port="):
			port = arg.trim_prefix("--port=").to_int()
	print("PERCHRUN perch_ride_run mode %s port %d pid %d" % [mode, port, OS.get_process_id()])
	WeatherManager.stop()
	WeatherManager.sky.start_at(0.0)
	island = ISLAND_SCENE.instantiate() as SandbarIsland
	island.with_creatures = false
	add_child(island)
	session = SESSION_SCENE.instantiate() as CoopSession
	add_child(session)
	session.terrain = island.terrain
	session.climate = island.climate
	session.spawn_points = island.spawn_points(false)
	session.creature_catalog = ContentCatalog.new(FIXTURES)
	session.local_name = "Yuni" if mode == "host" else "Papo"
	island.furnish(session)
	if mode == "host":
		_host()
	elif mode == "client":
		_client()
	else:
		_check("known mode", false, mode)
		_finish()


func _process(delta: float) -> void:
	_elapsed_s += delta
	if _watching:
		_watch()
	if not _done and _elapsed_s >= DEADLINE_S:
		_check("finished before the %d s deadline" % int(DEADLINE_S), false)
		_finish()


func _check(label: String, ok: bool, detail: String = "") -> bool:
	if ok:
		passes += 1
	else:
		fails += 1
	print("PERCHRUN %s %s: %s | %s" % ["PASS" if ok else "FAIL", mode, label, detail])
	return ok


func _finish() -> void:
	if _done:
		return
	_done = true
	print("PERCHRUN %s done: %d passed, %d failed" % [mode, passes, fails])
	session.queue_free()
	await get_tree().process_frame
	NetManager.leave()
	get_tree().quit(1 if fails > 0 else 0)


func _wait(condition: Callable, limit_s: float) -> bool:
	var left: float = limit_s
	while not condition.call() and left > 0.0:
		await get_tree().process_frame
		left -= get_process_delta_time()
	return condition.call()


func _gull() -> Creature:
	for child: Node in session.entities.get_children():
		var creature := child as Creature
		if creature != null and creature.data.id == GULL and not creature.is_queued_for_deletion():
			return creature
	return null


# --- host ---------------------------------------------------------------------------------------

func _host() -> void:
	if not _check("listening", NetManager.host(port) == OK, "udp %d" % port):
		_finish()
		return
	session.start()
	var me := session.body(CoopSession.HOST_ID)
	me.player_input.enabled = false
	var route := GameState.content.get_entry(&"routes", &"raft") as RouteData
	crossing = Crossing.launch(session, route, [CoopSession.HOST_ID] as Array[int], 100.0, DataEnums.DistanceBand.COAST, RandomNumberGenerator.new())
	crossing.plan = CrossingPlan.create(DEADLINE_S * 2.0)
	var riders := CrossingCreatures.attach(crossing, DataEnums.ChainFamily.FINAL, DataEnums.DistanceBand.COAST)
	_check("the final crossing places the galleguito", riders != null and _gull() != null)
	var perched := await _wait(func() -> bool: return _gull() != null and _gull().state_name() == &"PERCH", 20.0)
	if not _check("it lands on the host player's head", perched and _gull().perch_peer == CoopSession.HOST_ID):
		_finish()
		return
	print("PERCHRUN host waiting for a client on udp %d" % port)
	var joined := await _wait(func() -> bool: return session.peer_ids().size() > 1, 45.0)
	if not _check("a client joined mid-crossing", joined, str(session.peer_ids())):
		_finish()
		return
	var client_id: int = session.peer_ids()[1]
	while session.multiplayer.get_peers().has(client_id) and not _done:
		for direction: Vector2 in [Vector2.RIGHT, Vector2.LEFT]:
			me.intent = MoveIntent.create(direction)
			await get_tree().create_timer(WALK_S).timeout
			me.intent = MoveIntent.new()
			await get_tree().create_timer(REST_S).timeout
			if not session.multiplayer.get_peers().has(client_id):
				break
		var gull := _gull()
		_check("still on the host player's head between walks", gull != null and gull.state_name() == &"PERCH" and gull.perch_peer == CoopSession.HOST_ID)
	_check("the vessel untouched", crossing.integrity.value == 100.0, str(crossing.integrity.value))
	_finish()


# --- client -------------------------------------------------------------------------------------

func _client() -> void:
	if not _check("connecting", NetManager.join("127.0.0.1", port) == OK, "127.0.0.1:%d" % port):
		_finish()
		return
	session.start()
	var host_body := func() -> bool: return session.body(CoopSession.HOST_ID) != null
	if not _check("the host's player is here", await _wait(host_body, 20.0)):
		_finish()
		return
	var seen := func() -> bool: return _gull() != null and _gull().perch_peer == CoopSession.HOST_ID
	if not _check("the galleguito arrives perched on the host's player", await _wait(seen, 20.0)):
		_finish()
		return
	_gull_look = _gull().get_node(^"Look") as CreatureLook
	_rider = session.body(CoopSession.HOST_ID)
	_watching = true
	await get_tree().create_timer(WATCH_S).timeout
	_watching = false
	_check("drawn on the host player's head every frame", _off_head == 0, "%d frames, %d off, worst %.2f px" % [_frames, _off_head, _worst_px])
	_check("the host player walked both ways", _faced.size() == 2, str(_faced.keys()))
	_check("it faces the way the host player faces", _mismatched_facing == 0, "%d frames mismatched" % _mismatched_facing)
	_finish()


# Client: one frame's look at the gull, after every other node has processed this frame.
func _watch() -> void:
	if not is_instance_valid(_gull_look) or not is_instance_valid(_rider):
		_off_head += 1
		return
	_frames += 1
	var gap: float = _gull_look.global_position.distance_to(_rider.global_position + Vector2(0.0, CreatureLook.PERCH_SORT_PX))
	_worst_px = maxf(_worst_px, gap)
	if gap > SLACK_PX:
		_off_head += 1
	var dir: int = (_rider.get_node(^"Look") as PlayerLook).facing.dir
	if dir == Facing.Dir.LEFT or dir == Facing.Dir.RIGHT:
		_faced[dir] = true
		if (_gull_look.get_node(^"Sprite") as AnimatedSprite2D).flip_h != (dir == Facing.Dir.LEFT):
			_mismatched_facing += 1
