extends SceneTree
## Headless smoke run (build-verification spec): compiles every script, loads every scene and
## resource, boots the configured main scene, checks the core services and the content data,
## and exits non-zero on any engine error.
##
## Run from the repo root after one import:
##   godot --headless --path game --import
##   godot --headless --path game -s res://tests/smoke.gd

## Folders whose scripts must compile. res://tests is included because GUT skips test files
## it cannot parse, including the suite-integrity test that guards against that.
const SCRIPT_ROOTS: Array[String] = ["res://scripts", "res://scenes", "res://tests"]
## Folders whose scenes and resources must load. res://assets/art holds the art resources
## (sprite frames, look parts, credits), which must not depend on a download folder either.
const RESOURCE_ROOTS: Array[String] = ["res://scenes", "res://resources", "res://assets/art"]
const RESOURCE_EXTENSIONS: Array[String] = ["tscn", "tres", "res"]
## Git-ignored download folders (see .gitignore). Nothing committed may depend on them, or CI,
## which has none of them, breaks.
const IGNORED_ASSET_DIRS: Array[String] = [
	"res://assets/kenney/", "res://assets/oga/", "res://assets/itch/", "res://assets/audio/ambience/",
]
const RUN_FRAMES := 10


## Collects engine and script errors from any thread. Warnings are not collected: the GDScript
## warnings that matter (untyped declarations) are raised to errors in project.godot.
class ErrorCollector extends Logger:
	var messages: PackedStringArray = []
	var _lock := Mutex.new()

	func _log_error(function: String, file: String, line: int, code: String, rationale: String, _editor_notify: bool, error_type: int, _script_backtrace: Array[ScriptBacktrace]) -> void:
		if error_type == ERROR_TYPE_WARNING:
			return
		_lock.lock()
		messages.append("%s:%d (%s) %s %s" % [file, line, function, code, rationale])
		_lock.unlock()

	func _log_message(_message: String, _error: bool) -> void:
		pass

	func snapshot() -> PackedStringArray:
		_lock.lock()
		var copy := messages.duplicate()
		_lock.unlock()
		return copy


var _collector := ErrorCollector.new()
var _failures: PackedStringArray = []
var _frames: int = 0


# Registered in _init, before the autoloads are constructed, so errors raised while they are
# built are collected too (_initialize runs after that).
func _init() -> void:
	OS.add_logger(_collector)


func _initialize() -> void:
	var scripts_checked: int = 0
	for script_root: String in SCRIPT_ROOTS:
		if not DirAccess.dir_exists_absolute(script_root):
			_failures.append("script folder missing: %s" % script_root)
			continue
		var paths := _files_under(script_root, ["gd"])
		scripts_checked += paths.size()
		for path: String in paths:
			var script := load(path) as Script
			if script == null or not script.can_instantiate():
				_failures.append("script failed to load: %s" % path)
	if scripts_checked == 0:
		_failures.append("no scripts found under %s" % [SCRIPT_ROOTS])
	for resource_root: String in RESOURCE_ROOTS:
		_failures.append_array(_check_resources(resource_root))
	_boot_main_scene()


func _process(_delta: float) -> bool:
	_frames += 1
	if _frames == 1:
		_check_services_and_content()
	if _frames == RUN_FRAMES:
		_finish()
	return false


# Runs on the first frame: by then the autoloads are inside the tree and have run _ready.
func _check_services_and_content() -> void:
	_failures.append_array(CoreServices.check(root))
	var game_state: Node = root.get_node_or_null(^"GameState")
	if game_state != null and game_state.get(&"content") is ContentCatalog:
		_failures.append_array(ContentValidator.validate(game_state.get(&"content")))
	else:
		_failures.append("GameState.content is not a ContentCatalog")


func _boot_main_scene() -> void:
	var main_scene: String = ProjectSettings.get_setting("application/run/main_scene", "")
	if main_scene.is_empty():
		_failures.append("no main scene configured (application/run/main_scene)")
		return
	var packed := load(main_scene) as PackedScene
	if packed == null:
		_failures.append("main scene failed to load: %s" % main_scene)
		return
	root.add_child(packed.instantiate())


func _finish() -> void:
	var problems := _failures.duplicate()
	problems.append_array(_collector.snapshot())
	for problem: String in problems:
		printerr("SMOKE FAIL: ", problem)
	print("smoke: %d frames, %d problem(s)" % [_frames, problems.size()])
	quit(1 if problems.size() > 0 else 0)


## Loads every scene and resource under `dir_path` and reports any that fail to load or that
## depend on a git-ignored download folder. A missing folder is fine (no content yet).
func _check_resources(dir_path: String) -> PackedStringArray:
	var failures: PackedStringArray = []
	for path: String in _files_under(dir_path, RESOURCE_EXTENSIONS):
		for dependency: String in ResourceLoader.get_dependencies(path):
			for ignored: String in IGNORED_ASSET_DIRS:
				if dependency.contains(ignored):
					failures.append("%s depends on git-ignored %s" % [path, dependency.get_slice("::", 2) if dependency.contains("::") else dependency])
		if load(path) == null:
			failures.append("resource failed to load: %s" % path)
	return failures


## Every file under `dir_path` (recursively) whose extension is in `extensions`.
func _files_under(dir_path: String, extensions: Array[String]) -> PackedStringArray:
	var found: PackedStringArray = []
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return found
	for sub: String in dir.get_directories():
		found.append_array(_files_under(dir_path.path_join(sub), extensions))
	for file: String in dir.get_files():
		if extensions.has(file.get_extension()):
			found.append(dir_path.path_join(file))
	return found
