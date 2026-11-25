class_name GameShell
extends Node
## ui-shell "Screen flow": the main scene. It owns the settings, fits the window, shows one
## screen at a time and builds the run (island + CoopSession) in its World. Screens only ask
## (signals); the shell alone talks to NetManager. Solo goes straight to a run on the offline
## peer, with nothing waiting for another player.
##
## Hosting and joining are NetManager requests (net-platform): READY, PENDING or FAILED. The run
## is built only once the request's peer is installed (_continue, on READY at once or on `settled`
## later), never under the offline peer standing in for a pending one, so a pending joiner never
## acts as host. A join from outside the game (an invite, --connect=) starts at once from a menu
## screen and otherwise waits for the title; a lobby or a run is never interrupted.
##
## A co-op host's "Otra vez" is a rematch (coop-networking "Rematch with the same party"): the host
## frees its run, calls every connected client through its `Rematch` child and opens a new lobby on
## the same connection; each client rebuilds its run inside that call and joins again.

enum Flow {
	TITLE,
	JOIN,
	LOBBY,
	RUN,
	SUMMARY,
	SETTINGS,
	HOST_LOST,
	CREDITS,
	CONTROLS,
}

const TITLE_SCENE: PackedScene = preload("res://scenes/shell/title_screen.tscn")
const SETTINGS_SCENE: PackedScene = preload("res://scenes/shell/settings_screen.tscn")
const CREDITS_SCENE: PackedScene = preload("res://scenes/shell/credits_screen.tscn")
const CONTROLS_SCENE: PackedScene = preload("res://scenes/shell/controls_card.tscn")
const JOIN_SCENE: PackedScene = preload("res://scenes/shell/join_screen.tscn")
const SUMMARY_SCENE: PackedScene = preload("res://scenes/shell/summary_screen.tscn")
const SESSION_SCENE: PackedScene = preload("res://scenes/net/coop_session.tscn")
const ISLAND_SCENE: PackedScene = preload("res://scenes/levels/sandbar_island.tscn")
const LOBBY_SCENE: PackedScene = preload("res://scenes/shell/lobby_screen.tscn")
const HOST_LOST_SCENE: PackedScene = preload("res://scenes/ui/host_lost_screen.tscn")
const HUD_SCENE: PackedScene = preload("res://scenes/ui/run_hud.tscn")
const TINT_SCENE: PackedScene = preload("res://scenes/world/day_night_tint.tscn")
## A run's first morning: the clock reads 06:00, the start of dawn (docs/GAME_DESIGN.md §5).
const RUN_START_TIME_S: float = 0.0
## The title's line when hosting failed and the backend table has no line for the reason (an
## unreadable table): ENet's own wording.
const HOST_FAILED: String = "No se pudo abrir el puerto %d."

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
var island: SandbarIsland
## Tints the world view while a run is on, or null.
var tint: DayNightTint
## The island keeper: waits for the party and loads the next island (null outside a run).
var travel: IslandTravel
## Crossings still running, and the results of those that ended.
var crossings: Array[Node] = []
var crossing_results: Array[RefCounted] = []
## Seconds, for the run's length. Tests replace it.
var clock: Callable
## Rolls the run seed the host (or solo) starts every run with. Tests replace it.
var seed_source: Callable
## The death one-liners the summary picks from (the content's unless a test sets others).
var death_lines: DeathLines
## The host's rematch call, on a child named "Rematch" that outlives every run (design D2).
var rematch: RunRematch
var _run_started_s: float = 0.0
## While the local rider waits on the shore: who is still playing (null outside a run).
var _wait_label: Label
var _crossing_rng := RandomNumberGenerator.new()
# This shell's last host or join request (pending, or ready with its peer installed), or null.
var _request: NetRequest
# A join of this shell is under way: from the request until it fails, is cancelled, or its lobby
# or run shows.
var _joining: bool = false

## The world's own 640×360 view (ui-shell "Pixel filter"); the HUD and screens are outside it.
@onready var world_view: SubViewportContainer = $WorldView
@onready var world_viewport: SubViewport = $WorldView/Viewport
@onready var _world: Node2D = $WorldView/Viewport/World
@onready var _screens: Control = $Screens/Root
@onready var _backdrop: ColorRect = $Screens/Root/Backdrop


func _init() -> void:
	clock = _ticks_s
	seed_source = _roll_seed


func _ready() -> void:
	settings = GameSettings.load_from(settings_path)
	# The player id is kept from the first launch on (coop-reconnect).
	if not settings.identity_stored:
		settings.save()
	NetManager.join_failed.connect(_on_join_failed)
	NetManager.host_failed.connect(_on_host_failed)
	NetManager.outside_join_requested.connect(_on_outside_join)
	death_lines = DeathLines.from_catalog(GameState.content)
	rematch = RunRematch.new()
	rematch.name = "Rematch"
	add_child(rematch)
	rematch.called.connect(_on_rematch_called)
	apply_display()
	apply_pixel_filter()
	apply_flashes()
	apply_volume()
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
	title.controls_requested.connect(show_controls)
	title.credits_requested.connect(show_credits)
	title.quit_requested.connect(func() -> void: get_tree().quit())
	# ui-shell "First-launch name": once per install, while the name is still the default.
	if settings.player_name == GameSettings.DEFAULT_NAME and not settings.name_asked:
		title.ask_name(settings)
	# A join from outside the game kept during a lobby or a run (or one from the launch line)
	# starts now. Deferred: the title may show inside a NetManager signal.
	_take_outside_join.call_deferred()


func show_settings() -> void:
	var settings_screen := _show(SETTINGS_SCENE, Flow.SETTINGS) as SettingsScreen
	settings_screen.bind(settings)
	settings_screen.back_requested.connect(show_title)
	settings_screen.display_changed.connect(_on_display_changed)
	settings_screen.flashes_changed.connect(apply_flashes)


## art-pass "Credits screen": who made the art and fonts, offline; Volver and Esc go back to the
## title, as the settings screen does.
func show_credits() -> void:
	var credits_screen := _show(CREDITS_SCENE, Flow.CREDITS) as CreditsScreen
	credits_screen.show_credits(load(ArtCredits.STANDARD_PATH) as ArtCredits)
	credits_screen.back_requested.connect(show_title)


## ui-shell "Controles card" (run-menu design D6): on paper, offline; Volver and Esc go back to the
## title with "Controles" focused.
func show_controls() -> void:
	var card := _show(CONTROLS_SCENE, Flow.CONTROLS) as ControlsCard
	card.back_requested.connect(func() -> void:
		show_title()
		(screen as TitleScreen).focus_button(&"Controls"))


## damage-feedback "Reducir destellos": every hit and change cue reads it from HurtCues.
func apply_flashes() -> void:
	HurtCues.reduce_flashes = settings.reduce_flashes


## sound-pass "Volume level": the stored volume, on every sound. Ajustes calls it after a change.
func apply_volume() -> void:
	AudioManager.set_volume(float(settings.volume) / float(GameSettings.MAX_VOLUME))


func _on_display_changed() -> void:
	apply_display()
	apply_pixel_filter()


func show_join() -> void:
	var join := _show(JOIN_SCENE, Flow.JOIN) as JoinScreen
	join.back_requested.connect(back_to_title)
	join.connect_requested.connect(_join)


## Hosting: ask the backend for a session on `port`, gather players in the lobby, start when the
## host says so. A slower backend shows the lobby opening first; pressing again while it opens
## does nothing.
func start_host() -> void:
	if NetManager.pending_request() != null:
		return
	# The old run goes before the peer is swapped.
	_end_run()
	_joining = false
	_request = NetManager.request_host(port)
	match _request.state:
		NetRequest.State.READY:
			_continue(_request)
		NetRequest.State.PENDING:
			_show_opening()
			_request.settled.connect(_continue)
		_:
			_show_host_failure()


func show_lobby(is_host: bool) -> void:
	_joining = false
	var lobby := _show(LOBBY_SCENE, Flow.LOBBY) as LobbyScreen
	lobby.is_host = is_host
	lobby.show_roster(session.roster)
	if is_host:
		# How others join comes from the backend: the port opened and, on ENet, the LAN addresses.
		var info := NetManager.host_info()
		lobby.set_addresses(info.addresses if info != null else PackedStringArray())
		var note: String = NetManager.lobby_note()
		if not note.is_empty():
			lobby.note.text = note
		lobby.start_requested.connect(func() -> void: session.begin_run())
	lobby.back_requested.connect(back_to_title)


# The host's lobby while the backend opens the session: only Salir, which cancels. No run exists
# yet; _on_hosting() builds it and shows the full lobby.
func _show_opening() -> void:
	var lobby := _show(LOBBY_SCENE, Flow.LOBBY) as LobbyScreen
	lobby.show_opening()
	lobby.back_requested.connect(back_to_title)


# Kept for the join screen and tests: an address and port.
func _join(address: String, join_port: int) -> void:
	_join_target(NetJoinTarget.at_address(address, join_port))


## Joins `target` (an address, or a platform token). The run is built only once the client peer
## is installed: at once on ENet, a few frames later on a slower backend. A failure shows on the
## join screen, which opens if it is not showing.
func _join_target(target: NetJoinTarget) -> void:
	# The old run goes before the peer is swapped.
	_end_run()
	_joining = true
	_request = NetManager.request_join(target)
	match _request.state:
		NetRequest.State.READY:
			_continue(_request)
		NetRequest.State.PENDING:
			_request.settled.connect(_continue)
		_:
			_on_join_failed()


# The one continuation of a host or join request (design.md D3): called at once when the request
# comes back READY, or by its `settled` signal later. A cancelled, failed or replaced request is
# ignored; a late failure arrives through host_failed or join_failed instead.
func _continue(request: NetRequest) -> void:
	if request != _request or request.state != NetRequest.State.READY:
		return
	if request.kind == NetRequest.Kind.HOST:
		_on_hosting()
	else:
		_on_joining()


# The server peer is installed: the host's run, and the lobby with the host alone. A rematch passes
# the look slots each connected player keeps (art-pass "Look slots in a rematch").
func _on_hosting(kept_looks: Dictionary[int, int] = {}) -> void:
	_build_run()
	session.carried_looks = kept_looks
	session.local_name = settings.player_name
	session.roster_updated.connect(_refresh_lobby)
	session.run_started.connect(_enter_run)
	session.start(true)
	show_lobby(true)


# The client peer is installed (and connecting): the run is built as a client in the same step, so
# the session exists before the first packet from the host is read.
func _on_joining() -> void:
	_build_run(true)
	session.local_name = settings.player_name
	session.roster_updated.connect(_refresh_lobby)
	session.lobby_received.connect(func(in_run: bool) -> void:
		if in_run:
			_enter_run()
		else:
			show_lobby(false))
	session.run_started.connect(_enter_run)
	session.start()


# The title's line for a failed host: the reason's line, or ENet's own wording.
func _show_host_failure() -> void:
	if flow != Flow.TITLE:
		show_title()
	var title := screen as TitleScreen
	if title == null:
		return
	var text: String = NetManager.failure_text(NetManager.last_failure, NetManager.last_failure_args)
	title.description.text = text if not text.is_empty() else HOST_FAILED % port


# Hosting failed after the request returned: back to the title, which says why.
func _on_host_failed() -> void:
	if _request == null or _request.kind != NetRequest.Kind.HOST:
		return
	_request = null
	_end_run()
	show_title()
	_show_host_failure()


# A join of this shell failed, in the call or later: the join screen (opened if it is not showing)
# shows the reason's line, or "No se pudo conectar." when there is none.
func _on_join_failed() -> void:
	if not _joining and not screen is JoinScreen:
		return
	_joining = false
	_request = null
	_end_run()
	if not screen is JoinScreen:
		show_join()
	var text: String = NetManager.failure_text(NetManager.last_failure, NetManager.last_failure_args)
	(screen as JoinScreen).show_failed(text if not text.is_empty() else JoinScreen.FAILED)


# An invite or a platform "join game". Taken on the next idle step if a menu screen shows,
# otherwise kept by NetManager until the title shows.
func _on_outside_join(_target: NetJoinTarget) -> void:
	_take_outside_join.call_deferred()


# Whether a join from outside the game may start now: on the title, settings, credits or an idle
# join screen, with no run and nothing under way.
func _can_take_outside_join() -> bool:
	if _joining or session != null or NetManager.pending_request() != null:
		return false
	return flow in [Flow.TITLE, Flow.SETTINGS, Flow.CREDITS, Flow.JOIN]


# Starts the kept join from outside the game, if any and if nothing would be interrupted: the join
# screen in its connecting mode with the target's label.
func _take_outside_join() -> void:
	if not is_inside_tree() or not _can_take_outside_join():
		return
	var target: NetJoinTarget = NetManager.take_outside_join()
	if target == null:
		return
	if not screen is JoinScreen:
		show_join()
	(screen as JoinScreen).show_connecting(target.label)
	_join_target(target)


func _refresh_lobby() -> void:
	var lobby := screen as LobbyScreen
	if lobby != null and session != null:
		lobby.show_roster(session.roster)


func _on_host_lost() -> void:
	if flow == Flow.SUMMARY:
		# A client that finished its run keeps the summary; the run behind it goes.
		(screen as SummaryScreen).show_host_left()
		_backdrop.visible = true
		_end_run.call_deferred()
		return
	_close_screen()
	# An open run menu closes first, so it neither keeps the focus nor holds the input (design D8).
	if hud != null and hud.pause_menu != null:
		hud.pause_menu.resume()
	flow = Flow.HOST_LOST
	host_lost_screen = HOST_LOST_SCENE.instantiate() as HostLostScreen
	add_child(host_lost_screen)
	host_lost_screen.back_requested.connect(_leave_host_lost)
	# The HUD reads bodies that are going: it takes no input until it is freed with the run.
	if hud != null:
		hud.set_screen_shown(true)
	# The session is inside its own signal: free it after this frame.
	_end_run.call_deferred()


func _leave_host_lost() -> void:
	if host_lost_screen != null:
		host_lost_screen.queue_free()
		host_lost_screen = null
	back_to_title()


## Solo: the offline peer, a session that spawns the one player at once, straight to the run. Any
## host or join under way is cancelled; the backend is asked for nothing.
func start_solo() -> void:
	_request = null
	_joining = false
	# The old run goes before the peer is swapped.
	_end_run()
	NetManager.start_solo()
	_build_run()
	session.local_name = settings.player_name
	session.start()
	_enter_run()


## "Otra vez": a clean solo run from the summary. The old run ends before the peer is swapped.
func _restart_solo() -> void:
	_end_run()
	start_solo()


## A co-op host's "Otra vez" (endings-progression "Rematch from a co-op summary"): a new lobby on the
## same connection, which every connected client follows. The order is the rule (design D3): the
## old run is freed first, so its despawns reach each client before the call; the new lobby opens
## last, so its spawns reach each client after the call, in the session it rebuilt. NetManager is
## asked for nothing and the port stays open.
func _rematch() -> void:
	if session == null or not session.multiplayer.is_server():
		return
	var kept_looks: Dictionary[int, int] = session.look_slots()
	_end_run()
	rematch.call_party()
	_on_hosting(kept_looks)


# A client, inside the host's rematch call (design D4): the run is rebuilt now, not deferred, so the
# new run's spawns that follow the call in the same poll land in the new session; the call arrives
# on the Rematch node, not on the session being freed. The new session joins again on the same
# connection, with the same name and player id. The lobby shows at once, its list empty until the
# host answers; that also leaves Flow.RUN, so a run the host starts at once is entered with its HUD.
func _on_rematch_called() -> void:
	if session == null or session.multiplayer.is_server():
		return
	_on_joining()
	show_lobby(false)


## Ends the run (if any), cancels a host or join under way, goes offline and shows the title.
func back_to_title() -> void:
	_request = null
	_joining = false
	_end_run()
	NetManager.leave()
	show_title()


# A client's session exists before its connection completes, so only the caller knows it will not
# be the host: the host (or solo) places the island's pick-ups, a client receives them.
func _build_run(as_client: bool = false) -> void:
	_end_run()
	var solo: bool = not as_client and multiplayer.multiplayer_peer is OfflineMultiplayerPeer
	island = ISLAND_SCENE.instantiate() as SandbarIsland
	_world.add_child(island)
	session = SESSION_SCENE.instantiate() as CoopSession
	session.terrain = island.terrain
	session.climate = island.climate
	session.sky = WeatherManager.sky
	if not as_client:
		# A run starts on day 1 at dawn, calm, before the island's creatures read the hour, and
		# with a seed of its own (endings-progression "A fresh run starts clean").
		WeatherManager.sky.start_at(RUN_START_TIME_S)
		session.world_state = {"run_seed": seed_source.call()}
	session.spawn_points = island.spawn_points(solo)
	session.player_spawned.connect(_on_player_spawned)
	session.local_identity = settings.identity
	session.removal_recorded.connect(_on_removal_recorded)
	session.host_lost.connect(_on_host_lost)
	_world.add_child(session)
	island.furnish(session)
	travel = IslandTravel.new()
	travel.name = "Travel"
	session.add_child(travel)
	travel.setup(session, island)
	travel.island_loaded.connect(_on_island_loaded)
	travel.left_the_chain.connect(_check_run_over)
	var routes := session.get_node(^"Routes") as IslandRoutes
	routes.route_started.connect(_on_route_started)
	routes.progress_received.connect(_on_progress_received)
	if not as_client:
		island.place_pickups(session)


func _enter_run() -> void:
	_joining = false
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
	hud.world_view = world_view
	add_child(hud)
	hud.bind(session, session.multiplayer.get_unique_id(), session.multiplayer.multiplayer_peer is OfflineMultiplayerPeer)
	# The run menu (run-menu design D1): its Ajustes saves into these settings, and "Abandonar"
	# leaves as "Volver al inicio" does, for every role (design D5). Deferred: the menu is freed
	# with the HUD.
	var menu: PauseMenu = hud.pause_menu
	menu.settings = settings
	menu.abandon_confirmed.connect(back_to_title, CONNECT_DEFERRED)
	menu.display_changed.connect(_on_display_changed)
	menu.flashes_changed.connect(apply_flashes)
	# sound-pass: this peer's cues; freed with the HUD, which stops every loop when the run ends.
	var sounds := RunSounds.new()
	hud.add_child(sounds)
	sounds.bind(session, session.multiplayer.get_unique_id(), hud.needle)
	_wait_label = _make_wait_label()
	hud.add_child(_wait_label)


# Freed at once, before the peer is closed: closing a peer under live synchronizers logs
# engine errors.
func _end_run() -> void:
	WeatherManager.stop()
	# The pause menu may have paused the tree under the summary.
	get_tree().paused = false
	if tint != null:
		tint.free()
		tint = null
	if hud != null:
		hud.free()
		hud = null
	_wait_label = null
	travel = null
	crossings.clear()
	crossing_results.clear()
	if session != null:
		session.free()
		session = null
	if island != null:
		island.free()
		island = null


func _on_removal_recorded(_peer_id: int, _player_name: String) -> void:
	_check_run_over()


func _on_player_spawned(_peer_id: int, body: PlayerBody) -> void:
	body.meters.died.connect(_check_run_over)
	# The camera stays over the island, never past its edge.
	IslandArrival.fit_camera(body, island.bounds)


# The riders of a started route enter the crossing on every peer; it keeps the run open until it
# ends.
func _on_route_started(route_id: StringName, peer_ids: Array[int]) -> void:
	var routes := session.get_node(^"Routes") as IslandRoutes
	var route := GameState.content.get_entry(&"routes", route_id) as RouteData
	if route == null:
		return
	var integrity: float = routes.departure_integrity.get(route_id, float(route.vessel_integrity))
	var crossing := Crossing.launch(session, route, peer_ids, integrity, DataEnums.DistanceBand.COAST, _crossing_rng)
	CrossingCreatures.attach(crossing, island.layout.chain_family, DataEnums.DistanceBand.COAST)
	crossing.ended.connect(_on_crossing_ended.bind(crossing))
	crossings.append(crossing)
	_check_run_over()


# A joiner (crossing-late-join): the crossings under way it restored are followed like launched
# ones, and riders whose crossing ended before the join leave play here too.
func _on_progress_received(restored: Array[Crossing]) -> void:
	for crossing: Crossing in restored:
		if not crossings.has(crossing):
			crossing.ended.connect(_on_crossing_ended.bind(crossing))
			crossings.append(crossing)
	var routes := session.get_node(^"Routes") as IslandRoutes
	for peer_id: int in routes.departed:
		var rider := session.body(peer_id)
		if rider != null and not _in_crossing(peer_id):
			IslandArrival.hold(rider)
	_check_run_over()


# The riders wait out of play on the shore; the island keeper loads the next island once nobody
# else is playing (or the run ends if there is none).
func _on_crossing_ended(finished: CrossingResult, crossing: Crossing) -> void:
	crossings.erase(crossing)
	crossing_results.append(finished)
	if session != null:
		travel.crossing_ended(finished)
	crossing.queue_free()
	_check_run_over()


# Whether `peer_id` rides a crossing this shell follows (crossing-late-join).
func _in_crossing(peer_id: int) -> bool:
	for node: Node in crossings:
		if is_instance_valid(node) and (node as Crossing).peers().has(peer_id):
			return true
	return false


# The next island is live: this is its node and its routes now.
func _on_island_loaded(loaded: SandbarIsland) -> void:
	island = loaded
	var routes := session.get_node(^"Routes") as IslandRoutes
	routes.route_started.connect(_on_route_started)
	routes.progress_received.connect(_on_progress_received)


# The run ends when nobody is left playing and no island is next: every player is dead, or has
# left by a route on an island that names no next one. A dropped player keeps it open until they
# are removed (they may come back); the removal checks again.
func _check_run_over() -> void:
	if flow != Flow.RUN or session == null:
		return
	if travel.check() != IslandTravel.Outcome.OVER:
		return
	var solo: bool = session.multiplayer.multiplayer_peer is OfflineMultiplayerPeer
	var made := RunSummary.collect(session, travel.islands_reached, WeatherManager.sky.clock.day,
			clock.call() - _run_started_s, death_lines, GameState.content)
	WeatherManager.stop()
	# The HUD (and its pause menu) goes with the run: nothing under the summary can pause it. It
	# stops taking input first, so no key reaches it in the frame before it is freed (inventory-hud).
	if hud != null:
		hud.set_screen_shown(true)
		hud.queue_free()
		hud = null
	_wait_label = null
	var hosting: bool = not solo and session.multiplayer.is_server()
	var summary := _show(SUMMARY_SCENE, Flow.SUMMARY) as SummaryScreen
	# Solo starts again alone; a co-op host starts a rematch; a client waits for the host.
	summary.show_summary(made, "Otra vez" if solo or hosting else "")
	if not solo and not hosting:
		summary.show_waiting_for_host()
	summary.home_requested.connect(back_to_title)
	summary.restart_requested.connect(_restart_solo if solo else _rematch)


func _process(_delta: float) -> void:
	if _wait_label != null and session != null:
		var text: String = waiting_text(session)
		_wait_label.text = text
		_wait_label.visible = not text.is_empty()


## What this peer's rider sees while waiting on the shore after their crossing ended: who is still
## playing, a disconnected one marked (escape-routes "Split parties"). "" for anyone not waiting.
static func waiting_text(run_session: CoopSession) -> String:
	var own := run_session.body(run_session.multiplayer.get_unique_id())
	if own == null or not own.left_island or own.meters.dead:
		return ""
	var names: Array[String] = []
	for peer_id: int in run_session.peer_ids():
		var other := run_session.body(peer_id)
		if not other.left_island and not other.meters.dead:
			var shown: String = run_session.player_name(peer_id)
			if run_session.is_dropped(peer_id):
				shown += " (desconectado)"
			names.append(shown)
	if names.is_empty():
		return ""
	return "En la orilla. Esperando a: %s" % ", ".join(names)


func _make_wait_label() -> Label:
	var label := Label.new()
	label.name = "WaitLabel"
	label.visible = false
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.anchor_right = 1.0
	label.offset_top = 48.0
	return label


func _show(scene: PackedScene, next: Flow) -> Control:
	_close_screen()
	screen = scene.instantiate() as Control
	_backdrop.visible = next != Flow.TITLE and next != Flow.SUMMARY
	_screens.add_child(screen)
	flow = next
	return screen


func _close_screen() -> void:
	if screen != null:
		# A screen on its way out keeps no focus: a text field it held (the first-launch name)
		# would otherwise read as typing until it is freed (run-menu design D7).
		var focused: Control = get_viewport().gui_get_focus_owner() if is_inside_tree() else null
		if focused != null and screen.is_ancestor_of(focused):
			focused.release_focus()
		screen.queue_free()
		screen = null
	_backdrop.visible = false


func _ticks_s() -> float:
	return Time.get_ticks_usec() / 1000000.0


func _roll_seed() -> int:
	return randi()
