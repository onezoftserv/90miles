class_name SearchCapture
extends CreatureBrain
## guardacostas-capture design.md §5: the shore soldier's machine (SEARCH_CAPTURE). A soldier does not
## fight: it sees in a cone ahead of it (SightCone, by day and by night), and its sight fills the same
## spot meter as the boats' lights (PatrolWatch steps every meter once). A spot sends it running at
## the player at `soldier_chase_tiles_s` while they stay unhidden within its sight length; when the
## chase breaks, where it last saw them becomes the point it searches itself. Downed and dropped bodies
## are never its targets. Host only. States are append-only: `state` is synced.

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

## The patrol whose numbers the soldier uses (its boat's): sight, chase speed, touch.
var patrol: PatrolData = null
## The player it chases in CHASE, else null.
var target: PlayerBody = null
## Where it last saw the player it lost (a cell), NO_CELL before it lost anyone.
var lost_at: Vector2i = NO_CELL

var _last_seen_px: Vector2 = Vector2.ZERO


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
## downed or dropped.
func spot(creature: Creature, body: PlayerBody) -> void:
	if not can_target(body) or state == State.ESCORT or state == State.RETURN:
		return
	target = body
	_last_seen_px = body.global_position
	forget_path()
	enter(State.CHASE)
	creature.state_id = state


## A soldier's target: alive, standing (not downed, in a last stand or dead), connected and on the
## island.
static func can_target(body: PlayerBody) -> bool:
	if not is_instance_valid(body) or body.left_island or CreatureWorld.is_dropped(body):
		return false
	return body.meters == null or not (body.meters.downed or body.meters.last_stand or body.meters.dead)


func tick(creature: Creature, world: CreatureWorld, delta: float) -> void:
	if patrol == null:
		return
	if state == State.CHASE:
		_tick_chase(creature, world, delta)


func _tick_chase(creature: Creature, world: CreatureWorld, delta: float) -> void:
	var hidden: bool = is_instance_valid(target) and target.stealth_state != MovementStep.Stealth.VISIBLE
	var holds: bool = can_target(target) and cone(world).chase_holds(target.global_position / CreatureNav.TILE,
		creature.position / CreatureNav.TILE, hidden, world.weather().disabled_senses)
	if not holds:
		_lose(creature)
		return
	_last_seen_px = target.global_position
	follow_path(creature, world, world.nav.land, target.global_position, patrol.soldier_chase_tiles_s, delta)
	var to: Vector2 = target.global_position - creature.position
	if to.length() > EPSILON:
		creature.facing = to.normalized()


# The chase broke: where it last saw them is the point it searches itself.
func _lose(creature: Creature) -> void:
	target = null
	lost_at = CreatureNav.cell_of(_last_seen_px)
	forget_path()
	enter(State.SEARCH)
	creature.state_id = state
