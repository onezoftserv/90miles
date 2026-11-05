class_name TerrainQuery
extends RefCounted
## What the player body asks about the ground under it. GridTerrain implements it from a
## dictionary; island-generation will add a TileMapLayer-backed one. This base class is a
## featureless beach.

## Water current in tiles/s when the island does not say otherwise: the trade wind, east.
const DEFAULT_CURRENT: Vector2 = Vector2(1.0, 0.0)


func terrain_at(_cell: Vector2i) -> DataEnums.Terrain:
	return DataEnums.Terrain.BEACH


## Current in tiles/s at `_cell`.
func current_at(_cell: Vector2i) -> Vector2:
	return DEFAULT_CURRENT


static func is_water(terrain: DataEnums.Terrain) -> bool:
	return terrain == DataEnums.Terrain.DEEP or terrain == DataEnums.Terrain.SHALLOWS or terrain == DataEnums.Terrain.BRACKISH


## Brush hides a crouching player.
static func is_brush(terrain: DataEnums.Terrain) -> bool:
	return terrain == DataEnums.Terrain.SCRUB or terrain == DataEnums.Terrain.MANGROVE
