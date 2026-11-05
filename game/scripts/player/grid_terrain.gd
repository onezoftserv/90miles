class_name GridTerrain
extends TerrainQuery
## TerrainQuery backed by a dictionary of cells, for tests and the movement playground.

var cells: Dictionary[Vector2i, DataEnums.Terrain] = {}
## Terrain of every cell not in `cells`.
var default_terrain: DataEnums.Terrain = DataEnums.Terrain.BEACH
var current: Vector2 = DEFAULT_CURRENT


func set_cell(cell: Vector2i, terrain: DataEnums.Terrain) -> void:
	cells[cell] = terrain


func fill_rect(rect: Rect2i, terrain: DataEnums.Terrain) -> void:
	for y: int in range(rect.position.y, rect.end.y):
		for x: int in range(rect.position.x, rect.end.x):
			cells[Vector2i(x, y)] = terrain


func terrain_at(cell: Vector2i) -> DataEnums.Terrain:
	return cells.get(cell, default_terrain)


func current_at(_cell: Vector2i) -> Vector2:
	return current
