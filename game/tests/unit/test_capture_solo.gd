extends GutTest
## guardacostas-capture, group 7 (specs "Chase and shore squad", "Squad search", "Soldier sight",
## "Boat chase at sea", "The squad leaves"), with exactly 1 player, offline, on the real sandbar. The
## player is driven by the named input actions only; the boat's clock is set by hand, as
## test_patrol_solo.gd does, so it is in sight where the test needs it.
## - Spotted at night on open sand, the player runs inland until the light loses them and crouches in
##   scrub away from where they were lost: the squad never finds them, leaves after its 180 s and
##   the boat resumes its lap.
## - Crouching 1 tile from their own fire by day: the squad lands, a soldier searches the fire and
##   runs at them.
## - Spotted by a soldier 3 tiles behind, they run straight away and the soldier loses them.
## - Swimming in deep water, they are chased and hauled aboard; swimming for the shallows instead,
##   the chase breaks.
## - A day fire 5 tiles from the sea brings the squad, and the fire is its first point.

const SHELL_SCENE: PackedScene = preload("res://scenes/shell/game_shell.tscn")
const FIRE_SCENE: PackedScene = preload("res://scenes/structures/fire.tscn")
const SETTINGS_PATH: String = "user://test_capture_solo_settings.cfg"
const DT: float = 1.0 / 30.0
const IDLE_DT: float = 0.1
const TILE: float = 16.0
const STEER_PX: float = 1.0
const AT_TARGET_PX: float = 3.0
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
var _pressed: Dictionary[StringName, bool] = {}


func before_each() -> void:
	NetManager.start_solo()
	WeatherManager.stop()
	WeatherManager.sky.start_at(0.0)
	alerts = []


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
	boat = spawner.creatures(&"patrol_boat")[0]
	brain = boat.brain as PatrolRoute
	patrol = boat.data.patrol
	boat.patrol_alerted.connect(func(cause: StringName, _at: Vector2) -> void: alerts.append(cause))
	_clock(patrol.horizon_warning_s + patrol.route_lap_s + 1.0)
	land = AStarGrid2D.new()
	land.region = Rect2i(Vector2i.ZERO, island.built.size)
	land.cell_size = Vector2.ONE
	land.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	land.update()
	for y: int in island.built.size.y:
		for x: int in island.built.size.x:
			land.set_point_solid(Vector2i(x, y), TerrainQuery.is_water(island.terrain.terrain_at(Vector2i(x, y))))


func _clock(seconds: float) -> void:
	brain.set_clock(seconds)
	boat.advance(0.0)


# One frame in the engine's order: input, the body, the boat, the soldiers, the meter watch.
func _frame(dt: float = DT) -> void:
	body.player_input._physics_process(dt)
	body.net._physics_process(dt)
	body._physics_process(dt)
	boat.advance(dt)
	for creature: Creature in spawner.creatures():
		if creature != boat:
			creature.advance(dt)
	spawner._physics_process(dt)


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


func _steer(toward: Vector2) -> void:
	var gap: Vector2 = toward - body.global_position
	_act(&"move_right", gap.x > STEER_PX)
	_act(&"move_left", gap.x < -STEER_PX)
	_act(&"move_down", gap.y > STEER_PX)
	_act(&"move_up", gap.y < -STEER_PX)


func _stop() -> void:
	for action: StringName in MOVES:
		_act(action, false)


func _cell_of(at: Vector2) -> Vector2i:
	return Vector2i(floori(at.x / TILE), floori(at.y / TILE))


# Walks (or runs, or crouches, by the actions held) over land to `goal_cell`, input only.
func _walk_to(goal_cell: Vector2i, each_frame: Callable = Callable()) -> bool:
	var path := land.get_id_path(_cell_of(body.global_position), goal_cell)
	var waypoints: Array[Vector2] = []
	for i: int in range(1, path.size()):
		waypoints.append(IslandLayout.cell_center(path[i]))
	var budget: int = maxi(MIN_WALK_FRAMES, ceili(body.global_position.distance_to(IslandLayout.cell_center(goal_cell)) * FRAMES_PER_PX * 3.0))
	for waypoint: Vector2 in waypoints:
		while body.global_position.distance_to(waypoint) > AT_TARGET_PX:
			_steer(waypoint)
			_frame()
			if each_frame.is_valid():
				each_frame.call()
			budget -= 1
			if budget <= 0:
				_stop()
				return false
	_stop()
	_frame()
	return true


func _light_fire(cell: Vector2i) -> Fire:
	var lit := FIRE_SCENE.instantiate() as Fire
	lit.position = IslandLayout.cell_center(cell)
	session.add_child(lit)
	lit.light()
	return lit


func _soldiers() -> Array[Creature]:
	return brain.soldiers


func _land_cells() -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for cell: Vector2i in island.built.terrain.cells:
		if not TerrainQuery.is_water(island.built.terrain.cells[cell]):
			cells.append(cell)
	cells.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return a.y < b.y or (a.y == b.y and a.x < b.x))
	return cells


func _is(cell: Vector2i, terrain: DataEnums.Terrain) -> bool:
	return island.built.terrain.cells.get(cell, DataEnums.Terrain.DEEP) == terrain


# Runs frames until `done` or `limit_s` seconds pass (IDLE_DT frames). True if it happened.
func _until(done: Callable, limit_s: float, dt: float = IDLE_DT) -> bool:
	var seconds: float = 0.0
	while not done.call():
		if seconds >= limit_s:
			return false
		_frame(dt)
		seconds += dt
	return true


# The first lap time (0.1 s steps) from which the light covers `point_px` for `hold_s` running.
func _lit_from(point_px: Vector2, hold_s: float) -> float:
	var run: float = 0.0
	var t: float = 0.0
	while t < patrol.route_lap_s:
		_clock(patrol.horizon_warning_s + t)
		if brain.lights(point_px):
			run += 0.1
			if run >= hold_s - 0.0001:
				return t - run + 0.1
		else:
			run = 0.0
		t += 0.1
	return -1.0


# --- spotted at night, hidden away, the squad leaves ------------------------------------------------

func test_spotted_at_night_running_inland_and_crouching_in_scrub_outlasts_the_squad() -> void:
	await _start(NIGHT_S)
	# Open sand that the light falls on for 3 s, with scrub at least 14 tiles from where the boat is
	# then and 5 tiles from the sand.
	var sand: Vector2i = Vector2i(-1, -1)
	var start_t: float = -1.0
	var hide: Vector2i = Vector2i(-1, -1)
	# The open sand nearest the boat's loop, tried nearest first.
	var loop := PatrolLoop.build(island.terrain, island.built.size, patrol.route_lap_s, patrol.route_offshore_tiles)
	var shore: Array[Vector2i] = []
	for cell: Vector2i in _land_cells():
		if _is(cell, DataEnums.Terrain.BEACH) and not island.terrain.is_shaded(cell):
			shore.append(cell)
	var near_loop := func(cell: Vector2i) -> float:
		var best: float = INF
		for i: int in int(loop.lap_s / 5.0):
			best = minf(best, IslandLayout.cell_center(cell).distance_to(loop.pose_px(i * 5.0)))
		return best
	var gaps: Dictionary[Vector2i, float] = {}
	for cell: Vector2i in shore:
		gaps[cell] = near_loop.call(cell)
	shore.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return gaps[a] < gaps[b])
	for cell: Vector2i in shore.slice(0, 30):
		var t: float = _lit_from(IslandLayout.cell_center(cell), 3.0)
		if t < 0.0:
			continue
		_clock(patrol.horizon_warning_s + t)
		for scrub: Vector2i in _land_cells():
			if not _is(scrub, DataEnums.Terrain.SCRUB):
				continue
			var from_boat: float = IslandLayout.cell_center(scrub).distance_to(boat.position) / TILE
			if from_boat >= 14.0 and Vector2(scrub - cell).length() >= 5.0 and land.get_id_path(cell, scrub).size() > 0:
				hide = scrub
				break
		if hide.x >= 0:
			sand = cell
			start_t = t
			break
	assert_gte(start_t, 0.0, "the night light falls on some open sand with scrub far inland")
	_clock(patrol.horizon_warning_s + patrol.route_lap_s + 1.0)
	assert_true(_walk_to(sand), "walked to the sand")
	_clock(patrol.horizon_warning_s + start_t)
	assert_true(_until(func() -> bool: return alerts.has(&"sight"), 4.0, DT), "spotted on the sand")
	assert_eq(boat.state_name(), &"DOCKED", "a spot on land brings the squad")
	# Run inland (the lock breaks past 10 tiles), then crouch the last steps onto the scrub.
	_act(&"run", true)
	var lost_at: Array[Vector2i] = []
	var watch_lock := func() -> void:
		if brain.locked == null and lost_at.is_empty():
			lost_at.append(_cell_of(body.global_position))
	assert_true(_walk_to(hide, watch_lock), "ran to the scrub")
	_act(&"run", false)
	_act(&"crouch", true)
	_frame()
	assert_eq(body.stealth_state, MovementStep.Stealth.HIDDEN, "crouched in the scrub")
	assert_false(lost_at.is_empty(), "the light lost them on the way")
	assert_gt(Vector2(hide - lost_at[0]).length(), patrol.point_search_tiles, "more than 2 tiles from where they were lost")
	# The squad lands, searches and walks the island for its 180 s, then rows out.
	assert_true(_until(func() -> bool: return boat.squad_state == PatrolRoute.Squad.ASHORE, 15.0), "the squad lands")
	assert_true(_until(func() -> bool: return boat.state_name() == &"LAP", patrol.search_duration_s + 90.0), "the squad leaves and the boat resumes its lap")
	assert_false(body.captive, "never found")
	assert_eq(body.stealth_state, MovementStep.Stealth.HIDDEN)
	assert_eq(boat.squad_state, PatrolRoute.Squad.NONE)


# --- hiding by your own fire ----------------------------------------------------------------------

func _scrub_beside_beach() -> Array[Vector2i]:
	for cell: Vector2i in _land_cells():
		if not _is(cell, DataEnums.Terrain.SCRUB):
			continue
		for step: Vector2i in CreatureNav.STEPS_4:
			if _is(cell + step, DataEnums.Terrain.BEACH) and not island.terrain.is_shaded(cell + step):
				return [cell, cell + step] as Array[Vector2i]
	return [] as Array[Vector2i]


func test_hiding_1_tile_from_your_own_fire_is_found_when_a_soldier_searches_it() -> void:
	await _start(DAY_S)
	var pair := _scrub_beside_beach()
	assert_eq(pair.size(), 2)
	assert_true(_walk_to(pair[0]), "walked onto the scrub")
	_act(&"crouch", true)
	_frame()
	assert_eq(body.stealth_state, MovementStep.Stealth.HIDDEN)
	_light_fire(pair[1])
	_clock(patrol.horizon_warning_s + 1.0)
	assert_true(_until(func() -> bool: return boat.state_name() == &"DOCKED", 3.0), "the smoke brings the squad")
	assert_true(_until(func() -> bool: return boat.squad_state == PatrolRoute.Squad.ASHORE, 15.0))
	assert_eq(brain.plan.points[0].cell, pair[1], "the fire is the first point")
	var found := func() -> bool:
		for soldier: Creature in _soldiers():
			if (soldier.brain as SearchCapture).target == body:
				return true
		return false
	assert_true(_until(found, 90.0), "a soldier searches the fire and runs at them")


# --- outrunning a soldier ---------------------------------------------------------------------------

# The start of the longest straight run of open land along a row (no water, no scrub), and its length.
func _straight_run() -> Array:
	var best: Vector2i = Vector2i(-1, -1)
	var best_len: int = 0
	for y: int in island.built.size.y:
		var length: int = 0
		for x: int in island.built.size.x:
			var cell := Vector2i(x, y)
			var open: bool = (_is(cell, DataEnums.Terrain.BEACH) or _is(cell, DataEnums.Terrain.DUNE)) and not island.terrain.is_shaded(cell)
			length = length + 1 if open else 0
			if length > best_len:
				best_len = length
				best = Vector2i(x - length + 1, y)
	return [best, best_len]


func test_running_straight_away_outruns_a_soldier() -> void:
	await _start(DAY_S)
	var run := _straight_run()
	var start: Vector2i = run[0]
	assert_gte(run[1], 16, "a 16-tile open stretch")
	# Land the squad with a smoke alert far from the stretch, then pick one soldier.
	var pair := _scrub_beside_beach()
	_light_fire(pair[1])
	_clock(patrol.horizon_warning_s + 1.0)
	assert_true(_until(func() -> bool: return boat.squad_state == PatrolRoute.Squad.ASHORE, 18.0))
	assert_true(_walk_to(start + Vector2i(3, 0)), "on the stretch")
	var soldier: Creature = _soldiers()[0]
	soldier.position = IslandLayout.cell_center(start)
	soldier.facing = Vector2.RIGHT
	(soldier.brain as SearchCapture).spot(soldier, body)
	assert_eq(soldier.state_name(), &"CHASE")
	_act(&"run", true)
	_act(&"move_right", true)
	var seconds: float = 0.0
	while soldier.state_name() == &"CHASE" and seconds < 6.0:
		_frame()
		seconds += DT
	_stop()
	_act(&"run", false)
	assert_ne(soldier.state_name(), &"CHASE", "the chase broke")
	assert_false(body.captive)
	assert_almost_eq(seconds, 3.0, 0.6, "3 tiles of lead grow past 6 in about 3 s")
	assert_ne((soldier.brain as SearchCapture).lost_at, SearchCapture.NO_CELL, "it searches where it last saw them")


# --- at sea -----------------------------------------------------------------------------------------

# Walks to the east shore nearest the loop's start and swims out to it; true when swimming there.
func _swim_out() -> Vector2:
	var loop := PatrolLoop.build(island.terrain, island.built.size, patrol.route_lap_s, patrol.route_offshore_tiles)
	var start: Vector2 = loop.pose_px(0.0)
	var shore: Vector2i = Vector2i(-1, -1)
	for cell: Vector2i in _land_cells():
		if not _is(cell, DataEnums.Terrain.BEACH) and not _is(cell, DataEnums.Terrain.DUNE):
			continue
		if shore.x < 0 or IslandLayout.cell_center(cell).distance_to(start) < IslandLayout.cell_center(shore).distance_to(start):
			shore = cell
	assert_true(_walk_to(shore))
	var budget: int = 600
	while body.global_position.distance_to(start) > AT_TARGET_PX and budget > 0:
		_steer(start)
		_frame()
		budget -= 1
	_stop()
	return start


func test_a_swimmer_in_deep_water_is_chased_and_hauled_aboard() -> void:
	await _start(DAY_S)
	var start: Vector2 = _swim_out()
	assert_eq(body.movement_state, MovementStep.Move.SWIM)
	assert_eq(island.terrain.terrain_at(_cell_of(body.global_position)), DataEnums.Terrain.DEEP)
	# The boat comes round 5 tiles off: spotted by the water rule, chased.
	var loop := PatrolLoop.build(island.terrain, island.built.size, patrol.route_lap_s, patrol.route_offshore_tiles)
	var at_t: float = -1.0
	for i: int in int(patrol.route_lap_s * 10.0):
		if loop.pose_px(i * 0.1).distance_to(body.global_position) / TILE <= 5.0:
			at_t = i * 0.1
			break
	assert_gte(at_t, 0.0)
	_clock(patrol.horizon_warning_s + at_t)
	# Keep swimming out to sea.
	var away: Vector2 = (start - Vector2(island.built.size) * TILE / 2.0).normalized()
	_act(&"move_right", away.x > 0.3)
	_act(&"move_left", away.x < -0.3)
	_act(&"move_down", away.y > 0.3)
	_act(&"move_up", away.y < -0.3)
	assert_true(_until(func() -> bool: return body.captive, 10.0, DT), "hauled aboard")
	_stop()
	assert_true(body.captive_aboard, "aboard the boat")
	assert_false(body.can_be_freed(), "nobody can free a swimmer hauled aboard")
	assert_eq(alerts.count(&"water"), 1)


func test_swimming_for_the_shallows_breaks_the_chase() -> void:
	await _start(DAY_S)
	_swim_out()
	var loop := PatrolLoop.build(island.terrain, island.built.size, patrol.route_lap_s, patrol.route_offshore_tiles)
	var at_t: float = -1.0
	for i: int in int(patrol.route_lap_s * 10.0):
		if loop.pose_px(i * 0.1).distance_to(body.global_position) / TILE <= 5.5:
			at_t = i * 0.1
			break
	_clock(patrol.horizon_warning_s + at_t)
	assert_true(_until(func() -> bool: return boat.state_name() == &"CHASE", 2.0, DT), "chased")
	# Swim straight back to the beach: the shallows are about 2 to 4 tiles in.
	var centre: Vector2 = Vector2(island.built.size) * TILE / 2.0
	var shallows_reached: Array[bool] = [false]
	var chase_over := func() -> bool:
		_steer(centre)
		if island.terrain.terrain_at(_cell_of(body.global_position)) == DataEnums.Terrain.SHALLOWS:
			shallows_reached[0] = true
		return boat.state_name() != &"CHASE"
	assert_true(_until(chase_over, 6.0, DT), "the chase breaks")
	_stop()
	assert_true(shallows_reached[0], "in the shallows")
	assert_false(body.captive, "nobody hauled aboard")


# --- a day fire -------------------------------------------------------------------------------------

func test_a_day_fire_5_tiles_from_the_sea_brings_the_squad_and_is_its_first_point() -> void:
	await _start(DAY_S)
	var triggers := PatrolTriggers.build(island.terrain, island.built.size, patrol)
	var fire_cell: Vector2i = Vector2i(-1, -1)
	for cell: Vector2i in _land_cells():
		if (_is(cell, DataEnums.Terrain.BEACH) or _is(cell, DataEnums.Terrain.DUNE)) and absf(triggers.distance_at(cell) - 5.0) < 0.5:
			fire_cell = cell
			break
	assert_ne(fire_cell, Vector2i(-1, -1), "a cell 5 tiles from the sea")
	_light_fire(fire_cell)
	_clock(patrol.horizon_warning_s + 1.0)
	assert_true(_until(func() -> bool: return alerts.has(&"smoke"), 3.0), "the smoke alert")
	assert_eq(alerts.count(&"sight"), 0, "with no player spotted")
	assert_eq(boat.state_name(), &"DOCKED")
	assert_true(_until(func() -> bool: return boat.squad_state == PatrolRoute.Squad.ASHORE, 15.0), "a squad lands")
	assert_eq(brain.plan.points[0].cell, fire_cell, "the fire is the first point it searches")
	assert_eq(_soldiers().size(), 3)
