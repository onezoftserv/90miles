class_name ArrivalScatter
extends RefCounted
## Where each arriving rider lands (crossing "Arrival scatter", "Arrival scatter fallback";
## vessel-car-board design D7). Pure: the host picks the cells on the next island's built layout
## from each rider's route scatter and a seed, and sends them with the arrivals, so every peer lands
## everyone on the same cells. Riders of a route with the default scatter take the landing cells
## in peer order, as IslandArrival.landing_positions does. Every rider of a wider route lands, in
## peer order, on a beach cell reachable on foot from the first landing cell, within its range of
## every rider already placed; the first one placed takes the first landing cell, so a lone rider
## always does.

## A route's default arrival scatter in tiles (RouteData.arrival_scatter_tiles): the landing cells.
const DEFAULT_TILES: Vector2i = Vector2i(0, 5)


## The landing cell of every peer in `scatter` (peer -> its route's scatter, the minimum and
## maximum in tiles) on `built`, the wider routes' cells rolled from `seed_value`.
static func pick(built: IslandLayout, scatter: Dictionary[int, Vector2i], seed_value: int) -> Dictionary[int, Vector2i]:
	var peers: Array[int] = []
	for peer: int in scatter:
		peers.append(peer)
	peers.sort()
	var landing: Array[Vector2i] = built.landing_cells().duplicate()
	if landing.is_empty():
		landing = [built.solo_spawn]
	var placed: Dictionary[int, Vector2i] = {}
	var wide: Array[int] = []
	for peer: int in peers:
		if is_wide(scatter[peer]):
			wide.append(peer)
		else:
			placed[peer] = landing[placed.size() % landing.size()]
	if wide.is_empty():
		return placed
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var beach: Array[Vector2i] = beach_cells(built, landing[0])
	for peer: int in wide:
		if placed.is_empty():
			placed[peer] = landing[0]
			continue
		var free: Array[Vector2i] = []
		var taken: Array[Vector2i] = []
		taken.assign(placed.values())
		for cell: Vector2i in beach:
			if not taken.has(cell):
				free.append(cell)
		if free.is_empty():
			placed[peer] = landing[placed.size() % landing.size()]
			continue
		placed[peer] = _choose(free, taken, scatter[peer], rng)
	return placed


## True when `tiles` spreads riders wider than the default: they scatter over the beach.
static func is_wide(tiles: Vector2i) -> bool:
	return tiles.x > DEFAULT_TILES.x or tiles.y > DEFAULT_TILES.y


## The beach cells reachable on foot from `start`, by row and then column.
static func beach_cells(built: IslandLayout, start: Vector2i) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for cell: Vector2i in built.reachable_from(start):
		if built.terrain.cells.get(cell) == DataEnums.Terrain.BEACH:
			cells.append(cell)
	cells.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return a.y < b.y or (a.y == b.y and a.x < b.x))
	return cells


# One of `free` within `tiles` of every cell in `taken`, rolled; otherwise the fallback: the cell
# keeping the minimum from everyone that is nearest its farthest rider, else the cell farthest
# from its nearest rider. Ties go to the first in row-then-column order.
static func _choose(free: Array[Vector2i], taken: Array[Vector2i], tiles: Vector2i, rng: RandomNumberGenerator) -> Vector2i:
	var fitting: Array[Vector2i] = []
	for cell: Vector2i in free:
		if _nearest(cell, taken) >= tiles.x and _farthest(cell, taken) <= tiles.y:
			fitting.append(cell)
	if not fitting.is_empty():
		return fitting[rng.randi_range(0, fitting.size() - 1)]
	var best: Vector2i = free[0]
	var best_far: float = INF
	for cell: Vector2i in free:
		var far: float = _farthest(cell, taken)
		if _nearest(cell, taken) >= tiles.x and far < best_far:
			best = cell
			best_far = far
	if best_far < INF:
		return best
	var best_near: float = -1.0
	for cell: Vector2i in free:
		var near: float = _nearest(cell, taken)
		if near > best_near:
			best = cell
			best_near = near
	return best


static func _nearest(cell: Vector2i, taken: Array[Vector2i]) -> float:
	var nearest: float = INF
	for other: Vector2i in taken:
		nearest = minf(nearest, Vector2(cell - other).length())
	return nearest


static func _farthest(cell: Vector2i, taken: Array[Vector2i]) -> float:
	var farthest: float = 0.0
	for other: Vector2i in taken:
		farthest = maxf(farthest, Vector2(cell - other).length())
	return farthest
