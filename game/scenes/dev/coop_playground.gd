class_name CoopPlayground
extends MovementPlayground
## Manual co-op test island (coop-networking): the movement playground's terrain with a
## CoopSession, the quick-chat wheel and the host-lost screen. Start it after `--`:
##   godot --path game res://scenes/dev/coop_playground.tscn -- --host[=port]
##   godot --path game res://scenes/dev/coop_playground.tscn -- --join=address[:port]
##   godot --path game res://scenes/dev/coop_playground.tscn -- --solo
## or from its panel. Over the internet the host forwards UDP 7777 to its machine by hand (no
## UPnP). It prints "coop:" status lines so two headless processes can be checked from logs.

const SPAWN_POINTS: Array[Vector2] = [
	Vector2(40.0, 200.0), Vector2(72.0, 200.0), Vector2(40.0, 232.0), Vector2(72.0, 232.0),
]
## Fixed until island-generation owns the seed; the sky (WeatherManager) supplies weather and time.
const DEV_WORLD_STATE: Dictionary = {"island_seed": 0}
const HOST_LOST_SCENE: PackedScene = preload("res://scenes/ui/host_lost_screen.tscn")
const LOG_PREFIX: String = "coop:"

@onready var session: CoopSession = $Session
@onready var panel: Control = %Panel
@onready var address_field: LineEdit = %Address
@onready var note: Label = %Note
@onready var status_label: Label = %Status
@onready var wheel: QuickChatWheel = %Wheel
@onready var pause_menu: PauseMenu = $PauseMenu


## Reads `--host[=port]`, `--join=address[:port]` or `--solo`. Anything else, or a bad port
## or address, gives mode "" (show the panel).
static func parse_args(args: PackedStringArray) -> Dictionary:
	var result: Dictionary = _panel_mode()
	for arg: String in args:
		if arg == "--solo":
			result["mode"] = "solo"
		elif arg == "--host":
			result["mode"] = "host"
		elif arg.begins_with("--host="):
			var port: int = _port(arg.trim_prefix("--host="))
			if port < 0:
				return _panel_mode()
			result["mode"] = "host"
			result["port"] = port
		elif arg.begins_with("--join="):
			var target: String = arg.trim_prefix("--join=")
			var address: String = target.get_slice(":", 0)
			var port: int = _port(target.get_slice(":", 1)) if target.contains(":") else NetPeers.DEFAULT_PORT
			if port < 0 or not NetPeers.is_valid_address(address, port):
				return _panel_mode()
			result["mode"] = "join"
			result["address"] = address
			result["port"] = port
		else:
			return _panel_mode()
	return result


func _ready() -> void:
	super._ready()
	session.terrain = terrain
	session.climate = climate
	session.sky = WeatherManager.sky
	session.spawn_points = SPAWN_POINTS.duplicate()
	session.world_state = DEV_WORLD_STATE.duplicate()
	session.player_spawned.connect(_on_player_spawned)
	session.player_disconnected.connect(func(peer_id: int) -> void: _log("player %d dropped; downed for %d s" % [peer_id, CoopSession.DISCONNECT_DOWNED_S]))
	session.host_lost.connect(_on_host_lost)
	wheel.phrases = session.phrases
	wheel.rebuild()
	wheel.phrase_picked.connect(session.say)
	pause_menu.session = session
	(%Host as Button).pressed.connect(func() -> void: start(parse_args(PackedStringArray(["--host"]))))
	(%Join as Button).pressed.connect(_on_join_pressed)
	(%Solo as Button).pressed.connect(func() -> void: start(parse_args(PackedStringArray(["--solo"]))))
	NetManager.join_failed.connect(_on_join_failed)
	var args := parse_args(OS.get_cmdline_user_args())
	if args["mode"] != "":
		start(args)


## Starts hosting, joining or solo from a parse_args() result.
func start(args: Dictionary) -> void:
	var error: Error = OK
	match args["mode"]:
		"host":
			error = NetManager.host(args["port"])
		"join":
			error = NetManager.join(args["address"], args["port"])
		"solo":
			NetManager.start_solo()
		_:
			return
	if error != OK:
		status_label.text = "No se pudo empezar: %s." % error_string(error)
		_log("could not start %s: %s" % [args["mode"], error_string(error)])
		return
	panel.visible = false
	session.start()
	_log("started %s as peer %d" % [args["mode"], session.multiplayer.get_unique_id()])


func _on_join_pressed() -> void:
	start(parse_args(PackedStringArray(["--join=%s" % address_field.text.strip_edges()])))


func _on_player_spawned(peer_id: int, spawned: PlayerBody) -> void:
	if peer_id == session.multiplayer.get_unique_id():
		hud.bind(spawned.meters)
	_log("player %d spawned; players %s" % [peer_id, session.peer_ids()])


func _on_host_lost() -> void:
	_log("host lost")
	var screen := HOST_LOST_SCENE.instantiate() as HostLostScreen
	add_child(screen)
	screen.back_requested.connect(_on_back_requested)


func _on_join_failed() -> void:
	_log("join failed")
	get_tree().reload_current_scene.call_deferred()


func _on_back_requested() -> void:
	NetManager.leave()
	get_tree().reload_current_scene.call_deferred()


func _log(line: String) -> void:
	print("%s %s" % [LOG_PREFIX, line])


static func _panel_mode() -> Dictionary:
	return {"mode": "", "address": "", "port": NetPeers.DEFAULT_PORT}


# A port from text, or -1 when it is not a number from 1 to 65535.
static func _port(text: String) -> int:
	if not text.is_valid_int():
		return -1
	var port: int = text.to_int()
	return port if port >= 1 and port <= NetPeers.MAX_PORT else -1
