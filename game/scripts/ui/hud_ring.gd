class_name HudRing
extends Control
## The interact prompt's 10×10 px hold ring (inventory-hud "Hold ring", design D1): a faint circle
## that fills clockwise from the top, in the HUD's sun yellow, as a held press counts down. It takes
## neither clicks nor focus.

const SIZE: Vector2 = Vector2(10.0, 10.0)
const WIDTH: float = 2.0
const POINTS: int = 24
const FILL_COLOR: Color = Color(1.0, 0.8, 0.0)
const TRACK_COLOR: Color = Color(0.957, 0.937, 0.878, 0.35)

## How much of the hold has passed, 0 to 1.
var value: float = 0.0


func _init() -> void:
	size = SIZE
	custom_minimum_size = SIZE
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	focus_mode = Control.FOCUS_NONE


func set_value(next: float) -> void:
	var clamped: float = clampf(next, 0.0, 1.0)
	if clamped == value:
		return
	value = clamped
	queue_redraw()


func _draw() -> void:
	var center: Vector2 = SIZE / 2.0
	var radius: float = (SIZE.x - WIDTH) / 2.0
	draw_arc(center, radius, 0.0, TAU, POINTS, TRACK_COLOR, WIDTH)
	if value > 0.0:
		var start: float = -PI / 2.0
		draw_arc(center, radius, start, start + TAU * value, POINTS, FILL_COLOR, WIDTH)
