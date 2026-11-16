extends GutTest
## guardacostas-stealth, group 7 (design.md decisions 2, 5 and 9): the patrol boat's brain on a test
## world (a small island on deep water, no session). The boat's clock is set by hand and stepped in
## 0.1 s ticks. The spot meter (PatrolWatch) and the alerts (lock, search, give up, the lap that
## waits), the smoke, noise and water triggers, fog and the squall.

const PLAYER_SCENE: PackedScene = preload("res://scenes/player/player.tscn")
const FOG: WeatherData = preload("res://tests/fixtures/content/weather/fog_test.tres")
const STEP_S: float = 0.1
const TILE: float = 16.0
const NIGHT := DataEnums.DayPhase.NIGHT
const DAY := DataEnums.DayPhase.DAY
const VISIBLE := MovementStep.Stealth.VISIBLE
const HIDDEN := MovementStep.Stealth.HIDDEN

var island: SmallIsland
var world: CreatureWorld
var root: Node2D
var events: WorldEvents
var boat: Creature
var brain: PatrolRoute
var patrol: PatrolData
var watch: PatrolWatch


func before_each() -> void:
	WeatherManager.stop()
	WeatherManager.sky.start_at(0.0)
	island = SmallIsland.make(SmallIsland.PLAIN)
	world = CreatureWorld.new()
	world.terrain = island.terrain
	world.nav = CreatureNav.build(island.terrain, island.size)
	world.phase = NIGHT
	world.weather_override = GameState.content.get_entry(&"weather", &"calm") as WeatherData
	root = Node2D.new()
	add_child_autofree(root)
	events = WorldEvents.new()
	events.world = world
	root.add_child(events)
	world.events = events
	watch = PatrolWatch.new()
	watch.world = world
	boat = _boat(&"patrol_boat")
	patrol = boat.data.patrol


func _boat(id: StringName) -> Creature:
	var made := Creature.make(GameState.content.get_entry(&"creatures", id) as CreatureData)
	made.world = world
	root.add_child(made)
	brain = made.brain as PatrolRoute
	watch.boats.append(made)
	return made


func _player(cell: Vector2) -> PlayerBody:
	var body := PLAYER_SCENE.instantiate() as PlayerBody
	add_child_autofree(body)
	body.player_input.enabled = false
	body.auto_advance = false
	body.global_position = (cell + Vector2(0.5, 0.5)) * TILE
	return body


func _run(seconds: float) -> void:
	for i: int in roundi(seconds / STEP_S):
		boat.advance(STEP_S)


# The clock at `lap_s` seconds into the lap, settled with a zero-length tick.
func _lap_at(lap_s: float) -> void:
	brain.set_clock(patrol.horizon_warning_s + lap_s)
	boat.advance(0.0)


func _tiles_to(body: PlayerBody) -> float:
	return boat.position.distance_to(body.global_position) / TILE


# --- the states ---------------------------------------------------------------------------------

func test_the_states_are_in_order_and_named() -> void:
	assert_eq(PatrolRoute.State.AWAY, 0)
	assert_eq(PatrolRoute.State.HORIZON, 1)
	assert_eq(PatrolRoute.State.LAP, 2)
	assert_eq(PatrolRoute.State.ALERT_LOCK, 3)
	assert_eq(PatrolRoute.State.ALERT_SEARCH, 4)
	assert_eq(brain.names(), [&"AWAY", &"HORIZON", &"LAP", &"ALERT_LOCK", &"ALERT_SEARCH"] as Array[StringName])


func test_the_clock_gives_horizon_lap_and_away_and_the_boat_is_dark_off_its_lap() -> void:
	brain.set_clock(0.0)
	boat.advance(0.0)
	assert_eq(boat.state_name(), &"HORIZON")
	assert_false(boat.light_on)
	_run(19.0)
	assert_eq(boat.state_name(), &"HORIZON")
	_run(1.5)
	assert_eq(boat.state_name(), &"LAP")
	assert_true(boat.light_on, "night, sight enabled, in its lap")
	_run(100.0)
	assert_eq(boat.state_name(), &"AWAY")
	assert_false(boat.light_on)
	_run(60.0)
	assert_eq(boat.state_name(), &"HORIZON", "the loop is 180 s")


func test_in_its_lap_the_boat_is_on_the_loop_and_the_beam_is_the_searchlights() -> void:
	_lap_at(10.0)
	var loop := PatrolLoop.build(island.terrain, island.size, patrol.route_lap_s, patrol.route_offshore_tiles)
	assert_almost_eq(boat.position.x, loop.pose_px(10.0).x, 0.001)
	assert_almost_eq(boat.position.y, loop.pose_px(10.0).y, 0.001)
	var light := Searchlight.from_patrol(patrol)
	assert_almost_eq(boat.beam, light.beam_deg(loop.pose_at(10.0), loop.centroid, 10.0), 0.001)
	assert_almost_eq(boat.route_t, patrol.horizon_warning_s + 10.0, 0.001)


func test_by_day_there_is_no_light() -> void:
	world.phase = DAY
	_lap_at(10.0)
	assert_eq(boat.state_name(), &"LAP")
	assert_false(boat.light_on)


func test_a_night_beach_fire_alerts_once_as_the_lap_starts_and_not_again_that_lap() -> void:
	var fire := _fire(Vector2i(17, 18))
	brain.set_clock(patrol.horizon_warning_s - 0.5)
	watch_signals(boat)
	_run(1.5)
	assert_signal_emit_count(boat, "patrol_alerted", 1, "one smoke alert at the lap's start")
	assert_eq((get_signal_parameters(boat, "patrol_alerted", 0) as Array)[1], fire.position)
	_run(40.0)
	assert_signal_emit_count(boat, "patrol_alerted", 1, "the same fire, the same lap")


# --- lock and search ------------------------------------------------------------------------------

func test_a_spot_locks_the_player_and_the_beam_follows_them_while_visible() -> void:
	var body := _player(Vector2(21, 19))
	_lap_at(5.0)
	var clock_at_spot: float = boat.route_t
	watch_signals(boat)
	brain.spot(body, &"sight")
	assert_eq(boat.state_name(), &"ALERT_LOCK")
	assert_eq(boat.alert_serial, 1)
	assert_signal_emit_count(boat, "patrol_alerted", 1)
	var params: Array = get_signal_parameters(boat, "patrol_alerted", 0)
	assert_eq(params[0], &"sight")
	assert_almost_eq((params[1] as Vector2).x, body.global_position.x, 0.001)
	_run(3.0)
	assert_eq(boat.state_name(), &"ALERT_LOCK", "visible and in range: stays locked")
	assert_almost_eq(boat.route_t, clock_at_spot, 0.0001, "the clock waits")
	var aim: float = rad_to_deg((body.global_position / TILE - boat.position / TILE).angle())
	assert_almost_eq(wrapf(boat.beam - aim, -180.0, 180.0), 0.0, 0.01, "the beam is on the player")
	assert_true(brain.lights(body.global_position))


func test_hiding_breaks_the_lock_and_a_20_s_search_sweeps_30_degrees_round_the_last_position() -> void:
	var body := _player(Vector2(21, 19))
	_lap_at(5.0)
	brain.spot(body, &"sight")
	_run(1.0)
	var last_known: Vector2 = body.global_position
	body.stealth_state = HIDDEN
	boat.advance(STEP_S)
	assert_eq(boat.state_name(), &"ALERT_SEARCH")
	var aim: float = rad_to_deg((last_known / TILE - boat.position / TILE).angle())
	var widest: float = 0.0
	for i: int in 190:
		boat.advance(STEP_S)
		assert_eq(boat.state_name(), &"ALERT_SEARCH", "still searching at %.1f s" % (i * STEP_S))
		widest = maxf(widest, absf(wrapf(boat.beam - aim, -180.0, 180.0)))
	assert_almost_eq(widest, patrol.alert_sweep_deg, 1.0, "the beam swings 30 degrees either side")
	_run(1.0)
	assert_eq(boat.state_name(), &"LAP", "20 s after the lock broke it resumes")
	assert_eq(boat.alert_serial, 2, "the give-up line")
	assert_false(brain.locked != null)


func test_more_than_10_tiles_away_breaks_the_lock() -> void:
	var body := _player(Vector2(21, 19))
	_lap_at(5.0)
	brain.spot(body, &"sight")
	_run(0.5)
	assert_eq(boat.state_name(), &"ALERT_LOCK")
	body.global_position = boat.position + Vector2(10.5 * TILE, 0.0)
	boat.advance(STEP_S)
	assert_eq(boat.state_name(), &"ALERT_SEARCH")


func test_a_spot_during_the_search_locks_again_and_restarts_the_20_s() -> void:
	var body := _player(Vector2(21, 19))
	_lap_at(5.0)
	brain.spot(body, &"sight")
	body.stealth_state = HIDDEN
	_run(12.0)
	assert_eq(boat.state_name(), &"ALERT_SEARCH")
	assert_eq(boat.alert_serial, 1)
	body.stealth_state = VISIBLE
	watch_signals(boat)
	brain.spot(body, &"sight")
	assert_eq(boat.state_name(), &"ALERT_LOCK")
	assert_eq(boat.alert_serial, 2, "a second report, a second line")
	assert_signal_emit_count(boat, "patrol_alerted", 1)
	_run(5.0)
	body.stealth_state = HIDDEN
	_run(19.0)
	assert_eq(boat.state_name(), &"ALERT_SEARCH", "the 20 s counts from the new lock's end")
	_run(1.5)
	assert_eq(boat.state_name(), &"LAP")


func test_a_locked_player_is_not_reported_again_by_the_same_boat() -> void:
	var body := _player(Vector2(21, 19))
	_lap_at(5.0)
	brain.spot(body, &"sight")
	watch_signals(boat)
	brain.spot(body, &"sight")
	assert_signal_not_emitted(boat, "patrol_alerted")
	assert_eq(boat.alert_serial, 1)


func test_a_spot_of_another_player_during_a_lock_is_reported_and_the_lock_stays() -> void:
	var first := _player(Vector2(21, 19))
	var second := _player(Vector2(20, 19))
	_lap_at(5.0)
	brain.spot(first, &"sight")
	_run(2.0)
	var clock: float = boat.route_t
	var at: Vector2 = boat.position
	watch_signals(boat)
	brain.spot(second, &"sight")
	assert_signal_emit_count(boat, "patrol_alerted", 1, "the second player's spot is reported once")
	var params: Array = get_signal_parameters(boat, "patrol_alerted", 0)
	assert_eq(params[0], &"sight")
	assert_eq(params[1], second.global_position)
	assert_eq(boat.alert_serial, 2, "and calls the next line")
	assert_eq(boat.state_name(), &"ALERT_LOCK")
	assert_eq(brain.locked, first, "the lock stays on the first player")
	assert_eq(boat.route_t, clock, "the clock still waits")
	assert_eq(boat.position, at)
	brain.spot(first, &"sight")
	assert_signal_emit_count(boat, "patrol_alerted", 1, "the locked player is not reported again")
	assert_eq(boat.alert_serial, 2)
	_run(3.0)
	assert_eq(boat.state_name(), &"ALERT_LOCK")
	assert_eq(brain.locked, first)


func test_the_lap_waits_for_the_alert() -> void:
	var body := _player(Vector2(21, 19))
	brain.set_clock(0.0)
	boat.advance(0.0)
	_run(50.0)
	assert_eq(boat.state_name(), &"LAP")
	brain.spot(body, &"sight")
	_run(5.0)
	body.stealth_state = HIDDEN
	var elapsed: float = 50.0 + 5.0
	var seen_away: bool = false
	var guard: int = 0
	while guard < 3000:
		guard += 1
		boat.advance(STEP_S)
		elapsed += STEP_S
		if boat.state_name() == &"AWAY":
			seen_away = true
		if seen_away and boat.state_name() == &"HORIZON":
			break
	assert_almost_eq(elapsed, 205.0, 0.25, "an alert of 25 s makes a 205 s loop")


func test_the_alert_stops_the_boat() -> void:
	var body := _player(Vector2(21, 19))
	_lap_at(5.0)
	var at: Vector2 = boat.position
	brain.spot(body, &"sight")
	_run(10.0)
	assert_eq(boat.position, at)


# --- smoke, noise and water ---------------------------------------------------------------------

func _fire(cell: Vector2i) -> Node2D:
	var node := Node2D.new()
	node.position = (Vector2(cell) + Vector2(0.5, 0.5)) * TILE
	root.add_child(node)
	node.add_to_group(PlayerBody.FIRE_GROUP)
	return node


func test_a_day_fire_stops_the_boat_for_20_s_with_no_light() -> void:
	world.phase = DAY
	var fire := _fire(Vector2i(19, 19))
	watch_signals(boat)
	brain.set_clock(patrol.horizon_warning_s - 0.5)
	_run(1.6)
	assert_eq(boat.state_name(), &"ALERT_SEARCH")
	assert_false(boat.light_on, "no beam by day")
	assert_signal_emit_count(boat, "patrol_alerted", 1)
	var params: Array = get_signal_parameters(boat, "patrol_alerted", 0)
	assert_eq(params[0], &"smoke")
	assert_eq(params[1], fire.position)
	assert_eq(boat.alert_serial, 1)
	var at: Vector2 = boat.position
	_run(17.0)
	assert_eq(boat.state_name(), &"ALERT_SEARCH")
	assert_eq(boat.position, at)
	_run(3.0)
	assert_eq(boat.state_name(), &"LAP")
	assert_eq(boat.alert_serial, 2)
	assert_signal_emit_count(boat, "patrol_alerted", 1, "the same fire does not alert again this lap")


func test_a_night_fire_inland_does_not_alert() -> void:
	# A 16x16 beach: its middle is 8 tiles from the sea, more than the night rule's 2.
	island.terrain.fill_rect(Rect2i(12, 12, 16, 16), DataEnums.Terrain.BEACH)
	_fire(Vector2i(19, 19))
	watch_signals(boat)
	_lap_at(1.0)
	_run(30.0)
	assert_signal_not_emitted(boat, "patrol_alerted")


func test_a_noise_the_boat_hears_raises_a_noise_alert_at_the_source() -> void:
	_lap_at(5.0)
	var source: Vector2 = boat.position + Vector2(12.0 * TILE, 0.0)
	watch_signals(boat)
	events.make_noise(source, 15.0, &"test")
	assert_eq(boat.state_name(), &"ALERT_SEARCH")
	assert_signal_emit_count(boat, "patrol_alerted", 1)
	var params: Array = get_signal_parameters(boat, "patrol_alerted", 0)
	assert_eq(params[0], &"noise")
	assert_eq(params[1], source)
	assert_eq(boat.alert_serial, 1)


func test_noises_the_boat_does_not_hear_are_ignored_and_so_are_noises_off_its_lap() -> void:
	_lap_at(5.0)
	watch_signals(boat)
	events.make_noise(boat.position + Vector2(20.0 * TILE, 0.0), 15.0, &"far")
	events.make_noise(boat.position + Vector2(3.0 * TILE, 0.0), 6.0, &"quiet")
	assert_signal_not_emitted(boat, "patrol_alerted")
	brain.set_clock(0.0)
	boat.advance(0.0)
	events.make_noise(boat.position, 15.0, &"loud but on the horizon")
	assert_signal_not_emitted(boat, "patrol_alerted")


func test_a_swimmer_5_tiles_away_is_spotted_at_once_and_a_diver_3_tiles_away_is_not() -> void:
	world.phase = DAY
	_lap_at(5.0)
	var diver := _player(Vector2.ZERO)
	diver.global_position = boat.position + Vector2(3.0 * TILE, 0.0)
	diver.movement_state = MovementStep.Move.DIVE
	diver.stealth_state = MovementStep.Stealth.SUBMERGED
	watch_signals(boat)
	_run(1.0)
	assert_signal_not_emitted(boat, "patrol_alerted")
	var swimmer := _player(Vector2.ZERO)
	swimmer.global_position = boat.position + Vector2(5.0 * TILE, 0.0)
	swimmer.movement_state = MovementStep.Move.SWIM
	boat.advance(STEP_S)
	assert_eq(boat.state_name(), &"ALERT_LOCK")
	assert_eq(brain.locked, swimmer)
	var params: Array = get_signal_parameters(boat, "patrol_alerted", 0)
	assert_eq(params[0], &"water")
	assert_signal_emit_count(boat, "patrol_alerted", 1, "once, not every tick")


# --- fog and the squall -----------------------------------------------------------------------

func test_fog_puts_the_light_out_and_blinds_the_water_rule_but_not_smoke_or_noise() -> void:
	world.weather_override = FOG
	var swimmer := _player(Vector2.ZERO)
	_lap_at(5.0)
	swimmer.global_position = boat.position + Vector2(3.0 * TILE, 0.0)
	swimmer.movement_state = MovementStep.Move.SWIM
	watch_signals(boat)
	_run(2.0)
	assert_false(boat.light_on)
	assert_signal_not_emitted(boat, "patrol_alerted")
	assert_false(brain.lights(swimmer.global_position))
	events.make_noise(boat.position + Vector2(5.0 * TILE, 0.0), 15.0, &"test")
	assert_signal_emit_count(boat, "patrol_alerted", 1, "noise still works in fog")


func test_a_squall_ends_an_alert_and_the_next_horizon_comes_after_it() -> void:
	var body := _player(Vector2(21, 19))
	_lap_at(5.0)
	brain.spot(body, &"sight")
	assert_eq(boat.state_name(), &"ALERT_LOCK")
	var squall := GameState.content.get_entry(&"weather", &"squall") as WeatherData
	assert_true(squall.patrols_in_port)
	world.weather_override = squall
	boat.advance(STEP_S)
	assert_eq(boat.state_name(), &"AWAY", "at once")
	assert_false(boat.light_on)
	assert_null(brain.locked)
	var serial: int = boat.alert_serial
	for i: int in 2000:
		boat.advance(STEP_S)
		assert_eq(boat.state_name(), &"AWAY", "no boat in sight during the squall")
	assert_eq(boat.alert_serial, serial, "no give-up line")
	world.weather_override = GameState.content.get_entry(&"weather", &"calm") as WeatherData
	boat.advance(STEP_S)
	assert_eq(boat.state_name(), &"HORIZON", "the clock restarted")
	_run(18.0)
	assert_eq(boat.state_name(), &"HORIZON")
	_run(2.0)
	assert_eq(boat.state_name(), &"LAP")


func test_after_a_squall_no_boat_is_in_sight_before_its_own_horizon_warning() -> void:
	var second := _boat(&"patrol_boat")
	brain.set_member(boat, 0, 2)
	var second_brain := second.brain as PatrolRoute
	second_brain.set_member(second, 1, 2)
	for each: Creature in [boat, second]:
		(each.brain as PatrolRoute).set_clock(patrol.horizon_warning_s + 5.0)
		each.advance(0.0)
	var squall := GameState.content.get_entry(&"weather", &"squall") as WeatherData
	world.weather_override = squall
	for i: int in 50:
		boat.advance(STEP_S)
		second.advance(STEP_S)
	world.weather_override = GameState.content.get_entry(&"weather", &"calm") as WeatherData
	var horizon_at: Array[float] = [-1.0, -1.0]
	var lap_at: Array[float] = [-1.0, -1.0]
	for i: int in 2000:
		boat.advance(STEP_S)
		second.advance(STEP_S)
		var now_s: float = (i + 1) * STEP_S
		var boats: Array[Creature] = [boat, second]
		for k: int in 2:
			var name_now: StringName = boats[k].state_name()
			if name_now == &"HORIZON" and horizon_at[k] < 0.0:
				horizon_at[k] = now_s
			if name_now == &"LAP" and lap_at[k] < 0.0:
				lap_at[k] = now_s
			if (boats[k].brain as PatrolRoute).in_sight() and horizon_at[k] < 0.0:
				fail_test("boat %d in sight before its horizon warning at %.1f s" % [k, now_s])
				return
	assert_almost_eq(horizon_at[0], STEP_S, 0.001, "boat 0 restarts at once")
	assert_almost_eq(horizon_at[1], 90.0, 0.2, "boat 1 waits half the period")
	assert_almost_eq(lap_at[0], patrol.horizon_warning_s, 0.2)
	assert_almost_eq(lap_at[1], 90.0 + patrol.horizon_warning_s, 0.2, "in its lap only after its own warning")


# --- the spot meter ---------------------------------------------------------------------------

func test_the_meter_is_stepped_once_however_many_boats_light_the_player() -> void:
	var first_brain := brain
	var first := boat
	var second := _boat(&"patrol_boat")
	var body := _player(Vector2(21, 19))
	for each: Creature in [first, second]:
		(each.brain as PatrolRoute).set_clock(patrol.horizon_warning_s + 5.0)
		each.advance(0.0)
	(first_brain).spot(body, &"sight")
	(second.brain as PatrolRoute).spot(body, &"sight")
	assert_true((first_brain).lights(body.global_position))
	assert_true((second.brain as PatrolRoute).lights(body.global_position))
	for i: int in 10:
		watch.step(STEP_S)
	assert_almost_eq(body.spot_meter.value, 1.0, 0.001, "1 s per second, not 2")


func test_the_meter_spots_a_lit_player_at_2_s_and_the_nearest_lighting_boat_gets_the_alert() -> void:
	var body := _player(Vector2(21, 19))
	# Park the beam on the player: an alert's lock does it, then drop the lock by hand and re-spot.
	_lap_at(5.0)
	brain.spot(body, &"sight")
	brain.forget_lock()
	assert_eq(boat.state_name(), &"ALERT_SEARCH")
	body.spot_meter.clear()
	watch_signals(boat)
	var spotted_at: float = -1.0
	for i: int in 40:
		boat.advance(STEP_S)
		watch.step(STEP_S)
		if boat.state_name() == &"ALERT_LOCK":
			spotted_at = (i + 1) * STEP_S
			break
	assert_gt(spotted_at, 0.0, "spotted")
	assert_almost_eq(spotted_at, 2.0, 0.15)
	assert_signal_emit_count(boat, "patrol_alerted", 1)
	assert_eq((get_signal_parameters(boat, "patrol_alerted", 0) as Array)[0], &"sight")
	assert_almost_eq(body.spot_meter.value, 0.0, 0.0001, "reset after a spot")


func test_a_hidden_player_never_fills_and_a_dead_one_is_cleared() -> void:
	var body := _player(Vector2(21, 19))
	_lap_at(5.0)
	brain.spot(body, &"sight")
	brain.forget_lock()
	body.stealth_state = HIDDEN
	for i: int in 30:
		boat.advance(STEP_S)
		watch.step(STEP_S)
	assert_eq(body.spot_meter.value, 0.0)
	body.stealth_state = VISIBLE
	body.spot_meter.value = 1.0
	body.meters.dead = true
	watch.step(STEP_S)
	assert_eq(body.spot_meter.value, 0.0, "a dead player has no meter")


# --- dropped players ----------------------------------------------------------------------------

func test_a_dropped_player_has_no_meter_and_is_never_spotted_by_light() -> void:
	var body := _player(Vector2(21, 19))
	_lap_at(5.0)
	brain.spot(body, &"sight")
	brain.forget_lock()
	body.net.net_dropped = true
	body.spot_meter.value = 1.5
	watch.step(STEP_S)
	assert_eq(body.spot_meter.value, 0.0, "cleared")
	for i: int in 60:
		boat.advance(STEP_S)
		watch.step(STEP_S)
	assert_eq(body.spot_meter.value, 0.0, "never steps")
	assert_ne(boat.state_name(), &"ALERT_LOCK")


func test_a_dropped_swimmer_is_not_spotted_by_the_water_rule() -> void:
	var swimmer := _player(Vector2.ZERO)
	_lap_at(5.0)
	swimmer.global_position = boat.position + Vector2(3.0 * TILE, 0.0)
	swimmer.movement_state = MovementStep.Move.SWIM
	swimmer.net.net_dropped = true
	watch_signals(boat)
	_run(2.0)
	assert_signal_not_emitted(boat, "patrol_alerted")


func test_a_lock_on_a_body_that_drops_breaks_into_a_search() -> void:
	var body := _player(Vector2(21, 19))
	_lap_at(5.0)
	brain.spot(body, &"sight")
	assert_eq(boat.state_name(), &"ALERT_LOCK")
	body.net.net_dropped = true
	boat.advance(STEP_S)
	assert_eq(boat.state_name(), &"ALERT_SEARCH")
	assert_null(brain.locked)


# --- the watch's parameters -------------------------------------------------------------------

func test_an_unlit_player_is_not_spotted_by_a_smaller_boats_threshold() -> void:
	boat.data = boat.data.duplicate() as CreatureData
	boat.data.patrol = patrol.duplicate() as PatrolData
	boat.data.patrol.spot_time_s = 1.0
	var body := _player(Vector2(2, 2))
	_lap_at(5.0)
	assert_false(brain.lights(body.global_position))
	body.spot_meter.value = 1.2
	watch_signals(boat)
	watch.step(STEP_S)
	assert_signal_not_emitted(boat, "patrol_alerted")
	assert_almost_eq(body.spot_meter.value, 1.2 - body.spot_meter.drain_per_s * STEP_S, 0.001)


# --- per-kind rules ---------------------------------------------------------------------------

func test_two_patrol_kinds_on_one_world_get_their_own_water_radius() -> void:
	var wide := patrol.duplicate() as PatrolData
	wide.water_spot_radius_tiles = 8.0
	var narrow := patrol.duplicate() as PatrolData
	narrow.water_spot_radius_tiles = 3.0
	var none: Array[DataEnums.Sense] = []
	var at := Vector2(10.0, 10.0)
	var swim: MovementStep.Move = MovementStep.Move.SWIM
	assert_true(world.patrol_triggers(wide).water_spots(swim, at + Vector2(5.0, 0.0), at, none, true))
	assert_false(world.patrol_triggers(narrow).water_spots(swim, at + Vector2(5.0, 0.0), at, none, true), "its own radius")
	assert_true(world.patrol_triggers(wide).water_spots(swim, at + Vector2(5.0, 0.0), at, none, true))
