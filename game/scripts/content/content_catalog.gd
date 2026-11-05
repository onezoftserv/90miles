class_name ContentCatalog
extends RefCounted
## Finds content by folder (content-data spec): every .tres or .res file in
## <root>/<type>/ is one entry, keyed by its file name. Files added later are found without
## code changes, in the editor and in exported builds.

const DEFAULT_ROOT := "res://resources"
## Content type (folder name) -> the script every file in that folder must use.
const DEFAULT_TYPES: Dictionary[StringName, Script] = {}
const EXTENSIONS: Array[String] = ["tres", "res"]

var _root: String
var _types: Dictionary[StringName, Script]
var _cache: Dictionary[String, ContentData] = {}


func _init(root: String = DEFAULT_ROOT, types: Dictionary[StringName, Script] = DEFAULT_TYPES) -> void:
	_root = root
	_types = types


## Every content type this catalog knows, sorted.
func types() -> Array[StringName]:
	var keys: Array[StringName] = []
	keys.assign(_types.keys())
	keys.sort_custom(_by_text)
	return keys


func has_type(type: StringName) -> bool:
	return _types.has(type)


## The script every file of `type` must use, or null for an unknown type.
func script_for(type: StringName) -> Script:
	return _types.get(type)


func folder_path(type: StringName) -> String:
	return _root.path_join(String(type))


## Content file names in the folder of `type` (with extension), sorted.
func list_files(type: StringName) -> PackedStringArray:
	var files: PackedStringArray = []
	var folder := folder_path(type)
	if not has_type(type) or not DirAccess.dir_exists_absolute(folder):
		return files
	for entry: String in ResourceLoader.list_directory(folder):
		if not entry.ends_with("/") and EXTENSIONS.has(entry.get_extension()):
			files.append(entry)
	files.sort()
	return files


## Ids of every entry of `type`, sorted and unique.
func list_ids(type: StringName) -> Array[StringName]:
	var ids: Array[StringName] = []
	for file: String in list_files(type):
		var file_id := StringName(file.get_basename())
		if not ids.has(file_id):
			ids.append(file_id)
	ids.sort_custom(_by_text)
	return ids


func has_entry(type: StringName, entry_id: StringName) -> bool:
	return not _path_for(type, entry_id).is_empty()


## The entry `entry_id` of `type`, or null if it does not exist or is not content.
func get_entry(type: StringName, entry_id: StringName) -> ContentData:
	var key := "%s/%s" % [type, entry_id]
	if _cache.has(key):
		return _cache[key]
	var path := _path_for(type, entry_id)
	if path.is_empty():
		return null
	var entry := ResourceLoader.load(path) as ContentData
	if entry != null:
		_cache[key] = entry
	return entry


## Folders under the root that are not registered content types (their files are never
## validated or loaded, so they are reported instead of silently ignored).
func unregistered_folders() -> PackedStringArray:
	var stray: PackedStringArray = []
	if not DirAccess.dir_exists_absolute(_root):
		return stray
	for folder: String in DirAccess.get_directories_at(_root):
		if not folder.begins_with(".") and not has_type(StringName(folder)):
			stray.append(folder)
	stray.sort()
	return stray


# Matches against the exact listed file names, not ResourceLoader.exists(): Windows file systems
# ignore case, so "Rope" would resolve locally and then fail on Linux CI and in exports.
func _path_for(type: StringName, entry_id: StringName) -> String:
	if not has_type(type) or String(entry_id).is_empty():
		return ""
	var files := list_files(type)
	for ext: String in EXTENSIONS:
		var file := "%s.%s" % [entry_id, ext]
		if files.has(file):
			return folder_path(type).path_join(file)
	return ""


static func _by_text(a: StringName, b: StringName) -> bool:
	return String(a) < String(b)
