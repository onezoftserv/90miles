class_name SnapshotInterpolator
extends RefCounted
## Positions of a remote player over time (coop-networking "Host authority"): other players
## are drawn DELAY_S behind the newest host state, interpolated linearly between the two
## states around that time. No extrapolation: before the oldest or after the newest state,
## the nearest one is held.

const DELAY_S: float = 0.1
const MAX_STATES: int = 8

var _times: PackedFloat64Array = []
var _positions: PackedVector2Array = []


## Adds a state. One at or before the newest time is ignored (late or duplicate packet).
func push(time_s: float, position: Vector2) -> void:
	if not is_finite(time_s):
		return
	if not _times.is_empty() and time_s <= _times[_times.size() - 1]:
		return
	_times.append(time_s)
	_positions.append(position)
	while _times.size() > MAX_STATES:
		_times.remove_at(0)
		_positions.remove_at(0)


## The position at `time_s`, or `fallback` when there are no states.
func sample(time_s: float, fallback: Vector2 = Vector2.ZERO) -> Vector2:
	var count: int = _times.size()
	if count == 0:
		return fallback
	if time_s <= _times[0]:
		return _positions[0]
	if time_s >= _times[count - 1]:
		return _positions[count - 1]
	for i: int in range(1, count):
		if time_s <= _times[i]:
			var span: float = _times[i] - _times[i - 1]
			var weight: float = (time_s - _times[i - 1]) / span
			return _positions[i - 1].lerp(_positions[i], weight)
	return _positions[count - 1]


## The position to draw at local time `now_s`: DELAY_S behind it.
func sample_delayed(now_s: float, fallback: Vector2 = Vector2.ZERO) -> Vector2:
	return sample(now_s - DELAY_S, fallback)


func size() -> int:
	return _times.size()


func is_empty() -> bool:
	return _times.is_empty()


func clear() -> void:
	_times.clear()
	_positions.clear()
