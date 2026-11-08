class_name DevIslandTerrain
extends RefCounted
## The placeholder beach island shared by the movement playground and the shell's run (until
## the handmade sandbar exists): land, brush, mangrove, shallow, deep and brackish water and a
## shaded hut, drawn with colored rectangles, no textures.

const TILE: int = 16
const COLORS: Dictionary[DataEnums.Terrain, Color] = {
	DataEnums.Terrain.BEACH: Color("e8d9a0"),
	DataEnums.Terrain.DUNE: Color("cdbf7e"),
	DataEnums.Terrain.SCRUB: Color("6fa046"),
	DataEnums.Terrain.MANGROVE: Color("2f6b3a"),
	DataEnums.Terrain.SHALLOWS: Color("6ec6d9"),
	DataEnums.Terrain.DEEP: Color("1e4f8a"),
	DataEnums.Terrain.BRACKISH: Color("5a9a8a"),
	DataEnums.Terrain.ROCK: Color("8d8678"),
}
## Drawn over shaded cells.
const SHADE_COLOR: Color = Color(0.24, 0.16, 0.08, 0.45)
## The hut, in cells: on the beach, north of the start.
const HUT: Rect2i = Rect2i(0, 8, 4, 3)


static func build() -> GridTerrain:
	var terrain := GridTerrain.new()
	fill(terrain)
	return terrain


static func fill(terrain: GridTerrain) -> void:
	terrain.default_terrain = DataEnums.Terrain.DEEP
	terrain.fill_rect(Rect2i(0, 0, 16, 24), DataEnums.Terrain.BEACH)
	terrain.fill_rect(Rect2i(16, 0, 8, 24), DataEnums.Terrain.SHALLOWS)
	terrain.fill_rect(Rect2i(24, 0, 24, 24), DataEnums.Terrain.DEEP)
	terrain.fill_rect(Rect2i(4, 4, 6, 6), DataEnums.Terrain.SCRUB)
	terrain.fill_rect(Rect2i(10, 14, 4, 4), DataEnums.Terrain.MANGROVE)
	terrain.fill_rect(Rect2i(0, 20, 16, 4), DataEnums.Terrain.BRACKISH)
	terrain.set_shaded(HUT)


## Draws `terrain`'s cells and shade on `canvas` (call from its _draw).
static func draw(canvas: CanvasItem, terrain: GridTerrain) -> void:
	for cell: Vector2i in terrain.cells:
		var color: Color = COLORS.get(terrain.cells[cell], Color.MAGENTA)
		canvas.draw_rect(Rect2(Vector2(cell * TILE), Vector2(TILE, TILE)), color)
	for cell: Vector2i in terrain.shaded:
		canvas.draw_rect(Rect2(Vector2(cell * TILE), Vector2(TILE, TILE)), SHADE_COLOR)
