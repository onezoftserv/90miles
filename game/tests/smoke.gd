extends SceneTree
## Headless smoke run (build-verification spec): loads every script, boots the main scene,
## checks the core services and the content data, and exits non-zero on any engine error.
##
## Run from the repo root after one import:
##   godot --headless --path game --import
##   godot --headless --path game -s res://tests/smoke.gd

const MAIN_SCENE := "res://scenes/main/main.tscn"
const SCRIPT_ROOTS: Array[String] = ["res://scripts", "res://scenes"]
const RUN_FRAMES := 10


## Collects engine errors (not warnings) from any thread.
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


func _initialize() -> void:
	OS.add_logger(_collector)
	for script_root: String in SCRIPT_ROOTS:
		_failures.append_array(_check_scripts(script_root))
	var packed := load(MAIN_SCENE) as PackedScene
	if packed == null:
		_failures.append("main scene failed to load: %s" % MAIN_SCENE)
	else:
		root.add_child(packed.instantiate())
	_failures.append_array(CoreServices.check(root))
	var game_state: Node = root.get_node_or_null(^"GameState")
	if game_state != null and game_state.get(&"content") is ContentCatalog:
		_failures.append_array(ContentValidator.validate(game_state.get(&"content")))
	else:
		_failures.append("GameState.content is not a ContentCatalog")


func _process(_delta: float) -> bool:
	_frames += 1
	if _frames == RUN_FRAMES:
		_finish()
	return false


func _finish() -> void:
	var problems := _failures.duplicate()
	problems.append_array(_collector.snapshot())
	for problem: String in problems:
		printerr("SMOKE FAIL: ", problem)
	print("smoke: %d frames, %d problem(s)" % [_frames, problems.size()])
	OS.remove_logger(_collector)
	quit(1 if problems.size() > 0 else 0)


## Loads every .gd under `dir_path`; a script that fails to parse is reported by path.
func _check_scripts(dir_path: String) -> PackedStringArray:
	var failures: PackedStringArray = []
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return failures
	for sub: String in dir.get_directories():
		failures.append_array(_check_scripts(dir_path.path_join(sub)))
	for file: String in dir.get_files():
		if file.get_extension() != "gd":
			continue
		var path := dir_path.path_join(file)
		var script := load(path) as Script
		if script == null or not script.can_instantiate():
			failures.append("script failed to load: %s" % path)
	return failures
