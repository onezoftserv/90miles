class_name ContentValidator
extends RefCounted
## Checks every content file a catalog can see (content-data spec): each file uses its
## folder's type, its id equals its file name, it has a Spanish name, and every id it
## references exists. Returns one readable message per problem; empty means valid.

## Guards against runaway nesting (and cycles) in embedded parts.
const MAX_PART_DEPTH := 16


static func validate(catalog: ContentCatalog) -> PackedStringArray:
	var errors: PackedStringArray = []
	for folder: String in catalog.unregistered_folders():
		errors.append("%s: folder is not a registered content type, so its files are never checked" % folder)
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
		if data == null:
			errors.append("%s: %s is not a ContentData type" % [where, _script_name(expected)])
			continue
		if data.id != file_id:
			errors.append("%s: id is %s but the file name is %s" % [where, data.id, file_id])
		if data.requires_name() and data.name_es.strip_edges().is_empty():
			errors.append("%s: name_es is empty" % where)
		errors.append_array(_check_references(catalog, where, data))
	return errors


## Checks the references `obj` declares (a ContentData entry or an embedded DataPart), then
## recurses into every DataPart it holds, alone or in an array. `path` prefixes field names in
## messages ("parts[1].children[0]."), so nested problems say exactly where they are.
static func _check_references(catalog: ContentCatalog, where: String, obj: Resource, path: String = "", depth: int = 0) -> PackedStringArray:
	var errors: PackedStringArray = []
	if depth > MAX_PART_DEPTH:
		errors.append("%s: %sparts are nested deeper than %d levels" % [where, path, MAX_PART_DEPTH])
		return errors
	var refs: Dictionary[StringName, StringName] = obj.call(&"get_reference_fields")
	for field: StringName in refs:
		var target: StringName = refs[field]
		var label := path + String(field)
		if not field in obj:
			errors.append("%s: reference field %s does not exist" % [where, label])
			continue
		if not catalog.has_type(target):
			errors.append("%s: %s points at unknown content type %s" % [where, label, target])
			continue
		var ids: Array[StringName] = []
		var unsupported := _collect_ids(obj.get(field), ids)
		if not unsupported.is_empty():
			errors.append("%s: %s holds unsupported type %s (use an id, an array of ids or a dictionary keyed by id)" % [where, label, unsupported])
			continue
		for ref_id: StringName in ids:
			if not catalog.has_entry(target, ref_id):
				errors.append("%s: %s references missing %s/%s" % [where, label, target, ref_id])
	for prop: Dictionary in obj.get_property_list():
		if not int(prop["usage"]) & PROPERTY_USAGE_STORAGE:
			continue
		var prop_name: String = prop["name"]
		var value: Variant = obj.get(prop_name)
		if value is DataPart:
			errors.append_array(_check_references(catalog, where, value, "%s%s." % [path, prop_name], depth + 1))
		elif value is Array:
			var items: Array = value
			for i: int in items.size():
				if items[i] is DataPart:
					errors.append_array(_check_references(catalog, where, items[i], "%s%s[%d]." % [path, prop_name, i], depth + 1))
	return errors


## Appends the ids held by a reference field to `ids`: a single id, an array of ids, or
## dictionary keys. Returns the name of the first unsupported value type, or "" if none.
static func _collect_ids(value: Variant, ids: Array[StringName]) -> String:
	match typeof(value):
		TYPE_STRING_NAME, TYPE_STRING:
			if not String(value).is_empty():
				ids.append(StringName(value))
		TYPE_ARRAY, TYPE_PACKED_STRING_ARRAY:
			for item: Variant in value:
				if typeof(item) != TYPE_STRING_NAME and typeof(item) != TYPE_STRING:
					return type_string(typeof(item))
				ids.append(StringName(item))
		TYPE_DICTIONARY:
			for key: Variant in value:
				if typeof(key) != TYPE_STRING_NAME and typeof(key) != TYPE_STRING:
					return type_string(typeof(key))
				ids.append(StringName(key))
		TYPE_NIL:
			pass
		_:
			return type_string(typeof(value))
	return ""


static func _script_name(script: Script) -> String:
	if script == null:
		return "<no type>"
	var global_name := script.get_global_name()
	return String(global_name) if not String(global_name).is_empty() else script.resource_path


static func _resource_type_name(res: Resource) -> String:
	var script := res.get_script() as Script
	return _script_name(script) if script != null else res.get_class()
