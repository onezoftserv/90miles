class_name ClimateState
extends RefCounted
## The clock and weather a player's meters read: day phase, the 10:00-16:00 midday window and the
## weather's heat factor. WorldSky (weather-daynight) writes it from the one clock; tests and dev
## scenes may also set it by hand. One in-game hour is 30 real seconds.

var phase: DataEnums.DayPhase = DataEnums.DayPhase.DAY
## In-game 10:00-16:00.
var midday: bool = false
## 2 in scorching calm.
var heat_factor: float = 1.0
## WeatherData id now falling (squall = rain). WorldSky writes it with the rest; tests may set
## it by hand. crafting-inventory's rain catcher and condition checks read it.
var weather_id: StringName = &""
## Seconds since dawn on the one clock (hud-clarity's clock row: the strip, the time left and the
## morning and afternoon words). WorldSky writes it with the rest.
var time_of_day_s: float = 0.0
## The run's day count, from 1 at the run's start, never reset by travel (the clock row's "Día 2").
var day: int = 1
