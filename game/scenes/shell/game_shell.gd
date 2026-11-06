class_name GameShell
extends Node
## ui-shell "Screen flow": the main scene. It owns the settings, fits the window, shows one
## screen at a time and builds the run (island + CoopSession) in its World. Screens only ask
## (signals); the shell alone talks to NetManager. Solo goes straight to a run on the offline
## peer, with nothing waiting for another player.

enum Flow {
	TITLE,
	JOIN,
	LOBBY,
	RUN,
	SUMMARY,
	SETTINGS,
	HOST_LOST,
}

const TITLE_SCENE: PackedScene = preload("res://scenes/shell/title_screen.tscn")
const SETTINGS_SCENE: PackedScene = preload("res://scenes/shell/settings_screen.tscn")
const JOIN_SCENE: PackedScene = preload("res://scenes/shell/join_screen.tscn")
const SUMMARY_SCENE: PackedScene = preload("res://scenes/shell/summary_screen.tscn")
const SESSION_SCENE: PackedScene = preload("res://scenes/net/coop_session.tscn")
const ISLAND_SCENE: PackedScene = preload("res://scenes/levels/dev_island.tscn")
const LOBBY_SCENE: PackedScene = preload("res://scenes/shell/lobby_screen.tscn")
const HOST_LOST_SCENE: PackedScene = preload("res://scenes/ui/host_lost_screen.tscn")
const HUD_SCENE: PackedScene = preload("res://scenes/ui/run_hud.tscn")
const TINT_SCENE: PackedScene = preload("res://scenes/world/day_night_tint.tscn")
## A run's first morning: the clock reads 06:00, the start of dawn (docs/GAME_DESIGN.md §5).
const RUN_START_TIME_S: float = 0.0

## Where the settings live; tests point it elsewhere.
@export var settings_path: String = GameSettings.DEFAULT_PATH
## The port to host on; tests use 0 (any free port).
@export var port: int = NetPeers.DEFAULT_PORT
## Shown after the host goes away, or null.
var host_lost_screen: HostLostScreen
## The run's HUD, or null outside a run.
var hud: RunHud

var settings: GameSettings
var flow: Flow = Flow.TITLE
## The screen on show, or null during a run.
var screen: Control
## The run's session and island, or null outside a run.
var session: CoopSession
var island: DevIsland
## Tints the world view while a run is on, or null.
var tint: DayNightTint
## Seconds, for the run's length. Tests replace it.
var clock: Callable
var _run_started_s: float = 0.0

## The world's own 640×360 view (ui-shell "Pixel filter"); the HUD and screens are outside it.
@onready var world_view: SubViewportContainer = $WorldView
@onready var world_viewport: SubViewport = $WorldView/Viewport
@onready var _world: Node2D = $WorldView/Viewport/World
@onready var _screens: Control = $Screens/Root
@onready var _backdrop: ColorRect = $Screens/Root/Backdrop


func _init() -> void:
	clock = _ticks_s


func _ready() -> void:
	settings = GameSettings.load_from(settings_path)
	NetManager.join_failed.connect(_on_join_failed)
	apply_display()
	apply_pixel_filter()
	show_title()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"toggle_fullscreen"):
		settings.fullscreen = not settings.fullscreen
		settings.save()
		apply_display()
		get_viewport().set_input_as_handled()


## Fits the window to the settings: fullscreen, or the largest (or the fixed) whole-number
## scale of 640×360 that fits the usable screen. Does nothing on the headless display server.
func apply_display() -> void:
	if DisplayServer.get_name() == "headless":
		return
	if settings.fullscreen:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
		return
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	var screen_index := DisplayServer.window_get_current_screen()
	var usable := DisplayServer.screen_get_usable_rect(screen_index)
	var size := DisplayFit.window_size(DisplayFit.window_scale(settings.ui_scale, usable.size))
	DisplayServer.window_set_size(size)
	DisplayServer.window_set_position(usable.position + (usable.size - size) / 2)


## Nítido: the window enlarges the whole 640×360 picture with nearest filtering. Suave: the root
## canvas is drawn at the window's resolution and the world view runs the Scale2x shader.
func apply_pixel_filter() -> void:
	world_view.material = PixelFilter.material_for(settings.pixel_filter)
	get_window().content_scale_mode = PixelFilter.stretch_mode(settings.pixel_filter)
	get_window().oversampling = PixelFilter.font_oversampling(settings.pixel_filter)


func show_title() -> void:
	var title := _show(TITLE_SCENE, Flow.TITLE) as TitleScreen
	title.solo_requested.connect(start_solo)
	title.host_requested.connect(start_host)
	title.join_requested.connect(show_join)
	title.settings_requested.connect(show_settings)
	title.quit_requested.connect(func() -> void: get_tree().quit())


func show_settings() -> void:
	var settings_screen := _show(SETTINGS_SCENE, Flow.SETTINGS) as SettingsScreen
	settings_screen.bind(settings)
	settings_screen.back_requested.connect(show_title)
	settings_screen.display_changed.connect(_on_display_changed)


func _on_display_changed() -> void:
	apply_display()
	apply_pixel_filter()


func show_join() -> void:
	var join := _show(JOIN_SCENE, Flow.JOIN) as JoinScreen
	join.back_requested.connect(back_to_title)
	join.connect_requested.connect(_join)


## Hosting: open the port, gather players in the lobby, start when the host says so.
func start_host() -> void:
	if NetManager.host(port) != OK:
		var title := screen as TitleScreen
		if title != null:
			title.description.text = "No se pudo abrir el puerto %d." % port
		return
	_build_run()
	session.local_name = settings.player_name
	session.roster_updated.connect(_refresh_lobby)
	session.run_started.connect(_enter_run)
	session.start(true)
	show_lobby(true)


func show_lobby(is_host: bool) -> void:
	var lobby := _show(LOBBY_SCENE, Flow.LOBBY) as LobbyScreen
	lobby.is_host = is_host
	lobby.show_roster(session.roster)
	if is_host:
		lobby.set_addresses(LobbyScreen.local_addresses(IP.get_local_addresses()))
		lobby.start_requested.connect(func() -> void: session.begin_run())
	lobby.back_requested.connect(back_to_title)


# The session exists before the connection completes, so the host's spawns and messages
# always find it.
func _join(address: String, join_port: int) -> void:
	_build_run()
	session.local_name = settings.player_name
	if NetManager.join(address, join_port) != OK:
		_on_join_failed()
		return
	session.roster_updated.connect(_refresh_lobby)
	session.lobby_received.connect(func(in_run: bool) -> void:
		if in_run:
			_enter_run()
		else:
			show_lobby(false))
	session.run_started.connect(_enter_run)
	session.start()


func _on_join_failed() -> void:
	_end_run()
	var join := screen as JoinScreen
	if join != null:
		join.show_failed()


func _refresh_lobby() -> void:
	var lobby := screen as LobbyScreen
	if lobby != null and session != null:
		lobby.show_roster(session.roster)


func _on_host_lost() -> void:
	_close_screen()
	flow = Flow.HOST_LOST
	host_lost_screen = HOST_LOST_SCENE.instantiate() as HostLostScreen
	add_child(host_lost_screen)
	host_lost_screen.back_requested.connect(_leave_host_lost)
	# The session is inside its own signal: free it after this frame.
	_end_run.call_deferred()


func _leave_host_lost() -> void:
	if host_lost_screen != null:
		host_lost_screen.queue_free()
		host_lost_screen = null
	back_to_title()


## Solo: the offline peer, a session that spawns the one player at once, straight to the run.
func start_solo() -> void:
	NetManager.start_solo()
	_build_run()
	session.local_name = settings.player_name
	session.start()
	_enter_run()


## Ends the run (if any), goes offline and shows the title.
func back_to_title() -> void:
	_end_run()
	NetManager.leave()
	show_title()


func _build_run() -> void:
	_end_run()
	island = ISLAND_SCENE.instantiate() as DevIsland
	_world.add_child(island)
	session = SESSION_SCENE.instantiate() as CoopSession
	session.terrain = island.terrain
	session.climate = island.climate
	session.sky = WeatherManager.sky
	session.spawn_points = DevIsland.SPAWN_POINTS.duplicate()
	session.player_spawned.connect(_on_player_spawned)
	session.player_removed.connect(_on_player_removed)
	session.host_lost.connect(_on_host_lost)
	_world.add_child(session)


func _enter_run() -> void:
	if flow == Flow.RUN:
		return
	_close_screen()
	flow = Flow.RUN
	_run_started_s = clock.call()
	# The host owns the clock; a client runs its own between the host's resyncs (receive_sky)
	# without restarting the day or rolling weather.
	if session.multiplayer.is_server():
		WeatherManager.start(RUN_START_TIME_S)
	else:
		WeatherManager.follow()
	tint = TINT_SCENE.instantiate() as DayNightTint
	_world.add_child(tint)
	hud = HUD_SCENE.instantiate() as RunHud
	add_child(hud)
	hud.bind(session, session.multiplayer.get_unique_id(), session.multiplayer.multiplayer_peer is OfflineMultiplayerPeer)


# Freed at once, before the peer is closed: closing a peer under live synchronizers logs
# engine errors.
func _end_run() -> void:
	WeatherManager.stop()
	if tint != null:
		tint.free()
		tint = null
	if hud != null:
		hud.free()
		hud = null
	if session != null:
		session.free()
		session = null
	if island != null:
		island.free()
		island = null


func _on_player_removed(_peer_id: int, _last_position: Vector2) -> void:
	_check_run_over()


func _on_player_spawned(_peer_id: int, body: PlayerBody) -> void:
	body.meters.died.connect(_check_run_over)
	# The camera stays over the island, never past its edge.
	body.camera.limit_left = DevIsland.BOUNDS.position.x
	body.camera.limit_top = DevIsland.BOUNDS.position.y
	body.camera.limit_right = DevIsland.BOUNDS.end.x
	body.camera.limit_bottom = DevIsland.BOUNDS.end.y


# The run ends when every player in it is dead. A dropped player keeps it open until they are
# removed (they may come back); the removal checks again.
func _check_run_over() -> void:
	if flow != Flow.RUN or session == null:
		return
	var entries: Array[Dictionary] = []
	for peer_id: int in session.peer_ids():
		var dead: bool = session.body(peer_id).meters.dead
		if not dead:
			return
		entries.append({"name": session.player_name(peer_id), "dead": dead})
	WeatherManager.stop()
	var summary := _show(SUMMARY_SCENE, Flow.SUMMARY) as SummaryScreen
	summary.show_summary(entries, clock.call() - _run_started_s)
	summary.home_requested.connect(back_to_title)


func _show(scene: PackedScene, next: Flow) -> Control:
	_close_screen()
	screen = scene.instantiate() as Control
	_backdrop.visible = next != Flow.TITLE and next != Flow.SUMMARY
	_screens.add_child(screen)
	flow = next
	return screen


func _close_screen() -> void:
	if screen != null:
		screen.queue_free()
		screen = null
	_backdrop.visible = false


func _ticks_s() -> float:
	return Time.get_ticks_usec() / 1000000.0
