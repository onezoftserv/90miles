extends Node
## Manual measurement of the client-to-host intent link (intent-throttle): a host and a client as
## two processes, the client walking a square by setting its intent directly, both logging once a
## second what the link does to the intents. Never in CI. Start the host first:
##   godot --headless --path game res://tests/manual/intent_link_probe.tscn -- --role=host --port=7788
##   godot --headless --path game res://tests/manual/intent_link_probe.tscn -- --role=client --port=7788
## For delay, jitter, loss or reordering, put tools/net/udp_relay.py between them: the relay on 7788,
## the host on --port=7789, the client still on --port=7788.
## Options (either role): --seconds=<s> measured time before quitting, --idle=<s> wait before
## hosting or joining, --stall-ms=<ms> --stall-at=<s> --stall-for=<s> block every frame of this
## process for that long in that window (a loaded machine), --transfer=ordered|unreliable|reliable
## the transfer mode this process sends submit_intent with, --tag=<x> a label on every line.
## --open-throttle keeps ENet's packet throttle open (deceleration 0) from the moment each end knows
## the link: the host on peer_connected, the client on connected_to_server. --throttle-accel=<n>
## sets the acceleration that goes with it (ENet's default is 2).
## Client only: --connect=<address>[:<port>] (default 127.0.0.1 and --port), --requests-hz=<n> reliable
## no-op requests a second to the probe on the host, as a player's pick-ups, crafts and chat do
## (they are what give ENet round-trip samples on the client's side; intents give none).
## Lines: "PROBE <tag> <role> t=<s> ..." once a second, then "PROBE <tag> <role> summary ...".
## Client fields: sent (intents predicted), pend (unacknowledged), lag (newest seq minus the host's
## ack, in frames, max), snaps (host states that moved the predicted body more than SNAP_PX),
## snap_max and snap_sum (px), thr (ENet packet throttle to the host, min of the second, of 32),
## rtt and rtt_var (ms), loss (ENet's packet loss estimate, %), fps.
## Host fields: arr (intents that reached the rate limits: the session's clock is wrapped to count
## them, and this client sends nothing else that reads it), recv (intents queued for the client's
## body), lim (arrived but refused: rate limits, or a seq not newer than the last), gaps (seqs never
## queued), stale (the longest wait between two queued intents, ms), sim (simulated seconds the
## queued intents carry), bucket (the lowest simulated-time tokens left in PeerLimits, ms), thr,
## rtt and fps as on the client.

const PLAYGROUND_SCENE: PackedScene = preload("res://scenes/dev/coop_playground.tscn")
const LOG_PREFIX: String = "PROBE"
## The client walks each side of a square for this long.
const WALK_LEG_S: float = 1.5
const WALK: Array[Vector2] = [Vector2.RIGHT, Vector2.DOWN, Vector2.LEFT, Vector2.UP]
## A host state that moves the predicted body further than this is a visible correction.
const SNAP_PX: float = 0.5
## Extra seconds past --idle and --seconds before the run quits however far it got.
const DEADLINE_SLACK_S: float = 20.0
const THROTTLE_INTERVAL_MS: int = 5000
const THROTTLE_ACCELERATION: int = 2
const TRANSFER_MODES: Dictionary = {
	"ordered": MultiplayerPeer.TRANSFER_MODE_UNRELIABLE_ORDERED,
	"unreliable": MultiplayerPeer.TRANSFER_MODE_UNRELIABLE,
	"reliable": MultiplayerPeer.TRANSFER_MODE_RELIABLE,
}


## Runs a callable every physics frame at a chosen priority.
class FrameHook:
	extends Node
	var hook: Callable

	func _physics_process(_delta: float) -> void:
		hook.call()


var role: String = ""
var port: int = 7788
var address: String = "127.0.0.1"
var connect_port: int = 0
var seconds: float = 45.0
var idle_s: float = 5.0
var stall_ms: int = 0
var stall_at_s: float = 0.0
var stall_for_s: float = 0.0
var open_throttle: bool = false
var transfer: String = "ordered"
var tag: String = "-"
var requests_hz: float = 0.0
var throttle_accel: int = THROTTLE_ACCELERATION

var playground: CoopPlayground
var session: CoopSession
var body: PlayerBody
var _peer_id: int = 0
var _start_us: int = 0
var _second: int = 0
var _walk_s: float = 0.0
var _last_pos: Vector2 = Vector2.ZERO
var _last_seq_seen: int = 0
var _last_arrival_us: int = 0
var _arrived: int = 0
var _request_left_s: float = 0.0
var _requests_seen: int = 0
var _done: bool = false
var _w: Dictionary = {}
var _total: Dictionary = {}


func _ready() -> void:
	_parse(OS.get_cmdline_user_args())
	if role != "host" and role != "client":
		_log("usage: --role=host|client (see the script's header)")
		get_tree().quit(2)
		return
	# Quits even if the link never comes up (a failed join reloads the scene, but not this timer).
	get_tree().create_timer(idle_s + seconds + DEADLINE_SLACK_S).timeout.connect(get_tree().quit.bind(3))
	_reset_window()
	_total = {"sent": 0, "arr": 0, "bucket_min": 250, "recv": 0, "gaps": 0, "snaps": 0, "snap_sum": 0.0, "snap_max": 0.0,
		"stale_max": 0, "thr_min": 32, "thr_low_s": 0, "lag_max": 0, "sim": 0.0}
	await get_tree().create_timer(idle_s).timeout
	playground = PLAYGROUND_SCENE.instantiate() as CoopPlayground
	add_child(playground)
	session = playground.session
	session.rpc_config(&"submit_intent", {
		"rpc_mode": MultiplayerAPI.RPC_MODE_ANY_PEER,
		"transfer_mode": TRANSFER_MODES.get(transfer, MultiplayerPeer.TRANSFER_MODE_UNRELIABLE_ORDERED),
		"call_local": true,
		"channel": 0,
	})
	session.player_spawned.connect(_on_player_spawned)
	if open_throttle:
		session.multiplayer.peer_connected.connect(_open_throttle)
		session.multiplayer.connected_to_server.connect(_open_throttle.bind(CoopSession.HOST_ID))
	if role == "host":
		playground.start({"mode": "host", "port": port})
	else:
		playground.start({"mode": "join", "address": address, "port": connect_port if connect_port > 0 else port})
	var before := FrameHook.new()
	before.hook = _before_net
	before.process_physics_priority = -7
	add_child(before)
	var after := FrameHook.new()
	after.hook = _after_body
	after.process_physics_priority = 50
	add_child(after)
	_log("started transfer=%s open_throttle=%s stall=%dms@%.0f+%.0fs requests=%.1f/s" % [transfer, open_throttle, stall_ms, stall_at_s, stall_for_s, requests_hz])


func _process(_delta: float) -> void:
	if _start_us == 0 or _done:
		return
	var elapsed: float = _elapsed_s()
	if stall_ms > 0 and elapsed >= stall_at_s and elapsed < stall_at_s + stall_for_s:
		OS.delay_msec(stall_ms)
	_w["frames"] += 1
	_sample_link()
	if int(elapsed) > _second:
		_flush_window()
		_second = int(elapsed)
	if elapsed >= seconds:
		_done = true
		_summary()
		get_tree().quit()


func _on_player_spawned(peer_id: int, spawned: PlayerBody) -> void:
	var local: int = session.multiplayer.get_unique_id()
	if role == "client" and peer_id == local:
		body = spawned
		_peer_id = peer_id
		body.player_input.enabled = false
		var sync := body.get_node(^"StateSync") as MultiplayerSynchronizer
		sync.synchronized.connect(_on_synchronized)
		_last_pos = body.position
		_start_us = Time.get_ticks_usec()
		_log("own body spawned as peer %d" % peer_id)
	elif role == "host" and peer_id != local and body == null:
		body = spawned
		_peer_id = peer_id
		session.clock = _counting_clock
		_start_us = Time.get_ticks_usec()
		_log("client body spawned as peer %d" % peer_id)


# Client: sets this frame's walk intent before PlayerNet predicts and sends it.
# Host: counts the client's intents queued since the last frame, before PlayerNet steps them.
func _before_net() -> void:
	if body == null or not is_instance_valid(body) or _done:
		return
	if role == "client":
		if requests_hz > 0.0:
			_request_left_s -= get_physics_process_delta_time()
			if _request_left_s <= 0.0:
				_request_left_s += 1.0 / requests_hz
				probe_request.rpc_id(CoopSession.HOST_ID)
		_walk_s += get_physics_process_delta_time()
		var leg: int = int(_walk_s / WALK_LEG_S) % WALK.size()
		body.intent = MoveIntent.create(WALK[leg], false, false, false)
		_w["sent"] += 1
		return
	var now_us: int = Time.get_ticks_usec()
	var limits: PeerLimits = session._limits.get(_peer_id)
	if limits != null:
		_w["bucket"] = mini(_w["bucket"], int(limits.sim_time._tokens * 1000.0))
	for pending: PendingIntent in body.net._queue:
		if pending.seq <= _last_seq_seen:
			continue
		if _last_seq_seen > 0 and pending.seq > _last_seq_seen + 1:
			_w["gaps"] += pending.seq - _last_seq_seen - 1
		_last_seq_seen = pending.seq
		_w["recv"] += 1
		_w["sim"] += pending.delta
		if _last_arrival_us > 0:
			_w["stale_max"] = maxi(_w["stale_max"], (now_us - _last_arrival_us) / 1000)
		_last_arrival_us = now_us


# Host: a client's reliable no-op request (only counted).
@rpc("any_peer", "call_remote", "reliable")
func probe_request() -> void:
	_requests_seen += 1


# Client: the predicted position at the end of the frame, to compare with the next host state.
func _after_body() -> void:
	if role == "client" and body != null and is_instance_valid(body):
		_last_pos = body.position


# Client: runs after PlayerNet reconciled to this host state.
func _on_synchronized() -> void:
	if _done or body == null:
		return
	var moved: float = _last_pos.distance_to(body.position)
	if moved > SNAP_PX:
		_w["snaps"] += 1
		_w["snap_sum"] += moved
		_w["snap_max"] = maxf(_w["snap_max"], moved)
	_last_pos = body.position
	var buffer: PredictionBuffer = body.net.buffer
	_w["lag_max"] = maxi(_w["lag_max"], buffer.last_seq - buffer.acked_seq)
	_w["pend_max"] = maxi(_w["pend_max"], buffer.size())


# Keeps ENet's throttle open on this end's connection to `peer_id` (ENet tells the other end too).
func _open_throttle(peer_id: int) -> void:
	var enet := session.multiplayer.multiplayer_peer as ENetMultiplayerPeer
	if enet == null:
		return
	var connection: ENetPacketPeer = enet.get_peer(peer_id)
	if connection != null:
		connection.throttle_configure(THROTTLE_INTERVAL_MS, throttle_accel, 0)
		_log("throttle opened toward peer %d at %d/32" % [peer_id, connection.get_statistic(ENetPacketPeer.PEER_PACKET_THROTTLE)])


# Host: the session's clock, counting the intents that reach the rate limits.
func _counting_clock() -> float:
	_arrived += 1
	return Time.get_ticks_usec() / 1000000.0


func _sample_link() -> void:
	var connection := _enet_link()
	if connection == null:
		return
	var throttle: int = connection.get_statistic(ENetPacketPeer.PEER_PACKET_THROTTLE)
	_w["thr_min"] = mini(_w["thr_min"], throttle)
	_w["rtt"] = connection.get_statistic(ENetPacketPeer.PEER_ROUND_TRIP_TIME)
	_w["rtt_var"] = connection.get_statistic(ENetPacketPeer.PEER_ROUND_TRIP_TIME_VARIANCE)
	_w["loss"] = connection.get_statistic(ENetPacketPeer.PEER_PACKET_LOSS) * 100.0 / 65536.0


# This process's ENet connection to the other one, or null.
func _enet_link() -> ENetPacketPeer:
	if session == null or _peer_id == 0:
		return null
	var enet := session.multiplayer.multiplayer_peer as ENetMultiplayerPeer
	if enet == null or enet.get_connection_status() != MultiplayerPeer.CONNECTION_CONNECTED:
		return null
	var other: int = CoopSession.HOST_ID if role == "client" else _peer_id
	if not session.multiplayer.get_peers().has(other):
		return null
	return enet.get_peer(other)


func _flush_window() -> void:
	var line: String
	if role == "client":
		line = "t=%d sent=%d pend=%d lag=%d snaps=%d snap_max=%.1f snap_sum=%.1f thr=%d rtt=%d rtt_var=%d loss=%.1f fps=%d" % [
			_second + 1, _w["sent"], _w["pend_max"], _w["lag_max"], _w["snaps"], _w["snap_max"],
			_w["snap_sum"], _w["thr_min"], _w["rtt"], _w["rtt_var"], _w["loss"], _w["frames"]]
	else:
		_w["arr"] = _arrived
		_arrived = 0
		line = "t=%d arr=%d recv=%d lim=%d gaps=%d stale=%d sim=%.2f bucket=%d thr=%d rtt=%d rtt_var=%d fps=%d" % [
			_second + 1, _w["arr"], _w["recv"], _w["arr"] - _w["recv"], _w["gaps"], _w["stale_max"],
			_w["sim"], _w["bucket"], _w["thr_min"], _w["rtt"], _w["rtt_var"], _w["frames"]]
	_log(line)
	for key: String in ["sent", "arr", "recv", "gaps", "snaps", "snap_sum", "sim"]:
		_total[key] += _w[key]
	_total["snap_max"] = maxf(_total["snap_max"], _w["snap_max"])
	_total["stale_max"] = maxi(_total["stale_max"], _w["stale_max"])
	_total["thr_min"] = mini(_total["thr_min"], _w["thr_min"])
	_total["lag_max"] = maxi(_total["lag_max"], _w["lag_max"])
	_total["bucket_min"] = mini(_total["bucket_min"], _w["bucket"])
	if _w["thr_min"] < 32:
		_total["thr_low_s"] += 1
	_reset_window()


func _summary() -> void:
	if role == "client":
		_log("summary sent=%d snaps=%d snap_max=%.1f snap_sum=%.1f lag_max=%d thr_min=%d thr_low_s=%d" % [
			_total["sent"], _total["snaps"], _total["snap_max"], _total["snap_sum"], _total["lag_max"],
			_total["thr_min"], _total["thr_low_s"]])
	else:
		_log("summary arr=%d recv=%d lim=%d gaps=%d stale_max=%d sim=%.1f bucket_min=%d thr_min=%d thr_low_s=%d requests=%d" % [
			_total["arr"], _total["recv"], _total["arr"] - _total["recv"], _total["gaps"],
			_total["stale_max"], _total["sim"], _total["bucket_min"], _total["thr_min"], _total["thr_low_s"],
			_requests_seen])


func _reset_window() -> void:
	_w = {"sent": 0, "recv": 0, "gaps": 0, "snaps": 0, "snap_sum": 0.0, "snap_max": 0.0,
		"stale_max": 0, "thr_min": 32, "rtt": 0, "rtt_var": 0, "loss": 0.0, "lag_max": 0,
		"pend_max": 0, "sim": 0.0, "frames": 0, "arr": 0, "bucket": 250}


func _elapsed_s() -> float:
	return (Time.get_ticks_usec() - _start_us) / 1000000.0


func _parse(args: PackedStringArray) -> void:
	for arg: String in args:
		var key: String = arg.get_slice("=", 0)
		var value: String = arg.substr(key.length() + 1)
		match key:
			"--role":
				role = value
			"--port":
				port = value.to_int()
			"--connect":
				address = value.get_slice(":", 0)
				if value.contains(":"):
					connect_port = value.get_slice(":", 1).to_int()
			"--seconds":
				seconds = value.to_float()
			"--idle":
				idle_s = value.to_float()
			"--stall-ms":
				stall_ms = value.to_int()
			"--stall-at":
				stall_at_s = value.to_float()
			"--stall-for":
				stall_for_s = value.to_float()
			"--open-throttle":
				open_throttle = true
			"--transfer":
				transfer = value
			"--tag":
				tag = value
			"--throttle-accel":
				throttle_accel = value.to_int()
			"--requests-hz":
				requests_hz = value.to_float()


func _log(line: String) -> void:
	print("%s %s %s %s" % [LOG_PREFIX, tag, role, line])
