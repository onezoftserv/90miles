class_name CrossingResult
extends RefCounted
## What a crossing leaves for whatever comes next (crossing "End of the crossing"): the route, the
## vessel's state, the drift and each rider's state. Arrival on the next island reads it.

var route_id: StringName = &""
var integrity: float = 0.0
var broken: bool = false
## Always 0 on a coast crossing (no Gulf Stream there).
var drift_offset_tiles: float = 0.0
## Peer id -> {health, energy, aboard, dead}; on a board route also board (its integrity) and
## board_broken (vessel-car-board).
var riders: Dictionary[int, Dictionary] = {}
## A raft's maximum and fittings (island-stop "Fittings ride with the raft"): the beached raft keeps
## them. 0 and none for every other vessel.
var maximum: float = 0.0
var fittings: Array[StringName] = []


func to_dict() -> Dictionary:
	return {
		"route_id": String(route_id),
		"integrity": integrity,
		"broken": broken,
		"drift": drift_offset_tiles,
		"riders": riders.duplicate(true),
		"maximum": maximum,
		"fittings": _fitting_names(),
	}


# Plain strings, so nothing depends on how StringNames travel.
func _fitting_names() -> Array:
	var names: Array = []
	for id: StringName in fittings:
		names.append(String(id))
	return names


## Null for malformed data.
static func from_dict(data: Dictionary) -> CrossingResult:
	if not data.get("route_id") is String or not data.get("integrity") is float or not data.get("broken") is bool:
		return null
	if not data.get("drift") is float or not data.get("riders") is Dictionary:
		return null
	var result := CrossingResult.new()
	result.route_id = StringName(data["route_id"])
	result.integrity = data["integrity"]
	result.broken = data["broken"]
	result.drift_offset_tiles = data["drift"]
	# island-stop: optional, so a result written before the fittings still reads.
	var top: Variant = data.get("maximum", 0.0)
	if not (top is float or top is int) or not is_finite(float(top)):
		return null
	result.maximum = maxf(float(top), 0.0)
	result.fittings = VesselFittings.checked(data.get("fittings", []), VesselFittings.MAX)
	for peer: Variant in data["riders"]:
		var entry: Variant = data["riders"][peer]
		if not peer is int or not entry is Dictionary:
			return null
		result.riders[peer] = (entry as Dictionary).duplicate()
	return result
