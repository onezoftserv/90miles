extends GutTest
## island-pressure task 1 (crafting-inventory "Build stages", escape-routes "Raft stages"): a build-site
## recipe may list stages as data. The content check accepts stages whose inputs add up to the recipe's
## and whose times add up to its time, each above 0, with names in both languages and no tag inputs, on
## a build site only; the shipped raft lists its four stages.

const DRIFTWOOD: StringName = &"driftwood"
const TUBE: StringName = &"inner_tube"
const ROPE: StringName = &"rope"


func _stage(name_es: String, inputs: Dictionary[StringName, int], time_s: float) -> BuildStageData:
	var stage := BuildStageData.new()
	stage.name_es = name_es
	stage.name_en = name_es + " (en)"
	stage.inputs = inputs
	stage.time_s = time_s
	return stage


func _recipe() -> RecipeData:
	var recipe := RecipeData.new()
	recipe.id = &"fixture"
	recipe.name_es = "Prueba"
	recipe.station = RecipeData.Station.NONE
	recipe.build_site = true
	recipe.output_kind = RecipeData.OutputKind.VESSEL
	recipe.inputs = {DRIFTWOOD: 6, TUBE: 2, ROPE: 3} as Dictionary[StringName, int]
	recipe.time_s = 120.0
	recipe.stages = [
		_stage("Uno", {TUBE: 2, ROPE: 1} as Dictionary[StringName, int], 30.0),
		_stage("Dos", {DRIFTWOOD: 4, ROPE: 1} as Dictionary[StringName, int], 30.0),
		_stage("Tres", {DRIFTWOOD: 2, ROPE: 1} as Dictionary[StringName, int], 30.0),
		_stage("Cuatro", {} as Dictionary[StringName, int], 30.0),
	] as Array[BuildStageData]
	return recipe


func _errors(recipe: RecipeData) -> PackedStringArray:
	return ContentValidator._check_staged_recipe("recipes/fixture", recipe)


func test_a_valid_staged_recipe_passes() -> void:
	assert_eq(_errors(_recipe()), PackedStringArray())


func test_a_recipe_without_stages_is_not_checked() -> void:
	var plain := _recipe()
	plain.stages = [] as Array[BuildStageData]
	plain.time_s = 30.0
	assert_eq(_errors(plain), PackedStringArray())
	assert_false(plain.is_staged())
	assert_true(_recipe().is_staged())


func test_stage_inputs_that_do_not_add_up_fail() -> void:
	var short := _recipe()
	short.stages[1].inputs = {DRIFTWOOD: 3, ROPE: 1} as Dictionary[StringName, int]
	assert_eq(_errors(short).size(), 1, "5 driftwood in the stages, 6 in the recipe")
	var extra := _recipe()
	extra.stages[3].inputs = {&"knife": 1} as Dictionary[StringName, int]
	assert_eq(_errors(extra).size(), 1, "a stage input the recipe does not take")


func test_stage_times_that_do_not_add_up_fail() -> void:
	var recipe := _recipe()
	recipe.time_s = 100.0
	assert_eq(_errors(recipe).size(), 1)


func test_a_zero_time_stage_fails() -> void:
	var recipe := _recipe()
	recipe.stages[2].time_s = 0.0
	recipe.stages[3].time_s = 60.0
	assert_eq(_errors(recipe).size(), 1)


func test_a_staged_recipe_with_tag_inputs_fails() -> void:
	var recipe := _recipe()
	recipe.input_tags = {DataEnums.ItemTag.TINDER: 1} as Dictionary[DataEnums.ItemTag, int]
	assert_eq(_errors(recipe).size(), 1)


func test_a_stage_needs_names_in_both_languages() -> void:
	var recipe := _recipe()
	recipe.stages[0].name_en = ""
	assert_eq(_errors(recipe).size(), 1)
	recipe.stages[0].name_en = "One"
	recipe.stages[0].name_es = " "
	assert_eq(_errors(recipe).size(), 1)


func test_stages_need_a_build_site() -> void:
	var recipe := _recipe()
	recipe.build_site = false
	assert_eq(_errors(recipe).size(), 1)


func test_a_work_cost_needs_a_build_site_and_no_negative() -> void:
	var recipe := _recipe()
	recipe.work_energy_per_s = 1.0
	recipe.work_thirst_per_s = 0.25
	assert_eq(_errors(recipe), PackedStringArray())
	recipe.work_thirst_per_s = -1.0
	assert_eq(_errors(recipe).size(), 1)


# escape-routes "The raft's stages from data".
func test_the_rafts_stages_from_data() -> void:
	var raft := GameState.content.get_entry(&"recipes", &"raft") as RecipeData
	assert_not_null(raft)
	assert_eq(raft.time_s, 120.0)
	assert_eq(raft.inputs, {DRIFTWOOD: 6, TUBE: 2, ROPE: 3} as Dictionary[StringName, int])
	assert_eq(raft.stages.size(), 4)
	var names: PackedStringArray = []
	var names_en: PackedStringArray = []
	for stage: BuildStageData in raft.stages:
		names.append(stage.name_es)
		names_en.append(stage.name_en)
		assert_eq(stage.time_s, 30.0)
	assert_eq(names, PackedStringArray(["Amarrar las cámaras", "Armar el piso", "Amarrar la baranda", "Apretar los nudos"]))
	assert_eq(names_en, PackedStringArray(["Lash the tubes", "Build the deck", "Lash the rail", "Tighten the knots"]))
	assert_eq(raft.stages[0].inputs, {TUBE: 2, ROPE: 1} as Dictionary[StringName, int])
	assert_eq(raft.stages[1].inputs, {DRIFTWOOD: 4, ROPE: 1} as Dictionary[StringName, int])
	assert_eq(raft.stages[2].inputs, {DRIFTWOOD: 2, ROPE: 1} as Dictionary[StringName, int])
	assert_eq(raft.stages[3].inputs, {} as Dictionary[StringName, int])
	assert_eq(raft.work_energy_per_s, 1.0)
	assert_eq(raft.work_thirst_per_s, 0.25)
	assert_eq(_errors(raft), PackedStringArray())
	var errors: PackedStringArray = []
	for line: String in ContentValidator.validate(GameState.content):
		if line.begins_with("recipes/"):
			errors.append(line)
	assert_eq(errors, PackedStringArray(), "the content check reports nothing on the recipes")


func test_every_stage_name_fits_the_prompt_line() -> void:
	var raft := GameState.content.get_entry(&"recipes", &"raft") as RecipeData
	var words := HudText.load_default()
	for i: int in raft.stages.size():
		for locale: String in ["es", "en"]:
			var line: String = words.line(&"stage", locale) % [i + 1, raft.stages.size(), raft.stages[i].get_display_name(locale)]
			assert_lte(line.length(), 30, "%s fits the 30-glyph line" % line)
