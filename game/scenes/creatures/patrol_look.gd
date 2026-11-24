class_name PatrolLook
extends Node2D
## A patrol boat's look (guardacostas-stealth decision 11): the `PatrolLook` child of creature.tscn, in
## `art_view`, used on every peer, the host's too. For a boat in sight (its lap or an alert) it draws the
## launch (art-guardacostas D3): GuardacostasArt's hull on `hull`, side-on and mirrored when heading
## west, `move` while its drawn position moves and `idle` otherwise, drawn so its roof lamp covers the
## boat's position; and, while the boat's light is on, the searchlight
## as a PointLight2D with the generated cone texture (PatrolCone) rotated to the beam: under the night
## CanvasModulate a light brightens the sand it covers, which reads as a searchlight. It also speaks the
## loudhailer: when the boat's `alert_serial` changes, a call window over the boat (art-guardacostas D6,
## the session's `show_call`) shows a line of its PatrolData in the session's language: `alert_lines_<locale>` when the boat is
## alerting after the change (PatrolRoute.is_alert_state: a lock, a search, a chase or a docked boat), else `give_up_lines_<locale>`, picked by
## `alert_serial` mod the line count so every peer shows the same line. It reads the creature's synced
## position, facing, state, clock, beam, light and serial and never writes any of them. A creature that
## is not a patrol boat draws nothing. CreatureRig processes no frames, so tests drive `step` themselves.

const LIGHT_COLOR: Color = Color(1.0, 0.93, 0.72)
const LIGHT_ENERGY: float = 1.2
const MOVE: StringName = &"move"
const IDLE: StringName = &"idle"
## How far the drawn boat moves in a frame before it shows `move`.
const MOVING_PX: float = 0.01

## True while the hull is drawn (the boat is in its lap or an alert).
var hull_visible: bool = false
## The launch's sprite, or null before the first step of a patrol boat.
var hull: AnimatedSprite2D = null
## True while the hull shows mirrored (heading west).
var mirrored: bool = false
## The searchlight, or null before the first step of a patrol boat.
var light: PointLight2D = null
## The loudhailer line shown last, and how many have been shown.
var last_line: String = ""
var lines_shown: int = 0

var _serial: int = -1
var _last_position: Vector2 = Vector2.INF
var _art: GuardacostasArt = GuardacostasArt.standard()


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
	var in_sight: bool = PatrolRoute.is_in_sight_state(state)
	hull_visible = in_sight
	if hull == null:
		_make_hull()
	_draw_hull(creature)
	if light == null:
		_make_light(creature.data.patrol)
	light.visible = in_sight and creature.light_on
	light.rotation = deg_to_rad(creature.beam)
	_speak(creature, state)


## The top of the drawn launch over the boat's position, where a call window's tail points
## (art-guardacostas D6).
static func top_y() -> float:
	var art: GuardacostasArt = GuardacostasArt.standard()
	return art.hull_top_y() if art != null else -16.0


func _make_hull() -> void:
	hull = AnimatedSprite2D.new()
	hull.name = &"Hull"
	hull.centered = false
	hull.sprite_frames = _art.hull_frames if _art != null else null
	hull.visible = false
	# Under the searchlight's own child, which lights the sand and not the hull.
	add_child(hull)
	move_child(hull, 0)


# The launch side-on, mirrored by its heading, moving or idle, its lamp on the boat's position.
func _draw_hull(creature: Creature) -> void:
	hull.visible = hull_visible
	if absf(creature.facing.x) > 0.01:
		mirrored = creature.facing.x < 0.0
	var moved: bool = _last_position != Vector2.INF and creature.position.distance_to(_last_position) > MOVING_PX
	_last_position = creature.position
	if not hull_visible or hull.sprite_frames == null:
		return
	hull.flip_h = mirrored
	hull.offset = _art.hull_offset(mirrored)
	var animation: StringName = MOVE if moved else IDLE
	if hull.sprite_frames.has_animation(animation) and (not hull.is_playing() or hull.animation != animation):
		hull.play(animation)


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
	var alerting: bool = PatrolRoute.is_alert_state(state)
	var text: String = line_for(creature.data.patrol, CoopSession.locale_of(session), alerting, serial)
	if text.is_empty():
		return
	last_line = text
	lines_shown += 1
	session.show_call(creature, text)


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
	hull_visible = false
	if hull != null:
		hull.visible = false
	if light != null:
		light.visible = false
