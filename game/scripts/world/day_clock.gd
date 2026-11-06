class_name DayClock
extends RefCounted
## The one clock (weather-daynight "Day cycle"): a 720 s day of dawn 60, day 300, dusk 60 and
## night 300 seconds. One in-game hour is 30 s and the clock reads 06:00 when dawn starts.
## Pure logic: whoever owns it calls advance(); WeatherManager does in the game.

## A phase began (dawn only at the start of a new day, after day_started).
signal phase_changed(phase: DataEnums.DayPhase)
## Dawn of day `day` began.
signal day_started(day: int)

const HOUR_S: float = 30.0
const DAY_S: float = 720.0
const DAWN_HOUR: int = 6
## Seconds since dawn at which each phase begins.
const DAY_START_S: float = 60.0
const DUSK_START_S: float = 360.0
const NIGHT_START_S: float = 420.0
## The 10:00-16:00 window survival-meters reads as midday.
const MIDDAY_START_S: float = 120.0
const MIDDAY_END_S: float = 300.0
const PHASE_STARTS: Array[float] = [0.0, DAY_START_S, DUSK_START_S, NIGHT_START_S]

## Seconds since dawn, in [0, DAY_S).
var time_of_day_s: float = 0.0
var day: int = 1


## Runs the clock `delta` seconds, emitting every phase boundary it crosses, in order.
func advance(delta: float) -> void:
	if not is_finite(delta) or delta <= 0.0:
		return
	var remaining: float = delta
	while remaining > 0.0:
		var boundary: float = _next_boundary_s()
		var step: float = minf(remaining, boundary - time_of_day_s)
		time_of_day_s += step
		remaining -= step
		if time_of_day_s < boundary - 0.000001:
			break
		_cross(boundary)


## Jumps to `seconds` since dawn on `new_day` without signals (a level start or a host sync).
## Wraps into one day; ignores a non-finite time.
func set_time(seconds: float, new_day: int) -> void:
	if not is_finite(seconds):
		return
	time_of_day_s = fposmod(seconds, DAY_S)
	day = maxi(new_day, 1)


func phase() -> DataEnums.DayPhase:
	return phase_at(time_of_day_s)


## In-game hour 0-23.
func hour() -> int:
	return (DAWN_HOUR + int(time_of_day_s / HOUR_S)) % 24


## In-game minute 0-59.
func minute() -> int:
	return int(fmod(time_of_day_s, HOUR_S) * 2.0)


func is_midday() -> bool:
	return time_of_day_s >= MIDDAY_START_S and time_of_day_s < MIDDAY_END_S


## Seconds the current phase has run.
func phase_elapsed_s() -> float:
	return time_of_day_s - PHASE_STARTS[phase()]


static func phase_at(seconds: float) -> DataEnums.DayPhase:
	if seconds >= NIGHT_START_S:
		return DataEnums.DayPhase.NIGHT
	if seconds >= DUSK_START_S:
		return DataEnums.DayPhase.DUSK
	if seconds >= DAY_START_S:
		return DataEnums.DayPhase.DAY
	return DataEnums.DayPhase.DAWN


func _next_boundary_s() -> float:
	for start: float in PHASE_STARTS:
		if start > time_of_day_s + 0.000001:
			return start
	return DAY_S


func _cross(boundary: float) -> void:
	if boundary >= DAY_S:
		time_of_day_s = 0.0
		day += 1
		phase_changed.emit(DataEnums.DayPhase.DAWN)
		day_started.emit(day)
		return
	time_of_day_s = boundary
	phase_changed.emit(phase_at(boundary))
