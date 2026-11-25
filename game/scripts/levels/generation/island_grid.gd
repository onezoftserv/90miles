class_name IslandGrid
extends RefCounted
## Integer grid helpers for the island generator (island-generator design §4): grids are
## PackedInt32Array indexed y * width + x. Distances are integers: Chebyshev rings by
## breadth-first search, squared Euclidean inside a window, walks by an 8-way chamfer in
## half-tiles (2 per orthogonal step, 3 per diagonal). Ties always break by reading order.

## A distance no real cell reaches.
const FAR: int = 1 << 30
const ORTHOGONAL: Array[Vector2i] = [Vector2i(0, -1), Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, 1)]
const EIGHT: Array[Vector2i] = [
	Vector2i(-1, -1), Vector2i(0, -1), Vector2i(1, -1), Vector2i(-1, 0),
	Vector2i(1, 0), Vector2i(-1, 1), Vector2i(0, 1), Vector2i(1, 1),
]

var width: int = 0
var height: int = 0


func _init(columns: int = 0, rows: int = 0) -> void:
	width = columns
	height = rows


func cell_count() -> int:
	return width * height


func index_of(cell: Vector2i) -> int:
	return cell.y * width + cell.x


func cell_of(index: int) -> Vector2i:
	return Vector2i(index % width, index / width)


func has(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < width and cell.y < height


## A grid of `value` everywhere.
func filled(value: int) -> PackedInt32Array:
	var grid := PackedInt32Array()
	grid.resize(cell_count())
	grid.fill(value)
	return grid


## 1 where `grid` holds one of `values`, else 0.
func mask_of(grid: PackedInt32Array, values: Array) -> PackedInt32Array:
	var mask := filled(0)
	for i: int in grid.size():
		if values.has(grid[i]):
			mask[i] = 1
	return mask


## Chebyshev distance (8-way rings) from every cell to the nearest cell where `sources` is not 0;
## sources are 0, unreachable cells FAR. Breadth-first.
func chebyshev_from(sources: PackedInt32Array) -> PackedInt32Array:
	var distance := filled(FAR)
	var queue := PackedInt32Array()
	for i: int in sources.size():
		if sources[i] != 0:
			distance[i] = 0
			queue.append(i)
	var head: int = 0
	while head < queue.size():
		var i: int = queue[head]
		head += 1
		var cell: Vector2i = cell_of(i)
		for step: Vector2i in EIGHT:
			var next: Vector2i = cell + step
			if not has(next):
				continue
			var j: int = index_of(next)
			if distance[j] != FAR:
				continue
			distance[j] = distance[i] + 1
			queue.append(j)
	return distance


## The squared Euclidean distance from `cell` to the nearest cell where `sources` is not 0 within
## `radius` tiles (a square window); -1 when there is none. Cells off the grid count as sources
## when `edge_is_source`.
func nearest_squared(sources: PackedInt32Array, cell: Vector2i, radius: int, edge_is_source: bool = false) -> int:
	var best: int = -1
	for dy: int in range(-radius, radius + 1):
		for dx: int in range(-radius, radius + 1):
			var squared: int = dx * dx + dy * dy
			if squared > radius * radius or best >= 0 and squared >= best:
				continue
			var next := Vector2i(cell.x + dx, cell.y + dy)
			var source: bool = edge_is_source if not has(next) else sources[index_of(next)] != 0
			if source:
				best = squared
	return best


## 4-connected labels of the cells where `mask` is not 0: {labels: PackedInt32Array (-1 off the
## mask, bodies numbered in reading order of their first cell), sizes: PackedInt32Array,
## largest: int (the biggest body, the first on a tie; -1 when there is none)}.
func label_bodies(mask: PackedInt32Array) -> Dictionary:
	var labels := filled(-1)
	var sizes := PackedInt32Array()
	var largest: int = -1
	var queue := PackedInt32Array()
	for start: int in mask.size():
		if mask[start] == 0 or labels[start] != -1:
			continue
		var label: int = sizes.size()
		labels[start] = label
		queue.clear()
		queue.append(start)
		var head: int = 0
		while head < queue.size():
			var cell: Vector2i = cell_of(queue[head])
			head += 1
			for step: Vector2i in ORTHOGONAL:
				var next: Vector2i = cell + step
				if not has(next):
					continue
				var j: int = index_of(next)
				if mask[j] == 0 or labels[j] != -1:
					continue
				labels[j] = label
				queue.append(j)
		sizes.append(queue.size())
		if largest < 0 or queue.size() > sizes[largest]:
			largest = label
	return {"labels": labels, "sizes": sizes, "largest": largest}


## Walk distances in half-tiles from `start` over the cells where `walkable` is not 0: an
## orthogonal step costs 2, a diagonal 3, and a diagonal is taken only where both orthogonal
## neighbours are walkable (AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES). Unreached cells -1.
## Never shorter than the Euclidean shortest path and at most 6.1% longer.
func chamfer_walk(walkable: PackedInt32Array, start: Vector2i) -> PackedInt32Array:
	var distance := filled(-1)
	if not has(start) or walkable[index_of(start)] == 0:
		return distance
	# A bucket queue: every step costs 2 or 3, so buckets by distance are processed in order.
	var buckets: Array[Array] = [[index_of(start)]]
	var best := filled(FAR)
	best[index_of(start)] = 0
	var d: int = 0
	while d < buckets.size():
		for i: int in buckets[d]:
			if distance[i] != -1 or best[i] != d:
				continue
			distance[i] = d
			var cell: Vector2i = cell_of(i)
			for step: Vector2i in EIGHT:
				var next: Vector2i = cell + step
				if not has(next):
					continue
				var j: int = index_of(next)
				if walkable[j] == 0 or distance[j] != -1:
					continue
				var cost: int = 2
				if step.x != 0 and step.y != 0:
					if walkable[index_of(Vector2i(next.x, cell.y))] == 0 or walkable[index_of(Vector2i(cell.x, next.y))] == 0:
						continue
					cost = 3
				var reach: int = d + cost
				if reach >= best[j]:
					continue
				best[j] = reach
				while buckets.size() <= reach:
					buckets.append([])
				buckets[reach].append(j)
		d += 1
	return distance
