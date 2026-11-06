class_name WorldSky
extends RefCounted
## The game's one sky (weather-daynight): the clock and the weather cycle together, the
## ClimateState the meters read (written after every change), the CanvasModulate tint and the
## state dictionary the host sends to clients. Pure logic; WeatherManager holds the shared one.

## The phase or the weather changed, or a weather was warned.
signal changed

const TUNING_PATH: String = "res://resources/day_cycle.tres"
const WEATHER_TYPE: StringName = &"weather"
const STATE_KEYS: Array[String] = ["time_of_day_s", "day", "weather", "weather_left_s", "pending", "pending_in_s"]

var clock: DayClock = DayClock.new()
var weather: WeatherCycle
var climate: ClimateState = ClimateState.new()
var tuning: DayCycleTuning


func _init(states: Array[WeatherData], day_tuning: DayCycleTuning, rng: RandomNumberGenerator = null) -> void:
	weather = WeatherCycle.new(states, rng)
	tuning = day_tuning
	clock.phase_changed.connect(_on_phase_changed)
	weather.weather_changed.connect(_on_weather_changed)
	weather.weather_warned.connect(_on_weather_warned)
	_write_climate()


## A sky from the weather folder of `catalog` and the day-cycle data file.
static func from_catalog(catalog: ContentCatalog, rng: RandomNumberGenerator = null) -> WorldSky:
	var states: Array[WeatherData] = []
	for id: StringName in catalog.list_ids(WEATHER_TYPE):
		states.append(catalog.get_entry(WEATHER_TYPE, id) as WeatherData)
	return WorldSky.new(states, load(TUNING_PATH) as DayCycleTuning, rng)


## Starts a fresh day at `seconds` since dawn, calm.
func start_at(seconds: float) -> void:
	clock.set_time(seconds, 1)
	weather.apply(WeatherCycle.DEFAULT_ID, 0.0, &"", -1.0)
	_write_climate()
	changed.emit()


func advance(delta: float) -> void:
	clock.advance(delta)
	weather.advance(delta)
	_write_climate()


## The CanvasModulate colour: the phase colour blended from the previous phase's over
## blend_s, times the weather's tint.
func tint() -> Color:
	var phase: int = clock.phase()
	var previous: Color = tuning.phase_tints[(phase + 3) % 4]
	var blend: float = 1.0
	if tuning.blend_s > 0.0:
		blend = clampf(clock.phase_elapsed_s() / tuning.blend_s, 0.0, 1.0)
	return previous.lerp(tuning.phase_tints[phase], blend) * weather.current.canvas_tint


## The dark horizon line shows while a weather with that tell is warned.
func horizon_line_visible() -> bool:
	return weather.pending != null and weather.pending.tell == WeatherData.Tell.HORIZON_LINE


## What the host sends: time, day, weather and what is left of it, and the warned weather.
func to_state() -> Dictionary:
	return {
		"time_of_day_s": clock.time_of_day_s,
		"day": clock.day,
		"weather": weather.current.id,
		"weather_left_s": weather.current_left_s,
		"pending": weather.pending.id if weather.pending != null else &"",
		"pending_in_s": weather.pending_in_s,
	}


## Takes a host state. Returns false and changes nothing if a value is missing or out of range.
func apply_state(state: Dictionary) -> bool:
	if not _state_is_valid(state):
		return false
	var before: DataEnums.DayPhase = clock.phase()
	clock.set_time(float(state["time_of_day_s"]), int(state["day"]))
	weather.apply(StringName(state["weather"]), float(state["weather_left_s"]), StringName(state["pending"]), float(state["pending_in_s"]))
	_write_climate()
	if clock.phase() != before:
		clock.phase_changed.emit(clock.phase())
	changed.emit()
	return true


func _state_is_valid(state: Dictionary) -> bool:
	for key: String in STATE_KEYS:
		if not state.has(key):
			return false
	if not _is_number(state["time_of_day_s"]) or float(state["time_of_day_s"]) < 0.0 or float(state["time_of_day_s"]) >= DayClock.DAY_S:
		return false
	if not state["day"] is int or int(state["day"]) < 1:
		return false
	if not (state["weather"] is StringName or state["weather"] is String) or not weather.knows(StringName(state["weather"])):
		return false
	if not (state["pending"] is StringName or state["pending"] is String):
		return false
	var pending_id: StringName = StringName(state["pending"])
	if not pending_id.is_empty() and not weather.knows(pending_id):
		return false
	return _is_number(state["weather_left_s"]) and _is_number(state["pending_in_s"])


static func _is_number(value: Variant) -> bool:
	return (value is float or value is int) and is_finite(float(value))


func _write_climate() -> void:
	climate.phase = clock.phase()
	climate.midday = clock.is_midday()
	climate.heat_factor = weather.current.heat_gain_mult
	climate.weather_id = weather.current.id


func _on_phase_changed(phase: DataEnums.DayPhase) -> void:
	weather.on_phase_started(phase)
	_write_climate()
	changed.emit()


func _on_weather_changed(_weather_id: StringName) -> void:
	_write_climate()
	changed.emit()


func _on_weather_warned(_weather_id: StringName, _starts_in_s: float) -> void:
	changed.emit()
