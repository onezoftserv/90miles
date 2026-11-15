class_name PatrolLook
extends Node2D
## A patrol boat's look (guardacostas-stealth decision 11): the `PatrolLook` child of creature.tscn, in
## `art_view`, used on every peer, the host's too. For a boat in sight (its lap or an alert) it draws a
## placeholder hull until the art pass makes the boat, and, while the boat's light is on, the searchlight
## as a PointLight2D with the generated cone texture (PatrolCone) rotated to the beam: under the night
## CanvasModulate a light brightens the sand it covers, which reads as a searchlight. It also speaks the
## loudhailer: when the boat's `alert_serial` changes, a speech bubble over the boat shows for BUBBLE_S
## with a line of its PatrolData in the session's language: `alert_lines_<locale>` when the boat is
## alerting after the change (ALERT_LOCK or ALERT_SEARCH), else `give_up_lines_<locale>`, picked by
## `alert_serial` mod the line count so every peer shows the same line. It reads the creature's synced
## position, facing, state, clock, beam, light and serial and never writes any of them. A creature that
## is not a patrol boat draws nothing. CreatureRig processes no frames, so tests drive `step` themselves.

const BUBBLE_S: float = 3.0
const HULL_FILL: Color = Color(0.62, 0.67, 0.72)
const CABIN_FILL: Color = Color(0.86, 0.88, 0.9)
const HULL_LINE: Color = Color(0.1, 0.12, 0.18)
const LIGHT_COLOR: Color = Color(1.0, 0.93, 0.72)
const LIGHT_ENERGY: float = 1.2
## The hull's outline in pixels, bow toward +x: a 17 by 8 boat with a pointed bow.
const HULL_POINTS: PackedVector2Array = [
	Vector2(9.0, 0.0), Vector2(5.0, -4.0), Vector2(-8.0, -4.0), Vector2(-8.0, 4.0), Vector2(5.0, 4.0),
]
const CABIN_POINTS: PackedVector2Array = [
	Vector2(-1.0, -2.0), Vector2(-6.0, -2.0), Vector2(-6.0, 2.0), Vector2(-1.0, 2.0),
]

## True while the hull is drawn (the boat is in its lap or an alert).
var hull_visible: bool = false
## The searchlight, or null before the first step of a patrol boat.
var light: PointLight2D = null
## The loudhailer line shown last, and how many have been shown.
var last_line: String = ""
var lines_shown: int = 0

var _serial: int = -1
var _facing: float = 0.0


func _ready() -> void:
	# After the creature's own physics callbacks and the players' look: reads this frame's state.
	process_priority = 1


func _process(delta: float) -> void:
	step(delta)


## Draws the boat as it is now, `delta` seconds after the last step.
func step(_delta: float) -> void:
	var creature := get_parent() as Creature
	if creature == null or not creature.is_patrol():
		_hide()
		return
	var state: int = creature.state_id
	var in_sight: bool = state == PatrolRoute.State.LAP or state == PatrolRoute.State.ALERT_LOCK or state == PatrolRoute.State.ALERT_SEARCH
	if in_sight != hull_visible or not is_equal_approx(_facing, creature.facing.angle()):
		hull_visible = in_sight
		_facing = creature.facing.angle()
		queue_redraw()
	if light == null:
		_make_light(creature.data.patrol)
	light.visible = in_sight and creature.light_on
	light.rotation = deg_to_rad(creature.beam)
	_speak(creature, state)


func _draw() -> void:
	if not hull_visible:
		return
	draw_set_transform(Vector2.ZERO, _facing)
	draw_colored_polygon(HULL_POINTS, HULL_FILL)
	draw_colored_polygon(CABIN_POINTS, CABIN_FILL)
	var outline: PackedVector2Array = HULL_POINTS.duplicate()
	outline.append(HULL_POINTS[0])
	draw_polyline(outline, HULL_LINE, 1.0)


func _make_light(patrol: PatrolData) -> void:
	light = PointLight2D.new()
	light.name = "Searchlight"
	var cone: ImageTexture = PatrolCone.texture(patrol.searchlight_cone_deg, patrol.searchlight_range_tiles)
	light.texture = cone
	# The texture's apex is at its left edge: shift it so the apex is on the boat.
	light.offset = Vector2(cone.get_width() / 2.0, 0.0)
	light.color = LIGHT_COLOR
	light.energy = LIGHT_ENERGY
	light.shadow_enabled = false
	light.visible = false
	add_child(light)


# The loudhailer: the first step only learns the serial (a client that joins mid-alert says nothing),
# each change after it speaks the next line.
func _speak(creature: Creature, state: int) -> void:
	var serial: int = creature.alert_serial
	if _serial < 0:
		_serial = serial
		return
	if serial == _serial:
		return
	_serial = serial
	var session: CoopSession = CoopSession.of(creature)
	if session == null:
		return
	var alerting: bool = state == PatrolRoute.State.ALERT_LOCK or state == PatrolRoute.State.ALERT_SEARCH
	var text: String = line_for(creature.data.patrol, CoopSession.locale_of(session), alerting, serial)
	if text.is_empty():
		return
	last_line = text
	lines_shown += 1
	session.show_bubble(creature, text, null, BUBBLE_S)


## The loudhailer line for `serial`: the alert lines while the boat is alerting, else the give-up lines,
## in `locale` ("es", else English), picked by serial mod the line count. "" without any.
static func line_for(patrol: PatrolData, locale: String, alerting: bool, serial: int) -> String:
	var spanish: bool = locale == "es"
	var lines: PackedStringArray
	if alerting:
		lines = patrol.alert_lines_es if spanish else patrol.alert_lines_en
	else:
		lines = patrol.give_up_lines_es if spanish else patrol.give_up_lines_en
	if lines.is_empty():
		return ""
	return lines[posmod(serial, lines.size())]


func _hide() -> void:
	if hull_visible:
		hull_visible = false
		queue_redraw()
	if light != null:
		light.visible = false
