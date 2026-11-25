extends GutTest
## hud-clarity, content-data "Short names for counts" and "Launch lines", and the HUD text the clock
## and objective rows read: every key in Spanish and English. Pure data, 1 player, offline.

const SANDBAR_PATH: String = "res://resources/islands/sandbar.tres"
const CLOCK_KEYS: Array[StringName] = [&"dawn", &"morning", &"midday", &"afternoon", &"dusk", &"night", &"day", &"hours", &"minutes"]
const OBJECTIVE_KEYS: Array[StringName] = [&"gather", &"deliver", &"work", &"wait_dark", &"launch_default", &"at_sea"]

var root: String = UserTmp.path("test_hud_clarity_content")


func before_each() -> void:
	FsHelpers.remove_tree(root)


func after_all() -> void:
	FsHelpers.remove_tree(root)


func _item(id: StringName, name_es: String, short_es: String = "", short_en: String = "") -> ItemData:
	var item := ItemData.new()
	item.id = id
	item.name_es = name_es
	item.short_name_es = short_es
	item.short_name_en = short_en
	return item


func _errors() -> PackedStringArray:
	return ContentValidator.validate(ContentCatalog.new(root))


func _save(folder: String, file_id: String, res: Resource) -> void:
	assert_eq(FsHelpers.save_content(root, folder, file_id, res), OK, "saved %s/%s" % [folder, file_id])


func test_a_count_uses_the_short_name() -> void:
	var wood := _item(&"driftwood", "Madera de la costa", "madera", "wood")
	assert_eq(wood.count_name("es"), "madera")
	assert_eq(wood.count_name("en"), "wood")


func test_no_short_name_falls_back_to_the_name() -> void:
	var coco := _item(&"coco", "Coco")
	assert_eq(coco.count_name("en"), "Coco")
	assert_eq(coco.count_name("es"), "Coco")


func test_an_empty_english_short_name_falls_back_to_the_spanish_one() -> void:
	var wood := _item(&"driftwood", "Madera de la costa", "madera")
	wood.name_en = "Driftwood"
	assert_eq(wood.count_name("en"), "madera")


func test_the_raft_inputs_have_their_short_names() -> void:
	var expected: Dictionary[StringName, PackedStringArray] = {
		&"driftwood": PackedStringArray(["madera", "wood"]),
		&"inner_tube": PackedStringArray(["cámaras", "tubes"]),
		&"rope": PackedStringArray(["sogas", "ropes"]),
	}
	for id: StringName in expected:
		var item := GameState.content.get_entry(&"items", id) as ItemData
		assert_not_null(item, "item %s" % id)
		if item != null:
			assert_eq(item.count_name("es"), expected[id][0], "%s in Spanish" % id)
			assert_eq(item.count_name("en"), expected[id][1], "%s in English" % id)


func test_the_sandbar_launch_line() -> void:
	var sandbar := load(SANDBAR_PATH) as IslandLayoutData
	assert_eq(sandbar.launch_line("es"), "Zarpa pa'l cayo")
	assert_eq(sandbar.launch_line("en"), "Set off for the cay")


func test_an_empty_launch_line_is_empty_and_english_falls_back() -> void:
	var layout := IslandLayoutData.new()
	assert_eq(layout.launch_line("es"), "", "the objective row uses its default line")
	layout.launch_line_es = "Zarpa pa'l norte"
	assert_eq(layout.launch_line("en"), "Zarpa pa'l norte")


func test_a_short_name_too_long_is_reported_with_its_file() -> void:
	_save("items", "driftwood", _item(&"driftwood", "Madera", "maderitas"))
	var errors := _errors()
	assert_eq(errors.size(), 1, "exactly one error: %s" % [errors])
	if errors.size() == 1:
		assert_string_contains(errors[0], "items/driftwood")
		assert_string_contains(errors[0], "short_name_es")


func test_a_capitalised_short_name_is_reported() -> void:
	_save("items", "rope", _item(&"rope", "Soga", "sogas", "Ropes"))
	var errors := _errors()
	assert_eq(errors.size(), 1, "exactly one error: %s" % [errors])
	if errors.size() == 1:
		assert_string_contains(errors[0], "items/rope")
		assert_string_contains(errors[0], "short_name_en")


func test_an_eight_letter_short_name_passes() -> void:
	_save("items", "rope", _item(&"rope", "Soga", "sogasaaa", "ropesaaa"))
	assert_eq(_errors(), PackedStringArray())


func test_a_launch_line_too_long_is_reported_with_its_file() -> void:
	var layout := IslandLayoutData.new()
	layout.id = &"long_cay"
	layout.name_es = "Cayo largo"
	layout.launch_line_es = "Zarpa pa'l norte con to' y n"
	assert_eq(layout.launch_line_es.length(), 28)
	_save("islands", "long_cay", layout)
	var errors := _errors()
	assert_eq(errors.size(), 1, "exactly one error: %s" % [errors])
	if errors.size() == 1:
		assert_string_contains(errors[0], "islands/long_cay")
		assert_string_contains(errors[0], "launch_line_es")


func test_every_clock_word_and_objective_line_has_both_languages() -> void:
	var text := HudText.load_default()
	for key: StringName in CLOCK_KEYS:
		assert_has(HudText.CLOCK_WORDS, key)
		var pair: PackedStringArray = text.clock_words.get(key, PackedStringArray())
		assert_true(pair.size() == 2 and not pair[0].is_empty() and not pair[1].is_empty(), "clock word %s" % key)
	for key: StringName in OBJECTIVE_KEYS:
		assert_has(HudText.OBJECTIVE_LINES, key)
		var pair: PackedStringArray = text.objective_lines.get(key, PackedStringArray())
		assert_true(pair.size() == 2 and not pair[0].is_empty() and not pair[1].is_empty(), "objective line %s" % key)
	assert_eq(text.clock_word(&"morning"), "Mañana")
	assert_eq(text.clock_word(&"afternoon", "en"), "Afternoon")
	assert_eq(text.objective_line(&"wait_dark"), "Espera la noche pa' zarpar")
	assert_eq(text.objective_line(&"at_sea", "en"), "Hold on till land")
