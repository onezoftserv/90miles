extends GutTest
## content-data: folder type, id = file name, Spanish names, and references are checked.

const ROOT := "user://test_content_validator"


func before_each() -> void:
	TestFs.remove_tree(ROOT)


func after_all() -> void:
	TestFs.remove_tree(ROOT)


func _catalog() -> ContentCatalog:
	return ContentCatalog.new(ROOT, {&"things": FixtureItemData, &"recipes": FixtureRecipeData})


func _item(id: StringName, name_es: String = "Cosa") -> FixtureItemData:
	var item := FixtureItemData.new()
	item.id = id
	item.name_es = name_es
	return item


func _recipe(id: StringName) -> FixtureRecipeData:
	var recipe := FixtureRecipeData.new()
	recipe.id = id
	recipe.name_es = "Receta"
	return recipe


func _save(folder: String, file_id: String, res: Resource) -> void:
	assert_eq(TestFs.save_content(ROOT, folder, file_id, res), OK, "saved %s/%s" % [folder, file_id])


func _errors() -> PackedStringArray:
	return ContentValidator.validate(_catalog())


func _assert_one_error_containing(parts: Array[String]) -> void:
	var errors := _errors()
	assert_eq(errors.size(), 1, "exactly one error: %s" % [errors])
	for part: String in parts:
		assert_string_contains(errors[0] if errors.size() > 0 else "", part)


func test_valid_content_has_no_errors() -> void:
	_save("things", "driftwood", _item(&"driftwood"))
	_save("things", "rope", _item(&"rope"))
	var raft := _recipe(&"raft")
	raft.ingredients = {&"driftwood": 6, &"rope": 3}
	raft.tool = &"rope"
	raft.unlocks = [&"driftwood"] as Array[StringName]
	_save("recipes", "raft", raft)
	assert_eq(_errors(), PackedStringArray())


func test_empty_catalog_has_no_errors() -> void:
	assert_eq(_errors(), PackedStringArray())


func test_wrong_type_in_folder_names_file_and_expected_type() -> void:
	_save("things", "raft", _recipe(&"raft"))
	_assert_one_error_containing(["things/raft", "FixtureItemData"])


func test_id_must_match_file_name() -> void:
	_save("things", "reef_shark", _item(&"bull_shark"))
	_assert_one_error_containing(["things/reef_shark", "bull_shark", "reef_shark"])


func test_missing_spanish_name_is_reported() -> void:
	_save("things", "coconut", _item(&"coconut", ""))
	_assert_one_error_containing(["things/coconut", "name_es"])


func test_dangling_dictionary_key_reference() -> void:
	_save("things", "driftwood", _item(&"driftwood"))
	var raft := _recipe(&"raft")
	raft.ingredients = {&"driftwood": 6, &"driftwod": 1}
	_save("recipes", "raft", raft)
	_assert_one_error_containing(["recipes/raft", "ingredients", "things/driftwod"])


func test_dangling_single_id_reference() -> void:
	var raft := _recipe(&"raft")
	raft.tool = &"knife"
	_save("recipes", "raft", raft)
	_assert_one_error_containing(["recipes/raft", "tool", "things/knife"])


func test_dangling_array_reference() -> void:
	var raft := _recipe(&"raft")
	raft.unlocks = [&"sail"] as Array[StringName]
	_save("recipes", "raft", raft)
	_assert_one_error_containing(["recipes/raft", "unlocks", "things/sail"])


func test_empty_single_reference_is_allowed() -> void:
	_save("recipes", "raft", _recipe(&"raft"))
	assert_eq(_errors(), PackedStringArray())


func test_unloadable_file_is_reported() -> void:
	DirAccess.make_dir_recursive_absolute(ROOT.path_join("things"))
	var bad := FileAccess.open(ROOT.path_join("things/broken.tres"), FileAccess.WRITE)
	bad.store_string("this is not a resource")
	bad.close()
	var errors := _errors()
	assert_eq(errors.size(), 1, "exactly one error: %s" % [errors])
	if errors.size() == 1:
		assert_string_contains(errors[0], "things/broken")
	# Loading the broken file makes the engine log a parse error plus loader follow-ups;
	# they are what this test provokes, so they must not fail it.
	assert_engine_error("broken.tres")
	for tracked: Variant in get_errors():
		tracked.handled = true


func test_english_name_falls_back_to_spanish() -> void:
	var coco := _item(&"coco", "Coco")
	assert_eq(coco.get_display_name("en"), "Coco")
	coco.name_en = "Coconut"
	assert_eq(coco.get_display_name("en"), "Coconut")
	assert_eq(coco.get_display_name("es"), "Coco")


func test_unregistered_content_folder_is_reported() -> void:
	_save("things", "rope", _item(&"rope"))
	_save("stuff", "rope", _item(&"rope"))
	_assert_one_error_containing(["stuff", "not a registered content type"])


func test_duplicate_id_across_tres_and_res_is_reported() -> void:
	_save("things", "rope", _item(&"rope"))
	assert_eq(ResourceSaver.save(_item(&"rope"), ROOT.path_join("things/rope.res")), OK)
	_assert_one_error_containing(["things/rope", "duplicate id"])


func test_type_that_is_not_content_is_reported_not_crashed() -> void:
	var plain := FixturePlainResource.new()
	plain.id = &"a"
	_save("plains", "a", plain)
	var errors := ContentValidator.validate(ContentCatalog.new(ROOT, {&"plains": FixturePlainResource}))
	assert_eq(errors.size(), 1, "one error: %s" % [errors])
	if errors.size() == 1:
		assert_string_contains(errors[0], "FixturePlainResource")
		assert_string_contains(errors[0], "not a ContentData type")


func test_broken_reference_declarations_are_reported() -> void:
	var broken := FixtureBrokenRefsData.new()
	broken.id = &"b"
	broken.name_es = "Roto"
	_save("broken", "b", broken)
	var errors := ContentValidator.validate(ContentCatalog.new(ROOT, {&"broken": FixtureBrokenRefsData, &"things": FixtureItemData}))
	var joined := "\n".join(errors)
	assert_eq(errors.size(), 3, "three errors: %s" % [errors])
	assert_string_contains(joined, "count holds unsupported type int")
	assert_string_contains(joined, "reference field ghost does not exist")
	assert_string_contains(joined, "tool points at unknown content type nowhere")


func test_reference_check_is_case_sensitive() -> void:
	_save("things", "rope", _item(&"rope"))
	var raft := _recipe(&"raft")
	raft.tool = &"Rope"
	_save("recipes", "raft", raft)
	_assert_one_error_containing(["recipes/raft", "tool", "things/Rope"])
