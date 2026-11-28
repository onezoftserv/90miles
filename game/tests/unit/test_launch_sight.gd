extends GutTest
## island-pressure task 3.1, 1 player, offline (guardacostas-stealth "Launch in view"): the pure rule
## that says whether a launch is seen. A boat whose searchlight is off in the phase (dawn, day, dusk)
## sees every launch, whatever its loop state; at night only a lit cone on the starter sees it; a
## squall, a weather that blinds sight or an island with no boat hides it. Then the sweep: on the
## sandbar and the reshaped coast cay, with 1 and 2 boats, one full night period always has a window
## in which no light covers the raft site, so a night launch is always possible.

const SANDBAR: IslandLayoutData = preload("res://resources/islands/sandbar.tres")
const COAST_CAY: IslandLayoutData = preload("res://resources/islands/coast_cay.tres")
const TILE: float = 16.0
const SWEEP_STEP_S: float = 0.1
## The shortest dark window a launch needs: the launch prompt's 1 s hold, with room to aim it.
const MIN_WINDOW_S: float = 3.0
const D := DataEnums.DayPhase
## Where the raft is launched in the pure cases, in pixels.
const POINT: Vector2 = Vector2(100.0, 100.0)

var calm: WeatherData
var squall: WeatherData
var patrol: PatrolData


func before_each() -> void:
	calm = GameState.content.get_entry(&"weather", &"calm") as WeatherData
	squall = GameState.content.get_entry(&"weather", &"squall") as WeatherData
	patrol = (GameState.content.get_entry(&"creatures", &"patrol_boat") as CreatureData).patrol


func _boat(state: PatrolRoute.State, at_px: Vector2, beam_deg: float, light_on: bool, index: int = 0) -> Creature:
	var boat := Creature.make(GameState.content.get_entry(&"creatures", &"patrol_boat") as CreatureData)
	autofree(boat)
	boat.state_id = state
	boat.position = at_px
	boat.beam = beam_deg
	boat.light_on = light_on
	(boat.brain as PatrolRoute).member_index = index
	return boat


func _boats(list: Array) -> Array[Creature]:
	var typed: Array[Creature] = []
	typed.assign(list)
	return typed



func test_solo_by_day_the_boat_away_still_sees() -> void:
	var away := _boat(PatrolRoute.State.AWAY, Vector2(-500.0, -500.0), 0.0, false)
	for phase: DataEnums.DayPhase in [D.DAWN, D.DAY, D.DUSK]:
		assert_eq(LaunchSight.seen_by(_boats([away]), phase, calm, POINT), away, "phase %d" % phase)


func test_solo_at_night_out_of_the_light() -> void:
	# On its lap 5 tiles west of the point, the beam pointing north: the point is 90 degrees off.
	var lap := _boat(PatrolRoute.State.LAP, POINT + Vector2(-5.0 * TILE, 0.0), -90.0, true)
	assert_null(LaunchSight.seen_by(_boats([lap]), D.NIGHT, calm, POINT))
	var away := _boat(PatrolRoute.State.AWAY, Vector2(-500.0, -500.0), 0.0, false)
	assert_null(LaunchSight.seen_by(_boats([away]), D.NIGHT, calm, POINT), "a boat away has no light at night")


func test_solo_at_night_in_the_light() -> void:
	var lap := _boat(PatrolRoute.State.LAP, POINT + Vector2(-5.0 * TILE, 0.0), 0.0, true)
	assert_eq(LaunchSight.seen_by(_boats([lap]), D.NIGHT, calm, POINT), lap, "the beam points east, at the raft")
	var far := _boat(PatrolRoute.State.LAP, POINT + Vector2(-12.0 * TILE, 0.0), 0.0, true)
	assert_null(LaunchSight.seen_by(_boats([far]), D.NIGHT, calm, POINT), "beyond the light's 10 tiles")


func test_solo_in_a_squall() -> void:
	var away := _boat(PatrolRoute.State.AWAY, Vector2(-500.0, -500.0), 0.0, false)
	assert_true(squall.patrols_in_port)
	assert_null(LaunchSight.seen_by(_boats([away]), D.DAY, squall, POINT))


func test_a_weather_that_blinds_sight_hides_the_launch() -> void:
	var fog := WeatherData.new()
	fog.disabled_senses = [DataEnums.Sense.SIGHT] as Array[DataEnums.Sense]
	var away := _boat(PatrolRoute.State.AWAY, Vector2(-500.0, -500.0), 0.0, false)
	assert_null(LaunchSight.seen_by(_boats([away]), D.DAY, fog, POINT))


func test_an_island_with_no_boat() -> void:
	assert_null(LaunchSight.seen_by(_boats([]), D.DAY, calm, POINT))
	var crab := Creature.make(GameState.content.get_entry(&"creatures", &"land_crab") as CreatureData)
	autofree(crab)
	assert_null(LaunchSight.seen_by(_boats([crab]), D.DAY, calm, POINT), "a crab is no patrol")


func test_the_first_boat_by_member_index_raises_it() -> void:
	var second := _boat(PatrolRoute.State.LAP, Vector2.ZERO, 0.0, false, 1)
	var first := _boat(PatrolRoute.State.AWAY, Vector2.ZERO, 0.0, false, 0)
	assert_eq(LaunchSight.seen_by(_boats([second, first]), D.DAY, calm, POINT), first)


func test_a_swim_is_not_a_launch() -> void:
	var raft := GameState.content.get_entry(&"routes", &"raft") as RouteData
	var swim := GameState.content.get_entry(&"routes", &"binoculars_swim") as RouteData
	assert_true(raft.seen_at_launch, "the raft is seen at launch")
	assert_false(swim.seen_at_launch, "a swimmer stays under the water rule")


# --- the night windows --------------------------------------------------------------------------

# The longest stretch of one night period in which no boat's light covers the raft site, in seconds,
# with `count` boats spread on the loop as PatrolRoute.set_member spreads them.
func _longest_dark_window(layout: IslandLayoutData, count: int) -> float:
	var built := IslandLayout.build(layout)
	var loop := PatrolLoop.build(built.terrain, built.size, patrol.route_lap_s, patrol.route_offshore_tiles)
	assert_true(loop.valid, "the island has a loop")
	var light := Searchlight.from_patrol(patrol)
	var period: float = PatrolLoop.period_s(patrol)
	var site := Vector2(built.raft_site) + Vector2(0.5, 0.5)
	var longest: float = 0.0
	var run: float = 0.0
	# Two periods, so a window across the period's end counts whole.
	var steps: int = roundi(2.0 * period / SWEEP_STEP_S)
	for step: int in steps:
		var world_s: float = step * SWEEP_STEP_S
		var lit: bool = false
		for index: int in count:
			var clock: float = PatrolLoop.boat_clock(world_s, index, count, period)
			if PatrolLoop.phase_at(clock, period, patrol.horizon_warning_s, patrol.route_lap_s) != PatrolLoop.Phase.LAP:
				continue
			var lap_t: float = PatrolLoop.lap_time(clock, patrol.horizon_warning_s)
			var boat: Vector2 = loop.pose_at(lap_t)
			if light.is_lit(site, boat, light.beam_deg(boat, loop.centroid, lap_t)):
				lit = true
				break
		run = 0.0 if lit else run + SWEEP_STEP_S
		longest = maxf(longest, run)
	return minf(longest, period)


func test_every_night_period_has_a_dark_window_at_the_raft_site() -> void:
	for layout: IslandLayoutData in [SANDBAR, COAST_CAY]:
		for count: int in [1, 2]:
			var window: float = _longest_dark_window(layout, count)
			gut.p("%s, %d boat(s): longest dark window at the raft site %.1f s" % [layout.resource_path.get_file(), count, window])
			assert_gte(window, MIN_WINDOW_S, "%s with %d boat(s)" % [layout.resource_path.get_file(), count])
