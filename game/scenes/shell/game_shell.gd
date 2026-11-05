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

## Where the settings live; tests point it elsewhere.
@export var settings_path: String = GameSettings.DEFAULT_PATH

var settings: GameSettings
var flow: Flow = Flow.TITLE
## The screen on show, or null during a run.
var screen: Control
## The run's session and island, or null outside a run.
var session: CoopSession
var island: DevIsland
## Seconds, for the run's length. Tests replace it.
var clock: Callable
var _run_started_s: float = 0.0

@onready var _world: Node2D = $World
@onready var _screens: Control = $Screens/Root
@onready var _backdrop: ColorRect = $Screens/Root/Backdrop


func _init() -> void:
	clock = _ticks_s


func _ready() -> void:
	settings = GameSettings.load_from(settings_path)
	apply_display()
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


func show_title() -> void:
	var title := _show(TITLE_SCENE, Flow.TITLE) as TitleScreen
	title.solo_requested.connect(start_solo)
	title.join_requested.connect(show_join)
	title.settings_requested.connect(show_settings)
	title.quit_requested.connect(func() -> void: get_tree().quit())


func show_settings() -> void:
	var settings_screen := _show(SETTINGS_SCENE, Flow.SETTINGS) as SettingsScreen
	settings_screen.bind(settings)
	settings_screen.back_requested.connect(show_title)
	settings_screen.display_changed.connect(apply_display)


func show_join() -> void:
	var join := _show(JOIN_SCENE, Flow.JOIN) as JoinScreen
	join.back_requested.connect(show_title)


## Solo: the offline peer, a session that spawns the one player at once, straight to the run.
func start_solo() -> void:
	NetManager.start_solo()
	_build_run()
	session.roster[CoopSession.HOST_ID] = settings.player_name
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
	session.spawn_points = DevIsland.SPAWN_POINTS.duplicate()
	session.player_spawned.connect(_on_player_spawned)
	_world.add_child(session)


func _enter_run() -> void:
	_close_screen()
	flow = Flow.RUN
	_run_started_s = clock.call()


func _end_run() -> void:
	if session != null:
		session.queue_free()
		session = null
	if island != null:
		island.queue_free()
		island = null


func _on_player_spawned(_peer_id: int, body: PlayerBody) -> void:
	body.meters.died.connect(_check_run_over)


# The run ends when every player in it is dead.
func _check_run_over() -> void:
	if flow != Flow.RUN or session == null:
		return
	var entries: Array[Dictionary] = []
	for peer_id: int in session.peer_ids():
		var dead: bool = session.body(peer_id).meters.dead
		if not dead:
			return
		entries.append({"name": session.player_name(peer_id), "dead": dead})
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
