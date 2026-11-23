class_name ChangeWatch
extends RefCounted
## sound-pass design D5: remembers a value per key (a vessel's integrity, a patrol boat's alert
## serial, keyed by instance id) and reports how it changed since the last look. The first value of
## a key only seeds and reports no change, so a joiner, a new crossing or a boat first seen plays
## nothing. On a client the host's real values may land a moment after a key first appears, so for
## `settle_s` seconds from its first sight a key's changes only seed too (0 on the host and solo).

var settle_s: float = 0.0
var _last: Dictionary[int, float] = {}
var _first_seen_s: Dictionary[int, float] = {}


## The change since the last value of `key` (0 for its first, and while it settles); `now_s` is the
## caller's clock.
func observe(key: int, value: float, now_s: float = 0.0) -> float:
	if not _last.has(key):
		_last[key] = value
		_first_seen_s[key] = now_s
		return 0.0
	var change: float = value - _last[key]
	_last[key] = value
	if now_s - _first_seen_s[key] < settle_s:
		return 0.0
	return change


## Forgets every key not in `keys` (vessels and boats that are gone).
func keep_only(keys: Array) -> void:
	for key: int in _last.keys():
		if not keys.has(key):
			_last.erase(key)
			_first_seen_s.erase(key)


func reset() -> void:
	_last.clear()
	_first_seen_s.clear()
