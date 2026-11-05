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
