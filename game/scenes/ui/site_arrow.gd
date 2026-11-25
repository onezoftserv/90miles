class_name SiteArrow
extends Control
## hud-clarity, ui-shell "Raft-site arrow" and "When the raft-site arrow hides": while the level's raft
## site (or the raft built on it) has its centre off screen, one 9×9 arrow points at it from where the
## line from the view's centre to the site crosses FRAME, which keeps it off the HUD's windows, the
## horizon band and the bottom band. The art comes in two kit icons, a straight and a diagonal arrow,
## turned by quarter turns into eight directions: pixel art is never turned to any other angle. It
## reads the site by name, never another build site or anything secret. Drawing only.

## The band the arrow's rect keeps to: under the top windows, above the bottom band.
const FRAME: Rect2 = Rect2(8.0, 96.0, 624.0, 204.0)
## The view, in HUD pixels, less a margin: a site centre outside it is off screen.
const VIEW: Rect2 = Rect2(4.0, 4.0, 632.0, 352.0)
const CENTRE: Vector2 = Vector2(320.0, 180.0)
const ARROW_SIZE: Vector2 = Vector2(9.0, 9.0)
const SITE_NAMES: Array[NodePath] = [^"RaftSite", ^"Raft"]
## The eight directions, clockwise from east (y grows down), as unit steps.
const DIRECTIONS: Array[Vector2i] = [
	Vector2i(1, 0), Vector2i(1, 1), Vector2i(0, 1), Vector2i(-1, 1),
	Vector2i(-1, 0), Vector2i(-1, -1), Vector2i(0, -1), Vector2i(1, -1),
]

## The two 9×9 kit arrows (set in run_hud.tscn): straight pointing east, diagonal pointing north-east.
@export var straight: Texture2D = null
@export var diagonal: Texture2D = null

var session: CoopSession = null
var local_peer: int = CoopSession.HOST_ID
## Maps a point of the world's canvas into HUD pixels (RunHud.world_to_hud).
var to_hud: Callable = func(point: Vector2) -> Vector2: return point
## Whether the HUD wants the arrow away (a screen, the crafting list or a sign note).
var held: bool = false

var _rect: Rect2 = Rect2()
var _octant: int = -1


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)


## Places the arrow for this frame, or hides it.
func tick() -> void:
	var rect := Rect2()
	var octant: int = -1
	var target := site()
	if not held and target != null and is_instance_valid(session) and not session.has_left(local_peer):
		var point: Vector2 = to_hud.call(target.get_global_transform_with_canvas().origin)
		if not VIEW.has_point(point):
			rect = place(point)
			octant = octant_of(point)
	if rect != _rect or octant != _octant:
		_rect = rect
		_octant = octant
		queue_redraw()


## The level's raft site, or the raft built on it, or null.
func site() -> Node2D:
	if not is_instance_valid(session):
		return null
	for path: NodePath in SITE_NAMES:
		var found := session.get_node_or_null(path) as Node2D
		if found != null and not found.is_queued_for_deletion():
			return found
	return null


func shown() -> bool:
	return _octant >= 0


## The arrow's rect in HUD pixels; empty while hidden.
func arrow_rect() -> Rect2:
	return _rect


## The direction the arrow points, as a unit step (west is (-1, 0)); zero while hidden.
func direction() -> Vector2i:
	return DIRECTIONS[_octant] if _octant >= 0 else Vector2i.ZERO


## The 9×9 rect, in whole pixels, centred where the line from CENTRE to `point` leaves FRAME.
static func place(point: Vector2) -> Rect2:
	var ray: Vector2 = point - CENTRE
	var reach: float = INF
	if ray.x > 0.0:
		reach = minf(reach, (FRAME.end.x - CENTRE.x) / ray.x)
	elif ray.x < 0.0:
		reach = minf(reach, (FRAME.position.x - CENTRE.x) / ray.x)
	if ray.y > 0.0:
		reach = minf(reach, (FRAME.end.y - CENTRE.y) / ray.y)
	elif ray.y < 0.0:
		reach = minf(reach, (FRAME.position.y - CENTRE.y) / ray.y)
	var exit: Vector2 = CENTRE + ray * (reach if is_finite(reach) else 0.0)
	var half: Vector2 = ARROW_SIZE / 2.0
	var centre: Vector2 = exit.clamp(FRAME.position + half, FRAME.end - half)
	return Rect2((centre - half).floor(), ARROW_SIZE)


## Which of the eight directions points at `point` from CENTRE: 0 east, then clockwise.
static func octant_of(point: Vector2) -> int:
	var ray: Vector2 = point - CENTRE
	return posmod(roundi(ray.angle() / (PI / 4.0)), 8)


func _draw() -> void:
	if _octant < 0:
		return
	# Even octants are the straight arrow turned from east; odd ones the diagonal turned from
	# north-east (octant 7), each by whole quarter turns.
	var texture: Texture2D = straight if _octant % 2 == 0 else diagonal
	if texture == null:
		return
	var quarter_turns: int = _octant / 2 if _octant % 2 == 0 else ((_octant + 1) / 2) % 4
	draw_set_transform(_rect.position + ARROW_SIZE / 2.0, float(quarter_turns) * PI / 2.0, Vector2.ONE)
	draw_texture(texture, -ARROW_SIZE / 2.0)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
