extends GutTest
## content-batch-4, content-data "Tool, material and wearable items as data", "Gear descriptions in
## Cuban speech", "Gear the game cannot run yet is data, not code" and "Gear references only
## content that exists": the batch's 26 items load, validate and carry the numbers of
## docs/ITEMS.md. Worn slots, modifiers, weapons, fishing, traps, weather knock-off and the horn's
## noise are data here; the game runs them in later changes (design.md "Gaps").

const CAP := DataEnums.Capability
const TG := DataEnums.ItemTag
const ST := ModifierData.Stat
const OP := ModifierData.Op
const CX := ModifierData.Context
const SLOT := ItemData.EquipSlot
const WC := ItemData.WeaponClass

const TOOLS: Array[StringName] = [
	&"machete", &"broken_bottle", &"spear", &"fishing_line", &"lure", &"net", &"snare", &"pliers",
	&"compass", &"charts", &"flint_steel", &"shovel_oar", &"conch_horn",
]
const MATERIALS: Array[StringName] = [&"hardwood", &"line_spool", &"resin", &"cloth", &"tire"]
const WEARABLES: Array[StringName] = [
	&"straw_hat", &"life_vest", &"wetsuit_top", &"fins", &"sandals", &"gloves", &"sunglasses", &"military_belt",
]
## Shipped before this batch; it adds no second file for any of them.
const SHIPPED: Array[StringName] = [
	&"knife", &"lighter", &"mirror", &"binoculars", &"driftwood", &"dry_grass", &"inner_tube",
	&"plastic_jug", &"rope", &"tarp", &"nails", &"sombrero_cinta_roja",
]
## content-batch-11 builds these (balsero-lore 8.1).
const BATCH_11: Array[StringName] = [
	&"tabla_surf", &"tabla_vela", &"tanque_55", &"propela", &"bidon_combustible", &"azucar", &"camara_bici",
]
## Spoken Cuban contractions and words (CLAUDE.md "Writing and dialogue"); every Spanish
## description of the batch has at least one.
const CUBAN_SPEECH: PackedStringArray = [
	"pa'", "na'", "to'", "'tá", "'toy", "asere", "socio", "monte", "guajiro", "candela",
]
## Textbook words the spoken forms replace; the batch never uses them, and writes "nadar" where
## swimming is meant, so the homograph never appears either.
const TEXTBOOK: PackedStringArray = ["para", "nada"]

## Uses per docs/ITEMS.md "Tools"; 0 is no counter (never wears).
const DURABILITY: Dictionary[StringName, int] = {
	&"machete": 60, &"broken_bottle": 5, &"spear": 30, &"fishing_line": 25, &"lure": 0, &"net": 15,
	&"snare": 10, &"pliers": 50, &"compass": 0, &"charts": 0, &"flint_steel": 0, &"shovel_oar": 30,
	&"conch_horn": 0,
}
## Every capability of the batch, from the docs' words only (design.md Q6).
const CAPABILITIES: Dictionary[StringName, Array] = {
	&"machete": [CAP.OPEN_COCONUT, CAP.CUT_PATH],
	&"spear": [CAP.SPEAR_FISH],
	&"fishing_line": [CAP.LINE_FISH],
	&"net": [CAP.NET_FISH, CAP.TRAP],
	&"snare": [CAP.TRAP],
	&"pliers": [CAP.OPEN_CAN, CAP.PRY_NAILS, CAP.REPAIR],
	&"compass": [CAP.STEER],
	&"charts": [CAP.NAVIGATE_STREAM, CAP.REVEAL_LAYOUT],
	&"flint_steel": [CAP.LIGHT_FIRE],
	&"shovel_oar": [CAP.DIG, CAP.BURY_STASH],
	&"life_vest": [CAP.FLOAT_AT_ZERO_ENERGY],
	&"gloves": [CAP.HAND_PROTECTION],
	&"sunglasses": [CAP.GLARE_PROTECTION],
}
## [class, damage, reach in tiles]; every other item is no weapon.
const WEAPONS: Dictionary[StringName, Array] = {
	&"machete": [WC.BLADE, 20.0, 1.0],
	&"broken_bottle": [WC.BLADE, 8.0, 1.0],
	&"spear": [WC.SPEAR, 12.0, 2.0],
}
## Every modifier as [stat, op, value, context]; all apply to the holder.
const MODIFIERS: Dictionary[StringName, Array] = {
	&"lure": [[ST.LINE_FISH_RATE, OP.MULTIPLY, 2.0, CX.ALWAYS]],
	&"pliers": [[ST.BUILD_SPEED, OP.MULTIPLY, 1.5, CX.ALWAYS]],
	&"straw_hat": [[ST.HEAT_GAIN, OP.MULTIPLY, 0.7, CX.ALWAYS]],
	&"wetsuit_top": [
		[ST.SWIM_THIRST_FACTOR, OP.SET, 2.0, CX.IN_WATER],
		[ST.CORAL_DAMAGE, OP.MULTIPLY, 0.5, CX.ALWAYS],
		[ST.HEAT_GAIN, OP.MULTIPLY, 1.2, CX.ON_LAND],
	],
	&"life_vest": [[ST.SWIM_SPEED, OP.MULTIPLY, 0.8, CX.IN_WATER]],
	&"fins": [[ST.SWIM_SPEED, OP.MULTIPLY, 1.3, CX.IN_WATER], [ST.WALK_SPEED, OP.MULTIPLY, 0.7, CX.ON_LAND]],
	&"military_belt": [[ST.INVENTORY_SLOTS, OP.ADD, 2.0, CX.ALWAYS]],
}
## Worn slots (design.md Q4): fins and sandals share the feet.
const SLOTS: Dictionary[StringName, ItemData.EquipSlot] = {
	&"straw_hat": SLOT.HEAD, &"sunglasses": SLOT.FACE, &"wetsuit_top": SLOT.BODY, &"life_vest": SLOT.VEST,
	&"gloves": SLOT.HANDS, &"fins": SLOT.FEET, &"sandals": SLOT.FEET, &"military_belt": SLOT.WAIST,
}
## Only the doc's shiny items (design.md Q7).
const SHINY: Array[StringName] = [&"broken_bottle", &"lure", &"sunglasses"]
## [stack, weight], first-pass (design.md Q8).
const PACKING: Dictionary[StringName, Array] = {
	&"machete": [1, 1.5], &"broken_bottle": [1, 0.3], &"spear": [1, 1.5], &"fishing_line": [1, 0.2],
	&"lure": [1, 0.1], &"net": [1, 1.5], &"snare": [1, 0.3], &"pliers": [1, 0.5], &"compass": [1, 0.2],
	&"charts": [1, 0.1], &"flint_steel": [1, 0.2], &"shovel_oar": [1, 2.0], &"conch_horn": [1, 0.5],
	&"hardwood": [5, 3.0], &"line_spool": [5, 0.1], &"resin": [5, 0.2], &"cloth": [5, 0.2], &"tire": [1, 4.0],
	&"straw_hat": [1, 0.3], &"life_vest": [1, 1.5], &"wetsuit_top": [1, 1.0], &"fins": [1, 1.0],
	&"sandals": [1, 0.5], &"gloves": [1, 0.2], &"sunglasses": [1, 0.1], &"military_belt": [1, 0.5],
}


func _item(id: StringName) -> ItemData:
	return GameState.content.get_entry(&"items", id) as ItemData


func _batch() -> Array[StringName]:
	var all: Array[StringName] = []
	all.append_array(TOOLS)
	all.append_array(MATERIALS)
	all.append_array(WEARABLES)
	return all


# Each id, loaded; a missing one fails the test by name and is left out.
func _loaded(ids: Array[StringName]) -> Array[ItemData]:
	var found: Array[ItemData] = []
	for id: StringName in ids:
		var item := _item(id)
		if item == null:
			fail_test("items/%s is missing" % id)
		else:
			found.append(item)
	return found


func _sorted_ints(values: Array) -> Array[int]:
	var out: Array[int] = []
	for value: Variant in values:
		out.append(int(value))
	out.sort()
	return out


# --- every item ----------------------------------------------------------------------------------

func test_the_batch_loads_with_its_categories() -> void:
	for item: ItemData in _loaded(TOOLS):
		assert_eq(item.category, ItemData.Category.TOOL, "%s is a tool" % item.id)
	for item: ItemData in _loaded(MATERIALS):
		assert_eq(item.category, ItemData.Category.MATERIAL, "%s is a material" % item.id)
	for item: ItemData in _loaded(WEARABLES):
		assert_eq(item.category, ItemData.Category.WEARABLE, "%s is a wearable" % item.id)


func test_the_validator_reports_nothing_for_the_items() -> void:
	var problems: PackedStringArray = []
	for line: String in ContentValidator.validate(GameState.content):
		if line.begins_with("items/"):
			problems.append(line)
	assert_eq(problems, PackedStringArray(), "no item problems")


func test_nothing_doubled_and_nothing_taken_from_batch_11() -> void:
	for id: StringName in SHIPPED:
		assert_not_null(_item(id), "%s still ships" % id)
	for id: StringName in BATCH_11:
		assert_null(_item(id), "%s is content-batch-11's" % id)
	assert_null(_item(&"rock"), "rock waits for the recipes batch")
	assert_null(_item(&"stick"), "stick waits for the recipes batch")


func test_names_and_descriptions_in_both_languages() -> void:
	for item: ItemData in _loaded(_batch()):
		for text: String in [item.name_es, item.name_en, item.description_es, item.description_en]:
			assert_false(text.strip_edges().is_empty(), "%s has every name and description" % item.id)
		assert_ne(item.description_es, item.description_en, "%s's Spanish is not its English" % item.id)


func test_spanish_descriptions_use_cuban_speech() -> void:
	var textbook := RegEx.create_from_string("(?i)\\b(%s)\\b" % "|".join(TEXTBOOK))
	for item: ItemData in _loaded(_batch()):
		var text: String = item.description_es.to_lower()
		assert_null(textbook.search(text), "%s's Spanish has no textbook 'para' or 'nada'" % item.id)
		var spoken: bool = false
		for word: String in CUBAN_SPEECH:
			if text.contains(word):
				spoken = true
		assert_true(spoken, "%s's Spanish uses Cuban speech: %s" % [item.id, item.description_es])


func test_tags_and_packing() -> void:
	for item: ItemData in _loaded(_batch()):
		var expected: Array = []
		if TOOLS.has(item.id):
			expected.append(TG.TOOL)
		if MATERIALS.has(item.id):
			expected.append(TG.MATERIAL)
		if WEARABLES.has(item.id):
			expected.append(TG.WEARABLE)
		if WEAPONS.has(item.id):
			expected.append(TG.WEAPON)
		if SHINY.has(item.id):
			expected.append(TG.SHINY)
		assert_eq(_sorted_ints(item.tags), _sorted_ints(expected), "%s's tags" % item.id)
		assert_eq(item.stack_size, int(PACKING[item.id][0]), "%s's stack" % item.id)
		assert_almost_eq(item.weight, float(PACKING[item.id][1]), 0.0001, "%s's weight" % item.id)
		assert_almost_eq(item.spawn_weight, 1.0, 0.0001, "%s's spawn weight" % item.id)
		assert_eq(item.identify_group, ItemData.IdentifyGroup.NONE, "%s is always known" % item.id)


func test_capabilities_from_the_docs_words_only() -> void:
	for item: ItemData in _loaded(_batch()):
		var expected: Array = CAPABILITIES.get(item.id, [])
		assert_eq(_sorted_ints(item.capabilities), _sorted_ints(expected), "%s's capabilities" % item.id)


func test_weapons() -> void:
	for item: ItemData in _loaded(_batch()):
		var expected: Array = WEAPONS.get(item.id, [WC.NONE, 0.0, 1.0])
		assert_eq(item.weapon_class, expected[0], "%s's weapon class" % item.id)
		assert_almost_eq(item.weapon_damage, float(expected[1]), 0.0001, "%s's damage" % item.id)
		assert_almost_eq(item.weapon_reach_tiles, float(expected[2]), 0.0001, "%s's reach" % item.id)


func test_modifiers_on_the_holder() -> void:
	for item: ItemData in _loaded(_batch()):
		var expected: Array = MODIFIERS.get(item.id, [])
		var shapes: Array = []
		var wanted: Array = []
		for modifier: ModifierData in item.modifiers:
			shapes.append([modifier.stat, modifier.op, modifier.context])
			assert_eq(modifier.scope, ModifierData.Scope.HOLDER, "%s's modifier is the holder's" % item.id)
		for shape: Array in expected:
			wanted.append([shape[0], shape[1], shape[3]])
		assert_eq(shapes, wanted, "%s's modifiers" % item.id)
		if shapes != wanted:
			continue
		for i: int in expected.size():
			assert_almost_eq(item.modifiers[i].value, float(expected[i][2]), 0.0001, "%s's modifier %d" % [item.id, i])


func test_worn_slots() -> void:
	for item: ItemData in _loaded(_batch()):
		assert_eq(item.equip_slot, SLOTS.get(item.id, SLOT.NONE), "%s's slot" % item.id)
	assert_eq(_item(&"fins").equip_slot, _item(&"sandals").equip_slot, "fins or sandals, not both")


# --- tools ---------------------------------------------------------------------------------------

func test_durability_as_the_doc_gives_it() -> void:
	for item: ItemData in _loaded(TOOLS):
		assert_eq(item.durability, DURABILITY[item.id], "%s's uses" % item.id)
	for item: ItemData in _loaded(MATERIALS):
		assert_eq(item.durability, 0, "%s has no counter" % item.id)
	for item: ItemData in _loaded(WEARABLES):
		assert_eq(item.durability, 0, "%s never wears out" % item.id)


func test_only_the_horn_has_a_use() -> void:
	for item: ItemData in _loaded(_batch()):
		if item.id == &"conch_horn":
			continue
		assert_eq(item.uses.size(), 0, "%s works by what it enables, not by a use" % item.id)


func test_the_conch_leaves_its_horn() -> void:
	var conch := _item(&"conch")
	assert_eq(conch.durability, 1, "one bite, so the last one gives the remainder")
	assert_eq(conch.remainder_item_id, &"conch_horn")
	assert_true(conch.weight >= _item(&"conch_horn").weight, "the horn never weighs more than the conch")


func test_the_horn_is_blown_and_never_used_up() -> void:
	var horn := _item(&"conch_horn")
	assert_eq(horn.uses.size(), 1)
	var blow: ItemUseData = horn.uses[0]
	assert_eq(blow.action, ItemUseData.UseAction.PLAY, "the HUD reads Tocar")
	assert_false(blow.spends_use, "repeatable")
	assert_eq(blow.conditions.size(), 0)
	assert_eq(blow.effects.size(), 1)
	var noise: EffectData = blow.effects[0]
	assert_eq(noise.kind, EffectData.Kind.NOISE)
	assert_almost_eq(noise.radius_tiles, 15.0, 0.0001, "noise radius 15")


func test_flint_and_steel_light_a_fire_in_10_s() -> void:
	var flint := _item(&"flint_steel")
	assert_almost_eq(flint.tool_action_time_s, 10.0, 0.0001)
	assert_almost_eq(_item(&"lighter").tool_action_time_s, 1.0, 0.0001, "the lighter stays faster")


func test_the_broken_bottle_makes_the_target_bleed() -> void:
	var bottle := _item(&"broken_bottle")
	assert_eq(bottle.hit_effects.size(), 1)
	var cut: EffectData = bottle.hit_effects[0]
	assert_eq(cut.kind, EffectData.Kind.APPLY_STATUS)
	assert_eq(cut.status, DataEnums.Status.BLEEDING)
	assert_eq(cut.target, EffectData.Target.USE_TARGET)
	assert_almost_eq(cut.duration_s, 10.0, 0.0001)
	for item: ItemData in _loaded(_batch()):
		if item.id != &"broken_bottle":
			assert_eq(item.hit_effects.size(), 0, "%s has no hit effect" % item.id)


func test_fishing_and_traps_catch_only_what_exists() -> void:
	assert_eq(_item(&"net").catch_per_use, 3, "three fish per cast")
	for id: StringName in [&"net", &"snare"]:
		assert_eq(_item(id).trap_catches, [&"land_crab"] as Array[StringName], "%s traps crabs; hutía later" % id)
	for item: ItemData in _loaded(_batch()):
		if item.id != &"net":
			assert_eq(item.catch_per_use, 1, "%s's catch" % item.id)
		if item.id != &"net" and item.id != &"snare":
			assert_eq(item.trap_catches.size(), 0, "%s traps nothing" % item.id)


# --- wearables -----------------------------------------------------------------------------------

func test_the_yarey_hat_blows_off_and_the_red_band_does_not() -> void:
	assert_eq(_item(&"straw_hat").drops_in_weather_ids, [&"squall"] as Array[StringName])
	assert_eq(_item(&"sombrero_cinta_roja").drops_in_weather_ids.size(), 0, "the chin cord holds")
	for item: ItemData in _loaded(_batch()):
		if item.id != &"straw_hat":
			assert_eq(item.drops_in_weather_ids.size(), 0, "%s stays on in any weather" % item.id)


func test_sandals_carry_no_immunity_of_their_own() -> void:
	var sandals := _item(&"sandals")
	assert_eq(sandals.capabilities.size(), 0)
	assert_eq(sandals.modifiers.size(), 0)
	assert_eq(sandals.uses.size(), 0, "the urchin, stingray and fire-ant counters hold the immunity")
