extends GutTest
## island-pressure task 3.2, 1 player, offline, the real shell on the sandbar with its patrol boat
## (escape-routes "Starting a route", guardacostas-stealth "Launch in view", "A seen launch is a spot"):
## by day a raft launch is seen even with the boat away, does not start, spends nothing and docks the
## boat, whose squad searches from the player's cell; at night out of the light, in a squall, or by
## binoculars-and-swim the route starts. The boat's clock is set by hand, as test_capture_solo does.

const SHELL_SCENE: PackedScene = preload("res://scenes/shell/game_shell.tscn")
const HOUR_S: float = 30.0
## 14:00 and 22:00, seconds after 06:00.
const AFTERNOON_S: float = 8.0 * HOUR_S
const NIGHT_S: float = 16.0 * HOUR_S
const DT: float = 0.1
var settings_path: String = UserTmp.path("test_launch_spot_solo_settings.cfg")

var shell: GameShell
var session: CoopSession
var body: PlayerBody
var routes: IslandRoutes
var spawner: CreatureSpawner
var boat: Creature
var brain: PatrolRoute
var patrol: PatrolData
var alerts: Array[StringName] = []
var seen: Array = []


func before_each() -> void:
	NetManager.start_solo()
	WeatherManager.stop()
	WeatherManager.sky.start_at(0.0)
	alerts = []
	seen = []


func after_each() -> void:
	WeatherManager.sky.weather.rolls_enabled = true
	WeatherManager.sky.start_at(0.0)
	WeatherManager.stop()
	NetManager.leave()
	if FileAccess.file_exists(settings_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(settings_path))


func _start(at_s: float) -> void:
	shell = SHELL_SCENE.instantiate() as GameShell
	shell.settings_path = settings_path
	add_child_autofree(shell)
	(shell.screen as TitleScreen).solo_requested.emit()
	session = shell.session
	body = session.body(CoopSession.HOST_ID)
	body.player_input.enabled = false
	WeatherManager.sky.weather.rolls_enabled = false
	await wait_physics_frames(3)
	WeatherManager.stop()
	WeatherManager.sky.start_at(at_s)
	routes = session.get_node("Routes") as IslandRoutes
	routes.launch_seen.connect(func(id: StringName, peer: int) -> void: seen.append([id, peer]))
	spawner = session.get_node(NodePath(SandbarIsland.CREATURES_NAME)) as CreatureSpawner
	spawner.apply_phase(WeatherManager.phase())
	boat = spawner.creatures(&"patrol_boat")[0]
	brain = boat.brain as PatrolRoute
	patrol = boat.data.patrol
	boat.patrol_alerted.connect(func(cause: StringName, _at: Vector2) -> void: alerts.append(cause))


# The boat's loop clock, applied at once.
func _clock(seconds: float) -> void:
	brain.set_clock(seconds)
	boat.advance(0.0)


func _away() -> void:
	_clock(patrol.horizon_warning_s + patrol.route_lap_s + 1.0)
	assert_eq(brain.state, PatrolRoute.State.AWAY, "the boat is away beyond the horizon")


# The raft built from a full site, the player beside it.
func _built_raft() -> Raft:
	var site := session.get_node("RaftSite") as BuildSite
	for id: StringName in site.recipe.inputs:
		site.deposited[id] = site.recipe.inputs[id]
	site.work(1.0)
	var raft := session.get_node("Raft") as Raft
	body.global_position = raft.global_position
	return raft


func _launch(raft: Raft) -> void:
	raft.interactable.interacted.emit(body)


func _landed() -> bool:
	return boat.squad_state == PatrolRoute.Squad.ASHORE and brain.plan != null


# How far the boat's loop passes from `point_px` at its nearest, in pixels.
func _nearest_loop_px(point_px: Vector2) -> float:
	var loop: PatrolLoop = boat.view().loop
	var best: float = INF
	for sample: Vector2 in loop.samples:
		best = minf(best, (sample * 16.0).distance_to(point_px))
	return best


func _until(condition: Callable, max_s: float) -> bool:
	for i: int in roundi(max_s / DT):
		if condition.call():
			return true
		boat.advance(DT)
		for creature: Creature in spawner.creatures():
			if creature != boat:
				creature.advance(DT)
	return condition.call()


# escape-routes "Solo launch seen by day" and guardacostas-stealth "Solo by day", "Solo spotted at launch".
func test_solo_spotted_at_launch_by_day() -> void:
	await _start(AFTERNOON_S)
	_away()
	var raft := _built_raft()
	var cell: Vector2i = CreatureNav.cell_of(body.global_position)
	_launch(raft)
	assert_eq(seen, [[&"raft", 1]], "the launch was seen")
	assert_false(routes.has_left(1), "the player stays on the island")
	assert_true(is_instance_valid(raft) and raft.is_inside_tree(), "the raft stays on the beach")
	assert_eq(raft.integrity, 100.0, "at 100")
	assert_eq(alerts, [&"launch"] as Array[StringName], "the boat raised an alert, cause launch")
	assert_eq(brain.state, PatrolRoute.State.DOCKED, "it docks")
	assert_eq(boat.squad_state, PatrolRoute.Squad.ROWING_IN, "its dinghy rows in")
	assert_almost_eq(boat.position.distance_to(body.global_position), _nearest_loop_px(body.global_position), 16.0, "from the loop point nearest the raft, not from off the map")
	assert_true(_until(_landed, 60.0), "the squad lands")
	assert_eq(brain.plan.last_known(), cell, "its search starts at the player's cell")


func test_a_launch_seen_while_the_squad_is_ashore_changes_no_alert() -> void:
	await _start(AFTERNOON_S)
	_away()
	var raft := _built_raft()
	_launch(raft)
	assert_true(_until(_landed, 60.0))
	var serial: int = boat.alert_serial
	_launch(raft)
	assert_eq(brain.state, PatrolRoute.State.DOCKED, "still docked")
	assert_true(brain.squad_ashore(), "the squad stays ashore")
	assert_eq(seen.size(), 2, "the second launch was seen too")
	assert_false(routes.has_left(1))
	assert_lte(boat.alert_serial, serial + 1, "at most a new sighting")


func test_solo_at_night_out_of_the_light() -> void:
	await _start(NIGHT_S)
	_clock(patrol.horizon_warning_s + 10.0)
	assert_eq(brain.state, PatrolRoute.State.LAP)
	var raft := _built_raft()
	assert_false(brain.lights(body.global_position), "the sandbar's raft site is never lit")
	_launch(raft)
	assert_eq(seen, [], "not seen")
	assert_true(routes.has_left(1), "the raft route started")
	assert_eq(routes.route_left_by(1), &"raft")


func test_solo_at_night_in_the_light() -> void:
	await _start(NIGHT_S)
	_clock(patrol.horizon_warning_s + 10.0)
	var raft := _built_raft()
	# The cone put on the player at the raft: the boat 4 tiles south, its beam pointing north.
	boat.position = body.global_position + Vector2(0.0, 4.0 * 16.0)
	boat.beam = -90.0
	boat.light_on = true
	_launch(raft)
	assert_eq(seen, [[&"raft", 1]], "seen in the light")
	assert_false(routes.has_left(1))


func test_solo_in_a_squall() -> void:
	await _start(AFTERNOON_S)
	WeatherManager.sky.weather.apply(&"squall", 100.0, &"", -1.0)
	boat.advance(DT)
	assert_eq(brain.state, PatrolRoute.State.AWAY, "the boat is in port")
	var raft := _built_raft()
	_launch(raft)
	assert_eq(seen, [], "nobody sees a launch into the squall")
	assert_eq(routes.route_left_by(1), &"raft", "the raft route starts")


func test_a_swim_is_not_a_launch() -> void:
	await _start(AFTERNOON_S)
	_away()
	body.inventory.add(&"binoculars", 1)
	for i: int in body.inventory.slots.size():
		var slot := body.inventory.slots[i]
		if not slot.is_empty() and slot.item_id == &"binoculars":
			ItemUser.use(body, i, 0)
			break
	assert_eq(seen, [], "a swim is not seen at launch")
	assert_eq(routes.route_left_by(1), &"binoculars_swim", "the swim starts")
