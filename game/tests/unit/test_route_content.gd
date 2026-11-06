extends GutTest
## escape-routes "Sandbar routes as data": the raft and binoculars-and-swim are .tres files.


func _route(id: StringName) -> RouteData:
	return GameState.content.get_entry(&"routes", id) as RouteData


func test_the_raft_route_loads_from_data() -> void:
	var route := _route(&"raft")
	assert_not_null(route)
	assert_eq(route.capacity_mode, RouteData.CapacityMode.ALL)
	assert_eq(route.starter_kind, RouteData.StarterKind.BUILD_SITE)
	assert_eq(route.starter_id, &"raft")
	assert_true(route.starts_discovered)
	assert_eq(route.board_radius_tiles, 5)
	assert_false(route.name_es.is_empty())
	assert_false(route.name_en.is_empty())


func test_binoculars_and_swim_loads_from_data() -> void:
	var route := _route(&"binoculars_swim")
	assert_not_null(route)
	assert_eq(route.capacity_mode, RouteData.CapacityMode.PER_SWIMMER)
	assert_eq(route.starter_kind, RouteData.StarterKind.ITEM_USE)
	assert_eq(route.starter_id, &"binoculars")
	assert_false(route.starts_discovered)
	assert_eq(route.discover_conditions.size(), 1)
	assert_eq(route.discover_conditions[0].kind, ConditionData.Kind.WEATHER_IS_CLEAR)
	assert_eq(route.rider_requirements.size(), 2)
	assert_true(route.riders_swim)
	assert_false(route.name_es.is_empty())


func test_the_raft_recipe_takes_6_driftwood_2_tubes_3_rope() -> void:
	var recipe := GameState.content.get_entry(&"recipes", &"raft") as RecipeData
	assert_not_null(recipe)
	assert_eq(recipe.inputs, {&"driftwood": 6, &"inner_tube": 2, &"rope": 3})
	assert_true(recipe.build_site)
	assert_eq(recipe.time_s, 60.0)
	assert_eq(recipe.output_kind, RecipeData.OutputKind.VESSEL)


func test_binoculars_start_the_swim_and_are_not_used_up() -> void:
	var item := GameState.content.get_entry(&"items", &"binoculars") as ItemData
	assert_not_null(item)
	assert_eq(item.uses.size(), 1)
	assert_false(item.uses[0].spends_use)
	assert_eq(item.uses[0].effects[0].kind, EffectData.Kind.START_ROUTE)
	assert_eq(item.uses[0].effects[0].ref_id, &"binoculars_swim")


func test_route_content_passes_the_check() -> void:
	var lines: PackedStringArray = ContentValidator.validate(GameState.content)
	assert_eq(lines.size(), 0, "\n".join(lines))
