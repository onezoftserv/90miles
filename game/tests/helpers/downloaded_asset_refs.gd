class_name DownloadedAssetRefs
extends RefCounted
## Finds tracked files that refer into a git-ignored download folder (build-verification "No
## dependency on downloaded assets"; design.md K10). Art the game uses is copied into a tracked
## folder first, so a clean CI checkout, which has none of these folders, still runs.

## The same four prefixes as smoke.gd's IGNORED_ASSET_DIRS (a test keeps them equal).
const IGNORED_PREFIXES: PackedStringArray = [
	"res://assets/kenney/", "res://assets/oga/", "res://assets/itch/", "res://assets/audio/ambience/",
]
const SCANNED_EXTENSIONS: PackedStringArray = ["tscn", "tres", "gd", "gdshader", "gdshaderinc"]
## Never scanned: the addons, the import cache, the test guards that name the download folders
## on purpose (smoke.gd, test_player_scene.gd, test_theme.gd and the test for this helper), and
## the download folders themselves, which are git-ignored rather than tracked.
const SKIPPED_DIRS: PackedStringArray = [
	"res://addons", "res://.godot", "res://tests",
	"res://assets/kenney", "res://assets/oga", "res://assets/itch", "res://assets/audio/ambience",
]


## Every scanned file under res://, sorted.
static func tracked_files() -> PackedStringArray:
	var found: PackedStringArray = _files_under("res://")
	found.sort()
	return found


## One failure per reference into a download folder in any scanned file.
static func scan_tree() -> PackedStringArray:
	var failures: PackedStringArray = []
	for path: String in tracked_files():
		failures.append_array(scan_text(path, FileAccess.get_file_as_string(path)))
	return failures


## One failure per reference in `text`, naming `file` and the referenced path.
static func scan_text(file: String, text: String) -> PackedStringArray:
	var failures: PackedStringArray = []
	for reference: RegExMatch in _pattern().search_all(text):
		failures.append("%s refers to %s, inside a git-ignored download folder" % [file, reference.get_string()])
	return failures


static func _pattern() -> RegEx:
	var alternatives: PackedStringArray = []
	for prefix: String in IGNORED_PREFIXES:
		alternatives.append(_escape(prefix))
	var regex: RegEx = RegEx.new()
	regex.compile("(?:%s)[^\"'\\n)]*" % "|".join(alternatives))
	return regex


static func _escape(text: String) -> String:
	var escaped: String = ""
	for character: String in text:
		escaped += ("\\" + character) if ".()[]{}*+?^$|\\/".contains(character) else character
	return escaped


static func _files_under(dir_path: String) -> PackedStringArray:
	var found: PackedStringArray = []
	var dir: DirAccess = DirAccess.open(dir_path)
	if dir == null:
		return found
	for sub: String in dir.get_directories():
		var sub_path: String = dir_path.path_join(sub)
		if not SKIPPED_DIRS.has(sub_path):
			found.append_array(_files_under(sub_path))
	for file: String in dir.get_files():
		if SCANNED_EXTENSIONS.has(file.get_extension()):
			found.append(dir_path.path_join(file))
	return found
