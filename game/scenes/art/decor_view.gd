class_name DecorView
extends Node2D
## The scenery cells of a handmade layout (secret-cay "He left minutes ago": the embers, the
## smoking stub, the drag mark, the cut line, the post), each drawn as a tile of the colour its
## decor id has in the layout's `decor_colors`, until their art comes. Drawing only (`art_view`):
## it reads its parent island's `built.decor` and `layout.decor_colors` and never switches on an
## id, so a new decor kind is a data edit. It sits after the Terrain child, so it draws over the
## ground.

const TILE: float = 16.0
## How far inside its cell a decor tile is drawn, so the ground shows round it.
const INSET: float = 3.0

var _drawn: IslandLayout = null


func _init() -> void:
	add_to_group(&"art_view")


func _process(_delta: float) -> void:
	var built := get_parent().get(&"built") as IslandLayout if get_parent() != null else null
	if built != _drawn:
		_drawn = built
		queue_redraw()


func _draw() -> void:
	var source: Node = get_parent()
	if source == null:
		return
	var built := source.get(&"built") as IslandLayout
	var layout := source.get(&"layout") as IslandLayoutData
	if built == null or layout == null:
		return
	for entry: Dictionary in built.decor:
		var colour: Variant = layout.decor_colors.get(entry["decor_id"])
		if colour is Color:
			var cell: Vector2 = Vector2(entry["cell"]) * TILE
			draw_rect(Rect2(cell + Vector2(INSET, INSET), Vector2(TILE - 2.0 * INSET, TILE - 2.0 * INSET)), colour)
