extends GutTest
## secret-cay "Secret tuning data", "Secret items", "Secrecy", "One shared secret check", "The late
## note", "The note's voice" and "The red-band yarey hat", with the texts of docs/ITEMS.md "Secret
## items": the tuning holds every number and names the two pieces, the four items load from data
## with their tags, spawn weight 0, reveal radii and texts, and the shared check and filter tell
## secret entries apart. Everything here reads data; a solo offline game reads the same files.

const TUNING_PATH: String = "res://resources/secret_tuning.tres"
const COMPASS: StringName = &"brujula_rota"
const MAP: StringName = &"mapa_sin_norte"
const HAT: StringName = &"sombrero_cinta_roja"
const NOTE: StringName = &"nota_llegaste_tarde"
const SECRET_IDS: Array[StringName] = [COMPASS, MAP, HAT, NOTE]
const NOTE_ENTRY_IDS: Array[StringName] = [&"llegaste_tarde", &"decomisado", &"la_cola", &"ni_el_norte", &"el_sombrero"]
## docs/ITEMS.md "Secret items": the map's hint phrases by spot kind.
const HINTS_ES: Dictionary[StringName, String] = {
	&"palm": "una palma",
	&"flotsam": "un reguero de cosas que trajo el mar",
	&"hut": "un bohío sin techo",
	&"beach": "un pedazo de playa",
	&"dune": "una loma de arena",
	&"tide_pool": "un charco entre las piedras",
	&"workbench": "un banco de trabajo",
	&"raft_site": "un buen sitio pa' armar una balsa",
	&"default": "algo que no se entiende",
}
const HINTS_EN: Dictionary[StringName, String] = {
	&"palm": "a palm",
	&"flotsam": "a reguero of junk the sea brought in",
	&"hut": "a bohío with no roof",
	&"beach": "a stretch of beach",
	&"dune": "a hill of sand",
	&"tide_pool": "a pool among the rocks",
	&"workbench": "a workbench",
	&"raft_site": "a good spot to put a raft together",
	&"default": "something nobody can make out",
}

var tuning: SecretTuning


func before_all() -> void:
	tuning = load(TUNING_PATH) as SecretTuning


func _item(id: StringName) -> ItemData:
	return GameState.content.get_entry(&"items", id) as ItemData


# --- Enums ---------------------------------------------------------------------------------

func test_secret_is_the_last_item_tag() -> void:
	var keys: Array = DataEnums.ItemTag.keys()
	assert_eq(keys.back(), "SECRET")
	assert_eq(DataEnums.ItemTag.SECRET, keys.size() - 1)
	assert_eq(DataEnums.ItemTag.MEAT, keys.size() - 2, "appended after MEAT")


func test_point_to_secret_is_the_last_capability() -> void:
	var keys: Array = DataEnums.Capability.keys()
	assert_eq(keys.back(), "POINT_TO_SECRET")
	assert_eq(DataEnums.Capability.POINT_TO_SECRET, keys.size() - 1)
	assert_eq(DataEnums.Capability.POWER_SOURCE, keys.size() - 2, "appended after POWER_SOURCE")


# --- Tuning --------------------------------------------------------------------------------

func test_tuning_loads_as_secret_tuning() -> void:
	assert_not_null(tuning, "%s is a SecretTuning" % TUNING_PATH)


func test_tuning_names_the_two_pieces() -> void:
	assert_eq(tuning.map_item_id, MAP)
	assert_eq(tuning.compass_item_id, COMPASS)
	assert_true(GameState.content.has_entry(&"items", tuning.map_item_id), "the map id resolves")
	assert_true(GameState.content.has_entry(&"items", tuning.compass_item_id), "the compass id resolves")
	var compass := _item(tuning.compass_item_id)
	var map := _item(tuning.map_item_id)
	if compass == null or map == null:
		return
	assert_has(compass.capabilities, DataEnums.Capability.POINT_TO_SECRET)
	assert_eq(compass.conceal_radius_tiles, 3.0)
	assert_eq(map.conceal_radius_tiles, 3.0)


func test_tuning_holds_the_shipped_numbers() -> void:
	assert_almost_eq(tuning.run_chance, 0.33, 1e-6)
	assert_eq(tuning.index_min, 2)
	assert_eq(tuning.index_max, 5)
	assert_eq(tuning.shimmer_period_s, 6.0)
	assert_eq(tuning.shimmer_length_s, 0.75)
	assert_eq(tuning.concealed_pickup_hold_s, 1.5)
	assert_eq(tuning.band_edges_tiles, [40.0, 20.0, 11.0, 6.0] as Array[float])
	assert_eq(tuning.band_wobble_deg, [90.0, 45.0, 20.0] as Array[float])
	assert_eq(tuning.spin_turns_per_s, 0.5)
	assert_eq(tuning.chest_hold_s, 1.0)
	assert_eq(tuning.note_base_s, 6.0)
	assert_almost_eq(tuning.note_per_char_s, 0.05, 1e-6)
	assert_almost_eq(tuning.spot_percentile_min, 0.50, 1e-6)
	assert_almost_eq(tuning.spot_percentile_max, 0.85, 1e-6)
	assert_almost_eq(tuning.spot_fallback_percentile_min, 0.25, 1e-6)
	assert_almost_eq(tuning.spot_fallback_percentile_max, 1.0, 1e-6)
	assert_eq(tuning.spot_feature_min_tiles, 4.0)
	assert_eq(tuning.spot_feature_max_tiles, 10.0)
	assert_eq(tuning.spot_feature_kinds, [&"palm", &"pickup", &"tide_pool", &"workbench", &"raft_site"] as Array[StringName])


func test_shimmer_length_is_inside_the_accepted_range() -> void:
	assert_between(tuning.shimmer_length_s, 0.5, 1.0)


func test_every_spot_kind_has_a_hint_in_both_languages() -> void:
	assert_eq(tuning.spot_hints_es, HINTS_ES)
	assert_eq(tuning.spot_hints_en, HINTS_EN)


# --- The four items ------------------------------------------------------------------------

func test_the_four_items_are_secret_with_spawn_weight_0() -> void:
	for id: StringName in SECRET_IDS:
		var item := _item(id)
		assert_not_null(item, "%s loads" % id)
		if item == null:
			continue
		assert_has(item.tags, DataEnums.ItemTag.SECRET, "%s is secret" % id)
		assert_eq(item.spawn_weight, 0.0, "%s has spawn weight 0" % id)
		assert_false(item.name_es.is_empty(), "%s has a Spanish name" % id)
		assert_false(item.name_en.is_empty(), "%s has an English name" % id)


func test_only_the_compass_and_the_map_are_concealed() -> void:
	var radii: Dictionary[StringName, float] = {COMPASS: 3.0, MAP: 3.0, HAT: 0.0, NOTE: 0.0}
	for id: StringName in radii:
		var item := _item(id)
		if item != null:
			assert_eq(item.conceal_radius_tiles, radii[id], "%s reveal radius" % id)


func test_only_the_compass_points_to_secrets() -> void:
	var pointers: Array[StringName] = []
	for id: StringName in GameState.content.list_ids(&"items"):
		var item := _item(id)
		if item != null and item.capabilities.has(DataEnums.Capability.POINT_TO_SECRET):
			pointers.append(id)
	assert_eq(pointers, [COMPASS] as Array[StringName])


func test_the_compass() -> void:
	var compass := _item(COMPASS)
	if compass == null:
		fail_test("no compass")
		return
	assert_eq(compass.name_es, "Brújula rota")
	assert_eq(compass.name_en, "Broken compass")
	assert_eq(compass.category, ItemData.Category.ODDITY)
	assert_almost_eq(compass.weight, 0.3, 1e-6)
	assert_eq(compass.description_es, "La única brújula que nunca te manda pa'l Norte.")
	assert_eq(compass.description_en, "The only compass that never sends you to el Norte.")
	assert_does_not_have(compass.capabilities, DataEnums.Capability.STEER)
	assert_does_not_have(compass.capabilities, DataEnums.Capability.NAVIGATE_STREAM)


func test_the_map() -> void:
	var map := _item(MAP)
	if map == null:
		fail_test("no map")
		return
	assert_eq(map.name_es, "Mapa sin norte")
	assert_eq(map.name_en, "Map without north")
	assert_eq(map.category, ItemData.Category.ODDITY)
	assert_almost_eq(map.weight, 0.1, 1e-6)
	assert_eq(map.description_es, "Una X, {pista} y una rosa de los vientos torcida. Se nota que lo dibujaron con una brújula que no sirve.")
	assert_eq(map.description_en, "An X, {pista} and a crooked compass rose. You can tell it was drawn with a compass that doesn't work.")
	for text: String in [map.description_es, map.description_en]:
		assert_string_contains(text, "{pista}")
		assert_false(text.to_lower().contains("palma"), "no palm in the map's own text")
	assert_does_not_have(map.capabilities, DataEnums.Capability.REVEAL_LAYOUT)
	assert_does_not_have(map.capabilities, DataEnums.Capability.REVEAL_ROUTES)


func test_the_red_band_yarey_hat() -> void:
	var hat := _item(HAT)
	if hat == null:
		fail_test("no hat")
		return
	assert_eq(hat.name_es, "Sombrero de yarey con cinta roja")
	assert_eq(hat.name_en, "Yarey hat with a red band")
	assert_eq(hat.category, ItemData.Category.WEARABLE)
	assert_has(hat.tags, DataEnums.ItemTag.WEARABLE)
	assert_eq(hat.equip_slot, ItemData.EquipSlot.HEAD)
	assert_almost_eq(hat.weight, 0.3, 1e-6)
	assert_eq(hat.modifiers.size(), 1, "one modifier")
	if hat.modifiers.size() == 1:
		var heat: ModifierData = hat.modifiers[0]
		assert_eq(heat.stat, ModifierData.Stat.HEAT_GAIN)
		assert_eq(heat.op, ModifierData.Op.MULTIPLY)
		assert_almost_eq(heat.value, 0.7, 1e-6)
	assert_eq(hat.drops_in_weather_ids, [] as Array[StringName], "no weather knocks it off")
	assert_eq(hat.description_es, "Yarey de verdad, cinta roja sencilla y barbiquejo: a este no se lo lleva el viento.")
	assert_eq(hat.description_en, "Real yarey, a plain red band and a chin cord: the wind won't take this one.")
	for text: String in [hat.description_es, hat.description_en]:
		for owner_word: String in ["dueño", "owner"]:
			assert_false(text.to_lower().contains(owner_word), "the hat names no owner (%s)" % owner_word)


func test_the_late_note_from_data() -> void:
	var note := _item(NOTE) as TextData
	if note == null:
		fail_test("no note, or not a TextData")
		return
	assert_eq(note.name_es, "Llegaste tarde")
	assert_eq(note.name_en, "Too slow")
	assert_eq(note.category, ItemData.Category.TEXT)
	assert_eq(note.tags, [DataEnums.ItemTag.TEXT, DataEnums.ItemTag.SECRET] as Array[DataEnums.ItemTag])
	assert_eq(note.generation, TextData.Generation.HANDWRITTEN)
	assert_eq(note.pick_mode, TextData.PickMode.RANDOM_ONE)
	assert_false(note.important)
	var ids: Array[StringName] = []
	for entry: TextEntryData in note.entries:
		ids.append(entry.id)
		for text: String in [entry.heading_es, entry.heading_en, entry.body_es, entry.body_en]:
			assert_false(text.strip_edges().is_empty(), "%s has headings and bodies in both languages" % entry.id)
		assert_eq(entry.body_es_soft, "", "%s's Spanish soft body is empty (already clean)" % entry.id)
		assert_eq(entry.body_en_soft, "", "%s's English soft body is empty (already clean)" % entry.id)
		assert_gt(entry.weight, 0.0, "%s can be picked" % entry.id)
	assert_eq(ids, NOTE_ENTRY_IDS)


func test_the_note_is_alive_and_coming_back() -> void:
	var note := _item(NOTE) as TextData
	if note == null:
		fail_test("no note")
		return
	var owners: Array[StringName] = []
	for entry: TextEntryData in note.entries:
		assert_string_contains(entry.body_es, "jueves")
		assert_string_contains(entry.body_en, "Thursday")
		if entry.body_es.contains("dueño"):
			owners.append(entry.id)
	assert_eq(owners, [&"el_sombrero"] as Array[StringName], "exactly one entry says the hat has an owner")


func test_the_note_texts_match_the_docs() -> void:
	var note := _item(NOTE) as TextData
	if note == null or note.entries.size() != 5:
		fail_test("no note with 5 entries")
		return
	var first: TextEntryData = note.entries[0]
	assert_eq(first.heading_es, "Llegaste tarde")
	assert_eq(first.heading_en, "Too slow")
	assert_eq(first.body_es, "Llegaste tarde, mi hermano. Aquí el que no madruga no coge ni la nota, y esta te la dejé por lástima. Vuelvo el jueves.")
	var last: TextEntryData = note.entries[4]
	assert_eq(last.heading_es, "Sobre el sombrero")
	assert_eq(last.heading_en, "About the hat")
	assert_eq(last.body_es, "Ese sombrero tiene dueño, y no eres tú. Dijo que volvía por él. Yo vuelvo el jueves, a ver quién llega primero. Mientras, póntelo, que este sol no perdona. Pero no le cojas cariño.")


func test_driftwood_is_ordinary() -> void:
	var driftwood := _item(&"driftwood")
	assert_does_not_have(driftwood.tags, DataEnums.ItemTag.SECRET)
	assert_eq(driftwood.conceal_radius_tiles, 0.0)


# --- Secrecy -------------------------------------------------------------------------------

func test_no_weighted_pick_can_draw_a_secret_item() -> void:
	for id: StringName in SECRET_IDS:
		var item := _item(id)
		if item != null:
			assert_eq(item.spawn_weight, 0.0, "%s can never be drawn by spawn weight" % id)


func test_the_shared_check_and_filter() -> void:
	var cay := IslandLayoutData.new()
	cay.id = &"cay_stand_in"
	cay.secret = true
	var sandbar := GameState.content.get_entry(&"islands", &"sandbar") as IslandLayoutData
	var driftwood := _item(&"driftwood")
	var everything: Array = [driftwood, sandbar, cay]
	for id: StringName in SECRET_IDS:
		var item := _item(id)
		assert_not_null(item, "%s loads" % id)
		if item != null:
			assert_true(SecretRules.is_secret(item), "%s is secret" % id)
			everything.append(item)
	assert_true(SecretRules.is_secret(cay), "a layout marked secret is secret")
	assert_false(SecretRules.is_secret(driftwood), "driftwood is not secret")
	assert_false(SecretRules.is_secret(sandbar), "the sandbar is not secret")
	assert_false(SecretRules.is_secret(null), "nothing is not secret")
	assert_eq(SecretRules.without_secrets(everything), [driftwood, sandbar])
