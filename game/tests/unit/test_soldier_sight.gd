extends GutTest
## guardacostas-capture, group 5 (design.md §5, spec "Soldier sight"): a soldier's cone, 6 tiles and
## 120° by day and a 5-tile, 60° flashlight at night, fills the same spot meter as the searchlight
## through PatrolWatch. A hidden player is never seen, fog blinds every soldier, a spot sends the
## soldier running at the player, and a 6 tiles/s run beats its 5 tiles/s chase once the player is
## past its sight length. Ticks are 0.1 s on the brain, 1/60 s in the pure footrace.

const PLAYER_SCENE: PackedScene = preload("res://scenes/player/player.tscn")
const FOG: WeatherData = preload("res://tests/fixtures/content/weather/fog_test.tres")
const STEP_S: float = 0.1
const TICK: float = 1.0 / 60.0
const TILE: float = 16.0
const TOLERANCE: float = 0.000001
const DAY := DataEnums.DayPhase.DAY
const NIGHT := DataEnums.DayPhase.NIGHT

var patrol: PatrolData
var island: SmallIsland
var world: CreatureWorld
var root: Node2D
var watch: PatrolWatch
var soldier: Creature


func before_each() -> void:
	patrol = (GameState.content.get_entry(&"creatures", &"patrol_boat") as CreatureData).patrol
	island = SmallIsland.make(SmallIsland.PLAIN)
	world = CreatureWorld.new()
	world.terrain = island.terrain
	world.nav = CreatureNav.build(island.terrain, island.size)
	world.phase = DAY
	world.weather_override = GameState.content.get_entry(&"weather", &"calm") as WeatherData
	root = Node2D.new()
	add_child_autofree(root)
	watch = PatrolWatch.new()
	watch.world = world
	soldier = Creature.make(GameState.content.get_entry(&"creatures", &"shore_soldier") as CreatureData)
	soldier.world = world
	root.add_child(soldier)
	(soldier.brain as SearchCapture).patrol = patrol
	soldier.position = Vector2(17.5, 19.5) * TILE
	soldier.facing = Vector2.RIGHT
	watch.soldiers.append(soldier)


func _player(at_tiles: Vector2) -> PlayerBody:
	var body := PLAYER_SCENE.instantiate() as PlayerBody
	add_child_autofree(body)
	body.player_input.enabled = false
	body.auto_advance = false
	body.global_position = at_tiles * TILE
	return body


# The watch alone (the soldier stands still, facing right): `seconds` of 0.1 s ticks.
func _watch_for(seconds: float) -> void:
	for i: int in roundi(seconds / STEP_S):
		watch.step(STEP_S)


# --- the cones ------------------------------------------------------------------------------------

func test_by_day_the_cone_is_6_tiles_and_120_degrees() -> void:
	var cone := SightCone.for_soldier(patrol, DAY)
	assert_almost_eq(cone.range_tiles, 6.0, TOLERANCE)
	assert_almost_eq(cone.cone_deg, 120.0, TOLERANCE)
	var eye := Vector2(10.0, 10.0)
	assert_true(cone.sees(eye + Vector2(4.0, 0.0), eye, Vector2.RIGHT), "4 tiles ahead")
	assert_true(cone.sees(eye + Vector2(6.0, 0.0), eye, Vector2.RIGHT), "6 tiles ahead")
	assert_false(cone.sees(eye + Vector2(6.1, 0.0), eye, Vector2.RIGHT), "past 6 tiles")
	assert_true(cone.sees(eye + Vector2.RIGHT.rotated(deg_to_rad(59.0)) * 4.0, eye, Vector2.RIGHT), "59° off")
	assert_false(cone.sees(eye + Vector2.RIGHT.rotated(deg_to_rad(61.0)) * 4.0, eye, Vector2.RIGHT), "61° off")
	assert_false(cone.sees(eye + Vector2(-3.0, 0.0), eye, Vector2.RIGHT), "behind")


func test_at_night_it_is_a_5_tile_60_degree_flashlight() -> void:
	var cone := SightCone.for_soldier(patrol, NIGHT)
	assert_almost_eq(cone.range_tiles, 5.0, TOLERANCE)
	assert_almost_eq(cone.cone_deg, 60.0, TOLERANCE)
	var eye := Vector2(10.0, 10.0)
	assert_true(cone.sees(eye + Vector2(5.0, 0.0), eye, Vector2.RIGHT))
	assert_false(cone.sees(eye + Vector2(6.0, 0.0), eye, Vector2.RIGHT), "6 tiles is past the flashlight")
	assert_true(cone.sees(eye + Vector2.RIGHT.rotated(deg_to_rad(29.0)) * 3.0, eye, Vector2.RIGHT))
	assert_false(cone.sees(eye + Vector2.RIGHT.rotated(deg_to_rad(31.0)) * 3.0, eye, Vector2.RIGHT))


# --- the shared spot meter ------------------------------------------------------------------------

# Spec "Seen on open sand": 4 tiles in front by day, spotted at 2 s, and the soldier runs at them.
func test_a_player_4_tiles_in_front_by_day_is_spotted_at_2_s_and_chased() -> void:
	var body := _player(Vector2(21.5, 19.5))
	_watch_for(1.9)
	assert_eq(soldier.state_name(), &"SEARCH", "not yet")
	assert_almost_eq(body.spot_meter.value, 1.9, 0.0001)
	_watch_for(0.1)
	assert_eq(soldier.state_name(), &"CHASE", "spotted at 2 s: the soldier runs at them")
	assert_eq((soldier.brain as SearchCapture).target, body)


# Spec "Crouching in scrub": a hidden player's meter never fills.
func test_a_hidden_player_in_front_is_never_seen() -> void:
	var body := _player(Vector2(20.5, 19.5))
	body.stealth_state = MovementStep.Stealth.HIDDEN
	_watch_for(5.0)
	assert_eq(body.spot_meter.value, 0.0)
	assert_eq(soldier.state_name(), &"SEARCH")


# Spec "A flashlight at night": 6 tiles in front at night stays at 0.
func test_at_night_a_player_6_tiles_in_front_is_not_seen() -> void:
	world.phase = NIGHT
	var body := _player(Vector2(23.5, 19.5))
	_watch_for(3.0)
	assert_eq(body.spot_meter.value, 0.0)
	assert_eq(soldier.state_name(), &"SEARCH")


func test_in_fog_no_soldier_sees_anyone() -> void:
	world.weather_override = FOG
	var body := _player(Vector2(20.5, 19.5))
	_watch_for(3.0)
	assert_eq(body.spot_meter.value, 0.0)


func test_a_boats_light_and_a_soldier_fill_one_meter_once() -> void:
	world.phase = NIGHT
	var boat := Creature.make(GameState.content.get_entry(&"creatures", &"patrol_boat") as CreatureData)
	boat.world = world
	root.add_child(boat)
	watch.boats.append(boat)
	var route := boat.brain as PatrolRoute
	route.set_clock(patrol.horizon_warning_s + 5.0)
	boat.advance(0.0)
	var body := _player(Vector2(20.5, 19.5))
	# Put the body where the boat's light falls, and the soldier 3 tiles from it, facing it.
	var lit_at: Vector2 = Vector2.ZERO
	for x: int in range(10, 30):
		for y: int in range(10, 30):
			var spot := Vector2(x + 0.5, y + 0.5) * TILE
			if route.lights(spot):
				lit_at = spot
	assert_ne(lit_at, Vector2.ZERO, "the boat lights some cell")
	body.global_position = lit_at
	soldier.position = lit_at - Vector2(3.0, 0.0) * TILE
	soldier.facing = Vector2.RIGHT
	assert_true((soldier.brain as SearchCapture).sees(soldier, body.global_position))
	watch.step(1.0)
	assert_almost_eq(body.spot_meter.value, 1.0, 0.0001, "1 s of meter, not 2: one meter, filled once")


func test_a_downed_player_is_never_chased_by_a_soldier() -> void:
	var body := _player(Vector2(21.5, 19.5))
	body.meters.downed = true
	_watch_for(2.0)
	assert_eq(soldier.state_name(), &"SEARCH", "soldiers ignore downed bodies")


# --- the footrace -----------------------------------------------------------------------------------

# Spec "Outrunning a soldier": spotted 3 tiles behind by day, the player runs straight away at
# 6 tiles/s; the soldier at 5 falls behind and the chase breaks once they are past 6 tiles.
func test_a_runner_beats_the_chase_once_past_6_tiles() -> void:
	var cone := SightCone.for_soldier(patrol, DAY)
	var eye := Vector2(0.0, 0.0)
	var runner := Vector2(3.0, 0.0)
	var seconds: float = 0.0
	var no_senses: Array[DataEnums.Sense] = []
	while cone.chase_holds(runner, eye, false, no_senses) and seconds < 10.0:
		eye.x += patrol.soldier_chase_tiles_s * TICK
		runner.x += MovementModel.RUN_SPEED * TICK
		seconds += TICK
	assert_almost_eq(seconds, 3.0, TICK + TOLERANCE, "3 tiles of lead grow to 6 in 3 s")
	assert_false(cone.chase_holds(Vector2(1.0, 0.0), Vector2.ZERO, true, no_senses), "hiding breaks it at once")
	assert_false(cone.chase_holds(Vector2(1.0, 0.0), Vector2.ZERO, false, [DataEnums.Sense.SIGHT] as Array[DataEnums.Sense]), "fog breaks it")


func test_on_the_brain_the_chase_breaks_past_6_tiles_into_a_search_where_it_lost_them() -> void:
	var body := _player(Vector2(20.5, 19.5))
	var brain := soldier.brain as SearchCapture
	brain.spot(soldier, body)
	assert_eq(soldier.state_name(), &"CHASE")
	# The player is suddenly 7 tiles off: the soldier loses them and searches where it last saw them.
	var seen_at: Vector2 = body.global_position
	soldier.advance(STEP_S)
	body.global_position = soldier.position + Vector2(7.0, 0.0) * TILE
	soldier.advance(STEP_S)
	assert_ne(soldier.state_name(), &"CHASE", "the chase broke")
	assert_null(brain.target)
	assert_eq(brain.lost_at, CreatureNav.cell_of(seen_at), "where it last saw them")
