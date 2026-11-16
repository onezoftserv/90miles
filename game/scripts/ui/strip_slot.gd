class_name StripSlot
extends Panel
## One 26x26 slot of the inventory strip (inventory-hud "Slot contents", design D1; hud-window-kit
## design D6, owner answer Q11 a): a recessed well (the kit's `slot_well`) holding the item's 16x16
## icon at (5,4) or, until it has one, the first three letters of its name. Bottom-right, in the kit's
## 3x5 digits, the stack's count or a tool's uses left (orange on its last use, as SPD's ItemSlot
## warns); top-left, on the selected slot only and while the keyboard is the last device, the slot's
## key. No digit pixel ever lies inside the icon's square. The selected slot wears the sun-yellow and
## orange ring, and a ring inside it fills while the use button is held on it. A slot whose use the
## button would refuse now is dimmed, never hidden (SPD's `itemSelectable`, DCSS's invalid mark). It
## takes clicks, never focus; its tooltip names the item and its verb for the mouse.
## Drawn in DCSS's layer order (`InventoryRegion::pack_buffers`): well and ring, icon, letters, digits.

## A left click landed on this slot.
signal clicked

const SIZE: Vector2 = Vector2(26.0, 26.0)
const LETTERS: int = 3
## The letters of an item with no icon, in the 8 px font across the interior.
const NAME_RECT: Rect2 = Rect2(1.0, 9.0, 24.0, 8.0)
const ICON_RECT: Rect2 = Rect2(5.0, 4.0, 16.0, 16.0)
## The count's glyphs end at x 23 (their right edge at 24) on rows 20 to 24, below the icon.
const COUNT_END: Vector2 = Vector2(24.0, 20.0)
## The key's first glyph at (2,2), left of the icon's column 5.
const KEY_AT: Vector2 = Vector2(2.0, 2.0)
## The text holders the tests and the strip read; hidden, the digits draw instead.
const KEY_RECT: Rect2 = Rect2(2.0, 1.0, 8.0, 8.0)
const COUNT_RECT: Rect2 = Rect2(1.0, 17.0, 23.0, 8.0)
const FRAME_STYLE: StringName = &"HudSlot"
const SELECTED_STYLE: StringName = &"HudSlotSelected"
const COUNT_STYLE: StringName = &"HudCount"
## A dimmed slot's icon, letters and digits, as the craft list dims a row.
const DIM: Color = Color(1.0, 1.0, 1.0, 0.4)
## The use ring: centred in the interior, 2 px wide, in the selection's sun yellow, filling
## clockwise from the top.
const RING_CENTER: Vector2 = Vector2(13.0, 13.0)
const RING_RADIUS: float = 10.0
const RING_WIDTH: float = 2.0
const RING_POINTS: int = 32
const RING_COLOR: Color = HudStyle.SUN

var selected: bool = false
## The use button would refuse this slot's use now.
var dimmed: bool = false
## How much of the use hold has passed, 0 (no ring) to 1.
var ring: float = 0.0
## The key's text shows here only while the slot is selected; the count's always.
var key_label: Label = _label(KEY_RECT, HORIZONTAL_ALIGNMENT_LEFT)
var name_label: Label = _label(NAME_RECT, HORIZONTAL_ALIGNMENT_CENTER)
var count_label: Label = _label(COUNT_RECT, HORIZONTAL_ALIGNMENT_RIGHT)
var icon: TextureRect = TextureRect.new()
var count_digits: HudDigits = HudDigits.new()
var key_digits: HudDigits = HudDigits.new()
# The slot's key, shown only while selected.
var _key: String = ""
var _last_use: bool = false


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
	for holder: Label in [count_label, key_label]:
		holder.visible = false
	for digits: HudDigits in [count_digits, key_digits]:
		digits.size = SIZE
	count_digits.right_aligned = true
	count_digits.anchor = COUNT_END
	key_digits.anchor = KEY_AT
	for child: Control in [icon, name_label, count_label, key_label, count_digits, key_digits]:
		add_child(child)


## Shows `held` (an empty slot when `item` is null) with `key` top-left while selected ("" for none).
func show_item(item: ItemData, held: InventorySlot, key: String, locale: String = "es") -> void:
	_key = key
	if item == null or held.is_empty():
		icon.texture = null
		icon.visible = false
		name_label.text = ""
		count_label.text = ""
		_last_use = false
	else:
		icon.texture = item.sprite
		icon.visible = item.sprite != null
		name_label.text = "" if item.sprite != null else item.get_display_name(locale).left(LETTERS)
		count_label.text = count_text(held.count, item.durability, held.uses_left)
		_last_use = held.count <= 1 and item.durability > 1 and held.uses_left == 1
	count_digits.show_text(count_label.text, HudDigits.Tone.ORANGE if _last_use else HudDigits.Tone.CREAM)
	_show_key()


func set_selected(value: bool) -> void:
	selected = value
	theme_type_variation = SELECTED_STYLE if value else FRAME_STYLE
	_show_key()


## Dims (true) or lights the slot's contents; the well stays as it is.
func set_dimmed(value: bool) -> void:
	dimmed = value
	var tint: Color = DIM if value else Color.WHITE
	for part: CanvasItem in [icon, name_label, count_digits, key_digits]:
		part.modulate = tint


## Whether the count shows in the orange of a tool's last use.
func last_use() -> bool:
	return _last_use


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


# The key only on the selected slot; a key the atlas cannot draw (a layout's other symbol) falls
# back to the 8 px font in the same corner.
func _show_key() -> void:
	var shown: String = _key if selected else ""
	key_label.text = shown
	key_digits.show_text(shown)
	key_label.visible = not shown.is_empty() and not HudDigits.can_show(shown)


static func _label(rect: Rect2, alignment: HorizontalAlignment) -> Label:
	var label := Label.new()
	label.position = rect.position
	label.size = rect.size
	label.horizontal_alignment = alignment
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label
