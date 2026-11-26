class_name CrossingResult
extends RefCounted
## What a crossing leaves for whatever comes next (crossing "End of the crossing"): the route, the
## vessel's state, the drift and each rider's state. Arrival on the next island reads it.

var route_id: StringName = &""
var integrity: float = 0.0
var broken: bool = false
## The vessel's maximum: a raft's recipe integrity plus its fittings' bonuses (island-stop D6).
var maximum: float = 0.0
## The recipe ids of an intact raft's fittings; empty for a broken raft and any other vessel.
var fittings: Array[StringName] = []
## Always 0 on a coast crossing (no Gulf Stream there).
var drift_offset_tiles: float = 0.0
## Peer id -> {health, energy, aboard, dead}; on a board route also board (its integrity) and
## board_broken (vessel-car-board).
var riders: Dictionary[int, Dictionary] = {}


func to_dict() -> Dictionary:
	return {
		"route_id": String(route_id),
		"integrity": integrity,
		"broken": broken,
		"max": maximum,
		"fittings": _fitting_names(),
		"drift": drift_offset_tiles,
		"riders": riders.duplicate(true),
	}


## Null for malformed data.
static func from_dict(data: Dictionary) -> CrossingResult:
	if not data.get("route_id") is String or not data.get("integrity") is float or not data.get("broken") is bool:
		return null
	if not data.get("drift") is float or not data.get("riders") is Dictionary:
		return null
	var raw_max: Variant = data.get("max")
	if not (raw_max is float or raw_max is int) or not is_finite(float(raw_max)) or not data.get("fittings") is Array:
		return null
	var result := CrossingResult.new()
	result.route_id = StringName(data["route_id"])
	result.integrity = data["integrity"]
	result.broken = data["broken"]
	result.maximum = maxf(float(raw_max), 0.0)
	result.fittings = RaftRecord.checked_fittings(data["fittings"]) if not result.broken else ([] as Array[StringName])
	result.drift_offset_tiles = data["drift"]
	for peer: Variant in data["riders"]:
		var entry: Variant = data["riders"][peer]
		if not peer is int or not entry is Dictionary:
			return null
		result.riders[peer] = (entry as Dictionary).duplicate()
	return result


## The raft this result beaches on the next island, or null: a broken vessel beaches nothing.
func raft_record() -> RaftRecord:
	if broken or integrity <= 0.0:
		return null
	# A result built without a maximum (an older caller) beaches a raft out of the recipe's 100.
	var record := RaftRecord.bare(integrity, maxf(maximum, integrity) if maximum > 0.0 else -1.0)
	record.integrity = integrity
	record.maximum = maxf(record.maximum, integrity)
	record.fittings = fittings.duplicate()
	return record


func _fitting_names() -> Array:
	var names: Array = []
	for id: StringName in fittings:
		names.append(String(id))
	return names
