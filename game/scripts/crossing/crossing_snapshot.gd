class_name CrossingSnapshot
extends RefCounted
## A crossing under way as the host has it (crossing-late-join "Joining during a crossing"): what a
## peer that joins mid-crossing needs to build it. The host makes one with of() and sends
## to_dict(); a joiner checks what arrived with from_dict() and gives it to Crossing.restore().

const KEYS: Array[String] = ["serial", "route", "riders", "plan", "elapsed_s", "maximum", "value", "broken", "states", "positions"]

## The crossing's number: its node name and where its sea lies.
var serial: int = 0
var route_id: StringName = &""
## Peer ids in slot order (the slot gives the deck spot).
var riders: Array[int] = []
var plan: CrossingPlan
var elapsed_s: float = 0.0
var maximum: float = 0.0
var value: float = 0.0
var broken: bool = false
## Rider -> Crossing.Rider.
var states: Dictionary[int, int] = {}
## Rider -> where the host has their body (session coordinates).
var positions: Dictionary[int, Vector2] = {}


## Host: `crossing` as it is now.
static func of(crossing: Crossing) -> CrossingSnapshot:
	var snapshot := CrossingSnapshot.new()
	snapshot.serial = crossing.serial
	snapshot.route_id = crossing.route.id
	snapshot.riders = crossing.peers().duplicate()
	snapshot.plan = crossing.plan
	snapshot.elapsed_s = crossing.elapsed_s
	snapshot.maximum = crossing.integrity.maximum
	snapshot.value = crossing.integrity.value
	snapshot.broken = crossing.integrity.broken
	for peer: int in snapshot.riders:
		snapshot.states[peer] = crossing.rider_state(peer)
		var body := crossing.body_of(peer)
		if body != null:
			snapshot.positions[peer] = body.global_position
	return snapshot


## Plain containers only, so nothing depends on how typed ones travel.
func to_dict() -> Dictionary:
	var rider_list: Array = []
	rider_list.append_array(riders)
	var state_map: Dictionary = {}
	state_map.merge(states)
	var position_map: Dictionary = {}
	position_map.merge(positions)
	return {
		"serial": serial,
		"route": String(route_id),
		"riders": rider_list,
		"plan": plan.to_array() if plan != null else [],
		"elapsed_s": elapsed_s,
		"maximum": maximum,
		"value": value,
		"broken": broken,
		"states": state_map,
		"positions": position_map,
	}


## Null for malformed data (a joiner never trusts what arrives): a missing key, a serial outside
## 0..Crossing.MAX_SERIAL, a route not in the catalog, riders that are not 1 to 4 distinct peer
## ids, a malformed plan or one of no length, a number that is not finite, a rider without a valid
## state, or a position that is not finite.
## In-range numbers are clamped; states and positions of non-riders are dropped.
static func from_dict(data: Variant) -> CrossingSnapshot:
	if not data is Dictionary:
		return null
	var raw: Dictionary = data
	for key: String in KEYS:
		if not raw.has(key):
			return null
	var snapshot := CrossingSnapshot.new()
	if not snapshot._read_head(raw) or not snapshot._read_numbers(raw):
		return null
	if not snapshot._read_states(raw.get("states")) or not snapshot._read_positions(raw.get("positions")):
		return null
	return snapshot


func _read_head(raw: Dictionary) -> bool:
	var raw_serial: Variant = raw["serial"]
	var raw_route: Variant = raw["route"]
	if not raw_serial is int or raw_serial < 0 or raw_serial > Crossing.MAX_SERIAL:
		return false
	if not (raw_route is String or raw_route is StringName):
		return false
	serial = raw_serial
	route_id = StringName(raw_route)
	if GameState.content.get_entry(&"routes", route_id) == null:
		return false
	plan = CrossingPlan.from_array(raw["plan"])
	return plan != null and plan.length_s > 0.0 and _read_riders(raw["riders"])


func _read_riders(raw_riders: Variant) -> bool:
	if not raw_riders is Array:
		return false
	var list: Array = raw_riders
	if list.is_empty() or list.size() > NetPeers.MAX_PLAYERS:
		return false
	for peer: Variant in list:
		if not peer is int or peer < 1 or riders.has(peer):
			return false
		riders.append(peer)
	return true


func _read_numbers(raw: Dictionary) -> bool:
	for key: String in ["elapsed_s", "maximum", "value"]:
		var number: Variant = raw[key]
		if not (number is float or number is int) or not is_finite(float(number)):
			return false
	if not raw["broken"] is bool:
		return false
	maximum = maxf(float(raw["maximum"]), 0.0)
	value = clampf(float(raw["value"]), 0.0, maximum)
	elapsed_s = clampf(float(raw["elapsed_s"]), 0.0, plan.length_s)
	broken = raw["broken"]
	return true


func _read_states(raw_states: Variant) -> bool:
	if not raw_states is Dictionary:
		return false
	var map: Dictionary = raw_states
	for peer: int in riders:
		var state: Variant = map.get(peer)
		if not state is int or state < 0 or state >= Crossing.Rider.size():
			return false
		states[peer] = state
	return true


func _read_positions(raw_positions: Variant) -> bool:
	if not raw_positions is Dictionary:
		return false
	var map: Dictionary = raw_positions
	for peer: Variant in map:
		var spot: Variant = map[peer]
		if not peer is int or not spot is Vector2 or not (spot as Vector2).is_finite():
			return false
		if riders.has(peer):
			positions[peer] = spot
	return true
