extends GutTest
## vessel-car-board data: the two appended vessels, the arrival scatter field and the fixture
## routes the crossing tests use.


func after_each() -> void:
	FixtureRoutes.take_out()


func test_car_and_board_are_appended_after_the_dolphin_pod() -> void:
	assert_eq(int(DataEnums.Vessel.DOLPHIN_POD), 4)
	assert_eq(int(DataEnums.Vessel.CAR), 5)
	assert_eq(int(DataEnums.Vessel.BOARD), 6)
	assert_eq(DataEnums.Vessel.size(), 7)


func test_a_new_route_scatters_zero_to_five_tiles() -> void:
	assert_eq(RouteData.new().arrival_scatter_tiles, Vector2i(0, 5))


func test_shipped_routes_load_unchanged() -> void:
	var raft := load("res://resources/routes/raft.tres") as RouteData
	assert_eq(raft.vessel, DataEnums.Vessel.RAFT)
	assert_eq(raft.vessel_integrity, 100)
	assert_true(raft.vessel_kept_on_arrival)
	assert_eq(raft.arrival_scatter_tiles, Vector2i(0, 5))
	var swim := load("res://resources/routes/binoculars_swim.tres") as RouteData
	assert_eq(swim.vessel, DataEnums.Vessel.SWIMMERS)
	assert_false(swim.vessel_kept_on_arrival)
	assert_eq(swim.arrival_scatter_tiles, Vector2i(0, 5))


func test_fixture_routes_are_found_by_id_while_put_in() -> void:
	FixtureRoutes.put_in()
	var board := GameState.content.get_entry(&"routes", &"test_board") as RouteData
	assert_not_null(board)
	assert_eq(board.vessel, DataEnums.Vessel.BOARD)
	assert_eq(board.vessel_integrity, 60)
	assert_eq(board.capacity_mode, RouteData.CapacityMode.PER_SWIMMER)
	assert_eq(board.arrival_scatter_tiles, Vector2i(10, 20))
	assert_false(board.vessel_kept_on_arrival)
	assert_eq(board.dump_triggers, [RouteData.DumpTrigger.SQUALL, RouteData.DumpTrigger.SHARK_ATTACK] as Array[RouteData.DumpTrigger])
	var car := GameState.content.get_entry(&"routes", &"test_car") as RouteData
	assert_not_null(car)
	assert_eq(car.vessel, DataEnums.Vessel.CAR)
	assert_eq(car.vessel_integrity, 160)
	assert_almost_eq(car.squall_damage_multiplier, 1.5, 0.001)


func test_fixture_routes_are_gone_after_take_out() -> void:
	FixtureRoutes.put_in()
	FixtureRoutes.take_out()
	assert_null(GameState.content.get_entry(&"routes", &"test_board"))
	assert_null(GameState.content.get_entry(&"routes", &"test_car"))


func test_the_catalog_folder_never_lists_the_fixtures() -> void:
	FixtureRoutes.put_in()
	var ids := GameState.content.list_ids(&"routes")
	assert_false(ids.has(&"test_board"))
	assert_false(ids.has(&"test_car"))
	assert_false(GameState.content.has_entry(&"routes", &"test_board"))
