class_name InteractPrompt
extends Control
## The interact prompt (inventory-hud "Interact prompt", "Prompt placement", "Prompt verbs and
## targets"; design D1, D3, D4): one line on a HUD panel over the interactable InteractionPicker
## would pick for the local body now, "[E] Recoger Coco". This peer computes it with the same pure
## picker the host runs, so a client shows it without waiting; the host still decides. The verb,
## and the label where no content name applies, come from hud_text.tres under the interactable's
## prompt id; the content name comes from its owner (`Interactable.prompt_target`), and a thing
## that hides what it holds names only itself. Each frame it is placed from its target's canvas
## position mapped into the HUD: centred over it at whole pixels, its bottom edge 12 px above (34
## px above a player, over the name tag), at most 240 px wide, inside x 4-636, y 22-302 and off
## every HUD panel; a first line too wide puts its target on a second line, and a line still too
## wide ends in "…". Drawn in the HUD layer, the night tint and the Suave filter leave it
## alone. It hides while the player is down or gone, the crafting list is open, the run is paused
## or a screen is shown.
## A fresh interact press (the local body's intent, which is what the host's hold sees) locks the
## target as InteractionHold does (`PressTimer`): until release the prompt stays on it even when
## another comes nearer, and a 10 px ring left of the key fills over its hold time; the lock goes
## when the target is freed or disabled or, before the hold is done, out of reach and the slack,
## and nothing is shown again until release. Instant interactions show no ring. Ticked on physics
## frames, so in solo and on the host it runs on the same frames as the host's hold.
## A build site's prompt adds its state as this peer has it (inventory-hud "Build site prompt"):
## a line per missing input or tag, "Falta: Madera de la costa x4" first, or, once every input is
## in, the shared progress as a bar with its percentage.

## The local player's press landed on a workbench: the HUD opens the crafting list there.
signal bench_pressed(bench: Workbench)

const INTERACT_ACTION: StringName = &"interact"
const KEY_FORMAT: String = "[%s]"
const LINE_HEIGHT: float = 10.0
## Width of one glyph of the HUD's 8 px font.
const GLYPH_PX: float = 8.0
const MAX_WIDTH: float = 240.0
const RISE_PX: float = 12.0
## Over a player the prompt clears the NameTag label, whose top is 31 px above the body.
const PLAYER_RISE_PX: float = 34.0
## Where the prompt may sit: off the screen edges, below the top band's panels' row and above the
## inventory band.
const BOUNDS: Rect2 = Rect2(4.0, 22.0, 632.0, 280.0)
## Space left between the prompt and a HUD panel it is moved off.
const PANEL_GAP: float = 2.0
## The ring sits left of the first line with a 2 px gap.
const RING_SPACE: float = HudRing.SIZE.x + 2.0
## How far a locked press may stray before it is dropped, as the host's hold.
const LOCK_REACH_PX: float = InteractionPicker.REACH_PX + PlayerBody.REACH_SLACK_PX
## The progress bar sits left of its percentage: 48 px, then a 4 px gap.
const BAR_SPACE: float = 52.0
const BAR_GAP: float = 4.0
const NO_BAR: float = -1.0
const NO_BLOCKER: int = -1

## The local player, or null.
var body: PlayerBody = null
## The run's session (the language), or null.
var session: CoopSession = null
var text: HudText = HudText.load_default()
var device: InputLabels.Device = InputLabels.Device.KEYBOARD
## Hidden while a screen is shown over the run.
var screen_shown: bool = false
## Whether the HUD takes input now (no pause menu, summary or host-lost screen); RunHud answers.
var input_open: Callable = func() -> bool: return true
## Whether the crafting list holds the input; RunHud answers.
var list_open: Callable = func() -> bool: return false
## Maps a point of the world's canvas (the world view's own pixels, camera applied) into the HUD.
var to_hud: Callable = func(point: Vector2) -> Vector2: return point
## The HUD rects the prompt keeps clear of; RunHud answers.
var avoid: Callable = func() -> Array[Rect2]: return []
## The interactable the prompt is over, or null.
var target: Interactable = null
var _labels: Array[Label] = []
var _press: PressTimer = PressTimer.new()
var _was_held: bool = false
var _bar_value: float = NO_BAR

@onready var panel: PanelContainer = $Panel
@onready var ring: HudRing = $Ring
## The build progress bar; its fill is a child sized to the progress.
@onready var bar: ColorRect = $Bar
@onready var _bar_fill: ColorRect = $Bar/Fill


## "[E] Recoger Coco": the key, then the verb and the target `by` sees for `on`'s prompt id (the
## owner's content name, else the id's label), each left out when empty; the key alone without
## a prompt id.
static func head_text(on: Interactable, by: Node, key: String, words: HudText, locale: String) -> String:
	var parts := head_parts(on, by, key, words, locale)
	return parts[0] if parts[1].is_empty() else "%s %s" % [parts[0], parts[1]]


## The two halves of `head_text`: the key with the verb ("[E] Recoger"), and the target ("Coco",
## or "" for none).
static func head_parts(on: Interactable, by: Node, key: String, words: HudText, locale: String) -> PackedStringArray:
	var lead: String = KEY_FORMAT % key
	var id: StringName = on.prompt_id_for(by)
	if id.is_empty():
		return PackedStringArray([lead, ""])
	var verb: String = words.prompt_verb(id, locale)
	if not verb.is_empty():
		lead = "%s %s" % [lead, verb]
	var named: String = "" if on.hides_contents else on.prompt_target(by, locale)
	if named.is_empty():
		named = words.prompt_label(id, locale)
	return PackedStringArray([lead, named])


## Where a prompt of `size` goes for a target at `anchor` (HUD pixels): centred over it with its
## bottom edge `rise` above, clamped into BOUNDS, then moved below (or, with no room below, above)
## each of `blockers` it would cover.
static func place(anchor: Vector2, size: Vector2, rise: float, blockers: Array[Rect2]) -> Rect2:
	var rect := _clamped(Rect2(Vector2(roundf(anchor.x - size.x / 2.0), roundf(anchor.y - rise - size.y)), size))
	for i: int in blockers.size():
		var hit: int = _first_overlap(rect, blockers)
		if hit == NO_BLOCKER:
			break
		rect = _clamped(_off(rect, blockers[hit]))
	return rect


## What `site` still needs as this peer has it, one line per missing input or tag in the recipe's
## order ("Madera de la costa x4", "Yesca x1"), the first headed "Falta:"; none once all is in.
static func site_lines(site: BuildSite, words: HudText, locale: String) -> PackedStringArray:
	var shown: PackedStringArray = []
	var count_format: String = words.line(&"count", locale)
	var items := site.missing_items()
	for id: StringName in items:
		var item := GameState.content.get_entry(&"items", id) as ItemData
		shown.append(count_format % [item.get_display_name(locale) if item != null else String(id), items[id]])
	var tags := site.missing_tags()
	for tag: int in tags:
		shown.append(count_format % [words.tag_name(tag as DataEnums.ItemTag, locale), tags[tag]])
	if not shown.is_empty():
		shown[0] = "%s %s" % [words.line(&"missing", locale), shown[0]]
	return shown


static func _clamped(rect: Rect2) -> Rect2:
	var x: float = clampf(rect.position.x, BOUNDS.position.x, BOUNDS.end.x - rect.size.x)
	var y: float = clampf(rect.position.y, BOUNDS.position.y, BOUNDS.end.y - rect.size.y)
	return Rect2(Vector2(x, y).round(), rect.size)


static func _first_overlap(rect: Rect2, blockers: Array[Rect2]) -> int:
	for i: int in blockers.size():
		if rect.intersects(blockers[i]):
			return i
	return NO_BLOCKER


static func _off(rect: Rect2, blocker: Rect2) -> Rect2:
	var below := Rect2(Vector2(rect.position.x, blocker.end.y + PANEL_GAP), rect.size)
	if below.end.y <= BOUNDS.end.y:
		return below
	return Rect2(Vector2(rect.position.x, blocker.position.y - PANEL_GAP - rect.size.y), rect.size)


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Runs while the solo pause freezes the run, so the prompt hides under the pause menu.
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false


func _physics_process(delta: float) -> void:
	tick(delta)


## Follows `player` from now on.
func bind(player: PlayerBody, run_session: CoopSession = null) -> void:
	body = player
	session = run_session
	target = null
	_press.reset()


func set_device(value: InputLabels.Device) -> void:
	device = value


## One frame: follows the interact press, picks or keeps the target and draws the prompt over
## it, or hides.
func tick(delta: float) -> void:
	var held: bool = is_instance_valid(body) and body.intent.interact_held
	var fresh: bool = held and not _was_held
	_was_held = held
	if not _can_show():
		_hide()
		return
	if not held:
		_press.reset()
		target = _pick()
	elif fresh:
		_lock_pressed()
	elif not _press.keeps(body, LOCK_REACH_PX):
		target = null
	if target == null:
		_hide()
		return
	if held:
		_press.advance(delta)
	var shown := _lines_for(target)
	_bar_value = NO_BAR
	var site := target.get_parent() as BuildSite
	if site != null and site.recipe != null:
		var needs := site_lines(site, text, _locale())
		if needs.is_empty():
			_bar_value = site.progress()
			needs.append(text.line(&"percent", _locale()) % roundi(_bar_value * 100.0))
		shown.append_array(needs)
	_show(shown)


## The lines on show, top first; none while hidden.
func lines() -> PackedStringArray:
	var shown: PackedStringArray = []
	if not visible:
		return shown
	for label: Label in _labels:
		if label.visible:
			shown.append(label.text)
	return shown


## The prompt's rect in HUD pixels.
func prompt_rect() -> Rect2:
	return get_global_rect()


## The build progress the bar shows, 0 to 1, or below 0 with no bar on show.
func bar_progress() -> float:
	return _bar_value if visible and bar.visible else NO_BAR


func _can_show() -> bool:
	if not is_instance_valid(body) or body.left_island or body.downed or screen_shown:
		return false
	return is_inside_tree() and input_open.call() and not list_open.call()


# A fresh press goes to what the prompt showed: the body moves before the HUD in a frame, so that is
# what the host's hold picked at the press. If the host already used it up (an instant pick-up),
# nothing is locked until release; with nothing shown, the press goes to the picker's choice now.
func _lock_pressed() -> void:
	var pressed_on: Interactable = null
	if is_instance_valid(target):
		pressed_on = target
	elif target == null:
		pressed_on = _pick()
	target = null
	if pressed_on != null and pressed_on.enabled:
		target = pressed_on
		_press.lock(target)
		var bench := target.get_parent() as Workbench
		if bench != null:
			bench_pressed.emit(bench)


# What the host's press would reach now: the picker's choice among this peer's interactables.
func _pick() -> Interactable:
	var nearby: Array[Interactable] = []
	for node: Node in get_tree().get_nodes_in_group(Interactable.GROUP):
		var candidate := node as Interactable
		# Tests run a host and clients in one tree: only this peer's own world counts.
		if candidate != null and candidate.multiplayer == body.multiplayer:
			nearby.append(candidate)
	return InteractionPicker.pick(body.global_position, nearby, body)


# The head line, or the key with the verb and then the target when one line is too wide.
func _lines_for(on: Interactable) -> PackedStringArray:
	var key: String = InputLabels.label_for(INTERACT_ACTION, device, text, _locale())
	var parts := head_parts(on, body, key, text, _locale())
	if parts[1].is_empty():
		return PackedStringArray([parts[0]])
	var whole: String = "%s %s" % [parts[0], parts[1]]
	if whole.length() <= _first_line_chars(on):
		return PackedStringArray([whole])
	return parts


# Glyphs that fit the first line, beside the ring of a timed hold.
func _first_line_chars(on: Interactable) -> int:
	return floori((MAX_WIDTH - (RING_SPACE if _has_ring(on) else 0.0)) / GLYPH_PX)


func _has_ring(on: Interactable) -> bool:
	return on.hold_time_s > 0.0


# Lays out `shown` over the target; with a bar, the last line is its percentage.
func _show(shown: PackedStringArray) -> void:
	var indents: Array[float] = []
	var width: float = 0.0
	for i: int in shown.size():
		var indent: float = 0.0
		if i == 0 and _has_ring(target):
			indent = RING_SPACE
		elif i == shown.size() - 1 and _bar_value != NO_BAR:
			indent = BAR_SPACE
		indents.append(indent)
		shown[i] = InventoryStrip.cut(shown[i], floori((MAX_WIDTH - indent) / GLYPH_PX))
		width = maxf(width, shown[i].length() * GLYPH_PX + indent)
	var box := Vector2(width, shown.size() * LINE_HEIGHT)
	var anchor: Vector2 = (to_hud.call(target.get_global_transform_with_canvas().origin) as Vector2).round()
	var rise: float = PLAYER_RISE_PX if target.get_parent() is PlayerBody else RISE_PX
	var rect := place(anchor, box, rise, avoid.call())
	position = rect.position
	size = rect.size
	panel.position = Vector2.ZERO
	panel.size = rect.size
	ring.visible = _has_ring(target)
	ring.position = Vector2.ZERO
	ring.set_value(_press.progress() if _press.target == target else 0.0)
	_show_bar(shown.size() - 1)
	_set_lines(shown, indents)
	visible = true


# The bar on line `line`, filled to the progress, or hidden with no bar.
func _show_bar(line: int) -> void:
	bar.visible = _bar_value != NO_BAR
	if not bar.visible:
		return
	var width: float = BAR_SPACE - BAR_GAP
	bar.position = Vector2(0.0, line * LINE_HEIGHT + floorf((LINE_HEIGHT - bar.size.y) / 2.0))
	bar.size = Vector2(width, bar.size.y)
	_bar_fill.size = Vector2(roundf(width * clampf(_bar_value, 0.0, 1.0)), bar.size.y)


func _set_lines(shown: PackedStringArray, indents: Array[float]) -> void:
	while _labels.size() < shown.size():
		var label := Label.new()
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.clip_text = true
		add_child(label)
		_labels.append(label)
	for i: int in _labels.size():
		var label := _labels[i]
		label.visible = i < shown.size()
		if not label.visible:
			continue
		var left: float = indents[i]
		label.text = shown[i]
		label.position = Vector2(left, i * LINE_HEIGHT)
		label.size = Vector2(size.x - left, LINE_HEIGHT)


func _hide() -> void:
	_press.reset()
	target = null
	_bar_value = NO_BAR
	ring.set_value(0.0)
	visible = false


func _locale() -> String:
	return session.locale if is_instance_valid(session) else "es"
