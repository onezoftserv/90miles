class_name Facing
extends RefCounted
## Where a player's look faces (art-pass "Player facing"; design.md D2, P10), one per look: from the
## change of the body's drawn position over the last 0.1 s, on every peer, the host and a downed
## owner included. The larger axis wins and a tie faces sideways; below 0.05 tiles/s the last
## facing stays; a change of more than 2 tiles in the window (landing, boarding, the throw-in) is
## a teleport and keeps it too. Velocity is never read: a client's body on the host advances in
## bursts. A new body faces down.

enum Dir { DOWN, UP, LEFT, RIGHT }

## How far back the drawn position is compared (s).
const WINDOW_S: float = 0.1
## Below this speed the body keeps its facing and is not moving (tiles/s).
const DEAD_ZONE_TILES_S: float = 0.05
## A larger change within the window is a teleport (tiles).
const TELEPORT_TILES: float = 2.0
const TILE_PX: float = 16.0
## Floating-point slack on the window's edge (s).
const EPSILON_S: float = 0.000001

var dir: Dir = Dir.DOWN
## The last side faced, for lying poses drawn while facing up or down.
var last_side: Dir = Dir.RIGHT
var _moving: bool = false
# The drawn positions seen in the window, oldest first, and how long ago each was seen.
var _positions: Array[Vector2] = []
var _ages: Array[float] = []


## The frame row a facing draws: down, side (left mirrored) or up.
static func row_name(facing: Dir) -> StringName:
	match facing:
		Dir.UP:
			return &"up"
		Dir.LEFT, Dir.RIGHT:
			return &"side"
	return &"down"


## Sees the body drawn at `position` now, `delta` seconds after the last call.
func observe(position: Vector2, delta: float) -> void:
	for i: int in _ages.size():
		_ages[i] += delta
	_positions.append(position)
	_ages.append(0.0)
	# Keep one sample at or past the window's far edge, so the window is always spanned.
	while _ages.size() > 2 and _ages[1] >= WINDOW_S - EPSILON_S:
		_positions.pop_front()
		_ages.pop_front()
	var span_s: float = _ages[0]
	if span_s <= 0.0:
		return
	var change: Vector2 = position - _positions[0]
	if change.length() > TELEPORT_TILES * TILE_PX:
		_moving = false
		return
	var tiles_s: float = change.length() / TILE_PX / span_s
	_moving = tiles_s >= DEAD_ZONE_TILES_S
	if not _moving:
		return
	if absf(change.x) >= absf(change.y):
		dir = Dir.LEFT if change.x < 0.0 else Dir.RIGHT
		last_side = dir
	else:
		dir = Dir.UP if change.y < 0.0 else Dir.DOWN


## Whether the drawn body moves faster than the dead zone.
func moving() -> bool:
	return _moving


## Left is the side frames mirrored.
func flip_h() -> bool:
	return dir == Dir.LEFT
