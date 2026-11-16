class_name PatrolRoute
extends CreatureBrain
## guardacostas-stealth decisions 2 and 9: the patrol boat's machine. The boat owns a clock that runs
## through its loop (HORIZON, then the LAP in sight, then AWAY) and pauses while it alerts. In its LAP
## it stands on PatrolLoop's pose for the lap time and its beam is the Searchlight's sweep. A spot
## (the PatrolWatch's meter, or the water rule), a smoke trigger or a noise stops it: ALERT_LOCK on a
## player the light follows while they are visible and within the searchlight's range, otherwise
## ALERT_SEARCH round the last known position (or the smoke or noise) for `alert_s`, then back to the
## LAP where it stopped. A squall (patrols_in_port) ends any alert and sends it AWAY at once; fog
## blinds the light and the water rule but not smoke or noise. Host only: writes route_t, beam,
## alert_serial and light_on on the Creature for the network group, and emits Creature.patrol_alerted.
## States are append-only: `state` is synced.
##
## guardacostas-capture design.md §1 and §3: a spot of a swimmer in deep water (the water rule, or the
## meter on a swimmer) starts a CHASE instead of a lock. The boat leaves its loop and closes through
## deep water (BoatChase); a haul makes the swimmer a captive aboard, and a dive, the shallows, a
## 10-tile gap or a landing break it into the plain search round where they were. While it searches
## after a chase the boat makes its way back to its loop, and it resumes its lap where it stopped.

enum State {
	AWAY,
	HORIZON,
	LAP,
	ALERT_LOCK,
	ALERT_SEARCH,
	CHASE,
	DOCKED,
}

const EPSILON: float = 0.000001
const TILE: float = 16.0
## How often a boat in sight looks at the fires.
const SMOKE_CHECK_S: float = 1.0
## How far ahead of the boat the facing looks, in seconds of its lap.
const FACING_LOOKAHEAD_S: float = 0.1
## Tiles per second a boat off its loop (after a chase) makes its way back while it searches.
const RETURN_SPEED_TILES_S: float = 3.0

## The boat's seconds into its loop. Pauses during an alert.
var clock_s: float = 0.0
## The player the light follows in ALERT_LOCK, else null.
var locked: PlayerBody = null
## The swimmer the boat chases in CHASE, else null.
var chased: PlayerBody = null
## The swimmers hauled aboard (captives aboard), in the order they were hauled.
var aboard: Array[PlayerBody] = []
var member_index: int = 0
var member_count: int = 1

var _creature: Creature = null
var _world: CreatureWorld = null
var _patrol: PatrolData = null
var _loop: PatrolLoop = null
var _triggers: PatrolTriggers = null
var _light: Searchlight = null
var _search_light: Searchlight = null
var _built: bool = false
var _period_s: float = 0.0
var _phase: PatrolLoop.Phase = PatrolLoop.Phase.AWAY
var _in_port: bool = false
## After a squall: seconds this boat stays out of sight before its clock restarts at 0 (its horizon).
var _restart_wait_s: float = 0.0
var _search_s: float = 0.0
var _smoke_s: float = 0.0
var _aim_px: Vector2 = Vector2.ZERO
var _chase: BoatChase = null


func names() -> Array[StringName]:
	return [&"AWAY", &"HORIZON", &"LAP", &"ALERT_LOCK", &"ALERT_SEARCH", &"CHASE", &"DOCKED"]


## True for a state in which the boat is alerting (its clock paused). Every peer reads the synced
## `state_id` through this, so a client's look and view agree with the host's brain.
static func is_alert_state(value: int) -> bool:
	return value == State.ALERT_LOCK or value == State.ALERT_SEARCH or value == State.CHASE or value == State.DOCKED


## True for a state in which the boat is in sight: its lap or an alert.
static func is_in_sight_state(value: int) -> bool:
	return value == State.LAP or is_alert_state(value)


## Boat `index` of `count` on its island's loop: its clock starts that far behind boat 0's, so the
## horizon warnings are spread evenly (PatrolLoop.boat_clock at world time 0).
func set_member(creature: Creature, index: int, count: int) -> void:
	member_index = index
	member_count = maxi(count, 1)
	if creature.data != null and creature.data.patrol != null:
		var period: float = PatrolLoop.period_s(creature.data.patrol, PatrolLoop.experiencia_level())
		clock_s = PatrolLoop.boat_clock(0.0, member_index, member_count, period)


## Puts the loop clock at `seconds` (a test).
func set_clock(seconds: float) -> void:
	clock_s = seconds


## True while the boat is in sight: its lap or an alert.
func in_sight() -> bool:
	return is_in_sight_state(state)


## True while the boat is alerting.
func alerting() -> bool:
	return is_alert_state(state)


## Seconds of the search left; 0 outside ALERT_SEARCH.
func search_left_s() -> float:
	if state != State.ALERT_SEARCH or _patrol == null:
		return 0.0
	return maxf(_patrol.alert_s - _search_s, 0.0)


## Where the boat stands on its loop at its clock now, in pixels (where it resumes its lap).
func lap_pose_px() -> Vector2:
	if _loop == null or _patrol == null:
		return Vector2.ZERO
	return _loop.pose_px(PatrolLoop.lap_time(clock_s, _patrol.horizon_warning_s))


## Whether the boat's light covers `point_px` now (the light on, the range and the cone).
func lights(point_px: Vector2) -> bool:
	if _creature == null or not _creature.light_on or _light == null:
		return false
	return _light.is_lit(point_px / TILE, _creature.position / TILE, _creature.beam)


## The spot meter or the water rule spotted `body`: a new alert locked on them. While the boat is locked
## on someone, a spot of ANOTHER player is still reported (one `patrol_alerted` at their position and the
## next loudhailer line) but the lock, the clock and the timers stay as they are; the locked player is
## not reported again (the same player must not be reported every tick). Ignored out of sight.
func spot(body: PlayerBody, cause: StringName) -> void:
	if _creature == null or not in_sight() or aboard.has(body):
		return
	if state == State.ALERT_LOCK or state == State.CHASE:
		if body != locked and body != chased:
			_creature.alert_serial += 1
			_creature.patrol_alerted.emit(cause, body.global_position)
		return
	_respond(cause, body)


## The lock breaks: the boat searches round the last known position.
func forget_lock() -> void:
	if state != State.ALERT_LOCK:
		return
	locked = null
	_search_s = 0.0
	enter(State.ALERT_SEARCH)
	_creature.state_id = state


func tick(creature: Creature, world: CreatureWorld, delta: float) -> void:
	_creature = creature
	_world = world
	if not _build(creature, world):
		return
	var weather: WeatherData = world.weather()
	if weather.patrols_in_port:
		if not _in_port:
			_in_port = true
			locked = null
			_drop_chase()
			_restart_wait_s = 0.0
		enter(State.AWAY)
		_park()
		_publish(weather)
		return
	if _in_port:
		_in_port = false
		# Boat k stays out of sight for k * period / count, then starts at clock 0 with its own horizon
		# warning: the boats stay evenly spaced and none comes into sight unannounced.
		_restart_wait_s = _period_s * float(member_index) / float(member_count)
		clock_s = 0.0
		_phase = PatrolLoop.Phase.AWAY
	if _restart_wait_s > 0.0:
		_restart_wait_s -= delta
		if _restart_wait_s > 0.0:
			enter(State.AWAY)
			_park()
			_publish(weather)
			return
		_restart_wait_s = 0.0
	if alerting():
		_tick_alert(delta, weather)
	else:
		clock_s = fposmod(clock_s + delta, _period_s)
		_follow_loop()
	if in_sight():
		_watch_water(weather)
		_watch_smoke(delta)
	_publish(weather)


# --- the loop ------------------------------------------------------------------------------------

func _follow_loop() -> void:
	var phase: PatrolLoop.Phase = PatrolLoop.phase_at(clock_s, _period_s, _patrol.horizon_warning_s, _patrol.route_lap_s)
	match phase:
		PatrolLoop.Phase.HORIZON:
			enter(State.HORIZON)
			_park()
		PatrolLoop.Phase.AWAY:
			enter(State.AWAY)
			_park()
		PatrolLoop.Phase.LAP:
			if _phase != PatrolLoop.Phase.LAP:
				_triggers.begin_lap()
				_smoke_s = SMOKE_CHECK_S
			enter(State.LAP)
			var lap_t: float = PatrolLoop.lap_time(clock_s, _patrol.horizon_warning_s)
			var ahead: Vector2 = _loop.pose_at(lap_t + FACING_LOOKAHEAD_S) - _loop.pose_at(lap_t)
			_creature.position = _loop.pose_px(lap_t)
			if ahead != Vector2.ZERO:
				_creature.facing = ahead.normalized()
	_phase = phase


# Out of sight: waits at the lap's start.
func _park() -> void:
	_creature.position = _loop.pose_px(0.0)


# --- the alert ----------------------------------------------------------------------------------

func _tick_alert(delta: float, weather: WeatherData) -> void:
	if state == State.ALERT_LOCK:
		if _lock_holds(weather):
			_aim_px = locked.global_position
		else:
			forget_lock()
		return
	if state == State.CHASE:
		_tick_chase(delta)
		return
	_search_s += delta
	_return_to_loop(delta)
	if _search_s >= _patrol.alert_s - EPSILON:
		_creature.alert_serial += 1
		locked = null
		enter(State.LAP)


# Visible (not hidden or submerged), alive, on the island, within the light's range, sight working.
func _lock_holds(weather: WeatherData) -> bool:
	if not is_instance_valid(locked) or not CoopSession.is_alive(locked) or locked.left_island or CreatureWorld.is_dropped(locked):
		return false
	if weather.disabled_senses.has(DataEnums.Sense.SIGHT) or locked.stealth_state != MovementStep.Stealth.VISIBLE:
		return false
	return _creature.position.distance_to(locked.global_position) <= _patrol.searchlight_range_tiles * TILE + EPSILON


# A spot of `body` (sight or water): a swimmer in deep water is chased by a boat that can chase;
# anyone else is locked.
func _respond(cause: StringName, body: PlayerBody) -> void:
	if _can_chase() and _in_deep_water(body):
		_start_chase(cause, body)
	else:
		_raise(cause, body.global_position, body)


# A new alert: stops the boat (its clock is not advanced while it alerts), calls the next line and
# reports it. `target` is the locked player, null for smoke or noise.
func _raise(cause: StringName, at_px: Vector2, target: PlayerBody) -> void:
	_creature.alert_serial += 1
	locked = target
	_search_s = 0.0
	_aim_px = at_px
	enter(State.ALERT_LOCK if target != null else State.ALERT_SEARCH)
	# The synced state follows at once (not at the end of the next tick), so a look that sees the new
	# alert_serial in the same frame also sees the alert state it picks its loudhailer line by.
	_creature.state_id = state
	_creature.patrol_alerted.emit(cause, at_px)


func _watch_water(weather: WeatherData) -> void:
	for body: PlayerBody in _world.players():
		if state == State.ALERT_LOCK or state == State.CHASE:
			return
		if body.left_island or CreatureWorld.is_dropped(body) or aboard.has(body):
			continue
		if _triggers.water_spots(body.movement_state, body.global_position / TILE, _creature.position / TILE, weather.disabled_senses, true):
			_respond(&"water", body)
			return


func _watch_smoke(delta: float) -> void:
	if state == State.ALERT_LOCK or state == State.CHASE:
		return
	_smoke_s += delta
	if _smoke_s < SMOKE_CHECK_S - EPSILON:
		return
	_smoke_s = 0.0
	var fires: Array[Node2D] = _world.events.smoke_sources() if _world.events != null else _world.lit_fires()
	var found: Array[Node2D] = _triggers.smoke_alerts(fires, _world.phase, true)
	if not found.is_empty():
		_raise(&"smoke", found[0].global_position, null)


func _on_noise(position_px: Vector2, radius_tiles: float, _source: StringName) -> void:
	if _creature == null or state == State.ALERT_LOCK or state == State.CHASE or not in_sight():
		return
	if _triggers.noise_heard(_creature.position / TILE, position_px / TILE, radius_tiles, true):
		_raise(&"noise", position_px, null)


# --- the chase at sea (guardacostas-capture) ------------------------------------------------------

# A boat chases when its data gives it a chase speed and a haul time.
func _can_chase() -> bool:
	return _patrol != null and BoatChase.can_chase(_patrol, _creature.data.speed_tiles_s)


# The player swims in deep water: the boat can reach them.
func _in_deep_water(body: PlayerBody) -> bool:
	return CreatureWorld.is_swimming(body) and _is_deep(CreatureNav.cell_of(body.global_position))


func _start_chase(cause: StringName, body: PlayerBody) -> void:
	_creature.alert_serial += 1
	locked = null
	chased = body
	_chase = BoatChase.from_patrol(_patrol, _creature.data.speed_tiles_s)
	_search_s = 0.0
	_aim_px = body.global_position
	enter(State.CHASE)
	_creature.state_id = state
	_creature.patrol_alerted.emit(cause, body.global_position)


func _tick_chase(delta: float) -> void:
	if not is_instance_valid(chased) or not CoopSession.is_alive(chased) or chased.left_island or CreatureWorld.is_dropped(chased):
		_search_from(_aim_px)
		return
	var cell: Vector2i = CreatureNav.cell_of(chased.global_position)
	var submerged: bool = chased.stealth_state == MovementStep.Stealth.SUBMERGED
	var before: Vector2 = _creature.position
	var step := _chase.step(before / TILE, chased.global_position / TILE, _world.terrain.terrain_at(cell), submerged, delta, _is_deep)
	_creature.position = step.position * TILE
	if _creature.position != before:
		_creature.facing = (_creature.position - before).normalized()
	_aim_px = chased.global_position
	match step.outcome:
		BoatChase.Outcome.HAULED:
			_haul(chased)
		BoatChase.Outcome.LANDED:
			_came_ashore(chased)
		BoatChase.Outcome.DIVED, BoatChase.Outcome.SHALLOWS, BoatChase.Outcome.LOST:
			_search_from(chased.global_position)


# The swimmer is hauled aboard: a captive aboard, and the boat searches round where it took them.
func _haul(body: PlayerBody) -> void:
	if not aboard.has(body):
		aboard.append(body)
	_search_from(body.global_position)


# The swimmer came ashore before the haul: the boat searches round the place they came ashore.
func _came_ashore(body: PlayerBody) -> void:
	_search_from(body.global_position)


# The chase ends: the plain search round `at_px`, the boat making its way back to its loop.
func _search_from(at_px: Vector2) -> void:
	_drop_chase()
	_search_s = 0.0
	_aim_px = at_px
	enter(State.ALERT_SEARCH)
	_creature.state_id = state


func _drop_chase() -> void:
	chased = null
	_chase = null


func _is_deep(cell: Vector2i) -> bool:
	return _world.terrain.terrain_at(cell) == DataEnums.Terrain.DEEP


# While it searches, a boat off its loop (after a chase) heads back to where it stopped, through deep
# water, so it resumes its lap from there.
func _return_to_loop(delta: float) -> void:
	var home: Vector2 = lap_pose_px() / TILE
	var here: Vector2 = _creature.position / TILE
	if here.distance_to(home) <= EPSILON:
		return
	var next: Vector2 = BoatChase.move_toward(here, home, RETURN_SPEED_TILES_S * delta, _is_deep)
	if next != here:
		_creature.facing = (next - here).normalized()
	_creature.position = next * TILE


# --- the Creature's fields -------------------------------------------------------------------------

func _publish(weather: WeatherData) -> void:
	_creature.route_t = clock_s
	var sighted: bool = in_sight()
	_creature.light_on = sighted and _light.is_on(_world.phase, weather.disabled_senses)
	_creature.beam = _beam_now() if sighted else 0.0


func _beam_now() -> float:
	var boat: Vector2 = _creature.position / TILE
	match state:
		State.ALERT_LOCK, State.CHASE:
			return rad_to_deg((_aim_px / TILE - boat).angle())
		State.ALERT_SEARCH:
			return rad_to_deg((_aim_px / TILE - boat).angle()) + _search_light.offset_deg(_search_s)
	return _light.beam_deg(boat, _loop.centroid, PatrolLoop.lap_time(clock_s, _patrol.horizon_warning_s))


# --- the build ----------------------------------------------------------------------------------

# The loop, the light and the trigger rules of the boat's island, once. False when the boat has no
# patrol data or its island has no loop (it then does nothing).
func _build(creature: Creature, world: CreatureWorld) -> bool:
	if _built:
		return _loop != null
	_built = true
	_patrol = creature.data.patrol
	if _patrol == null or _patrol.route_period_s <= 0.0:
		push_warning("PatrolRoute: %s has no patrol loop data" % creature.data.id)
		return false
	var loop: PatrolLoop = world.patrol_loop(_patrol)
	if not loop.valid:
		return false
	_loop = loop
	_period_s = PatrolLoop.period_s(_patrol, PatrolLoop.experiencia_level())
	_triggers = world.patrol_triggers(_patrol)
	_light = Searchlight.from_patrol(_patrol)
	_search_light = Searchlight.from_patrol(_patrol)
	_search_light.arc_deg = _patrol.alert_sweep_deg * 2.0
	clock_s = fposmod(clock_s, _period_s)
	if world.events != null:
		world.events.noise_made.connect(_on_noise)
	creature.tree_exiting.connect(_release, CONNECT_ONE_SHOT)
	return true


# The boat leaves the tree: stop listening and drop the references that would keep a cycle alive.
func _release() -> void:
	if _world != null and is_instance_valid(_world.events) and _world.events.noise_made.is_connected(_on_noise):
		_world.events.noise_made.disconnect(_on_noise)
	_creature = null
	_world = null
	locked = null
	chased = null
	aboard.clear()
