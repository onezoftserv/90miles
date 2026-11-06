class_name WeatherCycle
extends RefCounted
## Calm or squall (weather-daynight "Weather states"): when a phase begins and nothing is warned
## or running, the host rolls the next weather by roll weight among the states allowed in that
## phase. A weather with a warning lead is announced first (weather_warned), then starts that
## many seconds later; one with a duration hands over to its followed-by weather when it ends.
## Clients set rolls_enabled to false and take the host's state instead.

## `weather_id` was rolled and will start in `starts_in_s`.
signal weather_warned(weather_id: StringName, starts_in_s: float)
signal weather_changed(weather_id: StringName)

const DEFAULT_ID: StringName = &"calm"
## Float slack when a countdown reaches zero.
const EPSILON_S: float = 0.000001

var rolls_enabled: bool = true
var current: WeatherData
## Seconds before the current weather ends; 0 means until the next roll.
var current_left_s: float = 0.0
## The warned weather, or null.
var pending: WeatherData = null
var pending_in_s: float = -1.0

var _states: Dictionary[StringName, WeatherData] = {}
var _rolled: Array[WeatherData] = []
var _rng: RandomNumberGenerator


func _init(states: Array[WeatherData], rng: RandomNumberGenerator = null) -> void:
	_rng = rng if rng != null else RandomNumberGenerator.new()
	for state: WeatherData in states:
		_states[state.id] = state
		if state.trigger == WeatherData.Trigger.PHASE_ROLL:
			_rolled.append(state)
	current = _states.get(DEFAULT_ID)


## Whether the weather with `id` is one this cycle knows.
func knows(id: StringName) -> bool:
	return _states.has(id)


## Host: a phase began, so roll unless a weather is warned or running.
func on_phase_started(phase: DataEnums.DayPhase) -> void:
	if not rolls_enabled or pending != null or current_left_s > 0.0:
		return
	var total: float = 0.0
	for state: WeatherData in _rolled:
		total += _weight(state, phase)
	if total <= 0.0:
		return
	var pick: float = _rng.randf() * total
	for state: WeatherData in _rolled:
		pick -= _weight(state, phase)
		if pick < 0.0:
			_begin(state)
			return


## Announces `id` now (or starts it at once when it has no warning lead).
func warn_weather(id: StringName) -> void:
	if _states.has(id):
		_begin(_states[id])


## Starts `id` at once, with its duration.
func start_weather(id: StringName) -> void:
	if _states.has(id):
		_start(_states[id])


func advance(delta: float) -> void:
	if pending != null:
		pending_in_s -= delta
		if pending_in_s <= EPSILON_S:
			_start(pending)
		return
	if current_left_s > 0.0:
		current_left_s -= delta
		if current_left_s <= EPSILON_S:
			var next_id: StringName = current.followed_by_weather_id if not current.followed_by_weather_id.is_empty() else DEFAULT_ID
			_start(_states[next_id] if _states.has(next_id) else _states[DEFAULT_ID])


## Takes the host's state without rolling or announcing anything.
func apply(weather_id: StringName, left_s: float, pending_id: StringName, pending_left_s: float) -> void:
	var changed: bool = current == null or current.id != weather_id
	current = _states[weather_id]
	current_left_s = maxf(left_s, 0.0)
	pending = _states.get(pending_id)
	pending_in_s = pending_left_s if pending != null else -1.0
	if changed:
		weather_changed.emit(weather_id)


## Chance in 0..1 that `id` is the roll among `states` in `phase`.
static func chance_of(states: Array[WeatherData], id: StringName, phase: DataEnums.DayPhase) -> float:
	var total: float = 0.0
	var mine: float = 0.0
	for state: WeatherData in states:
		var weight: float = _weight(state, phase)
		total += weight
		if state.id == id:
			mine = weight
	return mine / total if total > 0.0 else 0.0


static func _weight(state: WeatherData, phase: DataEnums.DayPhase) -> float:
	if not state.allowed_phases.is_empty() and not state.allowed_phases.has(phase):
		return 0.0
	return maxf(state.roll_weight, 0.0)


func _begin(state: WeatherData) -> void:
	if state.warning_lead_s > 0.0:
		pending = state
		pending_in_s = state.warning_lead_s
		weather_warned.emit(state.id, state.warning_lead_s)
		return
	_start(state)


func _start(state: WeatherData) -> void:
	pending = null
	pending_in_s = -1.0
	var changed: bool = current.id != state.id
	current = state
	current_left_s = state.duration_s
	if changed:
		weather_changed.emit(state.id)
