extends GutTest
## content-data: the data model's 34 classes in game/scripts/data. The 11 folders are
## registered, every class builds on the right base, every reference field is a stored id
## field pointing at a registered folder (for every kind), every typed container survives a
## .tres round trip, and ContentValidator checks real content down to ids inside parts.

const ROOT := "user://test_data_classes"
const ROUND_TRIP_ROOT := "user://test_data_classes_round_trip"
const DATA_DIR := "res://scripts/data"
## Folder -> the class its files use (data model manifest).
const FOLDER_CLASSES: Dictionary[StringName, StringName] = {
	&"creatures": &"CreatureData",
	&"items": &"ItemData",
	&"recipes": &"RecipeData",
	&"npcs": &"NpcData",
	&"dialogue": &"DialogueData",
	&"chains": &"ChainData",
	&"pois": &"PoiData",
	&"set_pieces": &"SetPieceData",
	&"routes": &"RouteData",
	&"backgrounds": &"BackgroundData",
	&"weather": &"WeatherData",
}
## Content classes whose files live in items/ as ItemData subclasses.
const ITEM_SUBCLASSES: Array[StringName] = [&"KeepsakeData", &"TextData"]
## Classes embedded inside content files, never files of their own.
const PART_CLASSES: Array[StringName] = [
	&"ChainRouteEntryData", &"ChoiceData", &"CompanionData", &"CompanionStatusData",
	&"ConditionData", &"CreatureCounterData", &"CreatureSpawnRuleData", &"DialogueLineData",
	&"DialogueStateData", &"EffectData", &"EndingRoleData", &"GrabData", &"ItemUseData",
	&"ModifierData", &"NpcHookData", &"NpcSpawnRuleData", &"PatrolData", &"QuestData",
	&"QuestStepData", &"SpawnEntryData", &"TextEntryData",
]
## Scripts in DATA_DIR that are not data model classes: the two bases and the enum holder.
const SUPPORT_CLASSES: Array[StringName] = [&"ContentData", &"DataEnums", &"DataPart"]
## Classes whose references depend on one of their enum fields -> that field.
const KIND_FIELDS: Dictionary[StringName, StringName] = {
	&"ConditionData": &"kind",
	&"EffectData": &"kind",
	&"KeepsakeData": &"unlock",
	&"RouteData": &"starter_kind",
	&"SpawnEntryData": &"kind",
}
## Nesting levels the round trip fills (ConditionData.children holds ConditionData).
const FILL_DEPTH := 3
## Stored properties the round-trip comparison leaves out (the script is compared directly).
const SKIPPED_PROPERTIES: Array[String] = ["script", "resource_path", "resource_scene_unique_id"]

var _scripts: Dictionary[StringName, GDScript] = {}


func before_all() -> void:
	for file: String in DirAccess.get_files_at(DATA_DIR):
		if file.get_extension() != "gd":
			continue
		var script := load(DATA_DIR.path_join(file)) as GDScript
		if script != null and not String(script.get_global_name()).is_empty():
			_scripts[script.get_global_name()] = script


func before_each() -> void:
	FsHelpers.remove_tree(ROOT)
	FsHelpers.remove_tree(ROUND_TRIP_ROOT)


func after_all() -> void:
	FsHelpers.remove_tree(ROOT)
	FsHelpers.remove_tree(ROUND_TRIP_ROOT)


# --- registration and class shape -------------------------------------------------------


func test_default_types_register_exactly_the_eleven_folders() -> void:
	var expected: Array[StringName] = []
	expected.assign(FOLDER_CLASSES.keys())
	expected.sort_custom(_by_text)
	assert_eq(ContentCatalog.new(ROOT).types(), expected)
	assert_eq(ContentCatalog.DEFAULT_TYPES.size(), 11)
	for folder: StringName in FOLDER_CLASSES:
		var script: Script = ContentCatalog.DEFAULT_TYPES.get(folder)
		var found: StringName = script.get_global_name() if script != null else &""
		assert_eq(found, FOLDER_CLASSES[folder], "%s/ files use %s" % [folder, FOLDER_CLASSES[folder]])


func test_data_folder_declares_exactly_the_model_classes() -> void:
	assert_eq(_model_classes().size(), 34, "the data model has 34 classes")
	var expected: Array[StringName] = _model_classes()
	expected.append_array(SUPPORT_CLASSES)
	expected.sort_custom(_by_text)
	var found: Array[StringName] = []
	found.assign(_scripts.keys())
	found.sort_custom(_by_text)
	assert_eq(found, expected, "class_name scripts in %s" % DATA_DIR)


func test_every_data_class_can_be_instantiated() -> void:
	var broken: PackedStringArray = []
	for class_id: StringName in _scripts:
		if class_id != &"DataEnums" and _new(class_id) == null:
			broken.append(String(class_id))
	assert_eq(broken, PackedStringArray(), "classes that cannot be instantiated as a Resource")


func test_folder_classes_are_content_and_parts_are_data_parts() -> void:
	var problems: PackedStringArray = []
	for class_id: StringName in _model_classes():
		var inst: Resource = _new(class_id)
		if inst == null:
			problems.append("%s: cannot be instantiated" % class_id)
		elif FOLDER_CLASSES.values().has(class_id):
			if not (inst is ContentData):
				problems.append("%s: folder class does not extend ContentData" % class_id)
		elif ITEM_SUBCLASSES.has(class_id):
			var parent: Script = _scripts[class_id].get_base_script()
			if parent == null or parent.get_global_name() != &"ItemData":
				problems.append("%s: does not extend ItemData directly" % class_id)
		elif not (inst is DataPart) or inst is ContentData:
			problems.append("%s: embedded class does not extend DataPart only" % class_id)
	assert_eq(problems, PackedStringArray())


# --- reference fields ---------------------------------------------------------------------


func test_reference_fields_are_stored_ids_pointing_at_registered_folders() -> void:
	var problems: Dictionary[String, bool] = {}
	var checked: int = 0
	for class_id: StringName in _scripts:
		if class_id == &"DataEnums":
			continue
		var base: Resource = _new(class_id)
		if base == null:
			problems["%s: cannot be instantiated" % class_id] = true
			continue
		var props := _stored_props(base)
		for inst: Resource in _kind_variants(class_id, props):
			var refs: Dictionary[StringName, StringName] = inst.call(&"get_reference_fields")
			for field: StringName in refs:
				checked += 1
				var problem := _reference_problem(class_id, props, field, refs[field])
				if not problem.is_empty():
					problems[problem] = true
	assert_gt(checked, 0, "reference fields were checked")
	var listed: PackedStringArray = PackedStringArray(problems.keys())
	listed.sort()
	assert_eq(listed, PackedStringArray())


func test_kind_dependent_references_change_with_their_kind() -> void:
	for class_id: StringName in KIND_FIELDS:
		var field: StringName = KIND_FIELDS[class_id]
		var base: Resource = _new(class_id)
		assert_not_null(base, "%s can be instantiated" % class_id)
		if base == null:
			continue
		var props := _stored_props(base)
		assert_true(props.has(String(field)), "%s has a stored %s field" % [class_id, field])
		if not props.has(String(field)):
			continue
		var seen: Dictionary[String, bool] = {}
		for value: int in _enum_values(props[String(field)]["hint_string"]):
			var inst: Resource = _new(class_id)
			inst.set(field, value)
			seen[str(inst.call(&"get_reference_fields"))] = true
		assert_gt(seen.size(), 1, "%s references change with %s" % [class_id, field])


func test_kind_dependent_references_point_where_the_model_says() -> void:
	assert_eq(_target(_condition(ConditionData.Kind.HAS_ITEM, &""), &"ref_id"), &"items")
	assert_eq(_target(_condition(ConditionData.Kind.STRUCTURE_BUILT, &""), &"ref_id"), &"recipes")
	assert_eq(_target(_condition(ConditionData.Kind.FLAG_SET, &""), &"ref_id"), &"")
	var effect := EffectData.new()
	effect.kind = EffectData.Kind.PLAY_DIALOGUE
	assert_eq(_target(effect, &"ref_id"), &"dialogue")
	effect.kind = EffectData.Kind.METER_ADD
	assert_eq(_target(effect, &"ref_id"), &"")
	var spawn := SpawnEntryData.new()
	spawn.kind = SpawnEntryData.Kind.CREATURE
	assert_eq(_target(spawn, &"ref_id"), &"creatures")
	spawn.kind = SpawnEntryData.Kind.ITEM_TAG
	assert_eq(_target(spawn, &"ref_id"), &"")
	var route := RouteData.new()
	route.starter_kind = RouteData.StarterKind.NPC
	assert_eq(_target(route, &"starter_id"), &"npcs")
	var keepsake := KeepsakeData.new()
	keepsake.unlock = KeepsakeData.UnlockKind.KILL_CREATURE
	assert_eq(_target(keepsake, &"unlock_ref_ids"), &"creatures")
	assert_eq(_target(keepsake, &"remainder_item_id"), &"items", "keeps ItemData's references")
	keepsake.unlock = KeepsakeData.UnlockKind.QUEST_COMPLETED
	assert_eq(_target(keepsake, &"unlock_ref_ids"), &"", "quest ids are not a content folder")


# --- .tres round trip ---------------------------------------------------------------------


func test_every_class_survives_a_round_trip_with_every_container_filled() -> void:
	var containers: int = 0
	var filled: int = 0
	for class_id: StringName in _model_classes():
		var original: Resource = _new(class_id)
		if original == null:
			fail_test("%s cannot be instantiated" % class_id)
			continue
		var problems: PackedStringArray = []
		containers += _container_count(original)
		filled += _fill(original, 0, problems, String(class_id))
		var loaded := _round_trip(original, String(class_id).to_snake_case())
		if loaded == null:
			continue
		assert_ne(loaded, original, "%s was read back from disk, not from the cache" % class_id)
		_diff(original, loaded, String(class_id), problems)
		assert_eq(problems, PackedStringArray(), "%s round trip" % class_id)
	assert_gt(containers, 0, "typed containers were found")
	assert_eq(filled, containers, "every typed Array and Dictionary field was filled")


# Guards the round-trip check itself, so a comparison that misses differences cannot pass it.
func test_round_trip_comparison_sees_lost_values_and_types() -> void:
	var filled: Resource = _new(&"ChainData")
	var problems: PackedStringArray = []
	_fill(filled, 0, problems, "ChainData")
	assert_eq(problems, PackedStringArray())
	var differences: PackedStringArray = []
	_diff(filled, _new(&"ChainData"), "ChainData", differences)
	var text := "\n".join(differences)
	assert_string_contains(text, "ChainData.biome_weights: had 2 entries")
	assert_string_contains(text, "ChainData.routes: had 1 elements")
	assert_string_contains(text, "ChainData.family: ")
	var untyped: PackedStringArray = []
	_diff([&"a"] as Array[StringName], [&"a"], "ids", untyped)
	assert_eq(untyped, PackedStringArray(["ids: lost its element type"]))


func test_enum_keyed_dictionaries_keep_their_keys_and_types() -> void:
	var recipe := RecipeData.new()
	recipe.input_tags = {DataEnums.ItemTag.FOOD: 2, DataEnums.ItemTag.MATERIAL: 3}
	var chain := ChainData.new()
	chain.biome_weights = {DataEnums.Terrain.BEACH: 0.5, DataEnums.Terrain.MANGROVE: 0.25}
	var weather := WeatherData.new()
	weather.family_weights = {DataEnums.ChainFamily.REEF: 2.0}
	var recipe_back := _round_trip(recipe, "enum_keys_recipe") as RecipeData
	var chain_back := _round_trip(chain, "enum_keys_chain") as ChainData
	var weather_back := _round_trip(weather, "enum_keys_weather") as WeatherData
	if recipe_back == null or chain_back == null or weather_back == null:
		return
	assert_eq(recipe_back.input_tags.size(), 2)
	assert_eq(recipe_back.input_tags.get(DataEnums.ItemTag.MATERIAL), 3)
	assert_eq(recipe_back.input_tags.get_typed_key_builtin(), TYPE_INT)
	assert_eq(recipe_back.input_tags.get_typed_value_builtin(), TYPE_INT)
	assert_eq(chain_back.biome_weights.size(), 2)
	assert_eq(chain_back.biome_weights.get(DataEnums.Terrain.MANGROVE), 0.25)
	assert_eq(chain_back.biome_weights.get_typed_key_builtin(), TYPE_INT)
	assert_eq(chain_back.biome_weights.get_typed_value_builtin(), TYPE_FLOAT)
	assert_eq(weather_back.family_weights.get(DataEnums.ChainFamily.REEF), 2.0)
	assert_eq(weather_back.family_weights.get_typed_key_builtin(), TYPE_INT)


func test_condition_children_nest_through_a_round_trip() -> void:
	var inner := _condition(ConditionData.Kind.ALL_OF, &"")
	inner.children = [
		_condition(ConditionData.Kind.HAS_ITEM, &"rope"),
		_condition(ConditionData.Kind.FLAG_SET, &"saw_lighthouse"),
	] as Array[DataPart]
	var outer := _condition(ConditionData.Kind.ANY_OF, &"")
	outer.children = [inner] as Array[DataPart]
	var back := _round_trip(outer, "nested_condition") as ConditionData
	if back == null:
		return
	assert_eq(back.kind, ConditionData.Kind.ANY_OF)
	assert_eq(back.children.size(), 1)
	# Typed DataPart (not ConditionData) to avoid a self-reference leak; entries stay conditions.
	assert_eq(back.children.get_typed_script(), DataPart)
	if back.children.size() != 1:
		return
	assert_true(back.children[0] is ConditionData, "children hold ConditionData entries")
	var inner_back: ConditionData = back.children[0]
	assert_eq(inner_back.kind, ConditionData.Kind.ALL_OF)
	assert_eq(inner_back.children.size(), 2)
	if inner_back.children.size() != 2:
		return
	assert_eq(inner_back.children[0].kind, ConditionData.Kind.HAS_ITEM)
	assert_eq(inner_back.children[0].ref_id, &"rope")
	assert_eq(inner_back.children[1].ref_id, &"saw_lighthouse")


# --- content check with real classes -------------------------------------------------------


func test_real_content_passes_the_content_check() -> void:
	_save_content_set(&"rope")
	assert_eq(ContentValidator.validate(_catalog()), PackedStringArray())


func test_broken_id_in_a_nested_condition_is_reported_with_its_path() -> void:
	_save_content_set(&"ghost")
	assert_eq(ContentValidator.validate(_catalog()), PackedStringArray([
		"creatures/land_crab: counters[0].conditions[0].children[0].ref_id references missing items/ghost",
	]))


func test_condition_ids_that_are_not_content_are_not_checked() -> void:
	_save_content_set(&"ghost", ConditionData.Kind.FLAG_SET)
	assert_eq(ContentValidator.validate(_catalog()), PackedStringArray())


func test_keepsake_unlock_ids_are_checked_against_their_folder() -> void:
	_save_content_set(&"rope", ConditionData.Kind.HAS_ITEM, &"ghost_crab")
	assert_eq(ContentValidator.validate(_catalog()), PackedStringArray([
		"items/medalla: unlock_ref_ids references missing creatures/ghost_crab",
	]))


# --- helpers ------------------------------------------------------------------------------


## The 34 data model classes, sorted.
func _model_classes() -> Array[StringName]:
	var names: Array[StringName] = []
	names.assign(FOLDER_CLASSES.values())
	names.append_array(ITEM_SUBCLASSES)
	names.append_array(PART_CLASSES)
	names.sort_custom(_by_text)
	return names


## A new instance of the data class `class_id`, or null if it does not build a Resource.
func _new(class_id: StringName) -> Resource:
	var script: GDScript = _scripts.get(class_id)
	if script == null or not script.can_instantiate():
		return null
	return script.new() as Resource


## Stored script properties of `obj`, by name.
func _stored_props(obj: Object) -> Dictionary[String, Dictionary]:
	var props: Dictionary[String, Dictionary] = {}
	for prop: Dictionary in obj.get_property_list():
		var usage: int = prop["usage"]
		if (usage & PROPERTY_USAGE_STORAGE) != 0 and (usage & PROPERTY_USAGE_SCRIPT_VARIABLE) != 0:
			props[String(prop["name"])] = prop
	return props


## A default instance plus one fresh instance per value of every enum field of `class_id`, so
## references that depend on a kind are seen for every kind.
func _kind_variants(class_id: StringName, props: Dictionary[String, Dictionary]) -> Array[Resource]:
	var variants: Array[Resource] = [_new(class_id)]
	for prop: Dictionary in props.values():
		if int(prop["type"]) != TYPE_INT or int(prop["hint"]) != PROPERTY_HINT_ENUM:
			continue
		for value: int in _enum_values(prop["hint_string"]):
			var inst: Resource = _new(class_id)
			inst.set(prop["name"], value)
			variants.append(inst)
	return variants


## Why `field` cannot be a reference of `class_id` to `target`, or "" if it can. It must be a
## stored StringName, Array[StringName] or Dictionary keyed by StringName (what
## ContentValidator reads) and point at a registered folder.
func _reference_problem(class_id: StringName, props: Dictionary[String, Dictionary], field: StringName, target: StringName) -> String:
	var label := "%s.%s" % [class_id, field]
	if not props.has(String(field)):
		return "%s: reference field is not a stored property" % label
	if not ContentCatalog.DEFAULT_TYPES.has(target):
		return "%s: points at %s, which is not a registered folder" % [label, target]
	var prop: Dictionary = props[String(field)]
	var hint_string: String = prop["hint_string"]
	match int(prop["type"]):
		TYPE_STRING_NAME:
			return ""
		TYPE_ARRAY:
			if hint_string == "%d:" % TYPE_STRING_NAME:
				return ""
		TYPE_DICTIONARY:
			if hint_string.begins_with("%d:;" % TYPE_STRING_NAME):
				return ""
	return "%s: holds %s %s, not an id, an Array[StringName] or a Dictionary keyed by StringName" % [label, type_string(int(prop["type"])), hint_string]


## Where `field` of `obj` points (a folder), or &"" if it is not a reference right now.
func _target(obj: Resource, field: StringName) -> StringName:
	var refs: Dictionary[StringName, StringName] = obj.call(&"get_reference_fields")
	return refs.get(field, &"")


func _condition(kind: ConditionData.Kind, ref_id: StringName) -> ConditionData:
	var condition := ConditionData.new()
	condition.kind = kind
	condition.ref_id = ref_id
	return condition


## Values of an enum hint list ("Name:0,Other:1"; a name without a value counts up).
static func _enum_values(hint_list: String) -> Array[int]:
	var values: Array[int] = []
	var next: int = 0
	for entry: String in hint_list.split(",", false):
		if entry.contains(":"):
			next = int(entry.get_slice(":", entry.get_slice_count(":") - 1))
		values.append(next)
		next += 1
	return values


## The last value of the enum hint list that is not `current` (`current` if it is the only one).
static func _other_enum_value(hint_list: String, current: int) -> int:
	var values := _enum_values(hint_list)
	values.reverse()
	for value: int in values:
		if value != current:
			return value
	return current


## Number of Array and Dictionary fields `obj` stores.
func _container_count(obj: Resource) -> int:
	var count: int = 0
	for prop: Dictionary in _stored_props(obj).values():
		if int(prop["type"]) in [TYPE_ARRAY, TYPE_DICTIONARY]:
			count += 1
	return count


## Sets every stored property of `obj` to a non-default value: typed Arrays and Dictionaries
## get elements (nested parts are filled in turn, FILL_DEPTH levels deep), part slots get a
## filled part, and scalars change. Engine resource slots (textures, scenes...) stay empty.
## Returns how many Array and Dictionary fields of `obj` itself were filled.
func _fill(obj: Resource, depth: int, problems: PackedStringArray, label: String) -> int:
	var filled: int = 0
	for prop: Dictionary in _stored_props(obj).values():
		var field: String = prop["name"]
		var where := "%s.%s" % [label, field]
		var hint_string: String = prop["hint_string"]
		var current: Variant = obj.get(field)
		var prop_type: int = prop["type"]
		if prop_type in [TYPE_ARRAY, TYPE_DICTIONARY] and int(prop["hint"]) != PROPERTY_HINT_TYPE_STRING:
			problems.append("%s: container is not typed" % where)
			continue
		match prop_type:
			TYPE_ARRAY:
				var samples := _samples(hint_string, depth, problems, where)
				if samples.is_empty():
					continue
				var items: Array = current
				items = items.duplicate()
				items.append_array(samples)
				obj.set(field, items)
				filled += 1
			TYPE_DICTIONARY:
				var keys := _samples(hint_string.get_slice(";", 0), depth, problems, where + " key")
				var values := _samples(hint_string.get_slice(";", 1), depth, problems, where + " value")
				if keys.is_empty() or values.is_empty():
					continue
				var entries: Dictionary = current
				entries = entries.duplicate()
				for i: int in keys.size():
					entries[keys[i]] = values[i % values.size()]
				obj.set(field, entries)
				filled += 1
			TYPE_OBJECT:
				if _scripts.has(StringName(hint_string)):
					obj.set(field, _sample_resource(hint_string, depth + 1, problems, where))
			TYPE_INT:
				if int(prop["hint"]) == PROPERTY_HINT_ENUM:
					obj.set(field, _other_enum_value(hint_string, int(current)))
				else:
					obj.set(field, int(current) + 7)
			TYPE_FLOAT:
				obj.set(field, 2.5 if float(current) != 2.5 else 3.5)
			TYPE_BOOL:
				obj.set(field, not bool(current))
			TYPE_STRING:
				obj.set(field, str(current) + " río")
			TYPE_STRING_NAME:
				obj.set(field, StringName(str(current) + "_rt"))
			TYPE_VECTOR2:
				obj.set(field, Vector2(2.5, 3.5) if current != Vector2(2.5, 3.5) else Vector2(4.5, 5.5))
			TYPE_VECTOR2I:
				obj.set(field, Vector2i(3, 9) if current != Vector2i(3, 9) else Vector2i(4, 11))
			TYPE_COLOR:
				obj.set(field, Color(0.25, 0.5, 0.75) if current != Color(0.25, 0.5, 0.75) else Color(0.5, 0.25, 1.0))
			_:
				problems.append("%s: no sample value for %s" % [where, type_string(prop_type)])
	return filled


## Two distinct sample elements for a typed container hint ("21:", "2/2:A:0,B:1",
## "24/17:EffectData"), one for resources. Empty, with a problem, if the type is unknown.
func _samples(elem_hint: String, depth: int, problems: PackedStringArray, where: String) -> Array:
	var head := elem_hint.get_slice(":", 0)
	var detail := elem_hint.substr(head.length() + 1)
	var elem_type := int(head.get_slice("/", 0))
	var elem_hint_kind := int(head.get_slice("/", 1)) if head.contains("/") else PROPERTY_HINT_NONE
	match elem_type:
		TYPE_STRING_NAME:
			return [&"rt_first", &"rt_second"]
		TYPE_STRING:
			return ["rt_first", "rt_second"]
		TYPE_INT:
			if elem_hint_kind == PROPERTY_HINT_ENUM:
				var values := _enum_values(detail)
				return [values[values.size() - 1], values[0]] if values.size() > 1 else [values[0]]
			return [3, 5]
		TYPE_FLOAT:
			return [0.5, 2.5]
		TYPE_OBJECT:
			var first := _sample_resource(detail, depth + 1, problems, where)
			return [first] if first != null else []
	problems.append("%s: no sample elements for %s" % [where, elem_hint])
	return []


## A resource of class `class_id`. Data classes are filled in turn while `depth` is below
## FILL_DEPTH; the engine types the data model uses get a small concrete stand-in.
func _sample_resource(class_id: String, depth: int, problems: PackedStringArray, where: String) -> Resource:
	if _scripts.has(StringName(class_id)):
		var part: Resource = _new(StringName(class_id))
		if part != null and depth < FILL_DEPTH:
			_fill(part, depth, problems, "%s<%s>" % [where, class_id])
		return part
	match class_id:
		"Texture2D":
			var texture := PlaceholderTexture2D.new()
			texture.size = Vector2(7, 9)
			return texture
		"SpriteFrames":
			var frames := SpriteFrames.new()
			frames.add_animation(&"rt_walk")
			return frames
	problems.append("%s: no sample resource for %s" % [where, class_id])
	return null


## Saves `res` as a .tres and loads it back from disk (bypassing the resource cache).
func _round_trip(res: Resource, file_id: String) -> Resource:
	var path := ROUND_TRIP_ROOT.path_join(file_id + ".tres")
	DirAccess.make_dir_recursive_absolute(ROUND_TRIP_ROOT)
	var err := ResourceSaver.save(res, path)
	assert_eq(err, OK, "saved %s" % path)
	if err != OK:
		return null
	var loaded := ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE)
	assert_not_null(loaded, "loaded %s" % path)
	return loaded


## Appends to `problems` every difference between `before` and `after` (its reloaded copy):
## values, element and key types, and nested resources field by field.
func _diff(before: Variant, after: Variant, where: String, problems: PackedStringArray) -> void:
	if typeof(before) != typeof(after):
		problems.append("%s: %s came back as %s" % [where, type_string(typeof(before)), type_string(typeof(after))])
		return
	match typeof(before):
		TYPE_OBJECT:
			_diff_resources(before, after, where, problems)
		TYPE_ARRAY:
			_diff_arrays(before, after, where, problems)
		TYPE_DICTIONARY:
			_diff_dictionaries(before, after, where, problems)
		_:
			if before != after:
				problems.append("%s: %s came back as %s" % [where, before, after])


func _diff_resources(before: Resource, after: Resource, where: String, problems: PackedStringArray) -> void:
	if before == null or after == null:
		if before != after:
			problems.append("%s: %s came back as %s" % [where, before, after])
		return
	if before.get_class() != after.get_class() or before.get_script() != after.get_script():
		problems.append("%s: %s came back as a different type" % [where, before])
		return
	for prop: Dictionary in before.get_property_list():
		var field: String = prop["name"]
		if (int(prop["usage"]) & PROPERTY_USAGE_STORAGE) == 0 or SKIPPED_PROPERTIES.has(field):
			continue
		_diff(before.get(field), after.get(field), "%s.%s" % [where, field], problems)


func _diff_arrays(before: Array, after: Array, where: String, problems: PackedStringArray) -> void:
	if before.get_typed_builtin() != after.get_typed_builtin() \
			or before.get_typed_class_name() != after.get_typed_class_name() \
			or before.get_typed_script() != after.get_typed_script():
		problems.append("%s: lost its element type" % where)
	if before.size() != after.size():
		problems.append("%s: had %d elements, came back with %d" % [where, before.size(), after.size()])
		return
	for i: int in before.size():
		_diff(before[i], after[i], "%s[%d]" % [where, i], problems)


func _diff_dictionaries(before: Dictionary, after: Dictionary, where: String, problems: PackedStringArray) -> void:
	if before.get_typed_key_builtin() != after.get_typed_key_builtin() \
			or before.get_typed_key_script() != after.get_typed_key_script() \
			or before.get_typed_value_builtin() != after.get_typed_value_builtin() \
			or before.get_typed_value_script() != after.get_typed_value_script():
		problems.append("%s: lost its key or value type" % where)
	if before.size() != after.size():
		problems.append("%s: had %d entries, came back with %d" % [where, before.size(), after.size()])
		return
	for key: Variant in before:
		if not after.has(key):
			problems.append("%s: key %s is missing after loading" % [where, key])
			continue
		_diff(before[key], after[key], "%s[%s]" % [where, key], problems)


func _catalog() -> ContentCatalog:
	return ContentCatalog.new(ROOT, ContentCatalog.DEFAULT_TYPES)


func _save(folder: String, entry: ContentData) -> void:
	var saved := FsHelpers.save_content(ROOT, folder, String(entry.id), entry)
	assert_eq(saved, OK, "saved %s/%s" % [folder, entry.id])


## A small real content set: rope (item), a keepsake unlocked by killing `medal_unlocked_by`,
## a snare recipe that needs rope, and a land crab that drops rope, steals it on contact, and
## has a counter that checks (inside an ANY_OF) a `condition_kind` condition on `held_item`.
func _save_content_set(held_item: StringName, condition_kind: ConditionData.Kind = ConditionData.Kind.HAS_ITEM, medal_unlocked_by: StringName = &"land_crab") -> void:
	var rope := ItemData.new()
	rope.id = &"rope"
	rope.name_es = "Soga"
	_save("items", rope)
	var medal := KeepsakeData.new()
	medal.id = &"medalla"
	medal.name_es = "Medalla"
	medal.category = ItemData.Category.KEEPSAKE
	medal.unlock = KeepsakeData.UnlockKind.KILL_CREATURE
	medal.unlock_ref_ids = [medal_unlocked_by] as Array[StringName]
	_save("items", medal)
	var snare := RecipeData.new()
	snare.id = &"snare"
	snare.name_es = "Trampa"
	snare.inputs = {&"rope": 2}
	_save("recipes", snare)
	var any_of := _condition(ConditionData.Kind.ANY_OF, &"")
	any_of.children = [_condition(condition_kind, held_item)] as Array[DataPart]
	var counter := CreatureCounterData.new()
	counter.conditions = [any_of] as Array[ConditionData]
	var steal := EffectData.new()
	steal.kind = EffectData.Kind.TAKE_ITEM
	steal.ref_id = &"rope"
	var crab := CreatureData.new()
	crab.id = &"land_crab"
	crab.name_es = "Cangrejo"
	crab.loot = {&"rope": 1}
	crab.counters = [counter] as Array[CreatureCounterData]
	crab.contact_effects = [steal] as Array[EffectData]
	_save("creatures", crab)


static func _by_text(a: StringName, b: StringName) -> bool:
	return String(a) < String(b)
