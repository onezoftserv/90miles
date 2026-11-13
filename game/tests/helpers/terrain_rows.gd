class_name TerrainRows
extends RefCounted
## Small hand-made grids for the terrain art tests, one string per row. Glyphs: `.` deep water,
## `~` shallows, `,` brackish, `s` beach, `d` dune, `b` scrub, `r` rock, `p` a tide pool (shallows
## that the art counts as land, listed by `pools`). Cells outside the rows are deep water.

const KINDS: Dictionary[String, DataEnums.Terrain] = {
	".": DataEnums.Terrain.DEEP,
	"~": DataEnums.Terrain.SHALLOWS,
	",": DataEnums.Terrain.BRACKISH,
	"s": DataEnums.Terrain.BEACH,
	"d": DataEnums.Terrain.DUNE,
	"b": DataEnums.Terrain.SCRUB,
	"r": DataEnums.Terrain.ROCK,
	"p": DataEnums.Terrain.SHALLOWS,
}


static func build(rows: PackedStringArray) -> GridTerrain:
	var terrain := GridTerrain.new()
	terrain.default_terrain = DataEnums.Terrain.DEEP
	for y: int in rows.size():
		for x: int in rows[y].length():
			terrain.set_cell(Vector2i(x, y), KINDS[rows[y][x]])
	return terrain


static func pools(rows: PackedStringArray) -> Array[Vector2i]:
	var found: Array[Vector2i] = []
	for y: int in rows.size():
		for x: int in rows[y].length():
			if rows[y][x] == "p":
				found.append(Vector2i(x, y))
	return found
