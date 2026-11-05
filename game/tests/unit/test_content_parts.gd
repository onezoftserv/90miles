extends GutTest
## content-data: "every referenced id SHALL exist" also holds for ids inside embedded parts
## (conditions, effects, spawn rules...), at any depth.

const ROOT := "user://test_content_parts"


func before_each() -> void:
	FsHelpers.remove_tree(ROOT)


func after_all() -> void:
	FsHelpers.remove_tree(ROOT)


func _catalog() -> ContentCatalog:
	return ContentCatalog.new(ROOT, {&"things": FixtureItemData, &"holders": FixtureHolderData})


func _part(item: StringName) -> FixturePartData:
	var part := FixturePartData.new()
	part.item = item
	return part


func _holder() -> FixtureHolderData:
	var holder := FixtureHolderData.new()
	holder.id = &"h"
	holder.name_es = "Soporte"
	return holder


func _save_rope() -> void:
	var rope := FixtureItemData.new()
	rope.id = &"rope"
	rope.name_es = "Soga"
	assert_eq(FsHelpers.save_content(ROOT, "things", "rope", rope), OK)


func _validate(holder: FixtureHolderData) -> PackedStringArray:
	assert_eq(FsHelpers.save_content(ROOT, "holders", "h", holder), OK)
	return ContentValidator.validate(_catalog())


func test_valid_nested_parts_pass() -> void:
	_save_rope()
	var holder := _holder()
	holder.main = _part(&"rope")
	var outer := _part(&"rope")
	outer.children = [_part(&"rope")] as Array[FixturePartData]
	holder.parts = [_part(&"rope"), outer] as Array[FixturePartData]
	assert_eq(_validate(holder), PackedStringArray())


func test_missing_id_in_a_single_part_names_its_path() -> void:
	_save_rope()
	var holder := _holder()
	holder.main = _part(&"ghost")
	var errors := _validate(holder)
	assert_eq(errors.size(), 1, "one error: %s" % [errors])
	if errors.size() == 1:
		assert_string_contains(errors[0], "holders/h: main.item references missing things/ghost")


func test_missing_id_deep_in_an_array_names_its_path() -> void:
	_save_rope()
	var holder := _holder()
	var outer := _part(&"rope")
	outer.children = [_part(&"rope"), _part(&"ghost")] as Array[FixturePartData]
	holder.parts = [_part(&"rope"), outer] as Array[FixturePartData]
	var errors := _validate(holder)
	assert_eq(errors.size(), 1, "one error: %s" % [errors])
	if errors.size() == 1:
		assert_string_contains(errors[0], "holders/h: parts[1].children[1].item references missing things/ghost")


func test_empty_part_slots_are_fine() -> void:
	_save_rope()
	var holder := _holder()
	holder.parts = [null, _part(&"rope")] as Array[FixturePartData]
	assert_eq(_validate(holder), PackedStringArray())
