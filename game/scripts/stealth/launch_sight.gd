class_name LaunchSight
extends RefCounted
## island-pressure D4 (guardacostas-stealth "Launch in view"): whether a patrol boat sees a launch at a
## point. In a phase when a boat's searchlight is off (dawn, day, dusk) the boat sees every launch,
## whatever its loop state: by day the guard watches the whole sea. In a searchlight phase (night) only
## a boat whose lit cone covers the point sees it. A squall (patrols in port), a weather that blinds
## sight or an island with no boat hides it. Pure over the boats' synced fields (state, light, beam,
## position), so the host's launch check and every peer's prompt warning give the same answer.

const TILE: float = 16.0
## The island's creature spawner in its session (SandbarIsland.CREATURES_NAME).
const CREATURES_NAME: StringName = &"Creatures"


## The first boat (by member index) of `boats` that sees a launch at `point_px` in `phase` and
## `weather`, or null when none does.
static func seen_by(boats: Array[Creature], phase: DataEnums.DayPhase, weather: WeatherData, point_px: Vector2) -> Creature:
	if weather != null and (weather.patrols_in_port or weather.disabled_senses.has(DataEnums.Sense.SIGHT)):
		return null
	var first: Creature = null
	for boat: Creature in boats:
		if not _sees(boat, phase, point_px):
			continue
		if first == null or _member_index(boat) < _member_index(first):
			first = boat
	return first


## The patrol boats of `session`'s island, on any peer.
static func boats_of(session: CoopSession) -> Array[Creature]:
	var boats: Array[Creature] = []
	if session == null or not is_instance_valid(session.entities):
		return boats
	for node: Node in session.entities.get_children():
		var boat := node as Creature
		if boat != null and not boat.is_queued_for_deletion() and boat.is_patrol() and not boat.is_passing():
			boats.append(boat)
	return boats


## The boat of `session`'s island that sees a launch at `point_px` now, or null: the phase from the
## session's climate, the weather from the island's creature world on the host (a test may pin it
## there) and from the sky otherwise.
static func seen_in(session: CoopSession, point_px: Vector2) -> Creature:
	if session == null or session.climate == null:
		return null
	return seen_by(boats_of(session), session.climate.phase, weather_of(session), point_px)


## The weather the island's boats run on: the host's creature world, else the shared sky.
static func weather_of(session: CoopSession) -> WeatherData:
	# Read by name and by duck typing: naming the island's class here would close a load cycle (the
	# island preloads the raft scene, whose routes read this sight).
	var spawner: Node = session.get_node_or_null(NodePath(CREATURES_NAME))
	var world: Object = spawner.get(&"world") if spawner != null else null
	if world != null and world.has_method(&"weather"):
		return world.call(&"weather") as WeatherData
	return WeatherManager.sky.weather.current


static func _sees(boat: Creature, phase: DataEnums.DayPhase, point_px: Vector2) -> bool:
	if boat == null or not is_instance_valid(boat) or boat.is_queued_for_deletion() or not boat.is_patrol():
		return false
	var patrol: PatrolData = boat.data.patrol
	if not patrol.searchlight_phases.has(phase):
		return true
	if not boat.light_on or not PatrolRoute.is_in_sight_state(boat.state_id):
		return false
	return Searchlight.from_patrol(patrol).is_lit(point_px / TILE, boat.position / TILE, boat.beam)


static func _member_index(boat: Creature) -> int:
	var route := boat.brain as PatrolRoute
	return route.member_index if route != null else 0
