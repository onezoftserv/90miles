class_name ContentValidator
extends RefCounted
## Checks every content file a catalog can see (content-data spec): each file uses its
## folder's type, its id equals its file name, it has a Spanish name, and every id it
## references exists. Returns one readable message per problem; empty means valid.


static func validate(catalog: ContentCatalog) -> PackedStringArray:
	var errors: PackedStringArray = []
	for type: StringName in catalog.types():
		errors.append_array(_validate_type(catalog, type))
	return errors


static func _validate_type(catalog: ContentCatalog, type: StringName) -> PackedStringArray:
	var errors: PackedStringArray = []
	var expected := catalog.script_for(type)
	var seen: Dictionary[StringName, bool] = {}
	for file: String in catalog.list_files(type):
		var file_id := StringName(file.get_basename())
		var where := "%s/%s" % [type, file_id]
		if seen.has(file_id):
			errors.append("%s: duplicate id, more than one file is named %s" % [where, file_id])
			continue
		seen[file_id] = true
		var res := ResourceLoader.load(catalog.folder_path(type).path_join(file))
		if res == null:
			errors.append("%s: file does not load" % where)
			continue
		if not is_instance_of(res, expected):
			errors.append("%s: expected %s, found %s" % [where, _script_name(expected), _resource_type_name(res)])
			continue
		var data := res as ContentData
		if data.id != file_id:
			errors.append("%s: id is %s but the file name is %s" % [where, data.id, file_id])
		if data.requires_name() and data.name_es.strip_edges().is_empty():
			errors.append("%s: name_es is empty" % where)
		errors.append_array(_check_references(catalog, where, data))
	return errors


static func _check_references(catalog: ContentCatalog, where: String, data: ContentData) -> PackedStringArray:
	var errors: PackedStringArray = []
	var refs := data.get_reference_fields()
	for field: StringName in refs:
		var target: StringName = refs[field]
		if not field in data:
			errors.append("%s: reference field %s does not exist" % [where, field])
			continue
		if not catalog.has_type(target):
			errors.append("%s: %s points at unknown content type %s" % [where, field, target])
			continue
		for ref_id: StringName in _ids_in(data.get(field)):
			if not catalog.has_entry(target, ref_id):
				errors.append("%s: %s references missing %s/%s" % [where, field, target, ref_id])
	return errors


## Ids held by a reference field: a single id, an array of ids, or dictionary keys.
static func _ids_in(value: Variant) -> Array[StringName]:
	var ids: Array[StringName] = []
	match typeof(value):
		TYPE_STRING_NAME, TYPE_STRING:
			if not String(value).is_empty():
				ids.append(StringName(value))
		TYPE_ARRAY, TYPE_PACKED_STRING_ARRAY:
			for item: Variant in value:
				ids.append_array(_ids_in(item))
		TYPE_DICTIONARY:
			for key: Variant in value:
				ids.append_array(_ids_in(key))
	return ids


static func _script_name(script: Script) -> String:
	if script == null:
		return "<no type>"
	var global_name := script.get_global_name()
	return String(global_name) if not String(global_name).is_empty() else script.resource_path


static func _resource_type_name(res: Resource) -> String:
	var script := res.get_script() as Script
	return _script_name(script) if script != null else res.get_class()
