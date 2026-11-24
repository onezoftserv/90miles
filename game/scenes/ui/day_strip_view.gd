class_name DayStripView
extends Control
## hud-clarity, ui-shell "Clock strip": the day drawn as a 56×7 box, a 1 px dark outline round the
## DayStrip parts, with a 2×7 sun-yellow marker at the time of day that stands over the outline at
## top and bottom, edged in the outline colour so it reads on the sand and the sun-orange.

const BOX_SIZE: Vector2i = Vector2i(DayStrip.STRIP_PX + 2, 7)
const MARKER_WIDTH: int = 2

## The marker's column inside the strip (DayStrip.marker_px).
var marker_px: int = 0
var _parts: Array[DayStrip.Part] = DayStrip.parts()


func _ready() -> void:
	custom_minimum_size = Vector2(BOX_SIZE)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


## Moves the marker to `seconds` since dawn; redraws only when its column changes.
func show_time(seconds: float) -> void:
	var px: int = DayStrip.marker_px(seconds)
	if px == marker_px:
		return
	marker_px = px
	queue_redraw()


func _draw() -> void:
	var top: float = floorf((size.y - float(BOX_SIZE.y)) / 2.0)
	draw_rect(Rect2(0.0, top, BOX_SIZE.x, BOX_SIZE.y), HudStyle.OUTLINE)
	for part: DayStrip.Part in _parts:
		draw_rect(Rect2(1.0 + part.from_px, top + 1.0, part.to_px - part.from_px, BOX_SIZE.y - 2), DayStrip.COLORS[part.key])
	var x: float = 1.0 + float(mini(marker_px, DayStrip.STRIP_PX - MARKER_WIDTH))
	draw_rect(Rect2(x - 1.0, top + 1.0, 1.0, BOX_SIZE.y - 2), HudStyle.OUTLINE)
	draw_rect(Rect2(x + MARKER_WIDTH, top + 1.0, 1.0, BOX_SIZE.y - 2), HudStyle.OUTLINE)
	draw_rect(Rect2(x, top, MARKER_WIDTH, BOX_SIZE.y), HudStyle.SUN)
