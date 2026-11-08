extends GutTest
## escape-routes with exactly 1 player, offline: build and launch the raft, swim alone, the
## discovery of the swim, and the run ending when the only player's crossing ends.

const ISLAND_SCENE: PackedScene = preload("res://scenes/levels/sandbar_island.tscn")
const SESSION_SCENE: PackedScene = preload("res://scenes/net/coop_session.tscn")
const SHELL_SCENE: PackedScene = preload("res://scenes/shell/game_shell.tscn")
const SETTINGS_PATH: String = "user://test_escape_routes_settings.cfg"

var island: SandbarIsland
var session: CoopSession
var routes: IslandRoutes
var started: Array = []


func before_each() -> void:
	NetManager.start_solo()
	WeatherManager.stop()
	WeatherManager.sky.start_at(0.0)
	started.clear()


func after_each() -> void:
	WeatherManager.stop()
	NetManager.leave()
	if FileAccess.file_exists(SETTINGS_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SETTINGS_PATH))


func _run() -> PlayerBody:
	island = ISLAND_SCENE.instantiate() as SandbarIsland
	add_child_autofree(island)
	session = SESSION_SCENE.instantiate() as CoopSession
	session.terrain = island.terrain
	session.climate = island.climate
	session.spawn_points = island.spawn_points(true)
	add_child_autofree(session)
	island.with_creatures = false
	island.furnish(session)
	session.start()
	routes = session.get_node("Routes") as IslandRoutes
	routes.route_started.connect(func(id: StringName, peers: Array[int]) -> void: started.append([id, peers]))
	var body := session.body(1)
	body.player_input.enabled = false
	return body


func _swimmer(weather: StringName, energy: float) -> PlayerBody:
	var body := _run()
	WeatherManager.sky.weather.apply(weather, 100.0, &"", -1.0)
	body.inventory.add(&"binoculars", 1)
	body.meters.energy = energy
	return body


# Uses the binoculars the way the inventory does: through the item's own use.
func _use_binoculars(body: PlayerBody) -> void:
	for i: int in body.inventory.slots.size():
		var slot := body.inventory.slots[i]
		if not slot.is_empty() and slot.item_id == &"binoculars":
			ItemUser.use(body, i, 0)
			return


func _fill(body: PlayerBody, site: BuildSite) -> void:
	body.global_position = site.global_position
	body.inventory.add(&"driftwood", 6)
	body.inventory.add(&"inner_tube", 2)
	body.inventory.add(&"rope", 3)


func test_solo_builds_and_launches_the_raft() -> void:
	var body := _run()
	_fill(body, session.get_node("RaftSite") as BuildSite)
	assert_true(session.deposit_for(1, NodePath("RaftSite")))
	body.crafter.advance(60.0)
	var raft := session.get_node("Raft") as Raft
	assert_not_null(raft)
	assert_eq(body.inventory.count_id(&"driftwood") + body.inventory.count_id(&"inner_tube") + body.inventory.count_id(&"rope"), 0)
	raft.interactable.interacted.emit(body)
	assert_eq(started.size(), 1)
	assert_eq(started[0][0], &"raft")
	assert_eq(started[0][1], [1])


func test_solo_swim_is_refused_in_a_squall() -> void:
	_use_binoculars(_swimmer(&"squall", 100.0))
	assert_eq(started.size(), 0)


func test_solo_swim_is_refused_at_energy_99() -> void:
	_use_binoculars(_swimmer(&"calm", 99.0))
	assert_eq(started.size(), 0)


func test_solo_swim_is_refused_while_bleeding() -> void:
	var body := _swimmer(&"calm", 100.0)
	body.meters.set_status(DataEnums.Status.BLEEDING, true)
	_use_binoculars(body)
	assert_eq(started.size(), 0)


func test_solo_swim_starts_in_calm_at_energy_100_and_keeps_the_binoculars() -> void:
	var body := _swimmer(&"calm", 100.0)
	_use_binoculars(body)
	assert_eq(started.size(), 1)
	assert_eq(started[0][0], &"binoculars_swim")
	assert_eq(started[0][1], [1])
	assert_eq(body.inventory.count_id(&"binoculars"), 1)
	assert_true(routes.has_left(1), "gone from the island")


func test_the_swim_is_discovered_when_a_squall_start_ends() -> void:
	var body := _swimmer(&"squall", 100.0)
	assert_false(routes.is_discovered(&"binoculars_swim"))
	assert_false(routes.start_for(1, &"binoculars_swim"), "refused before it is discovered")
	WeatherManager.sky.weather.apply(&"calm", 100.0, &"", -1.0)
	assert_true(routes.is_discovered(&"binoculars_swim"))
	assert_true(routes.start_for(1, &"binoculars_swim"))
	assert_eq(body.inventory.count_id(&"binoculars"), 1)


func test_solo_leaving_by_raft_lands_on_the_coast_cay() -> void:
	var shell := SHELL_SCENE.instantiate() as GameShell
	shell.settings_path = SETTINGS_PATH
	add_child_autofree(shell)
	(shell.screen as TitleScreen).solo_requested.emit()
	var body := shell.session.body(1)
	var site := shell.session.get_node("RaftSite") as BuildSite
	_fill(body, site)
	site.deposit(body)
	site.work(1.0)
	(shell.session.get_node("Raft") as Raft).interactable.interacted.emit(body)
	assert_eq(shell.flow, GameShell.Flow.RUN, "the crossing keeps the run open")
	var crossing := shell.crossings[0] as Crossing
	crossing.plan = CrossingPlan.create(60.0)
	CrossingRig.run(crossing, 60.0)
	await wait_frames(2)
	assert_eq(shell.flow, GameShell.Flow.RUN, "the solo player lands on the next island")
	assert_eq(shell.island.layout.id, &"coast_cay")
	assert_false(shell.session.body(1).left_island)
