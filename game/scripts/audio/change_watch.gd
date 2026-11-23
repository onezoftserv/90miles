class_name ChangeWatch
extends RefCounted
## sound-pass design D5: remembers a value per key (a vessel's integrity, a patrol boat's alert
## serial, keyed by instance id) and reports how it changed since the last look. The first value of
## a key only seeds and reports no change, so a joiner, a new crossing or a boat first seen plays
## nothing.

var _last: Dictionary[int, float] = {}


## The change since the last value of `key` (0 for its first).
func observe(key: int, value: float) -> float:
	if not _last.has(key):
		_last[key] = value
		return 0.0
	var change: float = value - _last[key]
	_last[key] = value
	return change


## Forgets every key not in `keys` (vessels and boats that are gone).
func keep_only(keys: Array) -> void:
	for key: int in _last.keys():
		if not keys.has(key):
			_last.erase(key)


func reset() -> void:
	_last.clear()
