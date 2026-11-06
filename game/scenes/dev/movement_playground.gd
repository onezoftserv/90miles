class_name MovementPlayground
extends Node2D
## Manual-test island for player-movement and survival-meters: land, brush, shallow, deep and
## brackish water, a shaded hut, one interactable, two players under a fixed midday sun, and the
## local player's meters HUD, and the crafting-inventory supplies (a workbench, a coconut, a knife,
## driftwood, dry grass and a tarp to pick up). Everything is drawn with colored rectangles, no textures.

const TILE: int = DevIslandTerrain.TILE
const HUT: Rect2i = DevIslandTerrain.HUT
## Items lying on the beach for the crafting-inventory manual check: id, count, cell.
const SUPPLIES: Array = [
	[&"coco", 1, Vector2i(2, 2)], [&"knife", 1, Vector2i(3, 2)], [&"driftwood", 3, Vector2i(4, 2)],
	[&"dry_grass", 2, Vector2i(5, 2)], [&"tarp", 1, Vector2i(6, 2)],
]
const WORKBENCH_CELL: Vector2i = Vector2i(8, 2)
## 10:00, seconds since dawn.
const START_TIME_S: float = 120.0

var terrain: GridTerrain = GridTerrain.new()
## Starts at 10:00 on the one clock (WeatherManager), so heat rises outside the hut in the
## midday sun and sunstroke can be tried by hand.
var climate: ClimateState = WeatherManager.sky.climate

@onready var hud: MetersHud = $Hud/MetersHud


func _ready() -> void:
	_build_terrain()
	_place_supplies()
	WeatherManager.start(START_TIME_S)
	var hud_bound: bool = false
	for child: Node in get_children():
		var body := child as PlayerBody
		if body == null:
			continue
		body.terrain = terrain
		body.climate = climate
		if body.local_player and not hud_bound:
			hud.bind(body.meters)
			hud_bound = true
	queue_redraw()


func _exit_tree() -> void:
	WeatherManager.stop()


func _place_supplies() -> void:
	var item_scene: PackedScene = preload("res://scenes/items/world_item.tscn")
	for supply: Array in SUPPLIES:
		var item := item_scene.instantiate() as WorldItem
		item.item_id = supply[0]
		item.count = supply[1]
		item.position = _cell_center(supply[2])
		add_child(item)
	var bench := Workbench.new()
	bench.position = _cell_center(WORKBENCH_CELL)
	add_child(bench)


func _cell_center(cell: Vector2i) -> Vector2:
	return (Vector2(cell) + Vector2(0.5, 0.5)) * TILE


func _build_terrain() -> void:
	DevIslandTerrain.fill(terrain)


func _draw() -> void:
	DevIslandTerrain.draw(self, terrain)
	for child: Node in get_children():
		if child is Interactable:
			draw_circle((child as Interactable).position, 4.0, Color("8b5a2b"))
