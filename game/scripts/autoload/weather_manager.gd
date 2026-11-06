extends Node
## WeatherManager autoload (core-services spec): the one day-night clock and the weather
## (weather-daynight). Thin: the logic is in WorldSky, DayClock and WeatherCycle. It is idle
## until a level calls start(), and it keeps the default pausable process mode, so the solo
## pause freezes it with the rest of the simulation.

signal phase_changed(phase: DataEnums.DayPhase)
signal day_started(day: int)
signal weather_changed(weather_id: StringName)
## A weather was rolled and starts in `starts_in_s` (a squall: the horizon line shows).
signal weather_warned(weather_id: StringName, starts_in_s: float)

## The game's one sky; levels hand its climate to the session and the bodies.
var sky: WorldSky
var running: bool = false


func _ready() -> void:
	sky = WorldSky.from_catalog(GameState.content)
	sky.clock.phase_changed.connect(phase_changed.emit)
	sky.clock.day_started.connect(day_started.emit)
	sky.weather.weather_changed.connect(weather_changed.emit)
	sky.weather.weather_warned.connect(weather_warned.emit)


func _process(delta: float) -> void:
	if running:
		sky.advance(delta)


## Starts a fresh calm day at `at_s` seconds since dawn and runs the clock.
func start(at_s: float = 0.0) -> void:
	sky.weather.rolls_enabled = true
	sky.start_at(at_s)
	running = true


func stop() -> void:
	running = false


func time_of_day_s() -> float:
	return sky.clock.time_of_day_s


func hour() -> int:
	return sky.clock.hour()


func minute() -> int:
	return sky.clock.minute()


func phase() -> DataEnums.DayPhase:
	return sky.clock.phase()


func is_midday() -> bool:
	return sky.clock.is_midday()


func weather_id() -> StringName:
	return sky.weather.current.id
