class_name QuickChatWheel
extends Control
## The radial quick-chat (coop-networking "Quick chat"): shown while the `quick_chat` button
## is held; the phrase under the mouse (or the right stick) is picked on release. 8 sectors of
## 45°, clockwise from north, in the order of the quick-chat content file.

## The player released the button over `slot`.
signal phrase_picked(slot: int)

const ACTION: StringName = &"quick_chat"
const SECTORS: int = 8
## Below this length (stick units, or RADIUS_PX for the mouse) nothing is picked.
const DEAD_ZONE: float = 0.35
const RADIUS_PX: float = 56.0
const SELECTED_COLOR: Color = Color(1.0, 0.85, 0.3)
const IDLE_COLOR: Color = Color(1.0, 1.0, 1.0)

## Set before the wheel enters the tree (or call rebuild()).
var phrases: QuickChatPhrases = QuickChatPhrases.new()
## The slot that would be picked now, or -1.
var selected: int = -1
var _labels: Array[Label] = []

@onready var _slots: Control = $Slots


## The sector of `direction` (screen space, y down): 0 is north, then clockwise; -1 within
## the dead zone.
static func slot_for(direction: Vector2, dead_zone: float = DEAD_ZONE) -> int:
	if not direction.is_finite() or direction.length() < dead_zone:
		return -1
	var sector: float = TAU / SECTORS
	return posmod(roundi(atan2(direction.x, -direction.y) / sector), SECTORS)


func _ready() -> void:
	visible = false
	rebuild()


## Lays out one label per phrase around the center.
func rebuild() -> void:
	for label: Label in _labels:
		label.queue_free()
	_labels.clear()
	for slot: int in phrases.size():
		var label := Label.new()
		label.text = phrases.text(slot)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.position = Vector2.UP.rotated(slot * TAU / SECTORS) * RADIUS_PX - Vector2(32.0, 6.0)
		label.size = Vector2(64.0, 12.0)
		_slots.add_child(label)
		_labels.append(label)
	_highlight()


func slot_label(slot: int) -> Label:
	return _labels[slot] if slot >= 0 and slot < _labels.size() else null


func open() -> void:
	selected = -1
	visible = true
	_highlight()


## Points the wheel: a stick vector (length up to 1) or a mouse offset divided by RADIUS_PX.
func aim(direction: Vector2) -> void:
	selected = slot_for(direction)
	_highlight()


## Closes the wheel and returns the picked slot (-1 for none), emitting phrase_picked.
func release() -> int:
	var picked: int = selected
	visible = false
	selected = -1
	_highlight()
	if picked >= 0 and picked < phrases.size():
		phrase_picked.emit(picked)
		return picked
	return -1


func _process(_delta: float) -> void:
	# A "q" typed into a text field is not the quick-chat button.
	var typing: bool = get_viewport().gui_get_focus_owner() is LineEdit
	var held: bool = Input.is_action_pressed(ACTION) and not typing
	if held and not visible:
		open()
	elif not held and visible:
		release()
	if visible:
		aim(_aim_direction())


func _aim_direction() -> Vector2:
	var stick := Vector2(Input.get_joy_axis(0, JOY_AXIS_RIGHT_X), Input.get_joy_axis(0, JOY_AXIS_RIGHT_Y))
	if stick.length() >= DEAD_ZONE:
		return stick
	return (get_global_mouse_position() - global_position) / RADIUS_PX


func _highlight() -> void:
	for slot: int in _labels.size():
		_labels[slot].modulate = SELECTED_COLOR if slot == selected else IDLE_COLOR
