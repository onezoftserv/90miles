extends GutTest
## content-batch-3, content-data "Water, food and plant items as data", "Spanish first, in Cuban
## speech", "Unknown plants hide what they are", "Risks the game cannot roll yet are never certain
## harm" and "References only to content that exists", and crafting-inventory "Raw food names its
## cooked form": the batch's 26 items load, validate and carry the numbers of docs/ITEMS.md.
## Chance rolls, statuses, drain multipliers, pick-up effects and cooking are data here; the game
## interprets them in a later change (design.md "Gaps").

const M := DataEnums.Meter
const ST := DataEnums.Status
const TG := DataEnums.ItemTag
const K := EffectData.Kind
const IG := ItemData.IdentifyGroup

const DRINKS: Array[StringName] = [&"still_cup", &"well_cup", &"seawater_cup", &"rum"]
const FOODS: Array[StringName] = [
	&"crab_raw", &"crab_cooked", &"fish_raw", &"fish_cooked", &"lobster", &"oysters", &"conch",
	&"bird_eggs", &"sea_grapes", &"mango", &"hutia_cooked", &"iguana_cooked", &"canned_food",
]
const PLANTS: Array[StringName] = [
	&"manzanillo", &"guao", &"jaguey", &"uva_caleta_unripe", &"hicaco", &"guanabana", &"noni",
	&"hongo_playa", &"tabaco_silvestre",
]
const FRUITS: Array[StringName] = [&"manzanillo", &"jaguey", &"uva_caleta_unripe", &"hicaco", &"guanabana", &"noni"]
const HERBS: Array[StringName] = [&"guao", &"tabaco_silvestre"]
## Spoken Cuban contractions and words (CLAUDE.md "Writing and dialogue"); every Spanish
## description of the batch has at least one.
const CUBAN_SPEECH: PackedStringArray = [
	"pa'", "na'", "to'", "'tá", "asere", "socio", "monte", "guajiro", "candela", "paladar",
]
## Textbook words the spoken forms replace; the batch never uses them (no homograph either).
const TEXTBOOK: PackedStringArray = ["para", "nada"]


func _item(id: StringName) -> ItemData:
	return GameState.content.get_entry(&"items", id) as ItemData


func _batch() -> Array[StringName]:
	var all: Array[StringName] = []
	all.append_array(DRINKS)
	all.append_array(FOODS)
	all.append_array(PLANTS)
	return all


# One effect as [kind, meter, status, amount, duration_s, delay_s, chance, roll_group].
func _shape(effect: EffectData) -> Array:
	return [effect.kind, effect.meter, effect.status, effect.amount, effect.duration_s, effect.delay_s, effect.chance, effect.roll_group]


func _e(kind: EffectData.Kind, meter: DataEnums.Meter, status: DataEnums.Status, amount: float, duration_s: float = 0.0, delay_s: float = 0.0, chance: float = 1.0, roll_group: int = 0) -> Array:
	return [kind, meter, status, amount, duration_s, delay_s, chance, roll_group]


func _add(meter: DataEnums.Meter, amount: float, duration_s: float = 0.0, delay_s: float = 0.0) -> Array:
	return _e(K.METER_ADD, meter, ST.NONE, amount, duration_s, delay_s)


func _poison(chance: float) -> Array:
	return _e(K.APPLY_STATUS, M.HEALTH, ST.POISON, -20.0, 30.0, 0.0, chance)


func _first_use_is(id: StringName, expected: Array) -> void:
	var item := _item(id)
	if item == null or item.uses.is_empty():
		fail_test("%s has no use" % id)
		return
	var shapes: Array = []
	for effect: EffectData in item.uses[0].effects:
		shapes.append(_shape(effect))
	assert_eq(shapes, expected, "%s's first use" % id)


func _all_effects(item: ItemData) -> Array[EffectData]:
	var found: Array[EffectData] = []
	for use: ItemUseData in item.uses:
		found.append_array(use.effects)
	found.append_array(item.pickup_effects)
	return found


func _revives(item: ItemData) -> bool:
	for effect: EffectData in _all_effects(item):
		if effect.kind == K.REVIVE:
			return true
	return false


# --- every item ----------------------------------------------------------------------------------

func test_the_batch_loads_with_its_categories() -> void:
	for id: StringName in DRINKS:
		assert_not_null(_item(id), "items/%s" % id)
		if _item(id) != null:
			assert_eq(_item(id).category, ItemData.Category.WATER, "%s is a drink" % id)
	for id: StringName in FOODS:
		assert_not_null(_item(id), "items/%s" % id)
		if _item(id) != null:
			assert_eq(_item(id).category, ItemData.Category.FOOD, "%s is food" % id)
	for id: StringName in PLANTS:
		assert_not_null(_item(id), "items/%s" % id)
		if _item(id) != null:
			assert_eq(_item(id).category, ItemData.Category.PLANT, "%s is a plant" % id)


func test_the_validator_reports_nothing_for_the_items() -> void:
	var problems: PackedStringArray = []
	for line: String in ContentValidator.validate(GameState.content):
		if line.begins_with("items/"):
			problems.append(line)
	assert_eq(problems, PackedStringArray(), "no item problems")


func test_no_second_file_for_sabila_or_the_coco_plum() -> void:
	assert_null(_item(&"sabila"), "sábila ships as aloe")
	assert_not_null(_item(&"aloe"), "aloe is the sábila entry")
	assert_null(_item(&"coco_plum"), "the coco plum is hicaco")
	assert_not_null(_item(&"hicaco"))


func test_names_and_descriptions_in_both_languages() -> void:
	for id: StringName in _batch():
		var item := _item(id)
		if item == null:
			fail_test("%s is missing" % id)
			continue
		for text: String in [item.name_es, item.name_en, item.description_es, item.description_en]:
			assert_false(text.strip_edges().is_empty(), "%s has every name and description" % id)
		assert_ne(item.description_es, item.description_en, "%s's Spanish is not its English" % id)


func test_spanish_descriptions_use_cuban_speech() -> void:
	var textbook := RegEx.create_from_string("(?i)\\b(%s)\\b" % "|".join(TEXTBOOK))
	for id: StringName in _batch():
		var item := _item(id)
		if item == null:
			fail_test("%s is missing" % id)
			continue
		var text: String = item.description_es.to_lower()
		var spoken: bool = false
		for word: String in CUBAN_SPEECH:
			if text.contains(word):
				spoken = true
		assert_true(spoken, "%s speaks Cuban: %s" % [id, item.description_es])
		assert_null(textbook.search(text), "%s has no textbook para or nada" % id)


func test_every_item_has_an_icon() -> void:
	for id: StringName in _batch():
		var item := _item(id)
		assert_true(item != null and item.sprite != null, "%s has an icon" % id)


func test_no_risk_is_a_certain_loss() -> void:
	for id: StringName in _batch():
		var item := _item(id)
		if item == null:
			continue
		for effect: EffectData in _all_effects(item):
			if effect.kind == K.METER_ADD and effect.amount < 0.0:
				assert_eq(effect.chance, 1.0, "%s: a meter loss is never chance-gated (chances are not rolled yet)" % id)


# --- drinks --------------------------------------------------------------------------------------

func test_drink_numbers() -> void:
	_first_use_is(&"still_cup", [_add(M.THIRST, 40.0)])
	_first_use_is(&"well_cup", [_add(M.THIRST, 30.0)])
	_first_use_is(&"seawater_cup", [_add(M.THIRST, 10.0), _add(M.THIRST, -30.0, 120.0)])
	_first_use_is(&"rum", [_add(M.THIRST, 5.0), _add(M.MORALE, 15.0), _add(M.ENERGY, -10.0), _add(M.THIRST, -10.0, 0.0, 60.0)])


func test_drinks_are_drunk() -> void:
	for id: StringName in DRINKS:
		var item := _item(id)
		if item != null and not item.uses.is_empty():
			assert_eq(item.uses[0].action, ItemUseData.UseAction.DRINK, "%s is drunk" % id)


func test_rum_has_three_swigs_and_no_water_tag() -> void:
	var rum := _item(&"rum")
	assert_eq(rum.durability, 3)
	assert_eq(rum.stack_size, 1, "a bottle with uses left does not stack")
	assert_false(rum.tags.has(TG.WATER))


func test_the_still_and_well_cups_revive_like_the_rain_cup() -> void:
	for id: StringName in [&"still_cup", &"well_cup"]:
		var cup := _item(id)
		assert_true(cup.tags.has(TG.WATER), "%s is water" % id)
		assert_eq(cup.uses.size(), 2, "%s drinks and revives" % id)
		if cup.uses.size() < 2:
			continue
		var revive: ItemUseData = cup.uses[1]
		assert_true(revive.can_target_others)
		assert_eq(revive.effects[0].kind, K.REVIVE)
		assert_eq(revive.effects[0].target, EffectData.Target.USE_TARGET)
		assert_eq(revive.effects[1].target, EffectData.Target.USE_TARGET, "the revived drink it")
		assert_eq(_shape(revive.effects[1]), _shape(cup.uses[0].effects[0]))


func test_seawater_and_rum_never_revive() -> void:
	assert_false(_revives(_item(&"seawater_cup")))
	assert_false(_revives(_item(&"rum")))


# --- foods ---------------------------------------------------------------------------------------

func test_food_numbers() -> void:
	_first_use_is(&"crab_raw", [_add(M.HUNGER, 20.0), _poison(0.3)])
	_first_use_is(&"crab_cooked", [_add(M.HUNGER, 25.0)])
	_first_use_is(&"fish_raw", [_add(M.HUNGER, 30.0), _poison(0.3)])
	_first_use_is(&"fish_cooked", [_add(M.HUNGER, 35.0)])
	_first_use_is(&"lobster", [_add(M.HUNGER, 35.0)])
	_first_use_is(&"oysters", [_add(M.HUNGER, 12.0), _add(M.THIRST, 2.0)])
	_first_use_is(&"conch", [_add(M.HUNGER, 25.0)])
	_first_use_is(&"bird_eggs", [_add(M.HUNGER, 10.0)])
	_first_use_is(&"sea_grapes", [_add(M.HUNGER, 5.0)])
	_first_use_is(&"mango", [_add(M.HUNGER, 20.0), _add(M.THIRST, 10.0)])
	_first_use_is(&"hutia_cooked", [_add(M.HUNGER, 40.0)])
	_first_use_is(&"iguana_cooked", [_add(M.HUNGER, 35.0)])
	_first_use_is(&"canned_food", [_add(M.HUNGER, 30.0), _poison(0.2)])


func test_foods_are_eaten_and_tagged() -> void:
	var meat: Array[StringName] = [&"crab_raw", &"crab_cooked", &"fish_raw", &"fish_cooked", &"lobster", &"oysters", &"conch", &"hutia_cooked", &"iguana_cooked"]
	for id: StringName in FOODS:
		var item := _item(id)
		if item == null:
			continue
		assert_eq(item.uses[0].action, ItemUseData.UseAction.EAT, "%s is eaten" % id)
		assert_true(item.tags.has(TG.FOOD), "%s is food" % id)
		assert_eq(item.tags.has(TG.MEAT), meat.has(id), "%s's meat tag" % id)
		assert_false(_revives(item), "%s never revives" % id)


func test_raw_food_cooks_into_its_safe_form() -> void:
	var pairs: Dictionary[StringName, StringName] = {&"crab_raw": &"crab_cooked", &"fish_raw": &"fish_cooked"}
	for raw: StringName in pairs:
		assert_eq(_item(raw).cooks_into, pairs[raw])
		assert_eq(_item(raw).cook_time_s, 20.0, "%s cooks in 20 s" % raw)
		for effect: EffectData in _all_effects(_item(pairs[raw])):
			assert_ne(effect.status, ST.POISON, "%s is safe" % pairs[raw])


func test_oysters_cut_hands_without_gloves() -> void:
	var oysters := _item(&"oysters")
	assert_eq(oysters.stack_size, 6)
	assert_eq(oysters.pickup_effects.size(), 1)
	var cut: EffectData = oysters.pickup_effects[0]
	assert_eq(cut.kind, K.APPLY_STATUS)
	assert_eq(cut.status, ST.BLEEDING)
	assert_eq(cut.conditions.size(), 1)
	var gloves: ConditionData = cut.conditions[0]
	assert_eq(gloves.kind, ConditionData.Kind.HAS_CAPABILITY)
	assert_eq(gloves.capability, DataEnums.Capability.HAND_PROTECTION)
	assert_eq(gloves.scope, ConditionData.Scope.ACTOR)
	assert_true(gloves.negate, "only a taker without hand protection is cut")


func test_eggs_stack_by_five() -> void:
	assert_eq(_item(&"bird_eggs").stack_size, 5)


func test_canned_food_needs_an_opener_and_spends_it() -> void:
	var can := _item(&"canned_food")
	assert_eq(can.uses[0].conditions.size(), 1)
	var opener: ConditionData = can.uses[0].conditions[0]
	assert_eq(opener.kind, ConditionData.Kind.HAS_CAPABILITY)
	assert_eq(opener.capability, DataEnums.Capability.OPEN_CAN)
	assert_eq(opener.scope, ConditionData.Scope.ACTOR)
	assert_true(opener.consume, "one use of the opener per can")
	assert_false(can.tags.has(TG.MEAT), "the dogs cannot smell a sealed can")


func test_the_knife_opens_cans() -> void:
	assert_true(_item(&"knife").capabilities.has(DataEnums.Capability.OPEN_CAN))


# --- plants --------------------------------------------------------------------------------------

func test_plant_numbers() -> void:
	_first_use_is(&"manzanillo", [_add(M.HEALTH, -50.0, 60.0), [K.DRAIN_MULTIPLIER, M.THIRST, ST.NONE, 0.0, 60.0, 0.0, 1.0, 0]])
	_first_use_is(&"jaguey", [_add(M.HUNGER, 15.0)])
	_first_use_is(&"uva_caleta_unripe", [_add(M.HUNGER, 3.0), _add(M.THIRST, -5.0)])
	_first_use_is(&"hicaco", [_add(M.HUNGER, 8.0), _add(M.THIRST, 3.0)])
	_first_use_is(&"guanabana", [_add(M.HUNGER, 25.0), _add(M.THIRST, 15.0), _add(M.MORALE, 10.0)])
	_first_use_is(&"noni", [_add(M.HUNGER, 5.0), _add(M.HEALTH, 10.0), _e(K.CURE_STATUS, M.NONE, ST.POISON, 0.0)])
	_first_use_is(&"hongo_playa", [_e(K.APPLY_STATUS, M.NONE, ST.HALLUCINATING, 0.0, 120.0, 0.0, 0.4, 1), _e(K.METER_ADD, M.HUNGER, ST.NONE, 10.0, 0.0, 0.0, 0.6, 1)])
	_first_use_is(&"tabaco_silvestre", [_add(M.MORALE, 10.0)])
	assert_eq(_item(&"manzanillo").uses[0].effects[1].multiplier, 2.0, "thirst x2")


func test_every_plant_hides_in_its_group() -> void:
	var groups: Dictionary[StringName, ItemData.IdentifyGroup] = {&"hongo_playa": IG.HONGO}
	for id: StringName in FRUITS:
		groups[id] = IG.FRUTA
	for id: StringName in HERBS:
		groups[id] = IG.HIERBA
	assert_eq(groups.size(), PLANTS.size(), "every plant has a group")
	for id: StringName in PLANTS:
		var plant := _item(id)
		assert_eq(plant.identify_group, groups[id], "%s's group" % id)
		assert_true(plant.tags.has(TG.UNKNOWN), "%s is unknown" % id)


func test_plants_of_a_group_share_tags_stack_and_weight() -> void:
	for group: Array[StringName] in [FRUITS, HERBS]:
		var first := _item(group[0])
		for id: StringName in group:
			var plant := _item(id)
			assert_eq(plant.tags, first.tags, "%s's tags match %s's" % [id, group[0]])
			assert_eq(plant.stack_size, first.stack_size, "%s's stack" % id)
			assert_eq(plant.weight, first.weight, "%s's weight" % id)
	assert_false(_item(&"noni").tags.has(TG.MEDICINE), "a medicine tag would give noni away")


func test_manchineel_always_looks_like_a_green_fruit() -> void:
	assert_eq(_item(&"manzanillo").fixed_unknown_look, &"fruta_verde")


func test_guao_burns_on_touch_and_is_not_eaten() -> void:
	var guao := _item(&"guao")
	assert_true(guao.uses.is_empty(), "no food")
	assert_eq(guao.pickup_effects.size(), 1)
	assert_eq(_shape(guao.pickup_effects[0]), _e(K.APPLY_STATUS, M.NONE, ST.BURNING, 0.0, 20.0))


func test_wild_tobacco_is_smoked_at_a_fire() -> void:
	var smoke: ItemUseData = _item(&"tabaco_silvestre").uses[0]
	assert_eq(smoke.action, ItemUseData.UseAction.SMOKE)
	assert_eq(smoke.conditions.size(), 1)
	assert_eq(smoke.conditions[0].kind, ConditionData.Kind.LIT_FIRE_NEARBY)
	assert_eq(smoke.conditions[0].radius_tiles, 2.0)


func test_guanabana_is_rare() -> void:
	assert_lt(_item(&"guanabana").spawn_weight, 1.0)
