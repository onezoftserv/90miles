class_name InventoryStrip
extends Control
## The local player's inventory in the HUD's bottom band (inventory-hud "Inventory strip", "Slot
## contents", "The selected item's line", "Strip follows the host"; design D1): one 26×26 slot per
## inventory slot, 2 px apart, centred 4 px above the view's bottom edge, screen slot n showing
## inventory slot n − 1; above the slots the selected item's line and the refusal line, and the
## carried weight to their right, each on a HUD panel. It only reads the bound body's inventory,
## which the host owns (a client's copy arrives through Inventory.from_net), and redraws on the
## frame that inventory changes. The selection is this peer's own and is never sent: the number
## row picks a screen slot by key position, D-pad right and left (here) and the wheel (routed from
## RunHud._input, so a slot under the pointer never swallows it) cycle the slots that hold
## something, and a click picks a slot. Nothing selects while a text field has focus or while
## `input_open` says a screen or the pause menu has the input.
## The use button (`use_item`, polled here) uses the selected item (inventory-hud "Using the
## selected item", "Refused uses"; design D5): on a fresh press the strip picks the use
## (`UsePlan.choose`) and checks it as the host will (`UsePlan.actor_reason`, then
## `ItemUser.check`) on the state this peer sees. A refusal shows its line on the notice and sends
## nothing; otherwise the selected slot's ring fills for the use's `time_s` and, at the end, the
## request goes to the host through `CoopSession.use_item`. Letting go, changing the selection,
## the slot's item or the use it would make, or losing the input cancels; one press makes at most
## one use. The use button does nothing while the crafting list is open (`list_open`).

## A use request went to the host: the slot, the item's use and the teammate's peer (0: the
## player themself).
signal use_sent(slot: int, use_index: int, target_peer: int)

## The HUD's fixed budget (ui-shell "HUD layout").
const VIEW_SIZE: Vector2 = Vector2(640.0, 360.0)
const SLOT_GAP: float = 2.0
const BOTTOM_MARGIN: float = 4.0
const LINE_HEIGHT: float = 10.0
## The item line's top sits this far above the slots' top edge.
const LINE_RISE: float = 12.0
## The item line's width over the 12 slots: 12 × 26 + 11 × 2 = 334 px.
const LINE_WIDTH_PX: float = 12.0 * StripSlot.SIZE.x + 11.0 * SLOT_GAP
## Glyphs of the HUD's font that fit the item line: 41.
const LINE_MAX_CHARS: int = floori(LINE_WIDTH_PX / HudStyle.GLYPH_PX)
const WEIGHT_GAP: float = 4.0
const WEIGHT_WIDTH: float = 100.0
## The weight readout's top, below the slots' top edge.
const WEIGHT_DROP: float = 9.0
const SEPARATOR: String = " · "
const ELLIPSIS: String = "…"
const USE_ACTION: StringName = &"use_item"
const SLOT_ACTION_FORMAT: String = "slot_%d"
const NEXT_ACTION: StringName = &"slot_next"
const PREV_ACTION: StringName = &"slot_prev"
## The refusal line (HudText.REFUSALS) for each reason; a reason not listed reads "not_now".
## CONDITION reads "condition" only when the missing thing is a tool (see `refusal_line`).
const REFUSAL_KEYS: Dictionary[ItemUser.Reason, StringName] = {
	ItemUser.Reason.EMPTY: &"empty",
	ItemUser.Reason.NO_USE: &"no_use",
	ItemUser.Reason.DOWN: &"down",
	ItemUser.Reason.AT_SEA: &"at_sea",
}
const NOT_NOW_KEY: StringName = &"not_now"
const CONDITION_KEY: StringName = &"condition"

## The player whose inventory this shows, or null.
var body: PlayerBody = null
## The run's session (teammates' names and peers), or null for a body outside one.
var session: CoopSession = null
var text: HudText = HudText.load_default()
var device: InputLabels.Device = InputLabels.Device.KEYBOARD
## The selected inventory slot: screen slot `selected + 1`.
var selected: int = 0
## Whether the HUD takes input now; RunHud answers (no pause menu, summary or host-lost screen).
var input_open: Callable = func() -> bool: return true
## Hidden, and deaf to input, while a screen is shown over the run.
var screen_shown: bool = false
## Whether the crafting list holds the input, so the use button does nothing; RunHud answers.
var list_open: Callable = func() -> bool: return false
# Typed with the base class: a typed array of one of our own classes can leak at exit.
var _views: Array[Control] = []
var _inventory: Inventory = null
var _use_key: String = ""
# The slot actions the input map defines, screen slot 1 first.
var _slot_actions: Array[StringName] = []
var _use_timer: PressTimer = PressTimer.new()
# The use button is down and this press was already taken (started, refused, cancelled or done):
# nothing more happens until it is let go.
var _use_latched: bool = false
# The use being held, with its slot and that slot's item when the hold began; null for none.
var _use_plan: UsePlan = null
var _use_slot: int = -1
var _use_item_id: StringName = &""

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


## "Peso 2,5/30" ("Weight 2.5/30" in English): the label, the carried weight and the limit, as
## `words` writes them in `locale`.
static func weight_text(carried: float, limit: float, words: HudText, locale: String) -> String:
	var point: String = words.line(&"decimal_point", locale)
	return words.line(&"weight_readout", locale) % [words.line(&"weight", locale), decimal(carried, point), decimal(limit, point)]


## `value` with at most one decimal, written with `point`: "2,5", "30".
static func decimal(value: float, point: String) -> String:
	var tenths: float = snappedf(value, 0.1)
	if is_equal_approx(tenths, roundf(tenths)):
		return str(roundi(tenths))
	return ("%.1f" % tenths).replace(".", point)


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Runs while the solo pause freezes the run, so a use press made under the pause menu is
	# taken there and does not start a use once the run resumes.
	process_mode = Node.PROCESS_MODE_ALWAYS
	while InputMap.has_action(StringName(SLOT_ACTION_FORMAT % (_slot_actions.size() + 1))):
		_slot_actions.append(StringName(SLOT_ACTION_FORMAT % (_slot_actions.size() + 1)))
	refresh()


# Slot keys and the D-pad. The wheel arrives through RunHud._input instead (`step`), and a mouse
# button here is never a slot input.
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton or not accepts_input():
		return
	for i: int in mini(_slot_actions.size(), _views.size()):
		if event.is_action_pressed(_slot_actions[i]):
			select(i)
			get_viewport().set_input_as_handled()
			return
	if event.is_action_pressed(NEXT_ACTION) or event.is_action_pressed(PREV_ACTION):
		step(1 if event.is_action_pressed(NEXT_ACTION) else -1)
		get_viewport().set_input_as_handled()


## Whether a slot input may change the selection now: a body to show, no screen, no pause, and
## no text field being typed in.
func accepts_input() -> bool:
	if not _has_body() or not visible or screen_shown:
		return false
	if get_viewport() != null and get_viewport().gui_get_focus_owner() is LineEdit:
		return false
	return input_open.call()


## Moves the selection to the next (1) or previous (-1) slot that holds an item.
func step(direction: int) -> void:
	select(next_filled(selected, direction))


## The first slot after `from` in `direction` that holds an item, wrapping round; `from` when no
## other slot does.
func next_filled(from: int, direction: int) -> int:
	if not _has_body():
		return from
	var count: int = body.inventory.slots.size()
	for i: int in range(1, count + 1):
		var index: int = posmod(from + direction * i, count)
		if not body.inventory.slots[index].is_empty():
			return index
	return from


func set_screen_shown(value: bool) -> void:
	screen_shown = value
	refresh()


## Shows `player`'s inventory from now on and stops following the body bound before.
func bind(player: PlayerBody, run_session: CoopSession = null) -> void:
	_unbind()
	_cancel_use()
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
	if index != _use_slot:
		_cancel_use()
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
	visible = not body.left_island and not screen_shown
	_use_key = InputLabels.label_for(USE_ACTION, device, text, _locale())
	_show_slots()
	_show_selection()
	_show_weight()
	_show_line()


func _process(delta: float) -> void:
	if not _has_body() or body.left_island or screen_shown:
		visible = false
		_cancel_use()
		# A press made now is taken: it does nothing once the strip shows again.
		_use_latched = Input.is_action_pressed(USE_ACTION)
		return
	visible = true
	_update_use(delta)
	# A downed teammate may have come into reach, which changes the use the line names.
	_show_line()


## Whether the use button may start a use now: what lets a slot input through, and no crafting
## list open.
func accepts_use() -> bool:
	return accepts_input() and not list_open.call()


## Why the host would refuse `plan` for slot `slot` on the state this peer sees, or OK: the
## plan's own reason (an empty slot, no use), then the acting player's, then the item's, as
## `CoopSession.use_for` checks them.
func use_reason(plan: UsePlan, slot: int) -> ItemUser.Reason:
	if plan.reason != ItemUser.Reason.OK:
		return plan.reason
	var actor: ItemUser.Reason = UsePlan.actor_reason(body, at_sea(), slot, plan.use_index, plan.target)
	if actor != ItemUser.Reason.OK:
		return actor
	return ItemUser.check(body, slot, plan.use_index, plan.target)


## The refusal line for `reason` about slot `slot`'s use `use_index`: a missing tool is named by
## its phrase ("Te falta con qué abrir el coco."), any other failed condition reads "not now".
func refusal_line(reason: ItemUser.Reason, slot: int, use_index: int) -> String:
	var locale := _locale()
	if reason == ItemUser.Reason.CONDITION:
		var missing := ItemUser.failed_condition(body, slot, use_index)
		var is_tool: bool = missing != null and missing.kind == ConditionData.Kind.HAS_CAPABILITY and not missing.negate
		var phrase: String = text.tool_phrase(missing.capability, locale) if is_tool else ""
		if not phrase.is_empty():
			return text.refusal(CONDITION_KEY, locale) % phrase
	return text.refusal(REFUSAL_KEYS.get(reason, NOT_NOW_KEY), locale)


## Whether the local player left the island by a route and is on the crossing (design D11).
func at_sea() -> bool:
	if session == null or not is_instance_valid(session) or not _has_body():
		return false
	return session.has_left(session.peer_of(body))


func _has_body() -> bool:
	return is_instance_valid(body)


# One frame of the use button: a fresh press picks and checks the use, a held one times it.
func _update_use(delta: float) -> void:
	if not Input.is_action_pressed(USE_ACTION):
		_use_latched = false
		_cancel_use()
		return
	var fresh: bool = not _use_latched
	_use_latched = true
	if not accepts_use():
		_cancel_use()
		return
	if fresh:
		_begin_use()
	elif _use_plan != null and not _same_use():
		_cancel_use()
	if _use_plan == null:
		return
	if _use_timer.advance(delta):
		_send_use()
	else:
		slot_view(_use_slot).set_ring(_use_timer.progress())


# A fresh press: refuse with a reason, or start timing the use.
func _begin_use() -> void:
	var plan := UsePlan.choose(body, selected, session)
	var reason: ItemUser.Reason = use_reason(plan, selected)
	if reason != ItemUser.Reason.OK:
		notice.show_line(refusal_line(reason, selected, plan.use_index))
		return
	_use_plan = plan
	_use_slot = selected
	_use_item_id = body.inventory.slots[selected].item_id
	var item := ItemUser.item_at(body, selected)
	_use_timer.start(item.uses[plan.use_index].time_s)


# Whether the hold in progress still names the use it began with, and that use still passes.
func _same_use() -> bool:
	if selected != _use_slot or body.inventory.slots[selected].item_id != _use_item_id:
		return false
	var now := UsePlan.choose(body, selected, session)
	if now.use_index != _use_plan.use_index or now.target != _use_plan.target:
		return false
	return use_reason(now, selected) == ItemUser.Reason.OK


func _send_use() -> void:
	var plan := _use_plan
	var slot: int = _use_slot
	_cancel_use()
	if session != null and is_instance_valid(session):
		session.use_item(slot, plan.use_index, plan.target_peer)
	use_sent.emit(slot, plan.use_index, plan.target_peer)


# Drops the hold in progress, if any; the button stays taken until it is let go.
func _cancel_use() -> void:
	var view := slot_view(_use_slot)
	if view != null:
		view.set_ring(0.0)
	_use_timer.reset()
	_use_plan = null
	_use_slot = -1
	_use_item_id = &""


func _locale() -> String:
	return CoopSession.locale_of(session)


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
		view.clicked.connect(_on_slot_clicked.bind(i))
		_slots.add_child(view)
		_views.append(view)
	selected = clampi(selected, 0, maxi(count - 1, 0))
	_layout()


func _on_slot_clicked(index: int) -> void:
	if accepts_input():
		select(index)


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
	weight_label.text = weight_text(inventory.weight(), inventory.tuning.weight_limit, text, _locale())


# The selected item's name and, when it has a use, the use key, its verb and the teammate it
# goes to. Nothing for an empty slot.
func _show_line() -> void:
	var line: String = ""
	var item: ItemData = ItemUser.item_at(body, selected) if _has_body() else null
	if item != null:
		var locale := _locale()
		var plan := UsePlan.choose(body, selected, session)
		var verb: String = ""
		var teammate: String = ""
		# At sea the use button is refused (design D11), so the line names no key and no verb.
		if plan.use_index >= 0 and not at_sea():
			verb = text.use_verb(item.uses[plan.use_index].action, locale)
			if plan.target != null and session != null:
				teammate = session.player_name(plan.target_peer)
		line = item_line_text(item.get_display_name(locale), _use_key, verb, teammate)
	if item_line.text != line:
		item_line.text = line
	item_line.visible = not line.is_empty()
	item_line_panel.visible = item_line.visible
