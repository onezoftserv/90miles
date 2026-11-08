extends GutTest
## inventory-hud "HUD text is data" and "Prompt verbs and targets": every word the HUD adds comes
## from game/resources/hud_text.tres, Spanish first with English beside it, and every interactable
## a scene places names a prompt id.

const SCENES_ROOT: String = "res://scenes"
const PLAIN_INTERACTABLE: String = "res://scripts/interaction/interactable.gd"
## Design D4's prompt ids.
const PROMPT_IDS: Array[StringName] = [&"pick_up", &"climb_palm", &"workbench", &"build", &"put_out", &"take_water", &"launch", &"shoo", &"drag", &"tie_down", &"untie", &"climb_aboard", &"pull"]
## The prompt ids whose target is a fixed label rather than a content name.
const LABELLED_PROMPTS: Array[StringName] = [&"climb_palm", &"workbench", &"put_out", &"launch", &"tie_down", &"untie", &"climb_aboard"]


func _text() -> HudText:
	return load(HudText.PATH) as HudText


func _both(pair: PackedStringArray) -> bool:
	return pair.size() == 2 and not pair[0].strip_edges().is_empty() and not pair[1].strip_edges().is_empty()


func _recipes() -> Array[RecipeData]:
	var found: Array[RecipeData] = []
	for id: StringName in GameState.content.list_ids(&"recipes"):
		var recipe := GameState.content.get_entry(&"recipes", id) as RecipeData
		if recipe != null:
			found.append(recipe)
	return found


# Every capability a HAS_CAPABILITY condition asks for, nested ones included.
func _condition_capabilities(conditions: Array, into: Array[DataEnums.Capability]) -> void:
	for part: Variant in conditions:
		var condition := part as ConditionData
		if condition == null:
			continue
		if condition.kind == ConditionData.Kind.HAS_CAPABILITY and not into.has(condition.capability):
			into.append(condition.capability)
		_condition_capabilities(condition.children, into)


func _used_capabilities() -> Array[DataEnums.Capability]:
	var used: Array[DataEnums.Capability] = []
	for recipe: RecipeData in _recipes():
		for tool: DataEnums.Capability in recipe.tools:
			if not used.has(tool):
				used.append(tool)
		if recipe.fast_tool != DataEnums.Capability.NONE and not used.has(recipe.fast_tool):
			used.append(recipe.fast_tool)
	for id: StringName in GameState.content.list_ids(&"items"):
		var item := GameState.content.get_entry(&"items", id) as ItemData
		if item == null:
			continue
		for use: ItemUseData in item.uses:
			_condition_capabilities(use.conditions, used)
	return used


func _scenes_under(folder: String) -> PackedStringArray:
	var found := PackedStringArray()
	for file: String in DirAccess.get_files_at(folder):
		if file.get_extension() == "tscn":
			found.append(folder.path_join(file))
	for sub: String in DirAccess.get_directories_at(folder):
		found.append_array(_scenes_under(folder.path_join(sub)))
	return found


func _extends_interactable(script: Script) -> bool:
	var current: Script = script
	while current != null:
		if current.resource_path == PLAIN_INTERACTABLE:
			return true
		current = current.get_base_script()
	return false


# Problems with one scene's interactables: a plain Interactable must name its prompt in the scene;
# a kind with its own script (DragHandle, RescuePoint) sets its prompt in code (design D4).
func _scene_problems(path: String) -> PackedStringArray:
	var problems := PackedStringArray()
	var state := (load(path) as PackedScene).get_state()
	for i: int in state.get_node_count():
		var script: Script = null
		var prompt: StringName = &""
		for p: int in state.get_node_property_count(i):
			var property: StringName = state.get_node_property_name(i, p)
			if property == &"script":
				script = state.get_node_property_value(i, p) as Script
			elif property == &"prompt_id":
				prompt = state.get_node_property_value(i, p)
		if script == null or not _extends_interactable(script):
			continue
		if script.resource_path != PLAIN_INTERACTABLE:
			var made := script.new() as Interactable
			prompt = made.prompt_id
			made.free()
		if prompt.is_empty():
			problems.append("%s: %s" % [path, state.get_node_path(i)])
	return problems


func test_the_file_loads_as_hud_text() -> void:
	assert_true(_text() is HudText)
	assert_true(HudText.load_default() is HudText)


func test_every_use_action_has_a_verb() -> void:
	var text := _text()
	for action: int in ItemUseData.UseAction.values():
		assert_true(_both(text.use_verbs.get(action, PackedStringArray())), "use verb %s" % ItemUseData.UseAction.keys()[action])


func test_every_prompt_id_has_a_verb_and_the_labelled_ones_a_label() -> void:
	var text := _text()
	for id: StringName in PROMPT_IDS:
		assert_true(_both(text.prompt_verbs.get(id, PackedStringArray())), "prompt verb %s" % id)
	for id: StringName in LABELLED_PROMPTS:
		assert_true(_both(text.prompt_labels.get(id, PackedStringArray())), "prompt label %s" % id)


func test_every_tag_a_recipe_takes_is_named() -> void:
	var text := _text()
	var checked: int = 0
	for recipe: RecipeData in _recipes():
		for tag: DataEnums.ItemTag in recipe.input_tags:
			assert_true(_both(text.tag_names.get(tag, PackedStringArray())), "%s tag %s" % [recipe.id, DataEnums.ItemTag.keys()[tag]])
			checked += 1
	assert_gt(checked, 0, "the fire takes tinder")


func test_every_tool_a_recipe_or_a_use_asks_for_has_a_phrase() -> void:
	var text := _text()
	var used := _used_capabilities()
	assert_true(used.has(DataEnums.Capability.OPEN_COCONUT), "the coconut asks for a blade")
	assert_true(used.has(DataEnums.Capability.LIGHT_FIRE), "the fire's fast tool")
	for capability: DataEnums.Capability in used:
		assert_true(_both(text.tool_phrases.get(capability, PackedStringArray())), "tool phrase %s" % DataEnums.Capability.keys()[capability])


func test_refusals_and_list_lines_have_both_languages() -> void:
	var text := _text()
	for key: StringName in HudText.REFUSALS:
		assert_true(_both(text.refusals.get(key, PackedStringArray())), "refusal %s" % key)
	for key: StringName in HudText.LINES:
		assert_true(_both(text.lines.get(key, PackedStringArray())), "line %s" % key)
	for template: String in [text.line(&"needs_tool"), text.line(&"faster"), text.refusal(&"condition")]:
		assert_string_contains(template, "%s")


func test_spanish_comes_first() -> void:
	var text := _text()
	assert_eq(text.use_verb(ItemUseData.UseAction.DRINK), "Beber")
	assert_eq(text.use_verb(ItemUseData.UseAction.EAT), "Comer")
	assert_eq(text.prompt_verb(&"pick_up"), "Recoger")
	assert_eq(text.prompt_verb(&"climb_palm") + " " + text.prompt_label(&"climb_palm"), "Trepar Mata de coco")
	assert_eq(text.prompt_verb(&"workbench") + " " + text.prompt_label(&"workbench"), "Fabricar en el banco")
	assert_eq(text.prompt_verb(&"launch") + " " + text.prompt_label(&"launch"), "Zarpar en la balsa")
	assert_eq(text.prompt_verb(&"shoo"), "Espantar")
	assert_eq(text.tag_name(DataEnums.ItemTag.TINDER), "Yesca")
	assert_eq(text.tool_phrase(DataEnums.Capability.OPEN_COCONUT), "abrir el coco")
	assert_eq(text.tool_phrase(DataEnums.Capability.LIGHT_FIRE), "prender candela")
	assert_eq(text.line(&"faster") % text.tool_phrase(DataEnums.Capability.LIGHT_FIRE), "Más rápido: prender candela")
	assert_eq(text.refusal(&"condition") % text.tool_phrase(DataEnums.Capability.OPEN_COCONUT), "Te falta con qué abrir el coco.")
	assert_eq(text.refusal(&"empty"), "No tienes nada ahí.")
	assert_eq(text.refusal(&"at_sea"), "En plena travesía no se puede.")
	assert_eq(text.line(&"weight"), "Peso")
	assert_eq(text.line(&"missing"), "Falta:")


func test_english_sits_beside_it_and_falls_back_to_spanish() -> void:
	var text := _text()
	assert_eq(text.prompt_verb(&"pick_up", "en"), "Pick up")
	assert_eq(text.prompt_verb(&"pick_up", "en_US"), "Pick up")
	var half := HudText.new()
	half.refusals[&"empty"] = PackedStringArray(["No tienes nada ahí.", ""])
	assert_eq(half.refusal(&"empty", "en"), "No tienes nada ahí.", "an empty translation shows the Spanish")
	assert_eq(half.refusal(&"missing_key", "en"), "", "an unknown key is empty")


func test_every_scene_interactable_names_a_prompt() -> void:
	var problems := PackedStringArray()
	var scenes := _scenes_under(SCENES_ROOT)
	assert_gt(scenes.size(), 10, "the scenes were found")
	for path: String in scenes:
		problems.append_array(_scene_problems(path))
	assert_eq(problems, PackedStringArray(), "interactables without a prompt id")
