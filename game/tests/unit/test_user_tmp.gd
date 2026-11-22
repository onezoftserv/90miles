extends GutTest
## Test isolation: user:// is shared by every checkout of this project on one machine, so each
## test process keeps its files in its own folder (UserTmp) and two GUT runs at once (two
## worktrees, or two processes in one) no longer clobber each other. Offline, one process.

const TESTS_ROOT: String = "res://tests"
## Only these scripts may spell out a user:// path: the helper that hands out the per-process
## paths, and the file helper that refuses to delete anything outside user://.
const ALLOWED: Array[String] = ["res://tests/helpers/user_tmp.gd", "res://tests/helpers/fs_helpers.gd"]
## Collected suites and their helpers; tests/manual holds launchers run by hand, outside GUT.
const SCANNED: Array[String] = ["res://tests/unit", "res://tests/helpers"]

var other_run: String = UserTmp.BASE.path_join("other_run_%d" % OS.get_process_id())


func after_each() -> void:
	FsHelpers.remove_tree(other_run)


func test_a_path_is_inside_this_process_folder() -> void:
	var path: String = UserTmp.path("test_user_tmp_settings.cfg")
	assert_eq(path, "%s/%d/test_user_tmp_settings.cfg" % [UserTmp.BASE, OS.get_process_id()])
	assert_true(DirAccess.dir_exists_absolute(path.get_base_dir()), "the folder exists, so ConfigFile.save works")
	var config := ConfigFile.new()
	config.set_value("player", "name", "Yuni")
	assert_eq(config.save(path), OK)
	DirAccess.remove_absolute(path)


func test_each_name_gets_its_own_path() -> void:
	assert_ne(UserTmp.path("test_a_settings.cfg"), UserTmp.path("test_b_settings.cfg"))
	assert_eq(UserTmp.path("test_a_settings.cfg"), UserTmp.path("test_a_settings.cfg"), "stable within a run")


func test_cleanup_leaves_another_runs_folder() -> void:
	DirAccess.make_dir_recursive_absolute(other_run)
	var kept := ConfigFile.new()
	kept.set_value("player", "name", "Papo")
	assert_eq(kept.save(other_run.path_join("settings.cfg")), OK)
	var mine: String = UserTmp.path("test_user_tmp_cleanup")
	DirAccess.make_dir_recursive_absolute(mine)
	UserTmp.remove_own()
	assert_false(DirAccess.dir_exists_absolute(UserTmp.own_root()), "this run's folder is gone")
	assert_true(FileAccess.file_exists(other_run.path_join("settings.cfg")), "the other run's file stays")
	assert_true(DirAccess.dir_exists_absolute(UserTmp.path("test_user_tmp_cleanup").get_base_dir()), "and a later path() makes this run's folder again")


func test_no_suite_or_helper_names_a_fixed_user_path() -> void:
	var fixed: PackedStringArray = []
	for root: String in SCANNED:
		for script_path: String in _scripts_under(root):
			if ALLOWED.has(script_path):
				continue
			var text: String = FileAccess.get_file_as_string(script_path)
			for quote: String in ["\"", "'"]:
				if text.contains(quote + "user:" + "//"):
					fixed.append(script_path)
					break
	assert_eq(fixed, PackedStringArray(), "use UserTmp.path(name) instead of a fixed user:// path")


func _scripts_under(dir_path: String) -> PackedStringArray:
	var found: PackedStringArray = []
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return found
	for file: String in dir.get_files():
		if file.get_extension() == "gd":
			found.append(dir_path.path_join(file))
	for sub: String in dir.get_directories():
		found.append_array(_scripts_under(dir_path.path_join(sub)))
	return found
