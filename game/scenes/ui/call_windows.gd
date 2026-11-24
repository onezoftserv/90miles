class_name CallWindows
extends Control
## art-guardacostas D6 (spec "Call windows"): the loudhailer's lines and the squad's calls, each in a
## small dark window of the HUD over its speaker, in the HUD's 8 px font. The session's `call_shown`
## signal brings each call; a window holds at most MAX_ROWS rows of MAX_GLYPHS glyphs, wrapped at
## words, and stays `show_s` seconds. Each frame a window is placed from its speaker's canvas position
## mapped into the HUD (`to_hud`): its bottom TAIL_PX over the speaker's top, centred, at whole pixels;
## kept EDGE_PX inside the view and above the bottom band (BOTTOM_Y); moved down under a top HUD window
## or up over the prompt or the local player's figure it would cover (`avoid`); stacked above an earlier window it would overlap. A
## 3 px tail points at the speaker, from the nearest edge when the speaker is off screen. A new call
## from the same speaker replaces its old one; a freed speaker's call goes. The window uses its own
## theme variation (VARIATION), not one of RunHud.HUD_PANELS, so the interact prompt never dodges a
## call. It reads the speakers' positions and draws; it never writes game state. Quick chat and signs
## keep their world speech bubbles.

enum Side { BOTTOM, TOP, LEFT, RIGHT }

## The window's theme variation: the `window_thin` stylebox with content margins 4/1/4/1.
const VARIATION: StringName = &"HudCall"
const MAX_GLYPHS: int = 30
const MAX_ROWS: int = 3
## The space between the window and its speaker, which the tail fills.
const TAIL_PX: float = 3.0
## How far inside the view a window stays.
const EDGE_PX: float = 2.0
## A window's bottom never goes below this (the bottom band starts under it).
const BOTTOM_Y: float = 326.0
const VIEW: Vector2 = Vector2(640.0, 360.0)
## A rect whose middle is above this is a top window: a window it covers moves down under it; any other
## (the prompt, the local player's figure) it moves up over.
const TOP_BAND_Y: float = 120.0
## A call stays at least this long.
const MIN_S: float = 3.0
## Characters read per second, after the first second.
const READ_CHARS_PER_S: float = 15.0
## The tail's colour: the window's own dark fill (#222034).
const TAIL_COLOR: Color = HudStyle.OUTLINE
## A speaker's top over its origin when its look gives none.
const DEFAULT_TOP_Y: float = -16.0

## The run's session, or null.
var session: CoopSession = null
## Maps a point of the world's canvas (the world view's own pixels, camera applied) into the HUD.
var to_hud: Callable = func(point: Vector2) -> Vector2: return point
## The HUD rects a window keeps clear of: the top windows and the prompt.
var avoid: Callable = func() -> Array[Rect2]: return []
## Nothing is drawn while a screen is shown over the run.
var screen_shown: bool = false
## How many calls have been shown.
var calls_shown: int = 0

var _calls: Array[Shown] = []


## One call on show.
class Shown extends RefCounted:
	var speaker: Node2D
	var text: String
	var left_s: float
	var panel: PanelContainer
	var rect: Rect2
	var anchor: Vector2
	var side: int = 0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	focus_mode = Control.FOCUS_NONE


func _process(delta: float) -> void:
	tick(delta)


## Shows the calls of `run_session` from now on.
func bind(run_session: CoopSession) -> void:
	session = run_session
	session.call_shown.connect(show_call)


## `text` split into rows of at most MAX_GLYPHS glyphs at its spaces (a longer word is cut).
static func rows(text: String) -> PackedStringArray:
	var out := PackedStringArray()
	var row: String = ""
	for word: String in text.split(" ", false):
		while word.length() > MAX_GLYPHS:
			if not row.is_empty():
				out.append(row)
				row = ""
			out.append(word.left(MAX_GLYPHS))
			word = word.substr(MAX_GLYPHS)
		if row.is_empty():
			row = word
		elif row.length() + 1 + word.length() <= MAX_GLYPHS:
			row += " " + word
		else:
			out.append(row)
			row = word
	if not row.is_empty():
		out.append(row)
	return out


## How long a call of `text` stays: 1 s plus 1 s per 15 characters, at least MIN_S.
static func show_s(text: String) -> float:
	return maxf(MIN_S, 1.0 + text.length() / READ_CHARS_PER_S)


## The window's rect for a speaker whose top is at `anchor` (HUD pixels), of `size`, clear of `avoid`
## and of the windows already `taken`.
static func place(anchor: Vector2, size: Vector2, avoid_rects: Array[Rect2], taken: Array[Rect2]) -> Rect2:
	var spot := Vector2(roundf(anchor.x) - floorf(size.x / 2.0), roundf(anchor.y) - TAIL_PX - size.y)
	spot = _inside(spot, size)
	# Twice, so a move off one rect that lands on another is caught.
	for _pass: int in 2:
		for other: Rect2 in avoid_rects:
			if Rect2(spot, size).intersects(other):
				if other.get_center().y < TOP_BAND_Y:
					spot.y = other.end.y + 1.0
				else:
					spot.y = other.position.y - 1.0 - size.y
				spot = _inside(spot, size)
	for other: Rect2 in taken:
		if Rect2(spot, size).intersects(other):
			spot.y = other.position.y - 1.0 - size.y
			spot = _inside(spot, size)
	return Rect2(spot, size)


## Which edge of `rect` the tail leaves from to point at a speaker whose top is at `anchor`.
static func tail_side(anchor: Vector2, rect: Rect2) -> int:
	if anchor.x > rect.end.x:
		return Side.RIGHT
	if anchor.x < rect.position.x:
		return Side.LEFT
	if anchor.y < rect.position.y:
		return Side.TOP
	return Side.BOTTOM


## The top of `speaker`'s drawn look over its origin, in its own pixels.
static func top_of(speaker: Node2D) -> float:
	var creature := speaker as Creature
	if creature != null and creature.is_patrol():
		return PatrolLook.top_y()
	if creature != null and creature.is_in_group(FreeHandle.SOLDIER_GROUP):
		return SquadLook.soldier_top_y()
	return DEFAULT_TOP_Y


## Shows `text` over `speaker`, replacing that speaker's call on show.
func show_call(speaker: Node2D, text: String) -> void:
	if speaker == null or text.is_empty():
		return
	var shown: Shown = null
	for each: Shown in _calls:
		if each.speaker == speaker:
			shown = each
	if shown == null:
		shown = Shown.new()
		shown.speaker = speaker
		shown.panel = _make_panel()
		add_child(shown.panel)
		_calls.append(shown)
	else:
		# A replaced call is the latest: it stacks over the others.
		_calls.erase(shown)
		_calls.append(shown)
	shown.text = text
	shown.left_s = show_s(text)
	calls_shown += 1
	var label := shown.panel.get_child(0) as Label
	label.text = "\n".join(rows(text))
	shown.panel.reset_size()
	tick(0.0)


## How many calls are on show.
func count() -> int:
	return _calls.size()


func speaker_of(index: int) -> Node2D:
	return _calls[index].speaker


func text_of(index: int) -> String:
	return _calls[index].text


func panel_of(index: int) -> PanelContainer:
	return _calls[index].panel


## The window's rect in HUD pixels, as placed by the last tick.
func rect_of(index: int) -> Rect2:
	return _calls[index].rect


## The edge the window's tail leaves from.
func side_of(index: int) -> int:
	return _calls[index].side


## Runs the calls' clocks `delta` seconds on and places the windows for this frame.
func tick(delta: float) -> void:
	for shown: Shown in _calls.duplicate():
		shown.left_s -= delta
		if shown.left_s <= 0.0 or not is_instance_valid(shown.speaker) or not shown.speaker.is_inside_tree():
			_calls.erase(shown)
			shown.panel.queue_free()
			shown.panel.visible = false
	var avoid_rects: Array[Rect2] = []
	if not _calls.is_empty():
		avoid_rects.assign(avoid.call())
	var taken: Array[Rect2] = []
	for shown: Shown in _calls:
		shown.panel.visible = not screen_shown
		var size: Vector2 = shown.panel.get_combined_minimum_size()
		shown.panel.size = size
		var canvas: Transform2D = shown.speaker.get_global_transform_with_canvas()
		var top: Vector2 = to_hud.call(canvas * Vector2(0.0, top_of(shown.speaker)))
		shown.anchor = top.round()
		shown.rect = place(shown.anchor, size, avoid_rects, taken)
		shown.side = tail_side(shown.anchor, shown.rect)
		shown.panel.position = shown.rect.position
		taken.append(shown.rect)
	queue_redraw()


func _draw() -> void:
	if screen_shown:
		return
	for shown: Shown in _calls:
		_draw_tail(shown)


# A 3 px tail of 5, 3 and 1 pixels from the window's edge toward the speaker.
func _draw_tail(shown: Shown) -> void:
	var rect: Rect2 = shown.rect
	for step: int in int(TAIL_PX):
		var half: int = 2 - step
		match shown.side:
			Side.BOTTOM, Side.TOP:
				var x: float = clampf(shown.anchor.x, rect.position.x + 3.0, rect.end.x - 4.0)
				var y: float = rect.end.y + step if shown.side == Side.BOTTOM else rect.position.y - 1.0 - step
				draw_rect(Rect2(x - half, y, 2 * half + 1, 1.0), TAIL_COLOR)
			Side.LEFT, Side.RIGHT:
				var y: float = clampf(shown.anchor.y, rect.position.y + 3.0, rect.end.y - 4.0)
				var x: float = rect.end.x + step if shown.side == Side.RIGHT else rect.position.x - 1.0 - step
				draw_rect(Rect2(x, y - half, 1.0, 2 * half + 1), TAIL_COLOR)


func _make_panel() -> PanelContainer:
	var panel := PanelContainer.new()
	panel.theme_type_variation = VARIATION
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var label := Label.new()
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(label)
	return panel


static func _inside(spot: Vector2, size: Vector2) -> Vector2:
	return Vector2(
		clampf(spot.x, EDGE_PX, VIEW.x - EDGE_PX - size.x),
		clampf(spot.y, EDGE_PX, BOTTOM_Y - size.y),
	)
