class_name SquadLook
extends Node2D
## guardacostas-capture design.md §14 (spec "Capture cues"): the shore squad's look, the `SquadLook`
## child of creature.tscn in `art_view`, used on every peer. It reads the creature's synced state and
## never writes it, so drawing never changes the simulation.
## - A shore soldier (SEARCH_CAPTURE) is a person of the people pack in an olive uniform and a patrol
##   cap (art-guardacostas D2): its look, one of GuardacostasArt's `soldier_looks` dealt by the number in
##   its node name, is composed like a player's (LookComposer) on `soldier_sprite`, its feet on the
##   creature's position over a drop shadow, walking or standing (PlayerPose) and facing its drawn motion
##   (Facing) as a player does. At night a flashlight's glint shows on the side it faces.
## - A patrol boat whose squad is out draws its dinghy (art-guardacostas D3): a DinghyLook child of the
##   boat's creature node at `dinghy_px`, on the line from the boat to the landing, `dinghy_t` of the way
##   (synced at the creatures' 10 Hz), rowing on the way and beached on the landing with the squad ashore.
## - A patrol boat speaks its squad's calls: when its `squad_serial` changes, a call window
##   (art-guardacostas D6, the session's `show_call`) shows over one of its soldiers a line of
##   `squad_<call>_lines_<locale>` (formal Spanish in Spanish), picked by `squad_serial` mod the line
##   count so every peer shows the same line. A landing or leaving call shows over the soldier nearest
##   the landing, a spot call over a soldier giving chase.
## CreatureRig processes no frames, so tests drive `step` themselves.

## How long a call waits for a soldier to show over (a client's soldiers can arrive after the call).
const PENDING_S: float = 2.0
const GLINT: Color = Color(0.98431373, 0.94901961, 0.21176471)
const SHADOW_SCENE: PackedScene = preload("res://scenes/art/shadow.tscn")
## The glint's height over the feet, and how far to the facing side.
const GLINT_Y: float = -12.0
const GLINT_SIDE_PX: float = 6.0

## True while the dinghy is drawn, and where (session pixels).
var dinghy_visible: bool = false
var dinghy_px: Vector2 = Vector2.ZERO
## The squad call shown last, and how many have been shown.
var last_call: String = ""
var calls_shown: int = 0
## The soldier the last call showed over.
var last_caller: Node2D = null

## A soldier's figure, its look and how it faces (null on a boat).
var soldier_sprite: AnimatedSprite2D = null
var soldier_look: PlayerLookData = null
var facing: Facing = Facing.new()
var pose: PlayerPose.Pose = PlayerPose.Pose.STANDING
## A boat's dinghy (null until its squad is first out).
var dinghy: DinghyLook = null

var _serial: int = -1
var _soldier: bool = false
var _pending_s: float = 0.0
var _art: GuardacostasArt = GuardacostasArt.standard()
var _glint_side: float = 0.0


func _ready() -> void:
	process_priority = 1


func _process(delta: float) -> void:
	step(delta)


## Draws the soldier or the dinghy as they are now, and speaks a new squad call.
func step(delta: float) -> void:
	var creature := get_parent() as Creature
	if creature == null or creature.data == null:
		return
	_soldier = creature.data.behavior == CreatureData.Behavior.SEARCH_CAPTURE
	if _soldier:
		_draw_soldier(creature, delta)
	if creature.is_patrol():
		var out: bool = creature.squad_state != PatrolRoute.Squad.NONE and creature.landing.x >= 0
		dinghy_visible = out
		if out:
			var landing: Vector2 = IslandLayout.cell_center(creature.landing)
			dinghy_px = creature.global_position.lerp(landing, clampf(creature.dinghy_t, 0.0, 1.0))
		_draw_dinghy(creature, out)
		_speak(creature)
	queue_redraw()


## The top of a drawn soldier over its feet, where a call window's tail points (art-guardacostas D6): the
## walking head anchor of the first soldier look.
static func soldier_top_y() -> float:
	var art: GuardacostasArt = GuardacostasArt.standard()
	if art == null or art.soldier_looks.is_empty():
		return PlayerPose.OFFSET.y
	return float(LookComposer.compose(art.soldier_looks[0]).head_anchor(&"walk"))


func _draw() -> void:
	if _soldier and _glint_side != 0.0:
		draw_rect(Rect2(_glint_side * GLINT_SIDE_PX - (1.0 if _glint_side < 0.0 else 0.0), GLINT_Y, 1.0, 1.0), GLINT)


# The soldier's figure: its look on first use, then the pose and facing of its drawn motion now.
func _draw_soldier(creature: Creature, delta: float) -> void:
	if soldier_sprite == null:
		_make_soldier(creature)
	facing.observe(creature.global_position, delta)
	pose = PlayerPose.Pose.WALK if facing.moving() else PlayerPose.Pose.STANDING
	var animation: StringName = PlayerPose.animation(pose, facing.dir)
	if soldier_sprite.sprite_frames != null and soldier_sprite.sprite_frames.has_animation(animation):
		soldier_sprite.offset = PlayerPose.sprite_offset(pose)
		soldier_sprite.flip_h = PlayerPose.flip_h(pose, facing.dir, facing.last_side)
		var fps: float = PlayerPose.fps(pose, facing.moving())
		if fps <= 0.0:
			if soldier_sprite.is_playing() or soldier_sprite.animation != animation:
				soldier_sprite.stop()
				soldier_sprite.animation = animation
			soldier_sprite.frame = PlayerPose.still_frame(pose)
		else:
			soldier_sprite.speed_scale = fps / maxf(soldier_sprite.sprite_frames.get_animation_speed(animation), 0.001)
			if not soldier_sprite.is_playing() or soldier_sprite.animation != animation:
				soldier_sprite.play(animation)
	_glint_side = 0.0
	if WeatherManager.phase() == DataEnums.DayPhase.NIGHT:
		match facing.dir:
			Facing.Dir.LEFT:
				_glint_side = -1.0
			Facing.Dir.RIGHT:
				_glint_side = 1.0
			_:
				_glint_side = -1.0 if facing.last_side == Facing.Dir.LEFT else 1.0


func _make_soldier(creature: Creature) -> void:
	var shadow := SHADOW_SCENE.instantiate() as DropShadow
	shadow.name = &"Shadow"
	add_child(shadow)
	soldier_sprite = AnimatedSprite2D.new()
	soldier_sprite.name = &"Soldier"
	soldier_sprite.centered = false
	soldier_sprite.offset = PlayerPose.OFFSET
	# The glint (this node's own drawing) shows over the figure.
	soldier_sprite.show_behind_parent = true
	soldier_look = _art.soldier_look(String(creature.name)) if _art != null else null
	if soldier_look != null:
		soldier_sprite.sprite_frames = LookComposer.compose(soldier_look).frames
	add_child(soldier_sprite)


# The dinghy as a child of the boat's creature node, so it sorts by its own place on the beach.
func _draw_dinghy(creature: Creature, out: bool) -> void:
	if not out:
		if dinghy != null:
			dinghy.hide_dinghy()
		return
	if dinghy == null:
		dinghy = DinghyLook.new()
		dinghy.name = DinghyLook.NODE_NAME
		dinghy.add_to_group(&"art_view")
		creature.add_child(dinghy)
	var beached: bool = creature.dinghy_t >= 1.0 and creature.squad_state == PatrolRoute.Squad.ASHORE
	dinghy.show_at(dinghy_px, beached)


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

