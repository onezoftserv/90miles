class_name BodyMarks
extends Control
## inventory-hud "Hidden mark" (design D1, D9): a 7×5 px closed eye over every player of the run
## whose stealth state is hidden, the local player included, on every peer. It is drawn in the HUD
## layer, so the night tint and the Suave filter, which apply to the world view only, leave its
## colours alone. Each frame a mark is placed from its body's canvas position mapped into the HUD:
## centred over the body at whole pixels, its bottom edge 3 px above the drawn head (BodyLook), or
## above the name tag's label while the tag shows. A submerged diver gets none, and nothing is drawn
## while a screen is over the run or for a body that has left the island or is gone.
## guardacostas-stealth "Patrol cues": a 7×5 px open eye over every player whose shown spot fraction
## (`PlayerBody.spot_shown`, the host's net_spot) is above 0 and who is not hidden (the closed eye
## wins), placed the same way. Its iris fills with the fraction: IRIS_PIXELS cells, `iris_pixels` of
## them dark, from the bottom row up and left to right.

const MARK_SIZE: Vector2 = Vector2(7.0, 5.0)
## Space between the mark's bottom edge and the head or the name tag.
const HEAD_GAP_PX: float = 3.0
## The 1 px outline and the eye's ground: the HUD panels' dark blue.
const OUTLINE_COLOR: Color = HudStyle.OUTLINE
## The eye: the HUD's cream.
const EYE_COLOR: Color = HudStyle.CREAM
## A closed eye in the 5×3 inside the outline: the lid's curve and two lashes, by pixel.
const EYE_PIXELS: Array[Vector2i] = [
	Vector2i(0, 0), Vector2i(4, 0),
	Vector2i(1, 1), Vector2i(2, 1), Vector2i(3, 1),
	Vector2i(1, 2), Vector2i(3, 2),
]
## The open eye in the 5×3 inside the outline: the almond's white, by pixel.
const OPEN_EYE_PIXELS: Array[Vector2i] = [
	Vector2i(1, 0), Vector2i(2, 0), Vector2i(3, 0),
	Vector2i(0, 1), Vector2i(1, 1), Vector2i(2, 1), Vector2i(3, 1), Vector2i(4, 1),
	Vector2i(1, 2), Vector2i(2, 2), Vector2i(3, 2),
]
## The iris: the middle 3×3 of the open eye's inside, filled from its bottom row up as the meter fills.
const IRIS_PIXELS: int = 9
const IRIS_COLOR: Color = HudStyle.OUTLINE
const TAG_NAME: StringName = &"NameTag"
## Every mark layer, so a speech bubble over a player can sit above its mark (design.md P11).
const GROUP: StringName = &"body_marks"

## The run's session (its players), or null.
var session: CoopSession = null
## Maps a point of the world's canvas (the world view's own pixels, camera applied) into the HUD.
var to_hud: Callable = func(point: Vector2) -> Vector2: return point
## Nothing is drawn while a screen is shown over the run.
var screen_shown: bool = false
# Each marked body's rect in HUD pixels, in the session's peer order.
var _marked: Array[Node] = []
var _rects: Array[Rect2] = []
# The same for the open eyes.
var _eyed: Array[Node] = []
var _eye_rects: Array[Rect2] = []


func _ready() -> void:
	add_to_group(GROUP)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	focus_mode = Control.FOCUS_NONE


func _process(_delta: float) -> void:
	tick()


## Follows the players of `run_session` from now on.
func bind(run_session: CoopSession) -> void:
	session = run_session
	tick()


## Places the marks for this frame.
func tick() -> void:
	_marked.clear()
	_rects.clear()
	_eyed.clear()
	_eye_rects.clear()
	if not screen_shown and is_instance_valid(session):
		for peer_id: int in session.peer_ids():
			var player := session.body(peer_id)
			if _hidden(player):
				_marked.append(player)
				_rects.append(_place(player))
			elif _spotted(player):
				_eyed.append(player)
				_eye_rects.append(_place(player))
	queue_redraw()


func has_mark(player: PlayerBody) -> bool:
	return _marked.has(player)


## True when an open eye shows over `player`: a spot fraction above 0 and not hidden.
func has_open_eye(player: PlayerBody) -> bool:
	return _eyed.has(player)


## The open eye's rect over `player` in HUD pixels, or an empty rect without one.
func eye_rect(player: PlayerBody) -> Rect2:
	var index: int = _eyed.find(player)
	return _eye_rects[index] if index >= 0 else Rect2()


## How full the open eye over `player` is, 0 to 1 (0 without one).
func eye_fill(player: PlayerBody) -> float:
	return clampf(player.spot_shown, 0.0, 1.0) if has_open_eye(player) else 0.0


## How many of the iris's IRIS_PIXELS are dark for a fill of `fraction`: any fill above 0 shows at least
## one, a full meter all of them.
static func iris_pixels(fraction: float) -> int:
	return clampi(ceili(fraction * IRIS_PIXELS - 0.000001), 1 if fraction > 0.0 else 0, IRIS_PIXELS)


## True when anything is marked over `player`: the closed eye or the open one (what a speech bubble or
## the interact prompt stacks over).
func has_marker(player: PlayerBody) -> bool:
	return has_mark(player) or has_open_eye(player)


## The rect of whichever mark shows over `player` (an empty rect without one).
func marker_rect(player: PlayerBody) -> Rect2:
	return mark_rect(player) if has_mark(player) else eye_rect(player)


## The mark's rect over `player` in HUD pixels, or an empty rect without one.
func mark_rect(player: PlayerBody) -> Rect2:
	var index: int = _marked.find(player)
	return _rects[index] if index >= 0 else Rect2()


## Every mark on show, in HUD pixels.
func mark_rects() -> Array[Rect2]:
	return _rects.duplicate()


## The colours a mark is drawn in: the outline, then the eye.
func mark_colors() -> PackedColorArray:
	return PackedColorArray([OUTLINE_COLOR, EYE_COLOR])


# Lit and not hidden: a shown spot fraction above 0 on a body still on the island.
func _spotted(player: PlayerBody) -> bool:
	if not is_instance_valid(player) or not player.is_inside_tree() or player.left_island:
		return false
	return player.spot_shown > 0.0 and player.stealth_state != MovementStep.Stealth.HIDDEN


func _hidden(player: PlayerBody) -> bool:
	if not is_instance_valid(player) or not player.is_inside_tree() or player.left_island:
		return false
	return player.stealth_state == MovementStep.Stealth.HIDDEN


# Centred over the body, its bottom HEAD_GAP_PX above the head or the shown name tag.
func _place(player: PlayerBody) -> Rect2:
	var canvas: Transform2D = player.get_global_transform_with_canvas()
	var anchor: Vector2 = to_hud.call(canvas.origin)
	var head: Vector2 = to_hud.call(canvas * Vector2(0.0, _top_of(player)))
	var bottom: float = roundf(head.y) - HEAD_GAP_PX
	return Rect2(Vector2(roundf(anchor.x - MARK_SIZE.x / 2.0), bottom - MARK_SIZE.y), MARK_SIZE)


# The topmost drawn point over the body's origin, in its own pixels: the name tag's label while the
# tag shows, else the head.
func _top_of(player: PlayerBody) -> float:
	var look := player.get_node_or_null(^"BodyLook") as BodyLook
	var top: float = look.head_y() if look != null else 0.0
	var tag := player.get_node_or_null(NodePath(TAG_NAME)) as NameTag
	if tag != null and tag.visible and tag.label != null:
		top = minf(top, tag.position.y + tag.label.position.y)
	return top


func _draw() -> void:
	for rect: Rect2 in _rects:
		draw_rect(rect, OUTLINE_COLOR)
		var inside: Vector2 = rect.position + Vector2.ONE
		for pixel: Vector2i in EYE_PIXELS:
			draw_rect(Rect2(inside + Vector2(pixel), Vector2.ONE), EYE_COLOR)
	for i: int in _eye_rects.size():
		_draw_open_eye(_eye_rects[i], clampf((_eyed[i] as PlayerBody).spot_shown, 0.0, 1.0))


# The outline, the almond in cream and the iris's dark pixels from the bottom row up.
func _draw_open_eye(rect: Rect2, fraction: float) -> void:
	draw_rect(rect, OUTLINE_COLOR)
	var inside: Vector2 = rect.position + Vector2.ONE
	for pixel: Vector2i in OPEN_EYE_PIXELS:
		draw_rect(Rect2(inside + Vector2(pixel), Vector2.ONE), EYE_COLOR)
	var dark: int = iris_pixels(fraction)
	for n: int in dark:
		# Bottom row first (y = 2), then the middle, then the top; left to right inside a row.
		var row: int = 2 - n / 3
		var column: int = 1 + n % 3
		draw_rect(Rect2(inside + Vector2(column, row), Vector2.ONE), IRIS_COLOR)
