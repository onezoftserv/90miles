extends GutTest
## build-verification: GUT skips test scripts it cannot parse and still exits 0, so a broken
## test file would pass CI silently. This test loads every script under res://tests and fails
## the run if any of them does not compile.

const TESTS_ROOT := "res://tests"


func test_every_test_script_compiles() -> void:
	var broken: PackedStringArray = []
	for path: String in _scripts_under(TESTS_ROOT):
		var script := load(path) as Script
		if script == null or not script.can_instantiate():
			broken.append(path)
	assert_eq(broken, PackedStringArray(), "test scripts that do not compile")


func test_suite_has_tests() -> void:
	var count: int = 0
	for path: String in _scripts_under(TESTS_ROOT.path_join("unit")):
		if path.get_file().begins_with("test_"):
			count += 1
	assert_gt(count, 1, "unit test files found")


func test_every_test_file_is_a_gut_test_with_tests() -> void:
	var problems: PackedStringArray = []
	for path: String in _scripts_under(TESTS_ROOT.path_join("unit")):
		if not path.get_file().begins_with("test_"):
			continue
		var script := load(path) as Script
		if script == null:
			continue
		if not _extends_gut_test(script):
			problems.append("%s does not extend GutTest" % path)
		var has_test := false
		for method: Dictionary in script.get_script_method_list():
			if String(method["name"]).begins_with("test_"):
				has_test = true
				break
		if not has_test:
			problems.append("%s has no test_ methods" % path)
	assert_eq(problems, PackedStringArray())


# GUT only collects res://tests/unit (see .gutconfig.json); a test file elsewhere never runs.
func test_no_test_files_outside_the_collected_folder() -> void:
	var stray: PackedStringArray = []
	for path: String in _scripts_under(TESTS_ROOT):
		if path.get_file().begins_with("test_") and not path.begins_with(TESTS_ROOT.path_join("unit/")):
			stray.append(path)
	assert_eq(stray, PackedStringArray())


func _extends_gut_test(script: Script) -> bool:
	var base := script.get_base_script()
	while base != null:
		if base.get_global_name() == &"GutTest":
			return true
		base = base.get_base_script()
	return false


func _scripts_under(dir_path: String) -> PackedStringArray:
	var found: PackedStringArray = []
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return found
	for sub: String in dir.get_directories():
		found.append_array(_scripts_under(dir_path.path_join(sub)))
	for file: String in dir.get_files():
		if file.get_extension() == "gd":
			found.append(dir_path.path_join(file))
	return found
