class_name SecretPlayground
extends Node2D
## The base of secret-cay's two dev scenes (secret-cay "Dev scenes for the hunt and the cay";
## design.md decision 11): the island scene built from `layout`, a CoopSession and the run HUD
## bound to the local player, as GameShell builds a run. Start it after `--`:
##   godot --path game res://scenes/dev/<scene>.tscn -- --solo
##   godot --path game res://scenes/dev/<scene>.tscn -- --host[=port]
##   godot --path game res://scenes/dev/<scene>.tscn -- --join=address[:port]
## or from its panel. Solo opens no port. It prints "secret:" lines so two headless processes can
## be checked from their logs. `--autopilot` walks the local player to each of the scene's targets
## in turn and holds interact there, so two headless processes play it with nobody at the keys.
## Neither scene's layout is offered by any run.

const ISLAND_SCENE: PackedScene = preload("res://scenes/levels/sandbar_island.tscn")
const SESSION_SCENE: PackedScene = preload("res://scenes/net/coop_session.tscn")
const HUD_SCENE: PackedScene = preload("res://scenes/ui/run_hud.tscn")
const LOG_PREFIX: String = "secret:"
const RUN_START_TIME_S: float = 0.0
const AUTOPILOT: String = "--autopilot"
## The autopilot holds interact once its player is this close to the target.
const ARRIVED_PX: float = 6.0

## The handmade layout this scene builds.
@export var layout: IslandLayoutData = null

var island: SandbarIsland = null
var session: CoopSession = null
var hud: RunHud = null
## "solo", "host", "join", or "" before it starts.
var mode: String = ""
## Extra flags this scene reads beside CoopPlayground's (`--autopilot`, `--with-pieces`).
var flags: PackedStringArray = PackedStringArray()
## The local player walks to the targets by itself (`--autopilot`).
var autopilot: bool = false

var _panel: PanelContainer = null
var _address: LineEdit = null
var _status: Label = null


## CoopPlayground's `--solo`, `--host[=port]` and `--join=address[:port]`, plus the flags in
## `known_flags`, which go to "flags".
static func parse_args(args: PackedStringArray, known_flags: PackedStringArray = PackedStringArray()) -> Dictionary:
	var rest := PackedStringArray()
	var found := PackedStringArray()
	for arg: String in args:
		if known_flags.has(arg):
			found.append(arg)
		else:
			rest.append(arg)
	var result: Dictionary = CoopPlayground.parse_args(rest)
	result["flags"] = found
	return result


func _ready() -> void:
	y_sort_enabled = true
	_make_panel()
	NetManager.join_failed.connect(_on_join_failed)
	var args := parse_args(OS.get_cmdline_user_args(), _known_flags())
	flags = args["flags"]
	if args["mode"] != "":
		start(args)


## Starts solo, hosting or joining from a parse_args() result, then builds the island, the session
## and the HUD. Returns whether it started.
func start(args: Dictionary) -> bool:
	var error: Error = OK
	match args["mode"]:
		"host":
			error = NetManager.host(args["port"])
		"join":
			error = NetManager.join(args["address"], args["port"])
		"solo":
			NetManager.start_solo()
		_:
			return false
	if error != OK:
		_status.text = "No se pudo empezar: %s." % error_string(error)
		log_line("could not start %s: %s" % [args["mode"], error_string(error)])
		return false
	mode = args["mode"]
	flags = args.get("flags", PackedStringArray())
	autopilot = flags.has(AUTOPILOT)
	_panel.visible = false
	_build()
	log_line("started %s as peer %d on %s" % [mode, session.multiplayer.get_unique_id(), layout.id])
	_on_built()
	return true


## Prints one status line for headless checks.
func log_line(line: String) -> void:
	print("%s %s" % [LOG_PREFIX, line])


## The scene's own extra flags.
func _known_flags() -> PackedStringArray:
	return PackedStringArray([AUTOPILOT])


## What the autopilot walks to next, or null when it is done.
func _autopilot_target() -> Node2D:
	return null


func _physics_process(_delta: float) -> void:
	if autopilot and session != null:
		_steer()


# The local player's intent: run to the target, then hold interact on it.
func _steer() -> void:
	var body := session.body(session.multiplayer.get_unique_id())
	if body == null:
		return
	body.player_input.enabled = false
	var target := _autopilot_target()
	if target == null:
		body.intent = MoveIntent.new()
		return
	var offset: Vector2 = target.global_position - body.global_position
	if offset.length() > ARRIVED_PX:
		body.intent = MoveIntent.create(offset.normalized(), true, false, false)
	else:
		body.intent = MoveIntent.create(Vector2.ZERO, false, false, true)


## After the island, the session and the HUD exist (every peer); the host has placed the pick-ups.
func _on_built() -> void:
	pass


func _build() -> void:
	var solo: bool = mode == "solo"
	island = ISLAND_SCENE.instantiate() as SandbarIsland
	island.layout = layout
	add_child(island)
	session = SESSION_SCENE.instantiate() as CoopSession
	session.terrain = island.terrain
	session.climate = island.climate
	session.sky = WeatherManager.sky
	session.spawn_points = island.spawn_points(solo)
	session.player_spawned.connect(_on_player_spawned)
	session.host_lost.connect(func() -> void: log_line("host lost"))
	add_child(session)
	island.furnish(session)
	var routes := session.get_node_or_null(^"Routes") as IslandRoutes
	if routes != null:
		routes.route_started.connect(_on_route_started)
	if mode != "join":
		WeatherManager.sky.start_at(RUN_START_TIME_S)
	session.start()
	if session.multiplayer.is_server():
		island.place_pickups(session)
		WeatherManager.start(RUN_START_TIME_S)
	else:
		WeatherManager.follow()
	hud = HUD_SCENE.instantiate() as RunHud
	add_child(hud)
	hud.bind(session, session.multiplayer.get_unique_id(), solo)


func _on_player_spawned(peer_id: int, body: PlayerBody) -> void:
	IslandArrival.fit_camera(body, island.bounds)
	log_line("player %d spawned at cell %s; players %s" % [peer_id, Vector2i(body.position / IslandLayout.TILE), session.peer_ids()])


func _on_route_started(route_id: StringName, peer_ids: Array[int]) -> void:
	log_line("players %s left the island by %s" % [peer_ids, route_id])


func _on_join_failed() -> void:
	log_line("join failed")


func _make_panel() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 10
	add_child(layer)
	_panel = PanelContainer.new()
	_panel.position = Vector2(8.0, 8.0)
	layer.add_child(_panel)
	var rows := VBoxContainer.new()
	_panel.add_child(rows)
	var title := Label.new()
	title.text = "Secreto de prueba"
	rows.add_child(title)
	_address = LineEdit.new()
	_address.text = "127.0.0.1"
	_address.placeholder_text = "IP del anfitrión"
	rows.add_child(_address)
	var buttons := HBoxContainer.new()
	rows.add_child(buttons)
	for entry: Array in [["Hospedar", "--host"], ["Unirse", ""], ["Solo", "--solo"]]:
		var button := Button.new()
		button.text = entry[0]
		buttons.add_child(button)
		var arg: String = entry[1]
		button.pressed.connect(func() -> void:
			var chosen: String = arg if not arg.is_empty() else "--join=%s" % _address.text.strip_edges()
			start(parse_args(PackedStringArray([chosen]) + flags, _known_flags())))
	_status = Label.new()
	rows.add_child(_status)
