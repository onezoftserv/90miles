class_name SquadPlan
extends RefCounted
## guardacostas-capture design.md §6 (specs "Squad search", "Last known position", "The squad
## leaves"): what a landed squad searches and when it leaves, as a pure plan the docked boat's brain
## owns and steps on the host. Cells are island cells; positions in tiles (a cell's centre is +0.5).
## - The landing: the BEACH cell nearest the boat in a straight line, unless the nearest land is much
##   nearer (the island has no beach on that side), then that land cell.
## - The points, built at landing: every lit fire, nearest the landing first, then the alert's last
##   known position. Each soldier takes the first point nobody has taken; a soldier with no point
##   walks between land cells drawn from a seeded stream (Brogue's waypoint wander).
## - Searching a point takes `point_search_s` and finds any hidden player within `point_search_tiles`.
## - A newer last known position replaces the old one and goes to the nearest free soldier.
## - The squad leaves when `search_duration_s` has passed since beaching and `capture_grace_s` since
##   its latest capture, at once when no free player is left on the island, or in a squall.
## Threshold checks use the movement model's 1e-6 tolerance.

enum PointKind {
	FIRE,
	LAST_KNOWN,
}

const EPSILON: float = 0.000001
const NOBODY: int = -1
const NO_CELL: Vector2i = Vector2i(-1, -1)
## The landing keeps to a beach unless the nearest land is this many tiles nearer than any beach.
const BEACH_DETOUR_TILES: float = 6.0

## One search point.
class Point extends RefCounted:
	var cell: Vector2i = Vector2i.ZERO
	var kind: SquadPlan.PointKind = SquadPlan.PointKind.FIRE
	## The soldier searching it, or NOBODY.
	var taken_by: int = SquadPlan.NOBODY
	var searched: bool = false


var search_duration_s: float = 180.0
var capture_grace_s: float = 60.0
var point_search_s: float = 3.0
var point_search_tiles: float = 2.0
## Where the dinghy beached.
var landing: Vector2i = Vector2i.ZERO
## Seconds since the dinghy beached.
var elapsed_s: float = 0.0
## elapsed_s at the squad's latest capture; negative before its first.
var last_capture_s: float = -1.0
var points: Array[Point] = []

var _walk: Array[Vector2i] = []
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()


## The plan for a squad landed on `landing_at` with `patrol`'s numbers: `fires` (their cells) and the
## alert's `last_known` cell (NO_CELL for none) become points; the random walk draws from
## `walk_cells` with `seed_value`.
static func build(patrol: PatrolData, landing_at: Vector2i, fires: Array[Vector2i], last_known: Vector2i, walk_cells: Array[Vector2i], seed_value: int) -> SquadPlan:
	var plan := SquadPlan.new()
	plan.search_duration_s = patrol.search_duration_s
	plan.capture_grace_s = patrol.capture_grace_s
	plan.point_search_s = patrol.point_search_s
	plan.point_search_tiles = patrol.point_search_tiles
	plan.landing = landing_at
	var order: Array[Vector2i] = fires.duplicate()
	var from: Vector2 = SquadPlan.center(landing_at)
	order.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		var da: float = SquadPlan.center(a).distance_squared_to(from)
		var db: float = SquadPlan.center(b).distance_squared_to(from)
		if absf(da - db) > EPSILON:
			return da < db
		return a.y < b.y or (a.y == b.y and a.x < b.x))
	for cell: Vector2i in order:
		plan._add_point(cell, PointKind.FIRE)
	if last_known != NO_CELL:
		plan._add_point(last_known, PointKind.LAST_KNOWN)
	plan._walk = walk_cells.duplicate()
	plan._walk.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return a.y < b.y or (a.y == b.y and a.x < b.x))
	plan._rng.seed = seed_value
	return plan


## The centre of `cell` in tiles.
static func center(cell: Vector2i) -> Vector2:
	return Vector2(cell) + Vector2(0.5, 0.5)


## The landing for a boat at `boat` (tiles) on an island of `cells` (cell -> terrain): the nearest
## BEACH cell in a straight line, or the nearest land cell when that is more than BEACH_DETOUR_TILES
## nearer (no beach on the boat's side). Ties go by reading order. NO_CELL without land.
static func landing_cell(boat: Vector2, cells: Dictionary) -> Vector2i:
	var beach: Vector2i = NO_CELL
	var land: Vector2i = NO_CELL
	for cell: Vector2i in cells:
		var terrain: DataEnums.Terrain = cells[cell]
		if TerrainQuery.is_water(terrain):
			continue
		if _nearer(cell, land, boat):
			land = cell
		if terrain == DataEnums.Terrain.BEACH and _nearer(cell, beach, boat):
			beach = cell
	if beach == NO_CELL:
		return land
	var beach_gap: float = center(beach).distance_to(boat)
	var land_gap: float = center(land).distance_to(boat)
	return land if beach_gap - land_gap > BEACH_DETOUR_TILES + EPSILON else beach


## Seconds the dinghy takes from `boat` (tiles) to the middle of `landing_at` at `speed_tiles_s`.
static func row_time_s(boat: Vector2, landing_at: Vector2i, speed_tiles_s: float) -> float:
	if speed_tiles_s <= 0.0:
		return 0.0
	return boat.distance_to(center(landing_at)) / speed_tiles_s


## Whether searching the point `cell` finds a hidden player standing at `player` (tiles).
func finds(cell: Vector2i, player: Vector2) -> bool:
	return center(cell).distance_to(player) <= point_search_tiles + EPSILON


## The point `soldier` searches: the one it holds, else the first nobody has taken (now its own), or
## null when every point is taken or searched (it walks).
func take_point(soldier: int) -> Point:
	var held := point_of(soldier)
	if held != null:
		return held
	for point: Point in points:
		if point.taken_by == NOBODY and not point.searched:
			point.taken_by = soldier
			return point
	return null


## The unsearched point `soldier` holds, or null.
func point_of(soldier: int) -> Point:
	for point: Point in points:
		if point.taken_by == soldier and not point.searched:
			return point
	return null


## `soldier` searched its point.
func searched(soldier: int) -> void:
	var point := point_of(soldier)
	if point != null:
		point.searched = true
		point.taken_by = NOBODY


## `soldier` drops its point unsearched (it chases, escorts or leaves): someone else may take it.
func drop_point(soldier: int) -> void:
	var point := point_of(soldier)
	if point != null:
		point.taken_by = NOBODY


## A newer last known position: it replaces the old one (searched or not) and goes to the nearest of
## `free_soldiers` (soldier -> position in tiles; not escorting or chasing). Returns that soldier, or
## NOBODY when none is free (the point waits for the first to take it).
func set_last_known(cell: Vector2i, free_soldiers: Dictionary) -> int:
	for i: int in range(points.size() - 1, -1, -1):
		if points[i].kind == PointKind.LAST_KNOWN:
			points.remove_at(i)
	var point := _add_point(cell, PointKind.LAST_KNOWN)
	var best: int = NOBODY
	var best_gap: float = INF
	var ids: Array = free_soldiers.keys()
	ids.sort()
	for soldier: int in ids:
		var gap: float = (free_soldiers[soldier] as Vector2).distance_to(center(cell))
		if gap < best_gap - EPSILON:
			best = soldier
			best_gap = gap
	if best != NOBODY:
		drop_point(best)
		point.taken_by = best
	return best


## The current last known position, NO_CELL when there is none to search.
func last_known() -> Vector2i:
	for point: Point in points:
		if point.kind == PointKind.LAST_KNOWN and not point.searched:
			return point.cell
	return NO_CELL


## The next random-walk cell (the stream is the plan's own, so equal seeds walk alike).
func next_walk_cell() -> Vector2i:
	if _walk.is_empty():
		return landing
	return _walk[_rng.randi_range(0, _walk.size() - 1)]


func advance(delta: float) -> void:
	elapsed_s += delta


## The squad captured someone now.
func note_capture() -> void:
	last_capture_s = elapsed_s


## The search is over: its time has passed, and the grace since the latest capture too.
func time_is_up() -> bool:
	if elapsed_s < search_duration_s - EPSILON:
		return false
	return last_capture_s < 0.0 or elapsed_s - last_capture_s >= capture_grace_s - EPSILON


## Whether the squad leaves now: its time is up, no free player is left on the island, or a squall.
func should_leave(free_on_island: int, squall: bool) -> bool:
	return squall or free_on_island <= 0 or time_is_up()


func _add_point(cell: Vector2i, kind: PointKind) -> Point:
	var point := Point.new()
	point.cell = cell
	point.kind = kind
	points.append(point)
	return point


static func _nearer(cell: Vector2i, best: Vector2i, boat: Vector2) -> bool:
	if best == NO_CELL:
		return true
	var a: float = center(cell).distance_squared_to(boat)
	var b: float = center(best).distance_squared_to(boat)
	if absf(a - b) > EPSILON:
		return a < b
	return cell.y < best.y or (cell.y == best.y and cell.x < best.x)
