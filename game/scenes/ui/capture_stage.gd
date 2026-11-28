class_name CaptureStage
extends Control
## art-guardacostas D9 and D13 (specs "Capture staging", "Confiscation notice"): La captura staged on
## every peer. When the session's CaptureScene starts, two black bars BAR_PX tall slide in at the top and
## bottom over SLIDE_S, the run HUD hides everything but the scene panel (`RunHud.set_staged`), and this
## peer's camera eases over FRAME_S to frame the patrol boat in sight nearest its held player, or the
## midpoint of that boat and its landing while its squad is ashore; with no boat in sight it stays. When
## the scene ends it all goes back the same way. Then, when the host reports what this peer's own player
## lost (`CaptureScene.confiscation_shown`), the notice row shows "Te quitaron: …" with the items' names
## for NOTICE_S. View only: the camera offset is this peer's own and is never synced, and nothing here
## writes game state.

const BAR_PX: float = 28.0
const BAR_COLOR: Color = Color(0.0, 0.0, 0.0, 1.0)
const SLIDE_S: float = 0.5
const FRAME_S: float = 0.6
const NOTICE_S: float = 5.0
## The view's open middle while staged lies between the top bar and the scene panel (y 28 to about 272),
## 30 px above the view's centre: the framed point is put there.
const FRAME_LIFT_PX: float = 30.0
const VIEW: Vector2 = Vector2(640.0, 360.0)
const ELLIPSIS: String = "…"
## The notice row's width in glyphs: its panel is 400 px wide with 4 px margins.
const NOTICE_GLYPHS: int = 49

var hud: RunHud = null
var session: CoopSession = null
var scene: CaptureScene = null
## True from the scene's start to its end.
var staged: bool = false
## How far the bars are in, 0 to 1.
var bars_in: float = 0.0
## The camera offset aimed at, and where it eased from.
var frame_target: Vector2 = Vector2.ZERO
var _frame_from: Vector2 = Vector2.ZERO
var _frame_t: float = 1.0
var _easing: bool = false
var _camera: Camera2D = null
var _text: HudText = HudText.load_default()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	focus_mode = Control.FOCUS_NONE
	position = Vector2.ZERO
	size = VIEW


func _process(delta: float) -> void:
	tick(delta)


## Stages `run_session`'s capture scene in `run_hud` from now on.
func bind(run_hud: RunHud, run_session: CoopSession) -> void:
	hud = run_hud
	session = run_session
	scene = run_session.capture if run_session != null else null
	if scene == null:
		return
	scene.scene_started.connect(_on_started)
	scene.scene_ended.connect(_on_ended)
	scene.confiscation_shown.connect(_on_confiscated)


## Slides the bars and eases the camera `delta` seconds on.
func tick(delta: float) -> void:
	var goal: float = 1.0 if staged else 0.0
	bars_in = move_toward(bars_in, goal, delta / SLIDE_S)
	if _frame_t < 1.0:
		_frame_t = minf(1.0, _frame_t + delta / FRAME_S)
	# The camera is written only while it eases or the scene is staged; otherwise it is left alone.
	var camera: Camera2D = _local_camera()
	if camera != null and (staged or _easing):
		camera.offset = _frame_from.lerp(frame_target, _ease(_frame_t))
	_easing = _frame_t < 1.0
	queue_redraw()


## The bars' rects in HUD pixels as they are drawn now.
func bar_rects() -> Array[Rect2]:
	var height: float = roundf(BAR_PX * bars_in)
	return [Rect2(0.0, 0.0, VIEW.x, height), Rect2(0.0, VIEW.y - height, VIEW.x, height)] as Array[Rect2]


## The camera offset that frames the boat for `body` (Vector2.ZERO with no boat in sight): the patrol
## boat in a sight state nearest the body, or the midpoint of it and its landing while its squad is out,
## put FRAME_LIFT_PX above the view's centre, in the open space between the top bar and the panel.
static func framing_offset(run_session: CoopSession, body: PlayerBody) -> Vector2:
	if run_session == null or body == null or run_session.entities == null:
		return Vector2.ZERO
	var best: Creature = null
	for node: Node in run_session.entities.get_children():
		var boat := node as Creature
		if boat == null or boat.is_queued_for_deletion() or not boat.is_patrol():
			continue
		if not PatrolRoute.is_in_sight_state(boat.state_id):
			continue
		if best == null or boat.position.distance_to(body.global_position) < best.position.distance_to(body.global_position):
			best = boat
	if best == null:
		return Vector2.ZERO
	var target: Vector2 = best.global_position
	if best.squad_state != PatrolRoute.Squad.NONE and best.landing.x >= 0:
		target = (target + IslandLayout.cell_center(best.landing)) / 2.0
	return (target + Vector2(0.0, FRAME_LIFT_PX) - body.global_position).round()


## "Te quitaron: " and the items' names in `locale`, joined with ", ", cut with "…" at the notice row.
static func confiscation_text(ids: PackedStringArray, locale: String, text: HudText) -> String:
	var names := PackedStringArray()
	for id: String in ids:
		names.append(HudText.item_name(StringName(id), locale))
	var line: String = text.line(&"confiscated", locale) % ", ".join(names)
	if line.length() > NOTICE_GLYPHS:
		line = line.left(NOTICE_GLYPHS - 1) + ELLIPSIS
	return line


func _on_started() -> void:
	staged = true
	if hud != null:
		hud.set_staged(true)
	var body: PlayerBody = _local_body()
	_ease_to(framing_offset(session, body))


func _on_ended() -> void:
	staged = false
	if hud != null:
		hud.set_staged(false)
	_ease_to(Vector2.ZERO)


func _on_confiscated(ids: PackedStringArray) -> void:
	if ids.is_empty() or hud == null or hud.notice == null:
		return
	hud.notice.show_line(confiscation_text(ids, CoopSession.locale_of(session), _text), NOTICE_S)


func _ease_to(offset: Vector2) -> void:
	var camera: Camera2D = _local_camera()
	_frame_from = camera.offset if camera != null else Vector2.ZERO
	frame_target = offset
	_frame_t = 0.0
	_easing = true


func _local_body() -> PlayerBody:
	if session == null or hud == null:
		return null
	return session.body(hud.local_peer)


func _local_camera() -> Camera2D:
	var body: PlayerBody = _local_body()
	if body == null or not is_instance_valid(body):
		return null
	return body.camera


static func _ease(t: float) -> float:
	return t * t * (3.0 - 2.0 * t)


func _draw() -> void:
	if bars_in <= 0.0:
		return
	for rect: Rect2 in bar_rects():
		draw_rect(rect, BAR_COLOR)
