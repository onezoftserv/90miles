class_name ClimateState
extends RefCounted
## The clock and weather a player's meters read: day phase, the 10:00-16:00 midday window and the
## weather's heat factor. weather-daynight will drive it; until then it stays at its defaults or
## a scene (the movement playground) sets it. One in-game hour is 30 real seconds.

var phase: DataEnums.DayPhase = DataEnums.DayPhase.DAY
## In-game 10:00-16:00.
var midday: bool = false
## 2 in scorching calm.
var heat_factor: float = 1.0
## WeatherData id now falling (squall = rain). weather-daynight drives it; a level or test sets
## it until then. crafting-inventory's rain catcher reads it.
var weather_id: StringName = &""
