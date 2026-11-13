class_name DevIslandTerrain
extends RefCounted
## The movement playground's beach (CoopPlayground's too): land, brush, mangrove, shallow, deep and
## brackish water and a shaded hut. TerrainView draws it (art-pass; design.md T1, T2), and TILE is
## the cell size every grid uses (IslandLayout.TILE).

const TILE: int = 16
## The hut, in cells: on the beach, north of the start.
const HUT: Rect2i = Rect2i(0, 8, 4, 3)


static func fill(terrain: GridTerrain) -> void:
	terrain.default_terrain = DataEnums.Terrain.DEEP
	terrain.fill_rect(Rect2i(0, 0, 16, 24), DataEnums.Terrain.BEACH)
	terrain.fill_rect(Rect2i(16, 0, 8, 24), DataEnums.Terrain.SHALLOWS)
	terrain.fill_rect(Rect2i(24, 0, 24, 24), DataEnums.Terrain.DEEP)
	terrain.fill_rect(Rect2i(4, 4, 6, 6), DataEnums.Terrain.SCRUB)
	terrain.fill_rect(Rect2i(10, 14, 4, 4), DataEnums.Terrain.MANGROVE)
	terrain.fill_rect(Rect2i(0, 20, 16, 4), DataEnums.Terrain.BRACKISH)
	terrain.set_shaded(HUT)

