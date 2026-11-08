class_name StripSlot
extends Panel
## One 26×26 slot of the inventory strip (inventory-hud "Slot contents", design D1): a 1 px frame
## around a 24×24 interior holding the item's 16×16 icon or, until it has one, the first three
## letters of its name; bottom-right the stack's count or a tool's uses left, outlined; top-left
## the slot's key while the keyboard is the last device. The selected slot wears the theme's
## sun-yellow frame, and a ring inside it fills while the use button is held on it. It takes
## clicks, never focus.

## A left click landed on this slot.
signal clicked

const SIZE: Vector2 = Vector2(26.0, 26.0)
const LETTERS: int = 3
const KEY_RECT: Rect2 = Rect2(2.0, 2.0, 8.0, 8.0)
const NAME_RECT: Rect2 = Rect2(1.0, 9.0, 24.0, 8.0)
const COUNT_RECT: Rect2 = Rect2(1.0, 16.0, 23.0, 8.0)
const ICON_RECT: Rect2 = Rect2(5.0, 5.0, 16.0, 16.0)
const FRAME_STYLE: StringName = &"HudSlot"
const SELECTED_STYLE: StringName = &"HudSlotSelected"
const COUNT_STYLE: StringName = &"HudCount"
## The use ring: centred in the interior, 2 px wide, in the selection's sun yellow, filling
## clockwise from the top.
const RING_CENTER: Vector2 = Vector2(13.0, 13.0)
const RING_RADIUS: float = 10.0
const RING_WIDTH: float = 2.0
const RING_POINTS: int = 32
const RING_COLOR: Color = HudStyle.SUN

var selected: bool = false
## How much of the use hold has passed, 0 (no ring) to 1.
var ring: float = 0.0
var key_label: Label = _label(KEY_RECT, HORIZONTAL_ALIGNMENT_LEFT)
var name_label: Label = _label(NAME_RECT, HORIZONTAL_ALIGNMENT_CENTER)
var count_label: Label = _label(COUNT_RECT, HORIZONTAL_ALIGNMENT_RIGHT)
var icon: TextureRect = TextureRect.new()


## What the slot shows for `count` of an item with `durability` and `uses_left`: the stack's
## count above 1, else the uses left of an item with more than 1 use, else nothing.
static func count_text(count: int, durability: int, uses_left: int) -> String:
	if count > 1:
		return str(count)
	if durability > 1:
		return str(uses_left)
	return ""


func _init() -> void:
	size = SIZE
	custom_minimum_size = SIZE
	focus_mode = Control.FOCUS_NONE
	mouse_filter = Control.MOUSE_FILTER_STOP
	theme_type_variation = FRAME_STYLE
	icon.position = ICON_RECT.position
	icon.size = ICON_RECT.size
	icon.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.visible = false
	count_label.theme_type_variation = COUNT_STYLE
	for child: Control in [icon, name_label, count_label, key_label]:
		add_child(child)


## Shows `held` (an empty slot when `item` is null) with `key` top-left ("" for none).
func show_item(item: ItemData, held: InventorySlot, key: String, locale: String = "es") -> void:
	key_label.text = key
	if item == null or held.is_empty():
		icon.texture = null
		icon.visible = false
		name_label.text = ""
		count_label.text = ""
		return
	icon.texture = item.sprite
	icon.visible = item.sprite != null
	name_label.text = "" if item.sprite != null else item.get_display_name(locale).left(LETTERS)
	count_label.text = count_text(held.count, item.durability, held.uses_left)


func set_selected(value: bool) -> void:
	selected = value
	theme_type_variation = SELECTED_STYLE if value else FRAME_STYLE


func set_ring(value: float) -> void:
	var clamped: float = clampf(value, 0.0, 1.0)
	if clamped == ring:
		return
	ring = clamped
	queue_redraw()


func _draw() -> void:
	if ring <= 0.0:
		return
	var start: float = -PI / 2.0
	draw_arc(RING_CENTER, RING_RADIUS, start, start + TAU * ring, RING_POINTS, RING_COLOR, RING_WIDTH)


func _gui_input(event: InputEvent) -> void:
	var click := event as InputEventMouseButton
	if click != null and click.pressed and click.button_index == MOUSE_BUTTON_LEFT:
		clicked.emit()
		accept_event()


static func _label(rect: Rect2, alignment: HorizontalAlignment) -> Label:
	var label := Label.new()
	label.position = rect.position
	label.size = rect.size
	label.horizontal_alignment = alignment
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label
