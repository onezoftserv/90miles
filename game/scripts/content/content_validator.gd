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
		errors.append_array(_check_secret(where, data))
		errors.append_array(_check_patrol(where, data))
		errors.append_array(_check_squad(catalog, where, data))
		errors.append_array(_check_vessel_recipe(where, data))
		errors.append_array(_check_staged_recipe(where, data))
	return errors


# island-pressure (crafting-inventory "Build stages", "Work costs"): a staged recipe is a build site
# whose stages add up to its inputs and its time, each stage with work time and names in both
# languages; stages take items only, never tags. A work cost is never negative.
static func _check_staged_recipe(where: String, data: ContentData) -> PackedStringArray:
	var errors: PackedStringArray = []
	var recipe := data as RecipeData
	if recipe == null:
		return errors
	if recipe.work_energy_per_s < 0.0 or recipe.work_thirst_per_s < 0.0:
		errors.append("%s: a work cost is never negative" % where)
	if not recipe.is_staged():
		return errors
	if not recipe.build_site:
		errors.append("%s: only a build site has stages" % where)
	if not recipe.input_tags.is_empty():
		errors.append("%s: a staged recipe takes items only, no tag inputs" % where)
	var summed: Dictionary[StringName, int] = {}
	var time_s: float = 0.0
	for i: int in recipe.stages.size():
		var stage: BuildStageData = recipe.stages[i]
		if stage == null:
			errors.append("%s: stage %d is empty" % [where, i + 1])
			continue
		if stage.name_es.strip_edges().is_empty() or stage.name_en.strip_edges().is_empty():
			errors.append("%s: stage %d needs a Spanish and an English name" % [where, i + 1])
		if stage.time_s <= 0.0:
			errors.append("%s: stage %d has no work time (time_s must be above 0)" % [where, i + 1])
		time_s += stage.time_s
		for id: StringName in stage.inputs:
			summed[id] = summed.get(id, 0) + stage.inputs[id]
	if summed != recipe.inputs:
		errors.append("%s: the stages' inputs %s do not add up to the recipe's %s" % [where, summed, recipe.inputs])
	if absf(time_s - recipe.time_s) > 0.001:
		errors.append("%s: the stages' times add up to %s s, not the recipe's %s s" % [where, time_s, recipe.time_s])
	return errors


# island-stop "Mending a built raft", "Raft fittings": a mend restores integrity and a fitting
# raises the maximum or changes the vessel at sea; both are worked on the raft itself, never at a
# bench or as a placed site.
static func _check_vessel_recipe(where: String, data: ContentData) -> PackedStringArray:
	var errors: PackedStringArray = []
	var recipe := data as RecipeData
	if recipe == null:
		return errors
	var kind := recipe.output_kind
	if kind != RecipeData.OutputKind.VESSEL_REPAIR and kind != RecipeData.OutputKind.VESSEL_UPGRADE:
		return errors
	if recipe.station != RecipeData.Station.NONE or recipe.build_site:
		errors.append("%s: a vessel recipe is worked on the raft: station NONE and no build site" % where)
	if kind == RecipeData.OutputKind.VESSEL_REPAIR and recipe.integrity_delta <= 0.0:
		errors.append("%s: a mend restores no integrity (integrity_delta must be above 0)" % where)
	if kind == RecipeData.OutputKind.VESSEL_UPGRADE and recipe.integrity_delta <= 0.0 and recipe.vessel_modifiers.is_empty():
		errors.append("%s: a fitting does nothing (no integrity_delta and no vessel modifier)" % where)
	for modifier: ModifierData in recipe.vessel_modifiers:
		if modifier == null or modifier.scope != ModifierData.Scope.VESSEL:
			errors.append("%s: a fitting's modifiers apply to the vessel (scope VESSEL)" % where)
	return errors


# guardacostas-capture "Shore squad data": a patrol creature that names a squad lands soldiers that
# search and capture, with a touch and a free radius, its calls in both languages, a scene and a
# commander. A missing id is the reference check's to report, so it is not reported twice here.
static func _check_squad(catalog: ContentCatalog, where: String, data: ContentData) -> PackedStringArray:
	var errors: PackedStringArray = []
	var creature := data as CreatureData if data is CreatureData else null
	if creature == null or creature.patrol == null:
		return errors
	var patrol: PatrolData = creature.patrol
	if patrol.squad_size <= 0 and patrol.squad_creature_id.is_empty():
		return errors
	if patrol.squad_size < 1:
		errors.append("%s: squad_size %d must be at least 1 for a patrol with a squad" % [where, patrol.squad_size])
	if patrol.squad_creature_id.is_empty():
		errors.append("%s: squad_creature_id is empty for a patrol with a squad" % where)
	elif catalog.has_entry(&"creatures", patrol.squad_creature_id):
		var soldier := catalog.get_entry(&"creatures", patrol.squad_creature_id) as CreatureData
		if soldier != null and soldier.behavior != CreatureData.Behavior.SEARCH_CAPTURE:
			errors.append("%s: squad creature %s must have the SEARCH_CAPTURE behavior" % [where, patrol.squad_creature_id])
	if patrol.capture_touch_tiles <= 0.0 or patrol.capture_touch_s <= 0.0:
		errors.append("%s: capture_touch_tiles and capture_touch_s must be above 0" % where)
	if patrol.free_guard_radius_tiles <= 0.0:
		errors.append("%s: free_guard_radius_tiles must be above 0" % where)
	if patrol.capture_dialogue_id.is_empty():
		errors.append("%s: capture_dialogue_id names no scene" % where)
	if patrol.commander_npc_id.is_empty():
		errors.append("%s: commander_npc_id names no commander" % where)
	for lines: Array in [
		["squad_land_lines_es", patrol.squad_land_lines_es], ["squad_land_lines_en", patrol.squad_land_lines_en],
		["squad_spot_lines_es", patrol.squad_spot_lines_es], ["squad_spot_lines_en", patrol.squad_spot_lines_en],
		["squad_leave_lines_es", patrol.squad_leave_lines_es], ["squad_leave_lines_en", patrol.squad_leave_lines_en],
	]:
		if (lines[1] as PackedStringArray).is_empty():
			errors.append("%s: %s needs at least one line" % [where, lines[0]])
	return errors


# secret-cay "Secret items": no item-tag spawn may ever draw a secret item, so its weight is 0.
static func _check_secret(where: String, data: ContentData) -> PackedStringArray:
	var item := data as ItemData if data is ItemData else null
	if item != null and item.tags.has(DataEnums.ItemTag.SECRET) and item.spawn_weight > 0.0:
		return PackedStringArray(["%s: a secret item must have spawn_weight 0, not %s" % [where, item.spawn_weight]])
	return PackedStringArray()


# guardacostas-stealth: a PATROL-tagged creature has a patrol part whose lap fits its period,
# whose cone and range make a light, whose meter drains and which has loudhailer lines.
static func _check_patrol(where: String, data: ContentData) -> PackedStringArray:
	var errors: PackedStringArray = []
	var creature := data as CreatureData if data is CreatureData else null
	if creature == null or not creature.creature_tags.has(DataEnums.CreatureTag.PATROL):
		return errors
	var patrol: PatrolData = creature.patrol
	if patrol == null:
		errors.append("%s: a PATROL creature needs a patrol part" % where)
		return errors
	if patrol.route_lap_s >= patrol.route_period_s - patrol.horizon_warning_s:
		errors.append("%s: route_lap_s %s must be shorter than route_period_s %s minus horizon_warning_s %s" % [where, patrol.route_lap_s, patrol.route_period_s, patrol.horizon_warning_s])
	if patrol.route_lap_s <= 0.0:
		errors.append("%s: route_lap_s must be above 0" % where)
	if patrol.spot_time_s <= 0.0:
		errors.append("%s: spot_time_s must be above 0" % where)
	if patrol.alert_s <= 0.0:
		errors.append("%s: alert_s must be above 0" % where)
	if patrol.searchlight_cone_deg <= 0.0 or patrol.searchlight_cone_deg > 180.0:
		errors.append("%s: searchlight_cone_deg %s must be above 0 and at most 180" % [where, patrol.searchlight_cone_deg])
	if patrol.searchlight_range_tiles <= 0.0:
		errors.append("%s: searchlight_range_tiles must be above 0" % where)
	if patrol.spot_drain_per_s <= 0.0:
		errors.append("%s: spot_drain_per_s must be above 0" % where)
	for lines: Array in [
		["alert_lines_es", patrol.alert_lines_es], ["alert_lines_en", patrol.alert_lines_en],
		["give_up_lines_es", patrol.give_up_lines_es], ["give_up_lines_en", patrol.give_up_lines_en],
	]:
		if (lines[1] as PackedStringArray).is_empty():
			errors.append("%s: %s needs at least one line" % [where, lines[0]])
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
