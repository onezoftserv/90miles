extends GutTest
## crafting-inventory content: the Milestone A items, recipes and tuning load, validate and
## carry the numbers the spec and survival-meters name.

const M := DataEnums.Meter


func _item(id: StringName) -> ItemData:
	return GameState.content.get_entry(&"items", id) as ItemData


func _recipe(id: StringName) -> RecipeData:
	return GameState.content.get_entry(&"recipes", id) as RecipeData


func test_crafting_files_validate() -> void:
	for id: StringName in [&"coco", &"rain_cup", &"driftwood", &"dry_grass", &"knife", &"tarp"]:
		assert_not_null(_item(id), "items/%s" % id)
	for id: StringName in [&"fire", &"rain_catcher"]:
		assert_not_null(_recipe(id), "recipes/%s" % id)
	for line: String in ContentValidator.validate(GameState.content):
		assert_false(line.begins_with("items/") or line.begins_with("recipes/"), line)


func test_coco_numbers() -> void:
	var coco := _item(&"coco")
	assert_eq(coco.durability, 1)
	var drink: ItemUseData = coco.uses[0]
	assert_eq(drink.effects[0].meter, M.THIRST)
	assert_eq(drink.effects[0].amount, 15.0)
	assert_eq(drink.effects[1].meter, M.HUNGER)
	assert_eq(drink.effects[1].amount, 5.0)
	var needs: ConditionData = drink.conditions[0]
	assert_eq(needs.kind, ConditionData.Kind.HAS_CAPABILITY)
	assert_eq(needs.capability, DataEnums.Capability.OPEN_COCONUT)
	assert_eq(needs.scope, ConditionData.Scope.ACTOR)
	assert_true(needs.consume)


func test_rain_cup_numbers() -> void:
	var cup := _item(&"rain_cup")
	assert_eq(cup.uses[0].effects[0].meter, M.THIRST)
	assert_eq(cup.uses[0].effects[0].amount, 25.0)
	var revive: ItemUseData = cup.uses[1]
	assert_true(revive.can_target_others)
	assert_eq(revive.effects[0].kind, EffectData.Kind.REVIVE)


func test_fire_recipe() -> void:
	var fire := _recipe(&"fire")
	assert_eq(fire.inputs, {&"driftwood": 3} as Dictionary[StringName, int])
	assert_eq(fire.input_tags, {DataEnums.ItemTag.TINDER: 1} as Dictionary[DataEnums.ItemTag, int])
	assert_eq(fire.station, RecipeData.Station.NONE)
	assert_true(fire.build_site)
	assert_eq(fire.output_kind, RecipeData.OutputKind.STRUCTURE)
	assert_eq(fire.time_s, 30.0)
	assert_eq(fire.fast_tool, DataEnums.Capability.LIGHT_FIRE)


func test_knife() -> void:
	var knife := _item(&"knife")
	assert_true(knife.capabilities.has(DataEnums.Capability.OPEN_COCONUT))
	assert_eq(knife.durability, 40)


func test_crafting_tuning() -> void:
	var tuning: CraftingTuning = preload("res://resources/crafting_tuning.tres")
	assert_eq(tuning.weight_limit, 30.0)
	assert_eq(tuning.fire_burn_s, 360.0)
	assert_eq(tuning.rain_fill_s, 30.0)
	assert_eq(tuning.rain_weather_id, &"squall")
