extends GutTest
## crossing "Arrival scatter" and "Beaching by vessel" (vessel-car-board design D7, D8) with exactly
## 1 player, offline, through the shell: a board crossing lands its rider on the first landing cell
## and leaves nothing on the beach; the arrival check keeps a host-picked cell; a cell that is not
## land falls back to the landing cells; only a raft kept on arrival is beached.

const SHELL_SCENE: PackedScene = preload("res://scenes/shell/game_shell.tscn")
const SETTINGS_PATH: String = "user://test_arrival_by_vessel_settings.cfg"
const COAST: StringName = &"coast_cay"


func before_each() -> void:
	NetManager.start_solo()
	WeatherManager.stop()
	WeatherManager.sky.start_at(0.0)
	FixtureRoutes.put_in()


func after_each() -> void:
	WeatherManager.stop()
	NetManager.leave()
	FixtureRoutes.take_out()
	if FileAccess.file_exists(SETTINGS_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SETTINGS_PATH))


func _shell() -> GameShell:
	var shell := SHELL_SCENE.instantiate() as GameShell
	shell.settings_path = SETTINGS_PATH
	add_child_autofree(shell)
	(shell.screen as TitleScreen).solo_requested.emit()
	shell.session.body(1).player_input.enabled = false
	return shell


func _result(route_id: StringName, peer: int, integrity: float, broken: bool = false) -> CrossingResult:
	var result := CrossingResult.new()
	result.route_id = route_id
	result.integrity = integrity
	result.broken = broken
	result.riders[peer] = {"health": 100.0, "energy": 80.0, "aboard": true, "dead": false}
	return result


# --- the arrival check --------------------------------------------------------------------------

func test_the_arrival_check_keeps_a_host_picked_cell() -> void:
	var clean: Variant = CoopSession.checked_arrivals({1: {"health": 50.0, "energy": 40.0, "cell": Vector2i(10, 42)}, 2: {"health": 60.0, "energy": 30.0}})
	assert_not_null(clean)
	if clean == null:
		return
	assert_eq((clean as Dictionary)[1].get("cell"), Vector2i(10, 42))
	assert_false((clean as Dictionary)[2].has("cell"), "a cell is optional")


func test_a_cell_of_another_type_refuses_the_arrivals() -> void:
	for bad: Variant in ["10,42", Vector2(10.0, 42.0), [10, 42], null]:
		assert_null(CoopSession.checked_arrivals({1: {"health": 50.0, "energy": 40.0, "cell": bad}}), "cell %s" % [bad])


# --- beaching -----------------------------------------------------------------------------------

func test_only_a_raft_kept_on_arrival_is_beached() -> void:
	var travel := IslandTravel.new()
	autofree(travel)
	travel._results = [_result(&"raft", 1, 70.0), _result(&"test_car", 2, 95.0), _result(&"test_board", 3, 50.0)] as Array[CrossingResult]
	assert_eq(travel._beached_integrity(), 70.0, "the raft at 70, not the car at 95 or a board")
	travel._results = [_result(&"test_car", 1, 95.0), _result(&"test_board", 2, 50.0), _result(&"binoculars_swim", 3, 0.0)] as Array[CrossingResult]
	assert_eq(travel._beached_integrity(), 0.0, "no raft, nothing beached")
	travel._results = [_result(&"raft", 1, 70.0, true)] as Array[CrossingResult]
	assert_eq(travel._beached_integrity(), 0.0, "a broken raft is lost")


# --- solo through the shell ---------------------------------------------------------------------

func test_solo_board_rider_lands_on_the_first_landing_cell_and_leaves_nothing() -> void:
	var shell := _shell()
	var body := shell.session.body(1)
	var routes := shell.session.get_node("Routes") as IslandRoutes
	routes.offered.append(GameState.content.get_entry(&"routes", &"test_board") as RouteData)
	routes.discovered[&"test_board"] = true
	body.inventory.add(&"tarp", 1)
	shell.session.climate.weather_id = &"trade_wind"
	assert_true(shell.session.start_route_for(1, &"test_board"))
	assert_eq(body.inventory.count_id(&"tarp"), 0, "the board was spent")
	var crossing := shell.crossings[0] as Crossing
	assert_true(crossing.is_board_route())
	crossing.plan = CrossingPlan.create(60.0, [] as Array[RefCounted])
	crossing.boards[1].value = 30.0
	CrossingRig.run(crossing, 60.0)
	await wait_process_frames(2)
	assert_eq(shell.island.layout.id, COAST)
	assert_eq(body.position, IslandLayout.cell_center(shell.island.built.landing_cells()[0]), "alone, on the first landing cell")
	assert_null(shell.session.get_node_or_null("Raft"), "the board is gone, no raft beached")
	assert_not_null(shell.session.get_node_or_null("RaftSite"), "the raft site is empty")


func test_a_cell_that_is_not_land_falls_back_to_the_landing_cells() -> void:
	var shell := _shell()
	shell.travel._load(COAST, {1: {"health": 90.0, "energy": 50.0, "cell": Vector2i(0, 0)}}, 0.0)
	await wait_process_frames(2)
	assert_eq(shell.island.layout.id, COAST)
	assert_eq(shell.session.body(1).position, IslandLayout.cell_center(shell.island.built.landing_cells()[0]))


func test_a_sent_land_cell_is_where_the_rider_stands() -> void:
	var shell := _shell()
	var beach := Vector2i(20, 26)
	shell.travel._load(COAST, {1: {"health": 90.0, "energy": 50.0, "cell": beach}}, 0.0)
	await wait_process_frames(2)
	assert_eq(shell.island.built.terrain.cells.get(beach), DataEnums.Terrain.BEACH)
	assert_eq(shell.session.body(1).position, IslandLayout.cell_center(beach))
