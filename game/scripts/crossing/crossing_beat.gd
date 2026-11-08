class_name CrossingBeat
extends RefCounted
## One event of the crossing plan, at a time of the crossing (named Beat because ChainData has its own CrossingEvent enum). SQUALL_WARN starts the sky's 60 s warning;
## SQUALL is the hit itself.

enum Kind {
	SQUALL_WARN,
	SQUALL,
	SHARK_PASS,
	ROCK,
}

var time_s: float = 0.0
var kind: Kind = Kind.SQUALL


static func create(at_s: float, event_kind: Kind) -> CrossingBeat:
	var event := CrossingBeat.new()
	event.time_s = at_s
	event.kind = event_kind
	return event


func to_array() -> Array:
	return [time_s, int(kind)]


## Null for anything that is not a [time, kind] pair of a known kind.
static func from_array(data: Variant) -> CrossingBeat:
	if not data is Array or (data as Array).size() != 2:
		return null
	var pair: Array = data
	if not (pair[0] is float or pair[0] is int) or not pair[1] is int:
		return null
	var kind_value: int = pair[1]
	if kind_value < 0 or kind_value >= Kind.size() or not is_finite(float(pair[0])):
		return null
	return create(float(pair[0]), kind_value as Kind)
