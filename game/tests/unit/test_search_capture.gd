extends GutTest
## guardacostas-capture, group 7 (design.md §4–§7, specs "Captives", "Free a captive", "The squad
## leaves"): the docked boat and its soldiers on a test world (a 28×12 beach on deep water, no session).
## A land alert docks the boat, the dinghy rows in at 2 tiles/s and three soldiers step ashore. A
## soldier leads its captive to the dinghy at drag speed and goes back to its plan, its touch resets
## when contact breaks, it never targets a downed or dropped body, a free player frees a seated captive
## with a 1 s hold while no soldier is within 3 tiles, and a soldier coming back cancels the hold.

const PLAYER_SCENE: PackedScene = preload("res://scenes/player/player.tscn")
const STEP_S: float = 0.1
const TILE: float = 16.0
const TOLERANCE: float = 0.000001
const SIZE: Vector2i = Vector2i(48, 40)
const BEACH: Rect2i = Rect2i(10, 14, 28, 12)

var terrain: GridTerrain
var world: CreatureWorld
var root: Node2D
var watch: PatrolWatch
var boat: Creature
var brain: PatrolRoute
var patrol: PatrolData
var spawned: Array[Creature] = []


func before_each() -> void:
	WeatherManager.stop()
	WeatherManager.sky.start_at(0.0)
	terrain = GridTerrain.new()
	terrain.default_terrain = DataEnums.Terrain.DEEP
	terrain.fill_rect(Rect2i(Vector2i.ZERO, SIZE), DataEnums.Terrain.DEEP)
	terrain.fill_rect(BEACH, DataEnums.Terrain.BEACH)
	terrain.fill_rect(Rect2i(30, 20, 3, 3), DataEnums.Terrain.SCRUB)
	world = CreatureWorld.new()
	world.terrain = terrain
	world.nav = CreatureNav.build(terrain, SIZE)
	world.phase = DataEnums.DayPhase.DAY
	world.weather_override = GameState.content.get_entry(&"weather", &"calm") as WeatherData
	world.island_id = &"test_beach"
	world.spawner = _spawn
	root = Node2D.new()
	add_child_autofree(root)
	watch = PatrolWatch.new()
	watch.world = world
	world.watch = watch
	spawned.clear()
	boat = Creature.make(GameState.content.get_entry(&"creatures", &"patrol_boat") as CreatureData)
	boat.world = world
	root.add_child(boat)
	brain = boat.brain as PatrolRoute
	patrol = boat.data.patrol
	watch.boats.append(boat)
	brain.set_clock(patrol.horizon_warning_s + 10.0)
	boat.advance(0.0)


func _spawn(data: CreatureData, at: Vector2) -> Creature:
	var made := Creature.make(data)
	made.position = at
	root.add_child(made)
	spawned.append(made)
	return made


func _player(cell: Vector2) -> PlayerBody:
	var body := PLAYER_SCENE.instantiate() as PlayerBody
	add_child_autofree(body)
	body.player_input.enabled = false
	body.auto_advance = false
	body.global_position = (cell + Vector2(0.5, 0.5)) * TILE
	return body


# The boat, its soldiers and the meter watch, for `seconds` of 0.1 s ticks.
func _run(seconds: float, bodies: Array[PlayerBody] = []) -> void:
	for i: int in roundi(seconds / STEP_S):
		_tick(bodies)


func _tick(bodies: Array[PlayerBody] = []) -> void:
	for body: PlayerBody in bodies:
		body.advance(STEP_S)
	boat.advance(STEP_S)
	for soldier: Creature in brain.soldiers.duplicate():
		if is_instance_valid(soldier):
			soldier.advance(STEP_S)
	watch.step(STEP_S)


# A player spotted on the beach docks the boat; the squad is ashore when this returns. The spotted
# player is moved far off (and hidden), so no soldier chases them.
func _land_squad() -> PlayerBody:
	var spotted := _player(Vector2(20, 15))
	brain.spot(spotted, &"sight")
	assert_eq(boat.state_name(), &"DOCKED", "a spot on land docks the boat")
	assert_eq(boat.squad_state, PatrolRoute.Squad.ROWING_IN)
	spotted.global_position = Vector2(2.5, 2.5) * TILE
	spotted.stealth_state = MovementStep.Stealth.SUBMERGED
	var seconds: float = 0.0
	while boat.squad_state == PatrolRoute.Squad.ROWING_IN and seconds < 20.0:
		_tick()
		seconds += STEP_S
	assert_eq(boat.squad_state, PatrolRoute.Squad.ASHORE)
	assert_eq(brain.soldiers.size(), 3, "three soldiers step ashore")
	return spotted


func _soldier(index: int = 0) -> Creature:
	return brain.soldiers[index]


func _landing_px() -> Vector2:
	return IslandLayout.cell_center(boat.landing)


# The cell `tiles` from the landing, inland along the beach (toward its middle).
func _inland(tiles: int) -> Vector2:
	var middle: Vector2 = Vector2(BEACH.get_center())
	var step: int = 1 if middle.x > boat.landing.x else -1
	return Vector2(boat.landing) + Vector2(step * tiles, 0)


# Every soldier but `keep` stands far up the beach, idle (walking nowhere).
func _send_away(keep: Creature = null) -> void:
	var at: int = 0
	for soldier: Creature in brain.soldiers:
		if soldier == keep:
			continue
		soldier.position = Vector2(36.5 - at, 24.5) * TILE
		at += 1


# --- the landing ----------------------------------------------------------------------------------

func test_a_land_alert_docks_the_boat_and_the_dinghy_rows_in_at_2_tiles_per_second() -> void:
	var spotted := _player(Vector2(20, 15))
	var at: Vector2 = boat.position
	watch_signals(boat)
	brain.spot(spotted, &"sight")
	assert_eq(boat.state_name(), &"DOCKED")
	assert_signal_emit_count(boat, "patrol_alerted", 1)
	assert_true(terrain.terrain_at(boat.landing) == DataEnums.Terrain.BEACH, "the landing is beach")
	var row_s: float = SquadPlan.row_time_s(at / TILE, boat.landing, patrol.landing_speed_tiles_s)
	spotted.global_position = Vector2(2.5, 2.5) * TILE
	spotted.stealth_state = MovementStep.Stealth.SUBMERGED
	var seconds: float = 0.0
	while boat.squad_state == PatrolRoute.Squad.ROWING_IN and seconds < 20.0:
		_tick()
		seconds += STEP_S
	assert_almost_eq(seconds, row_s, STEP_S + TOLERANCE, "the row takes distance / 2 tiles/s")
	assert_eq(boat.position, at, "the boat stopped where it was")
	assert_eq(brain.soldiers.size(), 3)
	for soldier: Creature in brain.soldiers:
		assert_lte(soldier.position.distance_to(_landing_px()), 1.5 * TILE, "on the landing")
		assert_eq((soldier.brain as SearchCapture).squad, brain)
	assert_eq(watch.soldiers.size(), 3, "every soldier is a sight source")


# --- the escort -----------------------------------------------------------------------------------

func test_a_captive_is_led_to_the_dinghy_at_2_tiles_per_second_and_the_soldier_goes_back() -> void:
	_land_squad()
	var soldier := _soldier()
	_send_away(soldier)
	var body := _player(_inland(6))
	soldier.position = body.global_position - Vector2(TILE * 0.5, 0.0)
	(soldier.brain as SearchCapture).spot(soldier, body)
	var seconds: float = 0.0
	while not body.captive and seconds < 5.0:
		_tick([body])
		seconds += STEP_S
	assert_true(body.captive, "a 2 s touch captures")
	assert_almost_eq(seconds, 2.0, STEP_S + TOLERANCE)
	assert_eq(soldier.state_name(), &"ESCORT")
	var walk: float = 0.0
	while soldier.state_name() == &"ESCORT" and walk < 10.0:
		_tick([body])
		walk += STEP_S
		assert_lte(body.global_position.distance_to(soldier.position), 1.6 * TILE, "the captive follows its soldier")
	var gap_tiles: float = 6.0
	assert_almost_eq(walk, gap_tiles / MovementModel.DRAG_SPEED, 1.0, "at drag speed, about 3 s")
	assert_true(brain.seated.has(body), "sitting in the dinghy")
	assert_eq(body.global_position, _landing_px(), "on the landing cell")
	assert_ne(soldier.state_name(), &"ESCORT", "the soldier goes back to its plan")
	assert_ne(soldier.state_name(), &"CHASE")
	_run(2.0, [body])
	assert_eq(body.global_position, _landing_px(), "a seated captive stays put")


func test_a_captive_cannot_move() -> void:
	_land_squad()
	var body := _player(Vector2(boat.landing))
	CaptureRules.capture(body, _soldier(), patrol)
	brain.seat(body)
	body.intent = MoveIntent.create(Vector2.RIGHT, true, false, false)
	var at: Vector2 = body.global_position
	_run(1.0, [body])
	assert_eq(body.global_position, at)


# --- the touch ------------------------------------------------------------------------------------

func test_the_touch_resets_when_contact_breaks() -> void:
	_land_squad()
	var soldier := _soldier()
	_send_away(soldier)
	var body := _player(_inland(6))
	var brain_s := soldier.brain as SearchCapture
	soldier.position = body.global_position - Vector2(TILE * 0.5, 0.0)
	brain_s.spot(soldier, body)
	for i: int in 15:
		body.global_position = soldier.position + Vector2(TILE * 0.5, 0.0)
		_tick()
	assert_almost_eq(brain_s.touch_s, 1.5, 0.11)
	assert_false(body.captive)
	# Out of reach for a tick (still in sight): the count starts again.
	body.global_position = soldier.position + Vector2(3.0 * TILE, 0.0)
	_tick()
	assert_eq(brain_s.touch_s, 0.0)
	var seconds: float = 0.0
	while not body.captive and seconds < 5.0:
		body.global_position = soldier.position + Vector2(TILE * 0.5, 0.0)
		_tick()
		seconds += STEP_S
	assert_almost_eq(seconds, 2.0, STEP_S + TOLERANCE, "a fresh 2 s of touch")


func test_downed_and_dropped_bodies_are_never_targets() -> void:
	_land_squad()
	var soldier := _soldier()
	var downed := _player(_inland(2))
	downed.meters.downed = true
	(soldier.brain as SearchCapture).spot(soldier, downed)
	assert_ne(soldier.state_name(), &"CHASE")
	var dropped := _player(_inland(3))
	dropped.net.net_dropped = true
	(soldier.brain as SearchCapture).spot(soldier, dropped)
	assert_ne(soldier.state_name(), &"CHASE")
	assert_false(SearchCapture.can_target(downed))
	assert_false(SearchCapture.can_target(dropped))


# --- freeing --------------------------------------------------------------------------------------

func _seated_captive() -> PlayerBody:
	_land_squad()
	var body := _player(Vector2(boat.landing))
	CaptureRules.capture(body, _soldier(), patrol)
	brain.seat(body)
	return body


func _hold(helper: PlayerBody, captive: PlayerBody, seconds: float, each: Callable = Callable()) -> void:
	helper.intent = MoveIntent.create(Vector2.ZERO, false, false, true)
	for i: int in roundi(seconds / STEP_S):
		if each.is_valid():
			each.call(i)
		captive.advance(STEP_S)
		helper.advance(STEP_S)


func test_a_free_player_frees_a_seated_captive_with_a_1_s_hold_when_no_soldier_is_within_3_tiles() -> void:
	var captive := _seated_captive()
	_send_away()
	var helper := _player(Vector2(boat.landing) + Vector2(0.6, 0))
	assert_false(captive.free_handle.guard_near())
	_hold(helper, captive, 0.9)
	assert_true(captive.captive, "not yet")
	_hold(helper, captive, 0.2)
	assert_false(captive.captive, "freed after 1 s")
	assert_eq(captive.global_position, _landing_px(), "standing on the landing beach")


func test_a_soldier_coming_within_3_tiles_cancels_the_hold() -> void:
	var captive := _seated_captive()
	_send_away()
	var helper := _player(Vector2(boat.landing) + Vector2(0.6, 0))
	var guard := _soldier(1)
	_hold(helper, captive, 1.5, func(i: int) -> void:
		if i == 5:
			guard.position = captive.global_position + Vector2(2.0 * TILE, 0.0))
	assert_true(captive.captive, "the guard came back at 0.5 s: the captive stays a captive")
	assert_true(captive.free_handle.guard_near())


func test_a_captive_hauled_aboard_cannot_be_freed() -> void:
	var body := _player(Vector2(2, 2))
	CaptureRules.capture(body, boat, patrol, true)
	assert_true(body.captive)
	assert_false(body.can_be_freed())


# --- leaving --------------------------------------------------------------------------------------

func test_the_squad_leaves_with_its_captive_and_the_boat_resumes_its_lap() -> void:
	var captive := _seated_captive()
	var free_player := _player(Vector2(2, 2))
	free_player.global_position = Vector2(36.5, 15.5) * TILE
	free_player.stealth_state = MovementStep.Stealth.HIDDEN
	watch_signals(brain)
	var clock_at: float = brain.clock_s
	brain.plan.elapsed_s = patrol.search_duration_s
	var seconds: float = 0.0
	while boat.state_name() == &"DOCKED" and seconds < 60.0:
		_tick([captive])
		seconds += STEP_S
	assert_eq(boat.state_name(), &"LAP", "the boat resumes its lap")
	assert_eq(brain.clock_s, clock_at, "where it stopped")
	assert_eq(boat.squad_state, PatrolRoute.Squad.NONE)
	assert_signal_emitted(brain, "rowed_out")
	var rowed: Array = get_signal_parameters(brain, "rowed_out", 0)
	assert_eq(rowed[0], [captive] as Array[PlayerBody], "with its captive")
	for soldier: Creature in spawned:
		assert_true(not is_instance_valid(soldier) or soldier.is_queued_for_deletion(), "the soldiers went aboard")
