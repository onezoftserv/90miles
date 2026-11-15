class_name PatrolTriggers
extends RefCounted
## guardacostas-stealth decision 7: what makes a patrol boat that is in sight raise an alert without
## the beam: smoke from a fire near the shore, a loud noise, a swimmer close by. Pure rules over
## plain values; the boat's brain (group 7) owns the clocks and asks these once a second or on an
## event. One instance per island: it holds the distance to the sea of every land cell (computed
## once) and the memory of which fires already alerted this lap.
##
## Units: every Vector2 is in tiles, a cell (x, y) spanning x..x+1 and y..y+1 as in PatrolLoop, and a
## land cell's centre is (x + 0.5, y + 0.5). A fire Node2D is read from its global_position in
## pixels (/ TILE) and judged by its cell. "In sight" is the caller's: a boat that is AWAY or on the
## HORIZON, or under a squall, passes in_sight = false and nothing triggers, nothing is remembered.

const TILE: float = 16.0
## What `distance_at` answers for a cell that is not land.
const NOT_LAND: float = 0.0

## Euclidean distance in tiles from each land cell's centre to the nearest sea cell's centre.
var sea_distance: Dictionary[Vector2i, float] = {}

var smoke_night_tiles: float = 2.0
var smoke_day_tiles: float = 6.0
var noise_min_radius_tiles: float = 8.0
var water_radius_tiles: float = 6.0

var _terrain: TerrainQuery = null
var _size: Vector2i = Vector2i.ZERO
var _sea: Dictionary[Vector2i, bool] = {}
# Instance ids of the fires that already alerted a boat this lap.
var _smoked: Dictionary[int, bool] = {}


## The rules of the island `terrain` (`size` columns and rows) with `patrol`'s numbers.
static func build(terrain: TerrainQuery, size: Vector2i, patrol: PatrolData) -> PatrolTriggers:
	var triggers := PatrolTriggers.new()
	triggers.smoke_night_tiles = patrol.smoke_shore_tiles_night
	triggers.smoke_day_tiles = patrol.smoke_shore_tiles_day
	triggers.noise_min_radius_tiles = patrol.noise_alert_min_radius_tiles
	triggers.water_radius_tiles = patrol.water_spot_radius_tiles
	triggers._terrain = terrain
	triggers._size = size
	triggers._flood_sea()
	triggers._measure()
	return triggers


# --- the sea ---------------------------------------------------------------------------------

## True for sea: deep or shallow water joined to the map edge. Brackish water (the coast cay's
## lagoon) and any water the land encloses are not sea.
func is_sea(cell: Vector2i) -> bool:
	return _sea.has(cell)


## Tiles from the centre of land `cell` to the nearest sea cell's centre; NOT_LAND (0) for water.
func distance_at(cell: Vector2i) -> float:
	return sea_distance.get(cell, NOT_LAND)


## The largest distance_at of any land cell.
func farthest_land_tiles() -> float:
	var farthest: float = 0.0
	for cell: Vector2i in sea_distance:
		farthest = maxf(farthest, sea_distance[cell])
	return farthest


## How many land cells lie more than `tiles` from the sea.
func land_beyond(tiles: float) -> int:
	var count: int = 0
	for cell: Vector2i in sea_distance:
		if sea_distance[cell] > tiles:
			count += 1
	return count


# --- smoke -----------------------------------------------------------------------------------

## Forgets which fires alerted: call it when a lap starts.
func begin_lap() -> void:
	_smoked.clear()


## Whether a lit fire in `cell` would alert a boat in sight now. At night, dawn and dusk (the dark
## side wins): within `smoke_shore_tiles_night` of the sea and not on a roofed cell. By day: within
## `smoke_shore_tiles_day`, roof or not. The once-per-lap memory is not consulted.
func smoke_qualifies(cell: Vector2i, phase: DataEnums.DayPhase) -> bool:
	if phase == DataEnums.DayPhase.DAY:
		return distance_at(cell) <= smoke_day_tiles
	if _terrain != null and _terrain.is_shaded(cell):
		return false
	return distance_at(cell) <= smoke_night_tiles


## The lit `fires` that alert a boat now, each fire once per lap: a fire returned here is
## remembered until begin_lap(). Nothing, and nothing remembered, when the boat is not in sight.
func smoke_alerts(fires: Array[Node2D], phase: DataEnums.DayPhase, in_sight: bool) -> Array[Node2D]:
	var alerting: Array[Node2D] = []
	if not in_sight:
		return alerting
	for fire: Node2D in fires:
		var id: int = fire.get_instance_id()
		if _smoked.has(id):
			continue
		var at: Vector2 = fire.global_position / TILE
		if smoke_qualifies(Vector2i(floori(at.x), floori(at.y)), phase):
			_smoked[id] = true
			alerting.append(fire)
	return alerting


# --- noise and water -------------------------------------------------------------------------

## Whether a boat at `boat` hears a noise of `radius_tiles` (after the place's multiplier) made at
## `source`: the radius reaches `noise_alert_min_radius_tiles` and the boat is within it. Straight-line
## distance on purpose (design decision 7): there is only open water between a beach and a boat.
func noise_heard(boat: Vector2, source: Vector2, radius_tiles: float, in_sight: bool) -> bool:
	if not in_sight or radius_tiles < noise_min_radius_tiles:
		return false
	return boat.distance_to(source) <= radius_tiles


## Whether a player moving `movement` at `player` is spotted at once by a boat at `boat`: swimming
## or floating within `water_spot_radius_tiles`, with SIGHT not among the weather's
## `disabled_senses`. A diver is never spotted this way.
func water_spots(movement: MovementStep.Move, player: Vector2, boat: Vector2, disabled_senses: Array[DataEnums.Sense], in_sight: bool) -> bool:
	if not in_sight or disabled_senses.has(DataEnums.Sense.SIGHT):
		return false
	if movement != MovementStep.Move.SWIM and movement != MovementStep.Move.FLOAT:
		return false
	return boat.distance_to(player) <= water_radius_tiles


# --- the build -------------------------------------------------------------------------------

# Deep or shallow cells reached from the grid edge by 4-neighbour steps.
func _flood_sea() -> void:
	var queue: Array[Vector2i] = []
	for x: int in _size.x:
		queue.append(Vector2i(x, 0))
		queue.append(Vector2i(x, _size.y - 1))
	for y: int in _size.y:
		queue.append(Vector2i(0, y))
		queue.append(Vector2i(_size.x - 1, y))
	var head: int = 0
	while head < queue.size():
		var cell: Vector2i = queue[head]
		head += 1
		if cell.x < 0 or cell.y < 0 or cell.x >= _size.x or cell.y >= _size.y or _sea.has(cell):
			continue
		if not _is_open_water(cell):
			continue
		_sea[cell] = true
		for step: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			queue.append(cell + step)


func _is_open_water(cell: Vector2i) -> bool:
	var terrain: DataEnums.Terrain = _terrain.terrain_at(cell)
	return terrain == DataEnums.Terrain.DEEP or terrain == DataEnums.Terrain.SHALLOWS


# The nearest sea cell to any land cell is always a shore cell (a sea cell with a non-sea
# neighbour, diagonals included), so the exact distance needs only those.
func _measure() -> void:
	var shore: Array[Vector2i] = []
	for cell: Vector2i in _sea:
		if _touches_non_sea(cell):
			shore.append(cell)
	for y: int in _size.y:
		for x: int in _size.x:
			var cell := Vector2i(x, y)
			if TerrainQuery.is_water(_terrain.terrain_at(cell)):
				continue
			var best: int = 1 << 30
			for sea: Vector2i in shore:
				var delta: Vector2i = sea - cell
				best = mini(best, delta.x * delta.x + delta.y * delta.y)
			sea_distance[cell] = sqrt(float(best))


func _touches_non_sea(cell: Vector2i) -> bool:
	for dy: int in range(-1, 2):
		for dx: int in range(-1, 2):
			var next := cell + Vector2i(dx, dy)
			if next.x < 0 or next.y < 0 or next.x >= _size.x or next.y >= _size.y:
				continue
			if not _sea.has(next):
				return true
	return false
