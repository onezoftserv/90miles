class_name PatrolView
extends RefCounted
## guardacostas-stealth decision 10: what a peer needs to draw a patrol boat from the host's synced
## state. It holds the boat's island loop and light, built from the host's own world on the host and
## from the session's terrain on a client (the same terrain every peer built from the layout), so the
## loop is the same on every peer. A client calls `step_client` each physics frame: in HORIZON, LAP
## and AWAY the boat's clock runs on locally between syncs (the host's value snaps it back at each
## sync) and the pose and beam come from PatrolLoop and Searchlight; in the alert states the synced
## position and beam stand. Never runs a trigger, a spot or an alert, and never emits.

var loop: PatrolLoop = null
var light: Searchlight = null
var patrol: PatrolData = null
var period_s: float = 0.0
## True once the loop is built and valid.
var valid: bool = false

var _tried: bool = false


## The view of `creature` (a patrol boat), built now. `valid` is false while its island has no loop
## or no terrain is known yet; `refresh` tries again until a terrain is there.
static func of(creature: Creature) -> PatrolView:
	var view := PatrolView.new()
	view.patrol = creature.data.patrol if creature.data != null else null
	view.refresh(creature)
	return view


## Builds the loop if it is not built yet and a terrain is known. Cheap once tried with a terrain.
func refresh(creature: Creature) -> void:
	if valid or _tried or patrol == null or patrol.route_period_s <= 0.0:
		return
	var built: PatrolLoop = null
	if creature.world != null:
		_tried = true
		built = creature.world.patrol_loop(patrol)
	else:
		var session: CoopSession = CoopSession.of(creature)
		if session == null or not session.terrain is GridTerrain:
			return
		_tried = true
		var terrain := session.terrain as GridTerrain
		built = PatrolLoop.build(terrain, extent_of(terrain), patrol.route_lap_s, patrol.route_offshore_tiles)
	if built == null or not built.valid:
		return
	loop = built
	light = Searchlight.from_patrol(patrol)
	period_s = PatrolLoop.period_s(patrol, PatrolLoop.experiencia_level())
	valid = true


## The grid's size in cells: one past the largest cell it holds.
static func extent_of(terrain: GridTerrain) -> Vector2i:
	var size := Vector2i.ZERO
	for cell: Vector2i in terrain.cells:
		size.x = maxi(size.x, cell.x + 1)
		size.y = maxi(size.y, cell.y + 1)
	return size


## Where the lap starts, in pixels: the point the boat comes from, Vector2.ZERO without a loop.
func start_px() -> Vector2:
	return loop.pose_px(0.0) if valid else Vector2.ZERO


## Client: advances `creature`'s drawn state by `delta` from its synced clock and state. In the alert
## states nothing is derived: the synced position and beam stand.
func step_client(creature: Creature, delta: float) -> void:
	refresh(creature)
	if not valid:
		return
	var state: int = creature.state_id
	if state == PatrolRoute.State.ALERT_LOCK or state == PatrolRoute.State.ALERT_SEARCH:
		return
	creature.route_t = fposmod(creature.route_t + delta, period_s)
	if state == PatrolRoute.State.LAP:
		var lap_t: float = clampf(PatrolLoop.lap_time(creature.route_t, patrol.horizon_warning_s), 0.0, loop.lap_s)
		creature.position = loop.pose_px(lap_t)
		creature.beam = light.beam_deg(loop.pose_at(lap_t), loop.centroid, lap_t)
	else:
		creature.position = loop.pose_px(0.0)
