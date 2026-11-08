class_name CrossingResult
extends RefCounted
## What a crossing leaves for whatever comes next (crossing "End of the crossing"): the route, the
## vessel's state, the drift and each rider's state. Arrival on the next island reads it.

var route_id: StringName = &""
var integrity: float = 0.0
var broken: bool = false
## Always 0 on a coast crossing (no Gulf Stream there).
var drift_offset_tiles: float = 0.0
## Peer id -> {health, energy, aboard, dead}.
var riders: Dictionary[int, Dictionary] = {}


func to_dict() -> Dictionary:
	return {
		"route_id": String(route_id),
		"integrity": integrity,
		"broken": broken,
		"drift": drift_offset_tiles,
		"riders": riders.duplicate(true),
	}


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
	for peer: Variant in data["riders"]:
		var entry: Variant = data["riders"][peer]
		if not peer is int or not entry is Dictionary:
			return null
		result.riders[peer] = (entry as Dictionary).duplicate()
	return result
