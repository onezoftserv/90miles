class_name GuardacostasArt
extends Resource
## art-guardacostas D5: the coast guard's art in one place, as CreatureArt is for the creatures. The
## launch's frames (`move` and `idle`, side-on, bow toward +x) with the pixel of its roof lamp, which
## sits on the boat's position and is the searchlight's apex; the dinghy's frames (`row` and
## `beached`) with the point of its keel that sits on the dinghy's position; and the soldiers' looks,
## composed like a player's (LookComposer) and dealt by the number in a soldier's node name, so every
## peer gives a soldier the same look. Art data only: nothing here changes the simulation.

const STANDARD_PATH: String = "res://assets/art/creatures/guardacostas_art.tres"

## The launch: `move` and `idle`, each cell `hull_cell` pixels.
@export var hull_frames: SpriteFrames = null
@export var hull_cell: Vector2i = Vector2i(96, 48)
## The roof lamp's pixel inside a hull cell (bow toward +x, not mirrored).
@export var hull_lamp_px: Vector2i = Vector2i.ZERO
## The dinghy: `row` and `beached`, each cell `dinghy_cell` pixels.
@export var dinghy_frames: SpriteFrames = null
@export var dinghy_cell: Vector2i = Vector2i(32, 16)
## The keel's middle inside a dinghy cell (bow toward +x, not mirrored): the point on its position.
@export var dinghy_foot_px: Vector2i = Vector2i.ZERO
## The soldiers' looks; a soldier named `Creature<n>` takes look n mod their count.
@export var soldier_looks: Array[PlayerLookData] = []

static var _standard: GuardacostasArt = null
var _hull_top: float = NAN


## The shipped coast guard art.
static func standard() -> GuardacostasArt:
	if _standard == null:
		_standard = load(STANDARD_PATH) as GuardacostasArt
	return _standard


## The number in a node name such as `Creature12` (its trailing digits), or 0 without any.
static func node_number(node_name: String) -> int:
	var digits: String = ""
	for i: int in range(node_name.length() - 1, -1, -1):
		var c: String = node_name[i]
		if c < "0" or c > "9":
			break
		digits = c + digits
	return digits.to_int() if not digits.is_empty() else 0


## The look of the soldier whose node is named `node_name`, or null without looks.
func soldier_look(node_name: String) -> PlayerLookData:
	if soldier_looks.is_empty():
		return null
	return soldier_looks[posmod(node_number(node_name), soldier_looks.size())]


## Where the hull's cell is drawn from so its lamp pixel covers the boat's position, mirrored or not.
func hull_offset(mirrored: bool) -> Vector2:
	var lamp_x: int = hull_cell.x - 1 - hull_lamp_px.x if mirrored else hull_lamp_px.x
	return -Vector2(lamp_x, hull_lamp_px.y)


## Where the dinghy's cell is drawn from so its keel's middle is on its position, mirrored or not.
func dinghy_offset(mirrored: bool) -> Vector2:
	var foot_x: int = dinghy_cell.x - 1 - dinghy_foot_px.x if mirrored else dinghy_foot_px.x
	return -Vector2(foot_x, dinghy_foot_px.y)


## The top of the drawn hull over the boat's position (its topmost opaque row in the first `idle`
## frame, which the lamp's row is measured against).
func hull_top_y() -> float:
	if is_nan(_hull_top):
		_hull_top = -float(hull_lamp_px.y)
		if hull_frames != null and hull_frames.has_animation(&"idle"):
			var frame: Texture2D = hull_frames.get_frame_texture(&"idle", 0)
			if frame != null:
				var used: Rect2i = frame.get_image().get_used_rect()
				_hull_top = float(used.position.y - hull_lamp_px.y)
	return _hull_top
