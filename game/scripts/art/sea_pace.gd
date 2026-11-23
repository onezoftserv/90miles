class_name SeaPace
extends RefCounted
## The sea's and the foam's own clocks (art-mood-pass "Squall on screen", design D4). Each clock
## runs at a pace that eases toward the weather's (`WeatherData.sea_pace` and `foam_pace`) at a
## steady rate, so a whole change takes `ease_s`. The rate changes and the clock never jumps, so no
## frame of the water or the foam skips. Pure and cosmetic: nothing reads it but the shaders, and it
## is never synced (each peer keeps its own).

var sea_time: float = 0.0
var foam_time: float = 0.0
var sea_pace: float = 1.0
var foam_pace: float = 1.0
## The seconds a whole change of pace takes; 0 changes it at once.
var ease_s: float = 0.0

var _sea_target: float = 1.0
var _foam_target: float = 1.0
var _sea_rate: float = 0.0
var _foam_rate: float = 0.0


func _init(ease_seconds: float = 0.0) -> void:
	ease_s = maxf(ease_seconds, 0.0)


## Moves both paces toward `sea_target` and `foam_target`, then runs both clocks `delta` seconds at
## the new paces. A new target sets the rate that covers the gap from here in `ease_s`.
func step(delta: float, sea_target: float, foam_target: float) -> void:
	if sea_target != _sea_target:
		_sea_target = sea_target
		_sea_rate = _rate(sea_pace, sea_target)
	if foam_target != _foam_target:
		_foam_target = foam_target
		_foam_rate = _rate(foam_pace, foam_target)
	sea_pace = move_toward(sea_pace, _sea_target, _sea_rate * delta)
	foam_pace = move_toward(foam_pace, _foam_target, _foam_rate * delta)
	sea_time += delta * sea_pace
	foam_time += delta * foam_pace


func _rate(from: float, to: float) -> float:
	if ease_s <= 0.0:
		return INF
	return absf(to - from) / ease_s
