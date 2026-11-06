extends GutTest
## crafting-inventory "Recipes" and "Workbench": a craft takes the recipe's time at a station in
## reach and consumes inputs only when it completes.

const PLAYER_SCENE: PackedScene = preload("res://scenes/player/player.tscn")

var body: PlayerBody
var bench: Workbench
var recipe: RecipeData


func before_each() -> void:
	body = PLAYER_SCENE.instantiate() as PlayerBody
	add_child_autofree(body)
	bench = Workbench.new()
	bench.position = Vector2(8, 0)
	add_child_autofree(bench)
	recipe = RecipeData.new()
	recipe.id = &"fixture_bench_recipe"
	recipe.station = RecipeData.Station.WORKBENCH
	recipe.inputs = {&"driftwood": 2} as Dictionary[StringName, int]
	recipe.time_s = 10.0
	recipe.output_item_id = &"dry_grass"
	recipe.output_count = 1
	body.crafter.register(recipe)


func test_workbench_recipe_consumes_inputs_after_its_time() -> void:
	body.inventory.add(&"driftwood", 3)
	assert_true(body.crafter.start(recipe, bench))
	body.crafter.advance(9.9)
	assert_eq(body.inventory.count_id(&"driftwood"), 3, "nothing consumed yet")
	body.crafter.advance(0.2)
	assert_eq(body.inventory.count_id(&"driftwood"), 1)
	assert_eq(body.inventory.count_id(&"dry_grass"), 1)
	assert_false(body.crafter.is_crafting())


func test_missing_input_starts_nothing() -> void:
	body.inventory.add(&"driftwood", 1)
	assert_false(body.crafter.start(recipe, bench))
	assert_false(body.crafter.is_crafting())
	assert_eq(body.inventory.count_id(&"driftwood"), 1)


func test_a_tool_the_recipe_needs_must_be_carried() -> void:
	recipe.tools = [DataEnums.Capability.OPEN_COCONUT] as Array[DataEnums.Capability]
	body.inventory.add(&"driftwood", 2)
	assert_false(body.crafter.start(recipe, bench))
	body.inventory.add(&"knife", 1)
	assert_true(body.crafter.start(recipe, bench))
	body.crafter.advance(10.0)
	assert_eq(body.inventory.slots[body.inventory.capability_slot(DataEnums.Capability.OPEN_COCONUT)].uses_left, 39)


func test_crafting_sets_the_hunger_state() -> void:
	body.inventory.add(&"driftwood", 2)
	body.crafter.start(recipe, bench)
	assert_true(body.crafter.is_crafting())
	assert_true(body._meter_context().crafting)


func test_walking_away_cancels() -> void:
	body.inventory.add(&"driftwood", 2)
	body.crafter.start(recipe, bench)
	body.position = Vector2(100, 0)
	body.crafter.advance(20.0)
	assert_false(body.crafter.is_crafting())
	assert_eq(body.inventory.count_id(&"driftwood"), 2)


func test_it_must_be_in_reach_to_start() -> void:
	body.inventory.add(&"driftwood", 2)
	body.position = Vector2(100, 0)
	assert_false(body.crafter.start(recipe, bench))
