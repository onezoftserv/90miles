class_name CrossingSteer
extends RefCounted
## The vessel's lateral position (crossing "Paddling"; design.md D2, D3): tiles east (+) or west (−)
## of the line it sails. The deck, the riders and the sea never move; hazards and flotsam are drawn
## at their lane minus this position, so the sea slides past the fixed raft. The host moves it from
## the riders paddling; the current pulls it back to the line when nobody paddles. Clients hold the
## host's position and velocity and run it forward between messages. Swimmers' routes keep it at 0.

const WEST: int = -1
const EAST: int = 1

## Tiles from the line, east positive.
var position: float = 0.0
## Tiles per second it moved in the last host step, or the host's last one on a client.
var velocity: float = 0.0
## Host: peer -> the side they paddle (WEST or EAST) while they hold a paddle.
var paddlers: Dictionary[int, int] = {}


## Host: `peer` paddles on `side` until they stop.
func start(peer: int, side: int) -> void:
	paddlers[peer] = EAST if side >= 0 else WEST


func stop(peer: int) -> void:
	paddlers.erase(peer)


## Host: one step of `delta` seconds. `active` are the peers whose paddling counts now (aboard and
## untied); `blow` halves paddling during a squall's blow.
func step(delta: float, tuning: CrossingTuning, active: Array[int], blow: bool) -> void:
	var west: int = 0
	var east: int = 0
	for peer: int in paddlers:
		if not active.has(peer):
			continue
		if paddlers[peer] == EAST:
			east += 1
		else:
			west += 1
	var before: float = position
	if west + east > 0:
		var speed: float = _speed(east, tuning) - _speed(west, tuning)
		if blow:
			speed *= tuning.blow_paddle_factor
		position = clampf(position + speed * delta, -tuning.max_offset_tiles, tuning.max_offset_tiles)
	else:
		position = move_toward(position, 0.0, tuning.pull_back_tiles_per_s * delta)
	velocity = (position - before) / delta if delta > 0.0 else 0.0


## Clients: runs the host's last velocity forward `delta` seconds, within the limit; a pull back
## never runs past the line.
func extrapolate(delta: float, tuning: CrossingTuning) -> void:
	var moved: float = position + velocity * delta
	if position != 0.0 and signf(moved) != signf(position) and signf(velocity) != signf(position):
		moved = 0.0
	position = clampf(moved, -tuning.max_offset_tiles, tuning.max_offset_tiles)


## Plain values for the wire: [position, velocity].
func to_array() -> Array:
	return [position, velocity]


## Takes [position, velocity] from the host; false (and unchanged) for anything malformed.
func read(data: Variant, tuning: CrossingTuning) -> bool:
	if not data is Array or (data as Array).size() != 2:
		return false
	var pair: Array = data
	for number: Variant in pair:
		if not (number is float or number is int) or not is_finite(float(number)):
			return false
	position = clampf(float(pair[0]), -tuning.max_offset_tiles, tuning.max_offset_tiles)
	velocity = clampf(float(pair[1]), -tuning.paddle_crew_tiles_per_s * 2.0, tuning.paddle_crew_tiles_per_s * 2.0)
	return true


static func _speed(count: int, tuning: CrossingTuning) -> float:
	if count <= 0:
		return 0.0
	return tuning.paddle_tiles_per_s if count == 1 else tuning.paddle_crew_tiles_per_s
