class_name MovementPlayground
extends Node2D
## Manual-test island for player-movement: land, brush, shallow, deep and brackish water, one
## interactable and two players. Everything is drawn with colored rectangles, no textures.

const TILE: int = 16
const COLORS: Dictionary[DataEnums.Terrain, Color] = {
	DataEnums.Terrain.BEACH: Color("e8d9a0"),
	DataEnums.Terrain.SCRUB: Color("6fa046"),
	DataEnums.Terrain.MANGROVE: Color("2f6b3a"),
	DataEnums.Terrain.SHALLOWS: Color("6ec6d9"),
	DataEnums.Terrain.DEEP: Color("1e4f8a"),
	DataEnums.Terrain.BRACKISH: Color("5a9a8a"),
}

var terrain: GridTerrain = GridTerrain.new()


func _ready() -> void:
	_build_terrain()
	for child: Node in get_children():
		var body := child as PlayerBody
		if body != null:
			body.terrain = terrain
	queue_redraw()


func _build_terrain() -> void:
	terrain.default_terrain = DataEnums.Terrain.DEEP
	terrain.fill_rect(Rect2i(0, 0, 16, 24), DataEnums.Terrain.BEACH)
	terrain.fill_rect(Rect2i(16, 0, 8, 24), DataEnums.Terrain.SHALLOWS)
	terrain.fill_rect(Rect2i(24, 0, 24, 24), DataEnums.Terrain.DEEP)
	terrain.fill_rect(Rect2i(4, 4, 6, 6), DataEnums.Terrain.SCRUB)
	terrain.fill_rect(Rect2i(10, 14, 4, 4), DataEnums.Terrain.MANGROVE)
	terrain.fill_rect(Rect2i(0, 20, 16, 4), DataEnums.Terrain.BRACKISH)


func _draw() -> void:
	for cell: Vector2i in terrain.cells:
		var color: Color = COLORS.get(terrain.cells[cell], Color.MAGENTA)
		draw_rect(Rect2(Vector2(cell * TILE), Vector2(TILE, TILE)), color)
	for child: Node in get_children():
		if child is Interactable:
			draw_circle((child as Interactable).position, 4.0, Color("8b5a2b"))
