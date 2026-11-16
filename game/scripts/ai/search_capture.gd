class_name SearchCapture
extends CreatureBrain
## guardacostas-capture design.md §5–§7: the shore soldier's machine (SEARCH_CAPTURE). A soldier does
## not fight. It sees in a cone ahead of it (SightCone, by day and by night), and its sight fills the
## same spot meter as the boats' lights (PatrolWatch steps every meter once). Host only. States are
## append-only: `state` is synced.
## - SEARCH: it takes the next point of its squad's plan (a fire, then the last known position) and
##   walks there at its own speed; with no point left it WALKs between random land cells.
## - POINT_SEARCH: it stands on the point for `point_search_s`, then finds any hidden player within
##   `point_search_tiles` (spotted at once: it runs at them).
## - CHASE: a spot sends it running at the player at `soldier_chase_tiles_s` while they stay unhidden
##   within its sight length. Touching them within `capture_touch_tiles` for `capture_touch_s` captures
##   them; the count resets when contact breaks. When the chase breaks, where it last saw them becomes
##   the last known position, which it searches itself. A player found by a point search is exposed:
##   hiding does not break that chase while they stay within `point_search_tiles` of where they were
##   found (a player spotted by sight who then hides still shakes the soldier: design.md §5 rejects the
##   Bush Hat rule).
## - ESCORT: it leads its captive to the dinghy at drag speed (the captive follows it as a dragged
##   body does), seats them there and goes back to its plan.
## - RETURN: the squad leaves; it walks back to the dinghy and waits there.
## Downed, dropped and captive bodies are never its targets. Without a squad (a test's lone soldier)
## it chases and searches where it lost a player, and nothing more.

enum State {
	SEARCH,
	POINT_SEARCH,
	WALK,
	CHASE,
	ESCORT,
	RETURN,
}

const EPSILON: float = 0.000001
const NO_CELL: Vector2i = Vector2i(-1, -1)
## Within this many tiles of its goal cell's centre a soldier has arrived.
const ARRIVE_TILES: float = 0.5
const NO_FIND: Vector2 = Vector2(-INF, -INF)

## The patrol whose numbers the soldier uses (its boat's): sight, speeds, search, touch.
var patrol: PatrolData = null
## Its boat's brain, which owns the squad's plan, the dinghy and the captives; null for a lone soldier.
var squad: PatrolRoute = null
## Its number in the squad (the plan's soldier index).
var index: int = 0
## The player it chases in CHASE, else null.
var target: PlayerBody = null
## The captive it leads in ESCORT, else null.
var escorting: PlayerBody = null
## Where it last saw the player it lost (a cell), NO_CELL before it lost anyone.
var lost_at: Vector2i = NO_CELL
## Seconds of unbroken touch on its target.
var touch_s: float = 0.0

var _last_seen_px: Vector2 = Vector2.ZERO
var _goal: Vector2i = NO_CELL
## Where the chased player was found by a point search (pixels); NO_FIND for a chase by sight.
var _found_px: Vector2 = NO_FIND
var _point_s: float = 0.0


func names() -> Array[StringName]:
	return [&"SEARCH", &"POINT_SEARCH", &"WALK", &"CHASE", &"ESCORT", &"RETURN"]


## The soldier's cone in `world`'s phase.
func cone(world: CreatureWorld) -> SightCone:
	return SightCone.for_soldier(patrol, world.phase)


## Whether `creature` (this soldier) sees `point_px` now: inside its cone along its facing. Hidden
## states are the meter's to apply, and the weather the watch's.
func sees(creature: Creature, point_px: Vector2) -> bool:
	if patrol == null or creature.world == null:
		return false
	return cone(creature.world).sees(point_px / CreatureNav.TILE, creature.position / CreatureNav.TILE, creature.facing)


## The meter spotted `body` in this soldier's sight: it runs at them, unless it is busy or they are
## not a target.
func spot(creature: Creature, body: PlayerBody) -> void:
	if not can_target(body) or state == State.ESCORT or state == State.RETURN or state == State.CHASE:
		return
	_chase(creature, body)
	if squad != null:
		squad.soldier_spotted(creature)


## A soldier's target: alive, standing (not downed, in a last stand or dead), connected, on the island
## and not a captive.
static func can_target(body: PlayerBody) -> bool:
	if not is_instance_valid(body) or body.left_island or body.captive or CreatureWorld.is_dropped(body):
		return false
	return body.meters == null or not (body.meters.downed or body.meters.last_stand or body.meters.dead)


## True while it is free to search: not chasing, escorting or going back to the dinghy.
func is_free() -> bool:
	return state == State.SEARCH or state == State.POINT_SEARCH or state == State.WALK


func tick(creature: Creature, world: CreatureWorld, delta: float) -> void:
	if patrol == null:
		return
	if squad != null and squad.squad_leaving() and state != State.RETURN:
		_return(creature)
	match state:
		State.CHASE:
			_tick_chase(creature, world, delta)
		State.ESCORT:
			_tick_escort(creature, world, delta)
		State.RETURN:
			_walk_to(creature, world, squad.landing_cell() if squad != null else CreatureNav.cell_of(creature.position), creature.data.speed_tiles_s, delta)
		State.POINT_SEARCH:
			_tick_point(creature, world, delta)
		_:
			_tick_search(creature, world, delta)


# --- searching ----------------------------------------------------------------------------------

func _tick_search(creature: Creature, world: CreatureWorld, delta: float) -> void:
	var plan: SquadPlan = squad.plan if squad != null else null
	var point: SquadPlan.Point = plan.take_point(index) if plan != null else null
	if point != null:
		enter(State.SEARCH)
		_goal = point.cell
	elif lost_at != NO_CELL and plan == null:
		enter(State.SEARCH)
		_goal = lost_at
	else:
		if state != State.WALK or _goal == NO_CELL:
			_goal = plan.next_walk_cell() if plan != null else CreatureNav.cell_of(creature.position)
			forget_path()
		enter(State.WALK)
	if _walk_to(creature, world, _goal, creature.data.speed_tiles_s, delta):
		if state == State.WALK:
			_goal = plan.next_walk_cell() if plan != null else _goal
			forget_path()
		else:
			_point_s = 0.0
			enter(State.POINT_SEARCH)


func _tick_point(creature: Creature, world: CreatureWorld, delta: float) -> void:
	_point_s += delta
	if _point_s < patrol.point_search_s - EPSILON:
		return
	var found: PlayerBody = _hidden_near(world, _goal)
	var plan: SquadPlan = squad.plan if squad != null else null
	if plan != null:
		plan.searched(index)
	if _goal == lost_at:
		lost_at = NO_CELL
	_goal = NO_CELL
	enter(State.SEARCH)
	if found != null:
		_chase(creature, found)
		_found_px = found.global_position
		if squad != null:
			squad.soldier_spotted(creature)


# The first hidden target within the point search's reach of `cell` (in peer order of the world).
func _hidden_near(world: CreatureWorld, cell: Vector2i) -> PlayerBody:
	var centre: Vector2 = SquadPlan.center(cell)
	for body: PlayerBody in world.players():
		if not can_target(body) or body.stealth_state == MovementStep.Stealth.VISIBLE:
			continue
		if centre.distance_to(body.global_position / CreatureNav.TILE) <= patrol.point_search_tiles + EPSILON:
			return body
	return null


# --- chasing and capturing ------------------------------------------------------------------------

func _chase(creature: Creature, body: PlayerBody) -> void:
	if squad != null and squad.plan != null:
		squad.plan.drop_point(index)
	target = body
	touch_s = 0.0
	_last_seen_px = body.global_position
	_found_px = NO_FIND
	forget_path()
	enter(State.CHASE)
	creature.state_id = state


## True while the chased player was found by a point search and is still within its reach of where
## they were found: their hiding no longer hides them from this soldier.
func is_exposed() -> bool:
	if not is_instance_valid(target) or _found_px == NO_FIND or patrol == null:
		return false
	return target.global_position.distance_to(_found_px) <= patrol.point_search_tiles * CreatureNav.TILE + EPSILON


func _tick_chase(creature: Creature, world: CreatureWorld, delta: float) -> void:
	var hidden: bool = is_instance_valid(target) and target.stealth_state != MovementStep.Stealth.VISIBLE and not is_exposed()
	var holds: bool = can_target(target) and cone(world).chase_holds(target.global_position / CreatureNav.TILE,
		creature.position / CreatureNav.TILE, hidden, world.weather().disabled_senses)
	if not holds:
		_lose(creature, world)
		return
	_last_seen_px = target.global_position
	var gap: float = creature.position.distance_to(target.global_position)
	if gap > patrol.capture_touch_tiles * CreatureNav.TILE * 0.5:
		follow_path(creature, world, world.nav.land, target.global_position, patrol.soldier_chase_tiles_s, delta)
	var to: Vector2 = target.global_position - creature.position
	if to.length() > EPSILON:
		creature.facing = to.normalized()
	if creature.position.distance_to(target.global_position) <= patrol.capture_touch_tiles * CreatureNav.TILE + EPSILON:
		touch_s += delta
		if touch_s >= patrol.capture_touch_s - EPSILON:
			_capture(creature, target)
	else:
		touch_s = 0.0


# The chase broke: where it last saw them is the last known position, which it searches itself.
func _lose(creature: Creature, world: CreatureWorld) -> void:
	target = null
	touch_s = 0.0
	_found_px = NO_FIND
	lost_at = CreatureNav.cell_of(_last_seen_px)
	forget_path()
	if squad != null:
		squad.soldier_lost(creature, lost_at)
	_goal = lost_at
	enter(State.SEARCH)
	creature.state_id = state


func _capture(creature: Creature, body: PlayerBody) -> void:
	target = null
	touch_s = 0.0
	_found_px = NO_FIND
	forget_path()
	if squad != null:
		escorting = squad.capture(body, creature)
	else:
		CaptureRules.capture(body, creature, patrol)
		escorting = body
	if escorting != null:
		enter(State.ESCORT)
	else:
		enter(State.SEARCH)
	creature.state_id = state


# --- leading a captive and going back --------------------------------------------------------------

func _tick_escort(creature: Creature, world: CreatureWorld, delta: float) -> void:
	if not is_instance_valid(escorting) or not escorting.captive:
		escorting = null
		enter(State.SEARCH)
		return
	var landing: Vector2i = squad.landing_cell() if squad != null else CreatureNav.cell_of(creature.position)
	if _walk_to(creature, world, landing, MovementModel.DRAG_SPEED, delta):
		if squad != null:
			squad.seat(escorting)
		escorting = null
		enter(State.SEARCH)


func _return(creature: Creature) -> void:
	if state == State.ESCORT and is_instance_valid(escorting) and squad != null:
		# The captive comes along to the dinghy.
		pass
	target = null
	touch_s = 0.0
	if squad != null and squad.plan != null:
		squad.plan.drop_point(index)
	forget_path()
	enter(State.RETURN)
	creature.state_id = state


## True when it stands at the dinghy (RETURN and arrived).
func is_back(creature: Creature) -> bool:
	if state != State.RETURN or squad == null:
		return false
	return creature.position.distance_to(SquadPlan.center(squad.landing_cell()) * CreatureNav.TILE) <= ARRIVE_TILES * CreatureNav.TILE + EPSILON


# Walks toward the centre of `cell` at `speed`; true once it has arrived.
func _walk_to(creature: Creature, world: CreatureWorld, cell: Vector2i, speed: float, delta: float) -> bool:
	var goal: Vector2 = CreatureNav.center_of(cell)
	if creature.position.distance_to(goal) <= ARRIVE_TILES * CreatureNav.TILE + EPSILON:
		return true
	var before: Vector2 = creature.position
	follow_path(creature, world, world.nav.land, goal, speed, delta)
	if creature.position == before:
		step_toward(creature, world, goal, speed, delta)
	return creature.position.distance_to(goal) <= ARRIVE_TILES * CreatureNav.TILE + EPSILON


## A soldier walks the land grid: land and shallows, never deep water.
func can_stand(_creature: Creature, world: CreatureWorld, position: Vector2) -> bool:
	return CreatureNav.is_open(world.nav.land, CreatureNav.cell_of(position))
