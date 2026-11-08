class_name CreatureNav
extends RefCounted
## The two navigation grids of an island (creatures-ai "Creature navigation"): `land` (beach 1,
## dune 1.5, mangrove 3, shallows 2, deep water solid) and `water(margin)` (deep and shallow water
## only, cells closer to land than `margin` tiles solid). Cells are 16 px.

const TILE: float = 16.0
const FAR: int = 99
const STEPS_8: Array[Vector2i] = [
	Vector2i(-1, -1), Vector2i(0, -1), Vector2i(1, -1), Vector2i(-1, 0),
	Vector2i(1, 0), Vector2i(-1, 1), Vector2i(0, 1), Vector2i(1, 1),
]
const STEPS_4: Array[Vector2i] = [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]
const LAND_COSTS: Dictionary[DataEnums.Terrain, float] = {
	DataEnums.Terrain.DUNE: 1.5,
	DataEnums.Terrain.MANGROVE: 3.0,
	DataEnums.Terrain.SHALLOWS: 2.0,
}

var land: AStarGrid2D = AStarGrid2D.new()
var size: Vector2i = Vector2i.ZERO

var _terrain: GridTerrain
var _distance: Dictionary[Vector2i, int] = {}
var _water: Dictionary[int, AStarGrid2D] = {}


static func build(terrain: GridTerrain, grid_size: Vector2i) -> CreatureNav:
	var nav := CreatureNav.new()
	nav._terrain = terrain
	nav.size = grid_size
	nav._build_land()
	nav._measure_land_distance()
	return nav


## The cell a pixel position is in.
static func cell_of(position: Vector2) -> Vector2i:
	return Vector2i(floori(position.x / TILE), floori(position.y / TILE))


## The pixel position of the middle of `cell`.
static func center_of(cell: Vector2i) -> Vector2:
	return (Vector2(cell) + Vector2(0.5, 0.5)) * TILE


## Whether `cell` is on `grid` and walkable.
static func is_open(grid: AStarGrid2D, cell: Vector2i) -> bool:
	return grid.region.has_point(cell) and not grid.is_point_solid(cell)


## Chebyshev distance in tiles from `cell` to the nearest land cell (0 on land, FAR when none).
func land_distance(cell: Vector2i) -> int:
	return _distance.get(cell, FAR)


## The water grid for creatures that keep `margin` tiles off the shore (cached per margin).
func water(margin: int) -> AStarGrid2D:
	if _water.has(margin):
		return _water[margin]
	var grid := _new_grid()
	for y: int in size.y:
		for x: int in size.x:
			var cell := Vector2i(x, y)
			var kind := _terrain.terrain_at(cell)
			var open: bool = (kind == DataEnums.Terrain.DEEP or kind == DataEnums.Terrain.SHALLOWS) and land_distance(cell) >= margin
			grid.set_point_solid(cell, not open)
	_water[margin] = grid
	return grid


## Every 4-connected group of at least `min_cells` beach cells, as arrays of cells.
func beach_groups(min_cells: int = 8) -> Array[PackedVector2Array]:
	var groups: Array[PackedVector2Array] = []
	var seen: Dictionary[Vector2i, bool] = {}
	var bounds := Rect2i(Vector2i.ZERO, size)
	for y: int in size.y:
		for x: int in size.x:
			var start := Vector2i(x, y)
			if seen.has(start) or _terrain.terrain_at(start) != DataEnums.Terrain.BEACH:
				continue
			var group := PackedVector2Array()
			var queue: Array[Vector2i] = [start]
			seen[start] = true
			while not queue.is_empty():
				var cell: Vector2i = queue.pop_back()
				group.append(Vector2(cell))
				for step: Vector2i in STEPS_4:
					var next := cell + step
					if seen.has(next) or not bounds.has_point(next) or _terrain.terrain_at(next) != DataEnums.Terrain.BEACH:
						continue
					seen[next] = true
					queue.append(next)
			if group.size() >= min_cells:
				groups.append(group)
	return groups


func _new_grid() -> AStarGrid2D:
	var grid := AStarGrid2D.new()
	grid.region = Rect2i(Vector2i.ZERO, size)
	grid.cell_size = Vector2.ONE
	grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_NEVER
	grid.update()
	return grid


func _build_land() -> void:
	land = _new_grid()
	for y: int in size.y:
		for x: int in size.x:
			var cell := Vector2i(x, y)
			var kind := _terrain.terrain_at(cell)
			land.set_point_solid(cell, kind == DataEnums.Terrain.DEEP)
			land.set_point_weight_scale(cell, LAND_COSTS.get(kind, 1.0))


func _measure_land_distance() -> void:
	var queue: Array[Vector2i] = []
	var bounds := Rect2i(Vector2i.ZERO, size)
	for y: int in size.y:
		for x: int in size.x:
			var cell := Vector2i(x, y)
			if not TerrainQuery.is_water(_terrain.terrain_at(cell)):
				_distance[cell] = 0
				queue.append(cell)
	var head: int = 0
	while head < queue.size():
		var cell: Vector2i = queue[head]
		head += 1
		for step: Vector2i in STEPS_8:
			var next := cell + step
			if _distance.has(next) or not bounds.has_point(next):
				continue
			_distance[next] = _distance[cell] + 1
			queue.append(next)
