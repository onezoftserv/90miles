class_name InventoryStrip
extends Control
## The local player's inventory in the HUD's bottom band (inventory-hud "Inventory strip", "Slot
## contents", "The selected item's line", "Strip follows the host"; design D1): one 26×26 slot per
## inventory slot, 2 px apart, centred 4 px above the view's bottom edge, screen slot n showing
## inventory slot n − 1; above the slots the selected item's line and the refusal line, and the
## carried weight to their right, each on a HUD panel. It only reads the bound body's inventory,
## which the host owns (a client's copy arrives through Inventory.from_net), and redraws on the
## frame that inventory changes. The selection is this peer's own and is never sent.

## The HUD's fixed budget (ui-shell "HUD layout").
const VIEW_SIZE: Vector2 = Vector2(640.0, 360.0)
const SLOT_GAP: float = 2.0
const BOTTOM_MARGIN: float = 4.0
const LINE_HEIGHT: float = 10.0
## The item line's top sits this far above the slots' top edge.
const LINE_RISE: float = 12.0
## Glyphs of the 8 px font that fit the item line's 334 px.
const LINE_MAX_CHARS: int = 41
const WEIGHT_GAP: float = 4.0
const WEIGHT_WIDTH: float = 100.0
## The weight readout's top, below the slots' top edge.
const WEIGHT_DROP: float = 9.0
const SEPARATOR: String = " · "
const ELLIPSIS: String = "…"
const USE_ACTION: StringName = &"use_item"
const SLOT_ACTION_FORMAT: String = "slot_%d"

## The player whose inventory this shows, or null.
var body: PlayerBody = null
## The run's session (teammates' names and peers), or null for a body outside one.
var session: CoopSession = null
var text: HudText = HudText.load_default()
var device: InputLabels.Device = InputLabels.Device.KEYBOARD
## The selected inventory slot: screen slot `selected + 1`.
var selected: int = 0
# Typed with the base class: a typed array of one of our own classes can leak at exit.
var _views: Array[Control] = []
var _inventory: Inventory = null
var _use_key: String = ""

@onready var panel: PanelContainer = $Panel
@onready var item_line_panel: PanelContainer = $ItemLinePanel
@onready var item_line: Label = $ItemLine
@onready var weight_panel: PanelContainer = $WeightPanel
@onready var weight_label: Label = $Weight
@onready var notice: HudNotice = $Notice
@onready var _slots: Control = $Slots


## "<name> · [<key>] <verb>: <teammate>" in at most `max_chars` glyphs: no verb gives the name
## alone, no teammate drops ": <teammate>". Too long, the teammate's name is cut first, then the
## item's, each cut ending in "…".
static func item_line_text(item_name: String, key: String, verb: String, teammate: String, max_chars: int = LINE_MAX_CHARS) -> String:
	var head_tail: String = "" if verb.is_empty() else "%s[%s] %s" % [SEPARATOR, key, verb]
	if not teammate.is_empty():
		head_tail += ": "
	var room_for_teammate: int = max_chars - item_name.length() - head_tail.length()
	if teammate.is_empty() and room_for_teammate >= 0:
		return item_name + head_tail
	if not teammate.is_empty() and room_for_teammate >= 1:
		return item_name + head_tail + cut(teammate, room_for_teammate)
	var teammate_part: String = "" if teammate.is_empty() else ELLIPSIS
	return cut(item_name, max_chars - head_tail.length() - teammate_part.length()) + head_tail + teammate_part


## `value` in at most `max_chars` glyphs, ending in "…" when cut.
static func cut(value: String, max_chars: int) -> String:
	if value.length() <= max_chars:
		return value
	if max_chars <= 0:
		return ""
	return value.left(max_chars - 1) + ELLIPSIS


## "Peso 2,5/30": the label, the carried weight and the limit, with a decimal comma.
static func weight_text(carried: float, limit: float, label: String) -> String:
	return "%s %s/%s" % [label, decimal(carried), decimal(limit)]


## `value` with at most one decimal, written with a comma: "2,5", "30".
static func decimal(value: float) -> String:
	var tenths: float = snappedf(value, 0.1)
	if is_equal_approx(tenths, roundf(tenths)):
		return str(roundi(tenths))
	return ("%.1f" % tenths).replace(".", ",")


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	refresh()


## Shows `player`'s inventory from now on and stops following the body bound before.
func bind(player: PlayerBody, run_session: CoopSession = null) -> void:
	_unbind()
	body = player
	session = run_session
	if _has_body():
		_inventory = player.inventory
		_inventory.changed.connect(_on_inventory_changed)
	refresh()


## The labels follow `value` (the last device the local player used).
func set_device(value: InputLabels.Device) -> void:
	if value == device:
		return
	device = value
	refresh()


## Selects inventory slot `index` (screen slot index + 1), empty or not.
func select(index: int) -> void:
	if index < 0 or index >= _views.size():
		return
	selected = index
	_show_selection()
	_show_line()


func slot_count() -> int:
	return _views.size()


## The view of inventory slot `index`, or null.
func slot_view(index: int) -> StripSlot:
	return _views[index] as StripSlot if index >= 0 and index < _views.size() else null


## The row of slots in HUD coordinates.
func strip_rect() -> Rect2:
	var width: float = _views.size() * StripSlot.SIZE.x + maxf(_views.size() - 1, 0.0) * SLOT_GAP
	var top: float = VIEW_SIZE.y - BOTTOM_MARGIN - StripSlot.SIZE.y
	return Rect2(floorf((VIEW_SIZE.x - width) / 2.0), top, width, StripSlot.SIZE.y)


## Redraws everything from the bound body's inventory.
func refresh() -> void:
	if not _has_body():
		visible = false
		return
	if body.inventory.slots.size() != _views.size():
		_rebuild(body.inventory.slots.size())
	visible = not body.left_island
	_use_key = InputLabels.label_for(USE_ACTION, device, text, _locale())
	_show_slots()
	_show_selection()
	_show_weight()
	_show_line()


func _process(_delta: float) -> void:
	if not _has_body() or body.left_island:
		visible = false
		return
	visible = true
	# A downed teammate may have come into reach, which changes the use the line names.
	_show_line()


func _has_body() -> bool:
	return is_instance_valid(body)


func _locale() -> String:
	return session.locale if session != null and is_instance_valid(session) else "es"


func _unbind() -> void:
	if is_instance_valid(_inventory) and _inventory.changed.is_connected(_on_inventory_changed):
		_inventory.changed.disconnect(_on_inventory_changed)
	_inventory = null


func _on_inventory_changed() -> void:
	refresh()


func _rebuild(count: int) -> void:
	for view: Control in _views:
		_slots.remove_child(view)
		view.queue_free()
	_views.clear()
	for i: int in count:
		var view := StripSlot.new()
		view.name = "Slot%d" % (i + 1)
		view.clicked.connect(select.bind(i))
		_slots.add_child(view)
		_views.append(view)
	selected = clampi(selected, 0, maxi(count - 1, 0))
	_layout()


func _layout() -> void:
	var row := strip_rect()
	for i: int in _views.size():
		_views[i].position = row.position + Vector2(i * (StripSlot.SIZE.x + SLOT_GAP), 0.0)
	_place(panel, row)
	var line_rect := Rect2(row.position.x, row.position.y - LINE_RISE, row.size.x, LINE_HEIGHT)
	_place(item_line_panel, line_rect)
	_place(item_line, line_rect)
	var weight_rect := Rect2(row.end.x + WEIGHT_GAP, row.position.y + WEIGHT_DROP, WEIGHT_WIDTH, LINE_HEIGHT)
	_place(weight_panel, weight_rect)
	_place(weight_label, weight_rect)


func _place(control: Control, rect: Rect2) -> void:
	control.position = rect.position
	control.size = rect.size


func _show_slots() -> void:
	var locale := _locale()
	for i: int in _views.size():
		var held := body.inventory.slots[i]
		var item: ItemData = body.inventory.item_for(held.item_id) if not held.is_empty() else null
		(_views[i] as StripSlot).show_item(item, held, _slot_key(i, locale), locale)


func _slot_key(index: int, locale: String) -> String:
	if device != InputLabels.Device.KEYBOARD:
		return ""
	return InputLabels.label_for(StringName(SLOT_ACTION_FORMAT % (index + 1)), device, text, locale)


func _show_selection() -> void:
	for i: int in _views.size():
		(_views[i] as StripSlot).set_selected(i == selected)


func _show_weight() -> void:
	var inventory := body.inventory
	weight_label.text = weight_text(inventory.weight(), inventory.tuning.weight_limit, text.line(&"weight", _locale()))


# The selected item's name and, when it has a use, the use key, its verb and the teammate it
# goes to. Nothing for an empty slot.
func _show_line() -> void:
	var line: String = ""
	var item: ItemData = UsePlan.item_in(body, selected) if _has_body() else null
	if item != null:
		var locale := _locale()
		var plan := UsePlan.choose(body, selected, session)
		var verb: String = ""
		var teammate: String = ""
		if plan.use_index >= 0:
			verb = text.use_verb(item.uses[plan.use_index].action, locale)
			if plan.target != null and session != null:
				teammate = session.player_name(plan.target_peer)
		line = item_line_text(item.get_display_name(locale), _use_key, verb, teammate)
	if item_line.text != line:
		item_line.text = line
	item_line.visible = not line.is_empty()
	item_line_panel.visible = item_line.visible
