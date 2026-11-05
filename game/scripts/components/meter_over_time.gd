class_name MeterOverTime
extends RefCounted
## A change spread evenly over time on one meter (seawater, poison). SurvivalMeters keeps a
## list of these and advances them every tick.

var meter: DataEnums.Meter
var rate_per_s: float
var time_left_s: float


func _init(on_meter: DataEnums.Meter, total: float, duration_s: float) -> void:
	meter = on_meter
	rate_per_s = total / duration_s
	time_left_s = duration_s


## The change due over the next `delta` seconds, never past the end. Advances the clock.
func take(delta: float) -> float:
	var step: float = minf(delta, time_left_s)
	time_left_s -= step
	return rate_per_s * step


func finished() -> bool:
	return time_left_s <= 0.0
