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

enum State {
	AWAY,
	HORIZON,
	LAP,
	ALERT_LOCK,
	ALERT_SEARCH,
}

const EPSILON: float = 0.000001
const TILE: float = 16.0
## How often a boat in sight looks at the fires.
const SMOKE_CHECK_S: float = 1.0
## How far ahead of the boat the facing looks, in seconds of its lap.
const FACING_LOOKAHEAD_S: float = 0.1

## The boat's seconds into its loop. Pauses during an alert.
var clock_s: float = 0.0
## The player the light follows in ALERT_LOCK, else null.
var locked: PlayerBody = null
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
var _search_s: float = 0.0
var _smoke_s: float = 0.0
var _aim_px: Vector2 = Vector2.ZERO


func names() -> Array[StringName]:
	return [&"AWAY", &"HORIZON", &"LAP", &"ALERT_LOCK", &"ALERT_SEARCH"]


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
	return state == State.LAP or state == State.ALERT_LOCK or state == State.ALERT_SEARCH


## True while the boat is alerting.
func alerting() -> bool:
	return state == State.ALERT_LOCK or state == State.ALERT_SEARCH


## Seconds of the search left; 0 outside ALERT_SEARCH.
func search_left_s() -> float:
	if state != State.ALERT_SEARCH or _patrol == null:
		return 0.0
	return maxf(_patrol.alert_s - _search_s, 0.0)


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
	if _creature == null or not in_sight():
		return
	if state == State.ALERT_LOCK:
		if body != locked:
			_creature.alert_serial += 1
			_creature.patrol_alerted.emit(cause, body.global_position)
		return
	_raise(cause, body.global_position, body)


## The lock breaks: the boat searches round the last known position.
func forget_lock() -> void:
	if state != State.ALERT_LOCK:
		return
	locked = null
	_search_s = 0.0
	enter(State.ALERT_SEARCH)


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
		enter(State.AWAY)
		_park()
		_publish(weather)
		return
	if _in_port:
		_in_port = false
		clock_s = PatrolLoop.boat_clock(0.0, member_index, member_count, _period_s)
		_phase = PatrolLoop.Phase.AWAY
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
	_search_s += delta
	if _search_s >= _patrol.alert_s - EPSILON:
		_creature.alert_serial += 1
		locked = null
		enter(State.LAP)


# Visible (not hidden or submerged), alive, on the island, within the light's range, sight working.
func _lock_holds(weather: WeatherData) -> bool:
	if not is_instance_valid(locked) or not CoopSession.is_alive(locked) or locked.left_island:
		return false
	if weather.disabled_senses.has(DataEnums.Sense.SIGHT) or locked.stealth_state != MovementStep.Stealth.VISIBLE:
		return false
	return _creature.position.distance_to(locked.global_position) <= _patrol.searchlight_range_tiles * TILE + EPSILON


# A new alert: stops the boat (its clock is not advanced while it alerts), calls the next line and
# reports it. `target` is the locked player, null for smoke or noise.
func _raise(cause: StringName, at_px: Vector2, target: PlayerBody) -> void:
	_creature.alert_serial += 1
	locked = target
	_search_s = 0.0
	_aim_px = at_px
	enter(State.ALERT_LOCK if target != null else State.ALERT_SEARCH)
	_creature.patrol_alerted.emit(cause, at_px)


func _watch_water(weather: WeatherData) -> void:
	for body: PlayerBody in _world.players():
		if state == State.ALERT_LOCK:
			return
		if body.left_island:
			continue
		if _triggers.water_spots(body.movement_state, body.global_position / TILE, _creature.position / TILE, weather.disabled_senses, true):
			_raise(&"water", body.global_position, body)
			return


func _watch_smoke(delta: float) -> void:
	if state == State.ALERT_LOCK:
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
	if _creature == null or state == State.ALERT_LOCK or not in_sight():
		return
	if _triggers.noise_heard(_creature.position / TILE, position_px / TILE, radius_tiles, true):
		_raise(&"noise", position_px, null)


# --- the Creature's fields -------------------------------------------------------------------------

func _publish(weather: WeatherData) -> void:
	_creature.route_t = clock_s
	var sighted: bool = in_sight()
	_creature.light_on = sighted and _light.is_on(_world.phase, weather.disabled_senses)
	_creature.beam = _beam_now() if sighted else 0.0


func _beam_now() -> float:
	var boat: Vector2 = _creature.position / TILE
	match state:
		State.ALERT_LOCK:
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
