extends GutTest
## island-stop, the vessel recipes as data (escape-routes "Mending a built raft", "Raft fittings"):
## the content check accepts a mend and a fitting worked on the raft, and refuses a mend that
## restores nothing, a fitting that does nothing, one placed at a bench or as a site, and a
## fitting modifier not scoped to the vessel. The appended modifier stats keep the old numbers.


func _recipe(kind: RecipeData.OutputKind, delta: float) -> RecipeData:
	var recipe := RecipeData.new()
	recipe.id = &"fixture"
	recipe.name_es = "Prueba"
	recipe.output_kind = kind
	recipe.station = RecipeData.Station.NONE
	recipe.integrity_delta = delta
	return recipe


func _errors(recipe: RecipeData) -> PackedStringArray:
	return ContentValidator._check_vessel_recipe("recipes/fixture", recipe)


func test_the_shipped_mend_validates() -> void:
	var mend := GameState.content.get_entry(&"recipes", &"raft_mend") as RecipeData
	assert_not_null(mend)
	assert_eq(_errors(mend), PackedStringArray())
	assert_eq(mend.output_kind, RecipeData.OutputKind.VESSEL_REPAIR)
	assert_eq(mend.inputs, {&"driftwood": 1, &"rope": 1} as Dictionary[StringName, int])
	assert_eq(mend.time_s, 10.0)
	assert_eq(mend.integrity_delta, 20.0)
	assert_eq(mend.skill, DataEnums.Skill.BUILDING)
	assert_eq(mend.skill_speed_multiplier, 2.0)
	assert_eq(mend.name_es, "Remiendo")


func test_a_mend_that_restores_nothing_is_refused() -> void:
	assert_eq(_errors(_recipe(RecipeData.OutputKind.VESSEL_REPAIR, 0.0)).size(), 1)


func test_a_fitting_needs_a_bonus_or_a_vessel_modifier() -> void:
	assert_eq(_errors(_recipe(RecipeData.OutputKind.VESSEL_UPGRADE, 20.0)), PackedStringArray(), "a bonus is enough")
	var shade := _recipe(RecipeData.OutputKind.VESSEL_UPGRADE, 0.0)
	assert_eq(_errors(shade).size(), 1, "nothing at all")
	var modifier := ModifierData.new()
	modifier.stat = ModifierData.Stat.VESSEL_DECK_SHADE
	modifier.op = ModifierData.Op.SET
	modifier.value = 1.0
	modifier.scope = ModifierData.Scope.VESSEL
	shade.vessel_modifiers = [modifier]
	assert_eq(_errors(shade), PackedStringArray(), "a vessel modifier is enough")
	modifier.scope = ModifierData.Scope.HOLDER
	assert_eq(_errors(shade).size(), 1, "but scoped to the vessel")


func test_a_vessel_recipe_is_never_worked_at_a_bench_or_as_a_site() -> void:
	var at_bench := _recipe(RecipeData.OutputKind.VESSEL_REPAIR, 20.0)
	at_bench.station = RecipeData.Station.WORKBENCH
	assert_eq(_errors(at_bench).size(), 1)
	var as_site := _recipe(RecipeData.OutputKind.VESSEL_REPAIR, 20.0)
	as_site.build_site = true
	assert_eq(_errors(as_site).size(), 1)


func test_other_recipes_are_left_alone() -> void:
	var fire := GameState.content.get_entry(&"recipes", &"fire") as RecipeData
	assert_eq(_errors(fire), PackedStringArray())


func test_the_appended_stats_keep_the_old_numbers() -> void:
	assert_eq(ModifierData.Stat.SONG_MORALE, 22, "the last stat before island-stop")
	assert_eq(ModifierData.Stat.VESSEL_HAZARD_DAMAGE, 23)
	assert_eq(ModifierData.Stat.VESSEL_DECK_SHADE, 24)
