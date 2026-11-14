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
## How many times the wider riders' cells are rolled, keeping the first roll where every rider fits
## (else the one that needs the fallback least): a greedy early pick can leave a later rider no room.
const ATTEMPTS: int = 16


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
	var best: Dictionary[int, Vector2i] = {}
	var best_misses: int = -1
	for attempt: int in ATTEMPTS:
		var rolled: Dictionary[int, Vector2i] = placed.duplicate()
		var misses: int = 0
		for peer: int in wide:
			if rolled.is_empty():
				rolled[peer] = landing[0]
				continue
			var taken: Array[Vector2i] = []
			taken.assign(rolled.values())
			var free: Array[Vector2i] = []
			for cell: Vector2i in beach:
				if not taken.has(cell):
					free.append(cell)
			if free.is_empty():
				rolled[peer] = landing[rolled.size() % landing.size()]
				misses += 1
				continue
			var fitting: Array[Vector2i] = _fitting(free, taken, scatter[peer])
			if fitting.is_empty():
				rolled[peer] = _fallback(free, taken, scatter[peer])
				misses += 1
			else:
				rolled[peer] = fitting[rng.randi_range(0, fitting.size() - 1)]
		if best_misses < 0 or misses < best_misses:
			best = rolled
			best_misses = misses
		if misses == 0:
			break
	return best


## True when `tiles` spreads riders wider than the default: they scatter over the beach.
static func is_wide(tiles: Vector2i) -> bool:
	return tiles.x > DEFAULT_TILES.x or tiles.y > DEFAULT_TILES.y


## The beach cells reachable on foot from `start` that hold nothing of the island's own (a palm,
## the raft site, a drinking spot, a sign, the hut, the workbench, a tide pool), by row and then
## column.
static func beach_cells(built: IslandLayout, start: Vector2i) -> Array[Vector2i]:
	var furnished: Dictionary[Vector2i, bool] = {}
	for list: Array[Vector2i] in [built.palms, built.drink_spots, built.hut_cells, built.tide_pools]:
		for cell: Vector2i in list:
			furnished[cell] = true
	for cell: Vector2i in [built.raft_site, built.workbench]:
		furnished[cell] = true
	for entry: Dictionary in built.signs:
		furnished[entry["cell"]] = true
	var cells: Array[Vector2i] = []
	for cell: Vector2i in built.reachable_from(start):
		if built.terrain.cells.get(cell) == DataEnums.Terrain.BEACH and not furnished.has(cell):
			cells.append(cell)
	cells.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return a.y < b.y or (a.y == b.y and a.x < b.x))
	return cells


# The cells of `free` within `tiles` of every cell in `taken`.
static func _fitting(free: Array[Vector2i], taken: Array[Vector2i], tiles: Vector2i) -> Array[Vector2i]:
	var fitting: Array[Vector2i] = []
	for cell: Vector2i in free:
		if _nearest(cell, taken) >= tiles.x and _farthest(cell, taken) <= tiles.y:
			fitting.append(cell)
	return fitting


# When no cell fits: the cell keeping the minimum from everyone that is nearest its farthest rider,
# else the cell farthest from its nearest rider. Ties go to the first in row-then-column order.
static func _fallback(free: Array[Vector2i], taken: Array[Vector2i], tiles: Vector2i) -> Vector2i:
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
