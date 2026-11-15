class_name CompassNeedle
extends Control
## The broken compass's needle (secret-cay "Needle on the carrier's HUD", "Needle target", "Needle
## bands"; design.md decision 5): a 24x24 dial top-centre under the day phase, on the HUD of the
## local player only, shown while that player carries an item that points to secrets. It points
## from the carrier to the nearest concealed item lying in the session, else the island's unopened
## chest, else spins. It ignores north: it is never a compass. Its swing narrows band by band with
## the straight-line distance in tiles (the same metric as the reveal radius): it spins beyond the
## first edge, wobbles inside it, and holds still inside the last. It rattles once on entering the
## first edge and re-arms beyond it. Drawing only: it reads the session and writes nothing back.

## The carrier came within the first band edge of the target (a cue for AudioManager when its
## sound exists).
signal rattled

const SIZE: Vector2 = Vector2(24.0, 24.0)
const TILE_PX: float = 16.0
const CHEST_NAME: StringName = &"Chest"
## Placeholder dial until the needle's art: a dark face in a brass ring, a red point, a pale tail.
const FACE: Color = Color("#222034")
const RING: Color = Color("#d9a066")
const POINT: Color = Color("#d95763")
const TAIL: Color = Color("#cbdbfc")
const NEEDLE_PX: float = 9.0

var tuning: SecretTuning = SecretTuning.standard()
## The local player, or null.
var body: PlayerBody = null
var session: CoopSession = null
## What it points at now (a concealed WorldItem or the chest), or null while it spins.
var target: Node2D = null
## The bearing from the carrier to the target, radians (0 east, clockwise on screen).
var bearing_rad: float = 0.0
## Where the needle points now.
var angle_rad: float = 0.0
## True while it spins (no target, or the target beyond the first edge).
var spinning: bool = true
## The wobble's half-width now, degrees (0 while it holds still or spins).
var wobble_deg: float = 0.0

var _clock_s: float = 0.0
var _armed: bool = true


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_to_group(RunHud.AVOID_GROUP)
	custom_minimum_size = SIZE
	size = SIZE
	visible = false


## Follows `player` of `run_session` from now on.
func bind(player: PlayerBody, run_session: CoopSession) -> void:
	body = player
	session = run_session
	_armed = true


func _process(delta: float) -> void:
	step(delta)


## Advances the needle by `delta` seconds.
func step(delta: float) -> void:
	_clock_s += delta
	var shown: bool = _carried()
	if visible != shown:
		visible = shown
	if not shown:
		_armed = true
		return
	target = _target()
	var tiles: float = INF
	if target != null:
		var offset: Vector2 = target.global_position - body.global_position
		tiles = offset.length() / TILE_PX
		bearing_rad = offset.angle()
	var edges: Array[float] = tuning.band_edges_tiles
	var outer: float = edges[0] if not edges.is_empty() else INF
	if tiles <= outer:
		if _armed:
			_armed = false
			rattled.emit()
	else:
		_armed = true
	spinning = tiles > outer
	if spinning:
		wobble_deg = 0.0
		angle_rad = wrapf(angle_rad + tuning.spin_turns_per_s * TAU * delta, -PI, PI)
	else:
		wobble_deg = _wobble_for(tiles, edges)
		angle_rad = bearing_rad + deg_to_rad(wobble_deg) * sin(_clock_s * tuning.wobble_rad_per_s)
	queue_redraw()


func _draw() -> void:
	var centre: Vector2 = SIZE / 2.0
	draw_circle(centre, SIZE.x / 2.0, RING)
	draw_circle(centre, SIZE.x / 2.0 - 2.0, FACE)
	var tip: Vector2 = Vector2.from_angle(angle_rad) * NEEDLE_PX
	draw_line(centre, centre + tip, POINT, 2.0)
	draw_line(centre, centre - tip * 0.6, TAIL, 2.0)


# The half-width of the band `tiles` falls in: the wobble of the innermost edge it is within, 0
# inside the last edge.
func _wobble_for(tiles: float, edges: Array[float]) -> float:
	var wobble: float = 0.0
	for i: int in edges.size():
		if tiles > edges[i]:
			break
		wobble = tuning.band_wobble_deg[i] if i < tuning.band_wobble_deg.size() else 0.0
	return wobble


func _carried() -> bool:
	if not is_instance_valid(body) or body.left_island or session == null:
		return false
	return body.inventory.capability_slot(DataEnums.Capability.POINT_TO_SECRET) >= 0


# The nearest concealed item lying in the session, else the unopened chest, else null.
func _target() -> Node2D:
	var best: Node2D = null
	var best_px: float = INF
	for node: Node in session.pickups.get_children():
		var item := node as WorldItem
		if item == null or item.is_queued_for_deletion() or not item.concealed:
			continue
		var px: float = item.global_position.distance_to(body.global_position)
		if px < best_px:
			best_px = px
			best = item
	if best != null:
		return best
	var chest := session.get_node_or_null(NodePath(CHEST_NAME)) as Node2D
	if chest != null and not bool(chest.get(&"opened")):
		return chest
	return null
