class_name StatusWatch
extends RefCounted
## Sees statuses clear on one body (survival-meters "Jumps and cures are told apart";
## damage-feedback design D3), from the status_flags it already holds (status-sync): a bit that was
## set and is clear now is a cure. The first value, a value after `reset()` and every value while
## dead only set where it starts. Feedback only: it reads and never writes.

var _has_base: bool = false
var _flags: int = 0


## The statuses in `mask` (one bit per DataEnums.Status), lowest first.
static func statuses(mask: int) -> Array[DataEnums.Status]:
	var found: Array[DataEnums.Status] = []
	for status: int in DataEnums.Status.values():
		if status != DataEnums.Status.NONE and mask & (1 << status) != 0:
			found.append(status as DataEnums.Status)
	return found


## Forgets the body: the next value only sets where it starts.
func reset() -> void:
	_has_base = false


## One drawn frame: the body's flags now and whether it is dead. Returns the bits cured since the
## last frame.
func observe(flags: int, dead: bool) -> int:
	if dead or not _has_base:
		_has_base = true
		_flags = flags
		return 0
	var cured: int = _flags & ~flags
	_flags = flags
	return cured
