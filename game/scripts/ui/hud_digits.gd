class_name HudDigits
extends Control
## Small 3x5 digits from the kit's atlas (inventory-hud "Slot contents"; hud-window-kit design D6):
## a slot's count bottom-right and its key top-left, each glyph in a baked 1 px dark outline, at a
## 4 px pitch so neighbouring outlines overlap. DCSS draws its quantities the same way, from digit
## tiles rather than a font (`GridRegion::draw_number`). The node covers its slot; `anchor` is where
## the glyphs sit in it: the first glyph's top-left pixel, or with `right_aligned` the pixel just
## right of the last glyph's right column.

## The atlas, named by the theme (`HudDigits/icons/atlas`) so the art rules find it in use.
const ATLAS_PATH: String = "res://assets/art/ui/digits_3x5.png"
## The atlas's glyph order: one 5x7 cell each, a 3x5 glyph at (1,1) inside its outline.
const GLYPHS: String = "0123456789-="
const CELL: Vector2 = Vector2(5.0, 7.0)
const GLYPH: Vector2 = Vector2(3.0, 5.0)
const PITCH: float = 4.0

## The atlas rows: the cream digits, and the orange ones for a tool's last use.
enum Tone { CREAM, ORANGE }

var text: String = ""
var tone: Tone = Tone.CREAM
var right_aligned: bool = false
var anchor: Vector2 = Vector2.ZERO


## Whether every character of `value` has a glyph in the atlas.
static func can_show(value: String) -> bool:
	for i: int in value.length():
		if not GLYPHS.contains(value[i]):
			return false
	return true


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


## Shows `value` (only atlas characters; anything else shows nothing) in `shown_tone`.
func show_text(value: String, shown_tone: Tone = Tone.CREAM) -> void:
	var next: String = value if can_show(value) else ""
	if next == text and shown_tone == tone:
		return
	text = next
	tone = shown_tone
	queue_redraw()


## Each glyph's 3x5 box in this node, left to right.
func glyph_rects() -> Array[Rect2]:
	var rects: Array[Rect2] = []
	var count: int = text.length()
	for i: int in count:
		var x: float = anchor.x + i * PITCH
		if right_aligned:
			x = anchor.x - GLYPH.x - (count - 1 - i) * PITCH
		rects.append(Rect2(Vector2(x, anchor.y), GLYPH))
	return rects


## The digit atlas, from the theme.
func atlas() -> Texture2D:
	return get_theme_icon(&"atlas", &"HudDigits")


func _draw() -> void:
	var rects := glyph_rects()
	for i: int in rects.size():
		var index: int = GLYPHS.find(text[i])
		var source := Rect2(Vector2(index * CELL.x, int(tone) * CELL.y), CELL)
		draw_texture_rect_region(atlas(), Rect2(rects[i].position - Vector2.ONE, CELL), source)
