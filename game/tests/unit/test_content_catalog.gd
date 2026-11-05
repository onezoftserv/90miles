extends GutTest
## content-data: content is discovered by folder, so new files need no code change.

const ROOT := "user://test_content_catalog"


func before_each() -> void:
	TestFs.remove_tree(ROOT)


func after_all() -> void:
	TestFs.remove_tree(ROOT)


func _catalog() -> ContentCatalog:
	return ContentCatalog.new(ROOT, {&"things": FixtureItemData})


func _item(id: StringName, name_es: String = "Cosa") -> FixtureItemData:
	var item := FixtureItemData.new()
	item.id = id
	item.name_es = name_es
	return item


func _save(id: StringName) -> void:
	assert_eq(TestFs.save_content(ROOT, "things", String(id), _item(id)), OK, "saved fixture %s" % id)


func test_lists_ids_from_file_names_sorted() -> void:
	_save(&"rope")
	_save(&"coconut")
	assert_eq(_catalog().list_ids(&"things"), [&"coconut", &"rope"] as Array[StringName])


func test_new_file_is_discovered_without_code_change() -> void:
	_save(&"rope")
	var catalog := _catalog()
	assert_false(catalog.has_entry(&"things", &"hutia"))
	_save(&"hutia")
	assert_true(catalog.has_entry(&"things", &"hutia"), "a file added after creation is found")
	assert_eq(catalog.get_entry(&"things", &"hutia").id, &"hutia")


func test_get_entry_returns_the_typed_resource() -> void:
	_save(&"coconut")
	var entry: ContentData = _catalog().get_entry(&"things", &"coconut")
	assert_true(entry is FixtureItemData)
	assert_eq(entry.name_es, "Cosa")


func test_get_entry_caches_the_loaded_resource() -> void:
	_save(&"coconut")
	var catalog := _catalog()
	assert_same(catalog.get_entry(&"things", &"coconut"), catalog.get_entry(&"things", &"coconut"))


func test_missing_folder_lists_no_ids() -> void:
	assert_eq(_catalog().list_ids(&"things"), [] as Array[StringName])


func test_unknown_type_lists_no_ids() -> void:
	assert_eq(_catalog().list_ids(&"nope"), [] as Array[StringName])


func test_unknown_id_returns_null() -> void:
	_save(&"coconut")
	var catalog := _catalog()
	assert_null(catalog.get_entry(&"things", &"mango"))
	assert_false(catalog.has_entry(&"things", &"mango"))


func test_ignores_non_resource_files_and_subfolders() -> void:
	_save(&"coconut")
	DirAccess.make_dir_recursive_absolute(ROOT.path_join("things/nested"))
	var note := FileAccess.open(ROOT.path_join("things/README.md"), FileAccess.WRITE)
	note.store_string("not content")
	note.close()
	assert_eq(_catalog().list_ids(&"things"), [&"coconut"] as Array[StringName])


func test_folder_path_joins_root_and_type() -> void:
	assert_eq(_catalog().folder_path(&"things"), ROOT.path_join("things"))
