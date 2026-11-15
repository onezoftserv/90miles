class_name SmallIsland
extends RefCounted
## A tiny inline island for the guardacostas-stealth loop tests: a GridTerrain, a size and
## nothing else, so a pose test builds in microseconds. Deep water everywhere except what a kind
## puts on top.

## A 5x4 beach on deep water: a plain rectangle.
const PLAIN: StringName = &"plain"
## An L of beach, so the hull has a concave side the loop must ignore.
const L_SHAPE: StringName = &"l_shape"
## A beach whose surroundings are all shallows: no deep water for a loop within 4 extra tiles.
const SHALLOW_ALL: StringName = &"shallow_all"
const SIZE: Vector2i = Vector2i(40, 40)

var terrain: GridTerrain = GridTerrain.new()
var size: Vector2i = SIZE


static func make(kind: StringName = PLAIN) -> SmallIsland:
	var island := SmallIsland.new()
	var sea: DataEnums.Terrain = DataEnums.Terrain.SHALLOWS if kind == SHALLOW_ALL else DataEnums.Terrain.DEEP
	island.terrain.default_terrain = sea
	island.terrain.fill_rect(Rect2i(Vector2i.ZERO, SIZE), sea)
	match kind:
		L_SHAPE:
			island.terrain.fill_rect(Rect2i(16, 14, 3, 10), DataEnums.Terrain.BEACH)
			island.terrain.fill_rect(Rect2i(19, 21, 6, 3), DataEnums.Terrain.BEACH)
		_:
			island.terrain.fill_rect(Rect2i(17, 18, 5, 4), DataEnums.Terrain.BEACH)
	return island
