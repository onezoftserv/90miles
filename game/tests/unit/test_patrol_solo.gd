extends GutTest
## guardacostas-stealth tasks 7.3: the patrol with exactly 1 player, offline. A real sandbar run through
## the game shell (NetManager.start_solo), the player driven by the named input actions alone (move_*,
## crouch), as test_hidden_solo.gd does: (a) a whole night hidden in the hut with a lit fire there, never
## spotted; (b) spotted on open sand at 2 s, locked, then to the scrub and crouch: not spotted again and
## the boat resumes its lap 20 s after the lock broke; (c) a beach fire alerts once per lap and not when
## put out on the horizon; (d) a swimmer 5 tiles from the boat by day is spotted at once and a diver 3
## tiles away is not; (e) fog: no light, never spotted on open sand; (f) a squall: no boat in sight;
## (g) the secret cay has no patrol. The boat's clock is set by hand to reach a lap quickly and the
## patrol logic is stepped by hand, but every posture and position the player has comes from the
## input path and the movement model.

const SHELL_SCENE: PackedScene = preload("res://scenes/shell/game_shell.tscn")
const FIRE_SCENE: PackedScene = preload("res://scenes/structures/fire.tscn")
const FOG: WeatherData = preload("res://tests/fixtures/content/weather/fog_test.tres")
const SECRET_SCENE: PackedScene = preload("res://scenes/dev/secret_cay_playground.tscn")
const SETTINGS_PATH: String = "user://test_patrol_solo_settings.cfg"
const DT: float = 1.0 / 30.0
const IDLE_DT: float = 0.1
const TILE: float = 16.0
const AT_TARGET_PX: float = 3.0
const AT_WAYPOINT_PX: float = 3.0
const STEER_PX: float = 1.0
const FRAMES_PER_PX: float = 2.0
const MIN_WALK_FRAMES: int = 120
const NIGHT_S: float = 430.0
const DAY_S: float = 100.0
const MOVES: Array[StringName] = [&"move_left", &"move_right", &"move_up", &"move_down"]

var shell: GameShell
var session: CoopSession
var island: SandbarIsland
var body: PlayerBody
var spawner: CreatureSpawner
var boat: Creature
var brain: PatrolRoute
var patrol: PatrolData
var land: AStarGrid2D
var alerts: Array[StringName] = []
var max_meter: float = 0.0
var lit_ticks: int = 0
var light_ticks: int = 0
var _pressed: Dictionary[StringName, bool] = {}


func before_each() -> void:
	NetManager.start_solo()
	WeatherManager.stop()
	WeatherManager.sky.start_at(0.0)
	alerts = []
	max_meter = 0.0
	lit_ticks = 0
	light_ticks = 0


func after_each() -> void:
	for action: StringName in _pressed.keys():
		_act(action, false)
	_pressed.clear()
	WeatherManager.sky.weather.rolls_enabled = true
	WeatherManager.sky.start_at(0.0)
	WeatherManager.stop()
	NetManager.leave()
	if FileAccess.file_exists(SETTINGS_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SETTINGS_PATH))


# --- the run -------------------------------------------------------------------------------------

# A solo run on the sandbar at `at_s` seconds since dawn, with its one boat parked in AWAY.
func _start(at_s: float) -> void:
	shell = SHELL_SCENE.instantiate() as GameShell
	shell.settings_path = SETTINGS_PATH
	add_child_autofree(shell)
	(shell.screen as TitleScreen).solo_requested.emit()
	session = shell.session
	island = shell.island
	body = session.body(CoopSession.HOST_ID)
	WeatherManager.sky.weather.rolls_enabled = false
	await wait_physics_frames(3)
	WeatherManager.stop()
	WeatherManager.sky.start_at(at_s)
	spawner = session.get_node(NodePath(SandbarIsland.CREATURES_NAME)) as CreatureSpawner
	spawner.apply_phase(WeatherManager.phase())
	var boats := spawner.creatures(&"patrol_boat")
	assert_eq(boats.size(), 1, "a solo run on the sandbar has exactly one patrol boat")
	boat = boats[0]
	brain = boat.brain as PatrolRoute
	patrol = boat.data.patrol
	boat.patrol_alerted.connect(_on_alerted)
	_clock(patrol.horizon_warning_s + patrol.route_lap_s + 1.0)
	_build_land()


func _on_alerted(cause: StringName, _at: Vector2) -> void:
	alerts.append(cause)


func _clock(seconds: float) -> void:
	brain.set_clock(seconds)
	boat.advance(0.0)


# One frame of `dt` in the engine's order: the input to an intent, the host stepping the body, then
# the island's boat and its meter watch.
func _frame(dt: float = DT) -> void:
	body.player_input._physics_process(dt)
	body.net._physics_process(dt)
	body._physics_process(dt)
	boat.advance(dt)
	spawner._physics_process(dt)
	max_meter = maxf(max_meter, body.spot_meter.value)
	if boat.light_on:
		light_ticks += 1
		if brain.lights(body.global_position):
			lit_ticks += 1


func _idle(seconds: float) -> void:
	for i: int in roundi(seconds / IDLE_DT):
		_frame(IDLE_DT)


func _act(action: StringName, pressed: bool) -> void:
	if _pressed.get(action, false) == pressed:
		return
	_pressed[action] = pressed
	var event := InputEventAction.new()
	event.action = action
	event.pressed = pressed
	event.strength = 1.0 if pressed else 0.0
	Input.parse_input_event(event)
	Input.flush_buffered_events()


func _build_land() -> void:
	land = AStarGrid2D.new()
	land.region = Rect2i(Vector2i.ZERO, island.built.size)
	land.cell_size = Vector2.ONE
	land.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	land.update()
	for y: int in island.built.size.y:
		for x: int in island.built.size.x:
			var cell := Vector2i(x, y)
			land.set_point_solid(cell, TerrainQuery.is_water(island.terrain.terrain_at(cell)))


func _cell_of(at: Vector2) -> Vector2i:
	return Vector2i(floori(at.x / TILE), floori(at.y / TILE))


func _steer(toward: Vector2) -> void:
	var gap: Vector2 = toward - body.global_position
	_act(&"move_right", gap.x > STEER_PX)
	_act(&"move_left", gap.x < -STEER_PX)
	_act(&"move_down", gap.y > STEER_PX)
	_act(&"move_up", gap.y < -STEER_PX)


func _stop() -> void:
	for action: StringName in MOVES:
		_act(action, false)


# Walks over land, cell centre to cell centre, to the middle of `goal_cell`, holding only the move
# actions. Returns false if it took too long.
func _walk_to(goal_cell: Vector2i) -> bool:
	var goal: Vector2 = IslandLayout.cell_center(goal_cell)
	var path := land.get_id_path(_cell_of(body.global_position), goal_cell)
	var waypoints: Array[Vector2] = []
	for i: int in range(1, path.size() - 1):
		waypoints.append(IslandLayout.cell_center(path[i]))
	waypoints.append(goal)
	var budget: int = maxi(MIN_WALK_FRAMES, ceili(body.global_position.distance_to(goal) * FRAMES_PER_PX * 2.0))
	for i: int in waypoints.size():
		var tolerance: float = AT_TARGET_PX if i == waypoints.size() - 1 else AT_WAYPOINT_PX
		while body.global_position.distance_to(waypoints[i]) > tolerance:
			_steer(waypoints[i])
			_frame()
			budget -= 1
			if budget <= 0:
				_stop()
				return false
	_stop()
	_frame()
	return true


func _hut_cell() -> Vector2i:
	return island.built.hut_cells[island.built.hut_cells.size() / 2]


func _light_fire(cell: Vector2i) -> Fire:
	var lit := FIRE_SCENE.instantiate() as Fire
	lit.position = IslandLayout.cell_center(cell)
	session.add_child(lit)
	lit.light()
	return lit


func _count(cause: StringName) -> int:
	return alerts.count(cause)


# --- (a) a whole night -----------------------------------------------------------------------------

func test_a_whole_night_in_the_hut_with_a_fire_is_never_spotted() -> void:
	await _start(NIGHT_S)
	assert_eq(spawner.world.phase, DataEnums.DayPhase.NIGHT)
	var hut: Vector2i = _hut_cell()
	assert_true(_walk_to(hut), "the player walked to the hut")
	var fire_cell: Vector2i = island.built.hut_cells[0]
	if fire_cell == hut:
		fire_cell = island.built.hut_cells[1]
	var fire := _light_fire(fire_cell)
	assert_true(fire.lit)
	assert_true(island.terrain.is_shaded(fire_cell), "the fire is under the hut's roof")
	_clock(0.0)
	_idle(300.0)
	assert_eq(body.stealth_state, MovementStep.Stealth.HIDDEN, "hidden in the hut all night")
	assert_gt(brain.history.count(&"LAP"), 0, "the boat made at least one lap")
	assert_gt(light_ticks, 0, "its light was on")
	assert_eq(alerts.size(), 0, "no alert of any kind: no sight spot and no smoke alert")
	assert_eq(max_meter, 0.0, "the meter never filled")
	assert_eq(boat.alert_serial, 0)
	gut.p("hut lit ticks %d of light ticks %d" % [lit_ticks, light_ticks])


# --- (b) spotted, hide and get away -----------------------------------------------------------------

# A cell of open sand with scrub within 3 tiles whose lap has the light on it for 3.6 s running, after
# a dark second: {cell, scrub, start_s}. Found with the real loop, beam and light, nearest the landing
# first, so the walk there is short.
func _find_spot() -> Dictionary:
	var loop := PatrolLoop.build(island.terrain, island.built.size, patrol.route_lap_s, patrol.route_offshore_tiles)
	var light := Searchlight.from_patrol(patrol)
	var steps: int = roundi(patrol.route_lap_s / IDLE_DT)
	var poses: Array[Vector2] = []
	var beams: Array[float] = []
	for i: int in steps:
		var t: float = i * IDLE_DT
		var at: Vector2 = loop.pose_at(t)
		poses.append(at)
		beams.append(light.beam_deg(at, loop.centroid, t))
	var scrubs: Array[Vector2i] = []
	var sands: Array[Vector2i] = []
	for cell: Vector2i in island.built.terrain.cells:
		match island.built.terrain.cells[cell]:
			DataEnums.Terrain.SCRUB:
				scrubs.append(cell)
			DataEnums.Terrain.BEACH, DataEnums.Terrain.DUNE:
				if not island.terrain.is_shaded(cell):
					sands.append(cell)
	var from: Vector2i = island.built.solo_spawn
	sands.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return (a - from).length_squared() < (b - from).length_squared())
	var window: int = 36
	for cell: Vector2i in sands:
		var scrub: Vector2i = Vector2i(-1, -1)
		for candidate: Vector2i in scrubs:
			if Vector2(candidate - cell).length() <= 3.0 and (scrub.x < 0 or Vector2(candidate - cell).length() < Vector2(scrub - cell).length()):
				scrub = candidate
		if scrub.x < 0 or land.get_id_path(from, cell).is_empty():
			continue
		var centre := Vector2(cell) + Vector2(0.5, 0.5)
		var run: int = 0
		for i: int in steps:
			if light.is_lit(centre, poses[i], beams[i]):
				run += 1
				if run == window and i - window >= 10:
					return {"cell": cell, "scrub": scrub, "start_s": (i - window + 1) * IDLE_DT}
			else:
				run = 0
	return {}


func test_spotted_on_open_sand_at_2_s_then_scrub_and_crouch_and_the_boat_resumes_its_lap() -> void:
	await _start(NIGHT_S)
	var spot := _find_spot()
	assert_false(spot.is_empty(), "the sandbar has open sand the light dwells on, with scrub within 3 tiles")
	if spot.is_empty():
		return
	var cell: Vector2i = spot["cell"]
	var scrub: Vector2i = spot["scrub"]
	assert_true(_walk_to(cell), "walked to the open sand")
	_frame()
	assert_eq(body.stealth_state, MovementStep.Stealth.VISIBLE, "upright on open sand")
	assert_eq(alerts.size(), 0)
	body.spot_meter.clear()
	_clock(patrol.horizon_warning_s + float(spot["start_s"]))
	var spotted_at: float = -1.0
	for i: int in 150:
		_frame()
		if brain.state == PatrolRoute.State.ALERT_LOCK:
			spotted_at = (i + 1) * DT
			break
	assert_gt(spotted_at, 0.0, "spotted")
	assert_almost_eq(spotted_at, 2.0, 0.15, "at 2 s on the sand in the beam")
	assert_eq(alerts, [&"sight"] as Array[StringName])
	assert_eq(boat.alert_serial, 1, "the loudhailer's first line")
	var stopped_at: float = boat.route_t
	# Out: the 3 tiles to the scrub, then down. The light follows them the whole way.
	assert_true(_walk_to(scrub), "walked to the scrub")
	assert_eq(brain.state, PatrolRoute.State.ALERT_LOCK, "still visible: still locked")
	_act(&"crouch", true)
	var broke: bool = false
	for i: int in 30:
		_frame()
		if brain.state == PatrolRoute.State.ALERT_SEARCH:
			broke = true
			break
	assert_true(broke, "crouching on scrub hides them and the lock breaks")
	assert_eq(body.stealth_state, MovementStep.Stealth.HIDDEN)
	var searched_s: float = 0.0
	while brain.state == PatrolRoute.State.ALERT_SEARCH and searched_s < 25.0:
		_frame()
		searched_s += DT
		assert_eq(body.stealth_state, MovementStep.Stealth.HIDDEN)
	assert_almost_eq(searched_s, patrol.alert_s, 0.15, "20 s later the boat resumes its lap")
	assert_eq(brain.state, PatrolRoute.State.LAP)
	assert_eq(alerts.size(), 1, "never spotted again")
	assert_eq(body.spot_meter.value, 0.0)
	assert_eq(boat.alert_serial, 2, "the give-up line")
	assert_almost_eq(boat.route_t, stopped_at, 0.2, "the lap went on from where it stopped")


# --- (c) a beach fire ---------------------------------------------------------------------------

func test_a_beach_fire_alerts_once_per_lap_and_not_when_put_out_on_the_horizon() -> void:
	await _start(NIGHT_S)
	assert_true(_walk_to(_hut_cell()), "the player waits in the hut, hidden")
	var rules := spawner.world.patrol_triggers(patrol)
	var beach: Vector2i = Vector2i(-1, -1)
	for cell: Vector2i in island.built.terrain.cells:
		var near: float = rules.distance_at(cell)
		if near > 0.5 and near <= 1.1 and not island.terrain.is_shaded(cell):
			beach = cell
			break
	assert_gte(beach.x, 0, "a land cell 1 tile from the sea")
	var fire := _light_fire(beach)
	_clock(0.0)
	_idle(patrol.horizon_warning_s - 1.0)
	assert_eq(_count(&"smoke"), 0, "on the horizon: nothing")
	_idle(5.0)
	assert_eq(_count(&"smoke"), 1, "the boat is in sight: one smoke alert at the fire")
	_idle(190.0)
	assert_eq(_count(&"smoke"), 1, "no second alert for that fire during that lap")
	assert_eq(alerts.size(), 1)
	# The next horizon: put it out.
	var guard: int = 0
	while brain.state != PatrolRoute.State.HORIZON and guard < 4000:
		_idle(IDLE_DT)
		guard += 1
	assert_eq(brain.state, PatrolRoute.State.HORIZON, "the next horizon warning")
	fire.put_out()
	assert_false(fire.lit)
	_idle(190.0)
	assert_eq(_count(&"smoke"), 1, "put out in time: no alert during the lap that followed")
	assert_gt(brain.history.count(&"LAP"), 1, "that lap ran")


# --- (d) a swimmer and a diver ------------------------------------------------------------------

func test_a_swimmer_5_tiles_from_the_boat_by_day_is_spotted_at_once_and_a_diver_3_tiles_away_is_not() -> void:
	await _start(DAY_S)
	var loop := PatrolLoop.build(island.terrain, island.built.size, patrol.route_lap_s, patrol.route_offshore_tiles)
	var start: Vector2 = loop.pose_px(0.0)
	# Land on the east coast, nearest the loop's start, then straight out to it.
	var shore: Vector2i = Vector2i(-1, -1)
	for cell: Vector2i in island.built.terrain.cells:
		var terrain: DataEnums.Terrain = island.built.terrain.cells[cell]
		if terrain != DataEnums.Terrain.BEACH and terrain != DataEnums.Terrain.DUNE:
			continue
		if shore.x < 0 or IslandLayout.cell_center(cell).distance_to(start) < IslandLayout.cell_center(shore).distance_to(start):
			shore = cell
	assert_true(_walk_to(shore), "walked to the east shore")
	var swim_budget: int = 600
	while body.global_position.distance_to(start) > AT_TARGET_PX and swim_budget > 0:
		_steer(start)
		_frame()
		swim_budget -= 1
	_stop()
	assert_eq(body.movement_state, MovementStep.Move.SWIM, "in the deep water")
	assert_eq(alerts.size(), 0, "no boat in sight on the way")
	# Dive, and put the boat 3 tiles away: a diver is not spotted.
	_act(&"crouch", true)
	_frame()
	assert_eq(body.movement_state, MovementStep.Move.DIVE)
	var near_t: float = _lap_time_at_distance(loop, body.global_position, 3.0)
	assert_gte(near_t, 0.0, "the boat passes 3 tiles from the diver")
	_clock(patrol.horizon_warning_s + near_t)
	assert_almost_eq(boat.position.distance_to(body.global_position) / TILE, 3.0, 0.3)
	for i: int in 30:
		_frame()
	assert_eq(body.movement_state, MovementStep.Move.DIVE, "still under")
	assert_eq(alerts.size(), 0, "a diver 3 tiles away is not spotted")
	# Surface with the boat 5 tiles away: spotted at once.
	var far_t: float = _lap_time_at_distance(loop, body.global_position, 5.0)
	assert_gte(far_t, 0.0)
	_clock(patrol.horizon_warning_s + far_t)
	assert_almost_eq(boat.position.distance_to(body.global_position) / TILE, 5.0, 0.3)
	_act(&"crouch", false)
	for i: int in 6:
		_frame()
	assert_eq(body.movement_state, MovementStep.Move.SWIM)
	assert_eq(alerts, [&"water"] as Array[StringName], "a swimmer 5 tiles away is spotted at once, once")


# The lap time (the first in the lap) when the boat is `tiles` from `point_px`, or -1.
func _lap_time_at_distance(loop: PatrolLoop, point_px: Vector2, tiles: float) -> float:
	var best: float = -1.0
	var best_gap: float = 0.2
	for i: int in roundi(patrol.route_lap_s / IDLE_DT):
		var t: float = i * IDLE_DT
		var gap: float = absf(loop.pose_px(t).distance_to(point_px) / TILE - tiles)
		if gap < best_gap:
			best_gap = gap
			best = t
	return best


# --- (e) fog and (f) a squall -----------------------------------------------------------------------

func test_in_fog_there_is_no_light_and_open_sand_all_night_is_never_spotted() -> void:
	await _start(NIGHT_S)
	spawner.world.weather_override = FOG
	_frame()
	assert_eq(body.stealth_state, MovementStep.Stealth.VISIBLE, "upright on the open landing")
	_clock(0.0)
	_idle(200.0)
	assert_gt(brain.history.count(&"LAP"), 0, "the boat lapped the island")
	assert_eq(light_ticks, 0, "no light is ever on")
	assert_eq(alerts.size(), 0, "never spotted")
	assert_eq(max_meter, 0.0)


func test_in_a_squall_no_boat_is_in_sight() -> void:
	await _start(NIGHT_S)
	_clock(patrol.horizon_warning_s + 30.0)
	assert_eq(brain.state, PatrolRoute.State.LAP, "half way through its lap")
	WeatherManager.sky.weather.start_weather(&"squall")
	assert_true(WeatherManager.sky.weather.current.patrols_in_port)
	var sighted: int = 0
	for i: int in 2000:
		_frame(IDLE_DT)
		if brain.in_sight() or boat.light_on:
			sighted += 1
	assert_eq(sighted, 0, "it left at once, light off, and never came back during the squall")
	assert_eq(alerts.size(), 0)


# --- (g) the secret cay -----------------------------------------------------------------------------

func test_the_secret_cay_has_no_patrol() -> void:
	NetManager.leave()
	var scene := SECRET_SCENE.instantiate() as SecretCayPlayground
	add_child_autofree(scene)
	assert_true(scene.start(SecretPlayground.parse_args(PackedStringArray(["--solo"]), PackedStringArray([SecretCayPlayground.WITH_PIECES]))))
	await wait_physics_frames(3)
	var boats: int = 0
	for node: Node in scene.session.entities.get_children():
		var creature := node as Creature
		if creature != null and creature.brain is PatrolRoute:
			boats += 1
	assert_eq(boats, 0, "no patrol boat")
	assert_null(scene.session.get_node_or_null(NodePath(SandbarIsland.CREATURES_NAME)), "no creature spawner at all")
