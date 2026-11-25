class_name SquadLook
extends Node2D
## guardacostas-capture design.md §14 (spec "Capture cues"): the shore squad's look, the `SquadLook`
## child of creature.tscn in `art_view`, used on every peer. It reads the creature's synced state and
## never writes it, so drawing never changes the simulation.
## - A shore soldier (SEARCH_CAPTURE) is a placeholder body until the art pass: an olive uniform with a
##   dark outline, a cap and a flashlight's glint on the side it faces.
## - A patrol boat whose squad is out draws its dinghy: a small placeholder hull on the line from the
##   boat to the landing, `dinghy_t` of the way (synced at the creatures' 10 Hz).
## - A patrol boat speaks its squad's calls: when its `squad_serial` changes, a call window (art-guardacostas
##   D6, the session's `show_call`) shows over one of its soldiers a line of `squad_<call>_lines_<locale>` (formal Spanish in
##   Spanish), picked by `squad_serial` mod the line count so every peer shows the same line. A landing
##   or leaving call shows over the soldier nearest the landing, a spot call over a soldier giving chase.
## CreatureRig processes no frames, so tests drive `step` themselves.

## The top of a drawn soldier over its origin, where a call window's tail points (art-guardacostas D6).
const SOLDIER_TOP_Y: float = -13.0
## How long a call waits for a soldier to show over (a client's soldiers can arrive after the call).
const PENDING_S: float = 2.0
const UNIFORM: Color = Color(0.36, 0.42, 0.24)
const CAP: Color = Color(0.25, 0.3, 0.17)
const SKIN: Color = Color(0.72, 0.53, 0.38)
const OUTLINE: Color = Color(0.1, 0.12, 0.18)
const GLINT: Color = Color(1.0, 0.93, 0.72)
const DINGHY_FILL: Color = Color(0.55, 0.42, 0.28)
## The dinghy's outline in pixels: a 9 by 5 rowing boat.
const DINGHY_POINTS: PackedVector2Array = [
	Vector2(5.0, 0.0), Vector2(3.0, -2.5), Vector2(-4.0, -2.5), Vector2(-4.0, 2.5), Vector2(3.0, 2.5),
]

## True while the dinghy is drawn, and where (session pixels).
var dinghy_visible: bool = false
var dinghy_px: Vector2 = Vector2.ZERO
## The squad call shown last, and how many have been shown.
var last_call: String = ""
var calls_shown: int = 0
## The soldier the last call showed over.
var last_caller: Node2D = null

var _serial: int = -1
var _soldier: bool = false
var _pending_s: float = 0.0


func _ready() -> void:
	process_priority = 1


func _process(delta: float) -> void:
	step(delta)


## Draws the soldier or the dinghy as they are now, and speaks a new squad call.
func step(_delta: float) -> void:
	var creature := get_parent() as Creature
	if creature == null or creature.data == null:
		return
	_soldier = creature.data.behavior == CreatureData.Behavior.SEARCH_CAPTURE
	if creature.is_patrol():
		var out: bool = creature.squad_state != PatrolRoute.Squad.NONE and creature.landing.x >= 0
		dinghy_visible = out
		if out:
			var landing: Vector2 = IslandLayout.cell_center(creature.landing)
			dinghy_px = creature.global_position.lerp(landing, clampf(creature.dinghy_t, 0.0, 1.0))
		_speak(creature)
	queue_redraw()


func _draw() -> void:
	var creature := get_parent() as Creature
	if creature == null:
		return
	if _soldier:
		_draw_soldier(creature.facing)
	elif dinghy_visible:
		var at: Vector2 = dinghy_px - creature.global_position
		draw_colored_polygon(_shifted(DINGHY_POINTS, at), DINGHY_FILL)
		draw_polyline(_closed(_shifted(DINGHY_POINTS, at)), OUTLINE, 1.0)


# A 7 by 13 figure standing on the creature's origin (its feet), facing left or right.
func _draw_soldier(facing: Vector2) -> void:
	draw_rect(Rect2(-4.0, -14.0, 9.0, 15.0), OUTLINE)
	draw_rect(Rect2(-3.0, -9.0, 7.0, 9.0), UNIFORM)
	draw_rect(Rect2(-3.0, -12.0, 7.0, 3.0), SKIN)
	draw_rect(Rect2(-3.0, -13.0, 7.0, 2.0), CAP)
	var side: float = 4.0 if facing.x >= 0.0 else -4.0
	draw_rect(Rect2(side, -6.0, 1.0, 1.0), GLINT)


# A new squad call: a call window over one of this boat's soldiers. On a client the call can arrive
# a frame before the soldiers do, so a call with nobody to show over waits for one, up to PENDING_S.
func _speak(creature: Creature) -> void:
	var serial: int = creature.squad_serial
	if _serial < 0:
		_serial = serial
		return
	if serial != _serial:
		_serial = serial
		_pending_s = PENDING_S
	if _pending_s <= 0.0:
		return
	_pending_s -= get_process_delta_time()
	var session := CoopSession.of(creature)
	var lines := _lines(creature.data.patrol, creature.squad_call, CoopSession.locale_of(session))
	var caller := _caller(creature, session)
	if lines.is_empty() or caller == null or session == null:
		return
	_pending_s = 0.0
	last_call = lines[serial % lines.size()]
	last_caller = caller
	calls_shown += 1
	session.show_call(caller, last_call)


static func _lines(patrol: PatrolData, call: int, locale: String) -> PackedStringArray:
	var english: bool = locale == "en"
	match call:
		PatrolRoute.Call.SPOT:
			return patrol.squad_spot_lines_en if english else patrol.squad_spot_lines_es
		PatrolRoute.Call.LEAVE:
			return patrol.squad_leave_lines_en if english else patrol.squad_leave_lines_es
	return patrol.squad_land_lines_en if english else patrol.squad_land_lines_es


# The soldier the call shows over: one giving chase for a spot call, else the one nearest the landing.
func _caller(creature: Creature, session: CoopSession) -> Node2D:
	if session == null or not is_inside_tree():
		return null
	var landing: Vector2 = IslandLayout.cell_center(creature.landing)
	var best: Node2D = null
	for node: Node in get_tree().get_nodes_in_group(FreeHandle.SOLDIER_GROUP):
		var soldier := node as Creature
		if soldier == null or soldier.is_queued_for_deletion() or CoopSession.of(soldier) != session:
			continue
		if creature.squad_call == PatrolRoute.Call.SPOT and soldier.state_id == SearchCapture.State.CHASE:
			return soldier
		if best == null or soldier.global_position.distance_to(landing) < best.global_position.distance_to(landing):
			best = soldier
	return best


static func _shifted(points: PackedVector2Array, by: Vector2) -> PackedVector2Array:
	var moved := PackedVector2Array()
	for point: Vector2 in points:
		moved.append(point + by)
	return moved


static func _closed(points: PackedVector2Array) -> PackedVector2Array:
	var closed := points.duplicate()
	closed.append(points[0])
	return closed
