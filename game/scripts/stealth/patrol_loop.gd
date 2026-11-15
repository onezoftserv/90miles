class_name PatrolLoop
extends RefCounted
## guardacostas-stealth decision 3: the patrol boat's loop. The convex hull of the island's land
## cell centres, each edge pushed out `offshore_tiles` and the neighbours joined at their
## intersection (a mitre), so every point of the loop is at least that far from the hull. It is
## sampled every half tile; a sample that is not deep water pushes the whole loop one tile more,
## at most MAX_EXTRA_PUSH times, and then the island gets no loop and a warning. The lap starts
## at the most easterly vertex and runs clockwise as seen on screen (y grows downward), so the
## first step goes south. A pure function of the terrain: the same on every peer. Positions are
## in tiles, cell (x, y) spanning x..x+1 and y..y+1; pose_px gives pixels.

const TILE: float = 16.0
const SAMPLE_STEP: float = 0.5
const MAX_EXTRA_PUSH: int = 4
## Seconds Experiencia adds to the period per level.
const EXPERIENCIA_SECONDS: float = 10.0
const EPSILON: float = 0.000001

## Where a boat is in its period.
enum Phase {
	HORIZON,
	LAP,
	AWAY,
}

## False when the island has no loop (no land, or no deep water within MAX_EXTRA_PUSH tiles).
var valid: bool = false
## The convex hull of the land cell centres, clockwise on screen.
var hull: PackedVector2Array = PackedVector2Array()
## The loop's corners, clockwise on screen, the most easterly first.
var points: PackedVector2Array = PackedVector2Array()
## Every half tile along the loop, starting at points[0].
var samples: PackedVector2Array = PackedVector2Array()
## The loop's length in tiles.
var perimeter: float = 0.0
## Seconds one lap takes.
var lap_s: float = 0.0
## The mean of the land cell centres: where the searchlight's sweep is centred.
var centroid: Vector2 = Vector2.ZERO
## Tiles the loop was pushed beyond `offshore_tiles` to reach deep water.
var extra_push: int = 0

# Arc length at each corner, `points.size() + 1` entries, the last being the perimeter.
var _arc: PackedFloat64Array = PackedFloat64Array()


## The loop of the island `terrain` (`size` columns and rows) for a lap of `lap_seconds`.
static func build(terrain: TerrainQuery, size: Vector2i, lap_seconds: float, offshore_tiles: float = 4.0) -> PatrolLoop:
	var loop := PatrolLoop.new()
	loop.lap_s = lap_seconds
	var land: PackedVector2Array = _land_centres(terrain, size)
	if land.is_empty():
		push_warning("PatrolLoop: the island has no land, so it gets no patrol loop")
		return loop
	var sum := Vector2.ZERO
	for centre: Vector2 in land:
		sum += centre
	loop.centroid = sum / land.size()
	loop.hull = _convex_hull(land)
	if loop.hull.size() < 3:
		push_warning("PatrolLoop: the island's land is a point or a line, so it gets no patrol loop")
		return loop
	for extra: int in MAX_EXTRA_PUSH + 1:
		var corners: PackedVector2Array = _offset_polygon(loop.hull, offshore_tiles + extra)
		var ring: PackedVector2Array = _rotate_to_start(corners)
		var ring_samples: PackedVector2Array = _sample(ring)
		if _all_deep(ring_samples, terrain, size):
			loop.points = ring
			loop.samples = ring_samples
			loop.extra_push = extra
			loop._measure()
			loop.valid = true
			return loop
	push_warning("PatrolLoop: no deep water within %d extra tiles of the hull, so the island gets no patrol loop" % MAX_EXTRA_PUSH)
	return loop


## Where the boat is `lap_time` seconds into its lap, in tiles. The start at 0 and at the lap's
## end; a time beyond the lap wraps. (0, 0) when the island has no loop.
func pose_at(lap_time: float) -> Vector2:
	if not valid or lap_s <= 0.0:
		return Vector2.ZERO
	var along: float = perimeter * fposmod(lap_time, lap_s) / lap_s
	for i: int in points.size():
		var end_arc: float = _arc[i + 1]
		if along <= end_arc or i == points.size() - 1:
			var from: Vector2 = points[i]
			var to: Vector2 = points[(i + 1) % points.size()]
			var length: float = end_arc - _arc[i]
			return from if length <= 0.0 else from.lerp(to, clampf((along - _arc[i]) / length, 0.0, 1.0))
	return points[0]


## pose_at in pixels.
func pose_px(lap_time: float) -> Vector2:
	return pose_at(lap_time) * TILE


## The boat's speed in tiles per second.
func speed_tiles_s() -> float:
	return perimeter / lap_s if lap_s > 0.0 else 0.0


## The loop's period: `patrol.route_period_s` plus 10 s per Experiencia level.
static func period_s(patrol: PatrolData, level: int = 0) -> float:
	return patrol.route_period_s + EXPERIENCIA_SECONDS * level


## The Experiencia level the loop reads. The seam for the skill: 0 until Experiencia exists.
static func experiencia_level() -> int:
	return 0


## The phase of a boat whose clock reads `clock_s` (any value: it is taken modulo the period).
static func phase_at(clock_s: float, period: float, warning_s: float, lap_seconds: float) -> Phase:
	var t: float = fposmod(clock_s, period) if period > 0.0 else 0.0
	if t < warning_s:
		return Phase.HORIZON
	if t < warning_s + lap_seconds:
		return Phase.LAP
	return Phase.AWAY


## Seconds into the lap for a clock in the LAP phase: the clock minus the warning.
static func lap_time(clock_s: float, warning_s: float) -> float:
	return clock_s - warning_s


## Boat `index` of `count` runs its clock index * period / count behind boat 0, wrapped to the period.
static func boat_clock(world_s: float, index: int, count: int, period: float) -> float:
	if period <= 0.0:
		return 0.0
	var offset: float = period * index / maxi(count, 1)
	return fposmod(world_s - offset, period)


# --- the build -------------------------------------------------------------------------------

func _measure() -> void:
	_arc = PackedFloat64Array([0.0])
	for i: int in points.size():
		_arc.append(_arc[i] + points[i].distance_to(points[(i + 1) % points.size()]))
	perimeter = _arc[points.size()]


# The centre of every land cell: not water, inside the grid. Row by row, so the order is fixed.
static func _land_centres(terrain: TerrainQuery, size: Vector2i) -> PackedVector2Array:
	var centres := PackedVector2Array()
	for y: int in size.y:
		for x: int in size.x:
			if not TerrainQuery.is_water(terrain.terrain_at(Vector2i(x, y))):
				centres.append(Vector2(x + 0.5, y + 0.5))
	return centres


# Andrew's monotone chain, without collinear points, returned clockwise as seen on screen (a
# positive shoelace sum with y downward).
static func _convex_hull(cloud: PackedVector2Array) -> PackedVector2Array:
	var sorted: Array[Vector2] = []
	sorted.assign(cloud)
	sorted.sort_custom(func(a: Vector2, b: Vector2) -> bool: return a.x < b.x or (a.x == b.x and a.y < b.y))
	if sorted.size() < 3:
		return PackedVector2Array(sorted)
	var chain: Array[Vector2] = []
	for point: Vector2 in sorted:
		while chain.size() >= 2 and (chain[-1] - chain[-2]).cross(point - chain[-2]) <= 0.0:
			chain.pop_back()
		chain.append(point)
	var lower_size: int = chain.size() + 1
	for i: int in range(sorted.size() - 2, -1, -1):
		var point: Vector2 = sorted[i]
		while chain.size() >= lower_size and (chain[-1] - chain[-2]).cross(point - chain[-2]) <= 0.0:
			chain.pop_back()
		chain.append(point)
	chain.pop_back()
	var ring := PackedVector2Array(chain)
	if _shoelace(ring) < 0.0:
		ring.reverse()
	return ring


static func _shoelace(ring: PackedVector2Array) -> float:
	var area: float = 0.0
	for i: int in ring.size():
		area += ring[i].cross(ring[(i + 1) % ring.size()])
	return area


# Each edge of the clockwise `ring` moved outward by `distance`, neighbours joined where their
# lines cross. For a positive shoelace sum the outward normal of an edge (dx, dy) is (dy, -dx).
static func _offset_polygon(ring: PackedVector2Array, distance: float) -> PackedVector2Array:
	var count: int = ring.size()
	var out := PackedVector2Array()
	for i: int in count:
		var before: Vector2 = ring[(i + count - 1) % count]
		var here: Vector2 = ring[i]
		var after: Vector2 = ring[(i + 1) % count]
		var in_dir: Vector2 = (here - before).normalized()
		var out_dir: Vector2 = (after - here).normalized()
		var in_start: Vector2 = before + Vector2(in_dir.y, -in_dir.x) * distance
		var out_start: Vector2 = here + Vector2(out_dir.y, -out_dir.x) * distance
		var denominator: float = in_dir.cross(out_dir)
		var along: float = (out_start - in_start).cross(out_dir) / denominator
		out.append(in_start + in_dir * along)
	return out


# The corners rotated so the most easterly (then most northerly) comes first. The ring is already
# clockwise on screen, so from there the first step goes south.
static func _rotate_to_start(corners: PackedVector2Array) -> PackedVector2Array:
	var best: int = 0
	for i: int in corners.size():
		var c: Vector2 = corners[i]
		var b: Vector2 = corners[best]
		if c.x > b.x + EPSILON or (absf(c.x - b.x) <= EPSILON and c.y < b.y):
			best = i
	var ring := PackedVector2Array()
	for i: int in corners.size():
		ring.append(corners[(best + i) % corners.size()])
	return ring


# Points every SAMPLE_STEP along the closed ring, from the first corner round to just short of it.
static func _sample(ring: PackedVector2Array) -> PackedVector2Array:
	var found := PackedVector2Array()
	for i: int in ring.size():
		var from: Vector2 = ring[i]
		var to: Vector2 = ring[(i + 1) % ring.size()]
		var pieces: int = maxi(ceili(from.distance_to(to) / SAMPLE_STEP - EPSILON), 1)
		for piece: int in pieces:
			found.append(from.lerp(to, float(piece) / pieces))
	return found


static func _all_deep(ring_samples: PackedVector2Array, terrain: TerrainQuery, size: Vector2i) -> bool:
	for sample: Vector2 in ring_samples:
		var cell := Vector2i(floori(sample.x), floori(sample.y))
		if cell.x < 0 or cell.y < 0 or cell.x >= size.x or cell.y >= size.y:
			return false
		if terrain.terrain_at(cell) != DataEnums.Terrain.DEEP:
			return false
	return true
