class_name CrossingBeat
extends RefCounted
## One event of the crossing plan, at a time of the crossing (named Beat because ChainData has its own CrossingEvent enum). SQUALL_WARN starts the sky's 60 s warning;
## SQUALL is the hit itself. A ROCK, DEBRIS or FLOTSAM beat names a lane, whole tiles east (+) or
## west (−) of the line the vessel sails, and reaches the deck rows at its time (crossing "Beat lanes
## and sides"). A SHARK_PASS names a side in `extra` (0 west, 1 east); a FLOTSAM beat names its piece
## in `extra`, an index into the crossing tuning's flotsam table. A beat in the old two-value form
## rides the line (lane 0) and a shark pass in it comes from the west.

enum Kind {
	SQUALL_WARN,
	SQUALL,
	SHARK_PASS,
	ROCK,
	## Floating debris (palos, a drum): a small hit that opens a leak (crossing "Leaks").
	DEBRIS,
	## A piece drifting by that a rider can take (crossing "Flotsam").
	FLOTSAM,
}

enum Side {
	WEST,
	EAST,
}

## Lanes run this far either side of the line.
const MAX_LANE: int = 10
## Flotsam indexes are checked against a table no longer than this when the caller does not say.
const MAX_PIECES: int = 64

var time_s: float = 0.0
var kind: Kind = Kind.SQUALL
var lane: int = 0
var extra: int = 0


static func create(at_s: float, event_kind: Kind, at_lane: int = 0, with_extra: int = 0) -> CrossingBeat:
	var event := CrossingBeat.new()
	event.time_s = at_s
	event.kind = event_kind
	event.lane = at_lane
	event.extra = with_extra
	return event


## The shark pass's side, a `Side` (int: a class's own enum cannot be its return type here).
func side() -> int:
	return Side.EAST if extra == Side.EAST else Side.WEST


## True for the beats that come down a lane (rocks, debris, flotsam).
func is_lane_beat() -> bool:
	return kind == Kind.ROCK or kind == Kind.DEBRIS or kind == Kind.FLOTSAM


## The old two-value form when lane and extra are both 0, so plans without lanes read as before.
func to_array() -> Array:
	if lane == 0 and extra == 0:
		return [time_s, int(kind)]
	return [time_s, int(kind), lane, extra]


## Null for anything that is not a [time, kind] pair or a [time, kind, lane, extra] four of a known
## kind, a lane within ±MAX_LANE, a side of 0 or 1 for a shark pass, an index below `pieces` for
## flotsam and 0 for every other kind.
static func from_array(data: Variant, pieces: int = MAX_PIECES) -> CrossingBeat:
	if not data is Array:
		return null
	var raw: Array = data
	if raw.size() != 2 and raw.size() != 4:
		return null
	if not (raw[0] is float or raw[0] is int) or not raw[1] is int:
		return null
	var kind_value: int = raw[1]
	if kind_value < 0 or kind_value >= Kind.size() or not is_finite(float(raw[0])):
		return null
	var at_lane: int = 0
	var with_extra: int = 0
	if raw.size() == 4:
		if not raw[2] is int or not raw[3] is int:
			return null
		at_lane = raw[2]
		with_extra = raw[3]
	if absi(at_lane) > MAX_LANE:
		return null
	var lane_kind: bool = kind_value == Kind.ROCK or kind_value == Kind.DEBRIS or kind_value == Kind.FLOTSAM
	if at_lane != 0 and not lane_kind:
		return null
	match kind_value as Kind:
		Kind.SHARK_PASS:
			if with_extra != Side.WEST and with_extra != Side.EAST:
				return null
		Kind.FLOTSAM:
			if with_extra < 0 or with_extra >= pieces:
				return null
		_:
			if with_extra != 0:
				return null
	return create(float(raw[0]), kind_value as Kind, at_lane, with_extra)
