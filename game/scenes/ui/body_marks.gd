class_name BodyMarks
extends Control
## inventory-hud "Hidden mark" (design D1, D9): a 7×5 px closed eye over every player of the run
## whose stealth state is hidden, the local player included, on every peer. It is drawn in the HUD
## layer, so the night tint and the Suave filter, which apply to the world view only, leave its
## colours alone. Each frame a mark is placed from its body's canvas position mapped into the HUD:
## centred over the body at whole pixels, its bottom edge 3 px above the drawn head (BodyLook), or
## above the name tag's label while the tag shows. A submerged diver gets none, and nothing is drawn
## while a screen is over the run or for a body that has left the island or is gone.

const MARK_SIZE: Vector2 = Vector2(7.0, 5.0)
## Space between the mark's bottom edge and the head or the name tag.
const HEAD_GAP_PX: float = 3.0
## The 1 px outline and the eye's ground: the HUD panels' dark blue.
const OUTLINE_COLOR: Color = Color(0.04, 0.08, 0.13)
## The eye: the HUD's cream.
const EYE_COLOR: Color = Color(0.957, 0.937, 0.878)
## A closed eye in the 5×3 inside the outline: the lid's curve and two lashes, by pixel.
const EYE_PIXELS: Array[Vector2i] = [
	Vector2i(0, 0), Vector2i(4, 0),
	Vector2i(1, 1), Vector2i(2, 1), Vector2i(3, 1),
	Vector2i(1, 2), Vector2i(3, 2),
]
const TAG_NAME: StringName = &"NameTag"

## The run's session (its players), or null.
var session: CoopSession = null
## Maps a point of the world's canvas (the world view's own pixels, camera applied) into the HUD.
var to_hud: Callable = func(point: Vector2) -> Vector2: return point
## Nothing is drawn while a screen is shown over the run.
var screen_shown: bool = false
# Each marked body's rect in HUD pixels, in the session's peer order.
var _marked: Array[Node] = []
var _rects: Array[Rect2] = []


func _ready() -> void:
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
	if not screen_shown and is_instance_valid(session):
		for peer_id: int in session.peer_ids():
			var player := session.body(peer_id)
			if _hidden(player):
				_marked.append(player)
				_rects.append(_place(player))
	queue_redraw()


func has_mark(player: PlayerBody) -> bool:
	return _marked.has(player)


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
