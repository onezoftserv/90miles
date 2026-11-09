extends GutTest
## build-verification "No dependency on downloaded assets" (art-pass delta, design.md K10): no
## tracked scene, resource, script or shader under res://, nor project.godot, refers to a file
## inside a git-ignored download folder. Only the five test guards that name those folders in order
## to forbid them are skipped (design.md K29); the rest of res://tests is scanned.

const SMOKE_PATH: String = "res://tests/smoke.gd"
## A scene's text whose sprite points into the itch download folder ("A reference into a
## download folder"). Kept as .txt so the import never tries to resolve it.
const FIXTURE_PATH: String = "res://tests/fixtures/art/refs/sprite_from_itch.tscn.txt"
const FIXTURE_AS: String = "res://scenes/fixture/sprite_from_itch.tscn"
const FIXTURE_TARGET: String = "res://assets/itch/metrocity/extracted/Character Model.png"


func _smoke_constant(constant: String) -> Variant:
	var script: Script = load(SMOKE_PATH) as Script
	return script.get_script_constant_map()[constant]


func test_the_guard_checks_the_same_four_folders_as_the_smoke_run() -> void:
	var smoke_dirs: Array = _smoke_constant("IGNORED_ASSET_DIRS")
	assert_eq(smoke_dirs.size(), 4)
	assert_eq(Array(DownloadedAssetRefs.IGNORED_PREFIXES), smoke_dirs)


func test_no_tracked_file_refers_to_a_download_folder() -> void:
	var files: PackedStringArray = DownloadedAssetRefs.tracked_files()
	assert_gt(files.size(), 100, "files scanned")
	assert_eq(DownloadedAssetRefs.scan_tree(), PackedStringArray())


func test_every_kind_of_tracked_file_is_scanned() -> void:
	var files: PackedStringArray = DownloadedAssetRefs.tracked_files()
	for path: String in ["res://scenes/player/player.tscn", "res://resources/crossing_tuning.tres", "res://scripts/levels/island_travel.gd", "res://scenes/shell/sea.gdshader"]:
		assert_has(files, path)


func test_the_tests_are_scanned_except_the_guards() -> void:
	var files: PackedStringArray = DownloadedAssetRefs.tracked_files()
	for path: String in ["res://tests/manual/capture_inventory_hud.tscn", "res://tests/fixtures/art/fixtures.tres", "res://tests/unit/test_art_tracked.gd", "res://tests/helpers/art_checks.gd"]:
		assert_has(files, path)
	for path: String in DownloadedAssetRefs.GUARD_FILES:
		assert_does_not_have(files, path)
	for path: String in files:
		assert_false(path.begins_with("res://addons/"), path)
		assert_false(path.begins_with("res://.godot/"), path)


func test_each_guard_is_a_file_that_names_a_download_folder() -> void:
	assert_eq(DownloadedAssetRefs.GUARD_FILES.size(), 5)
	for path: String in DownloadedAssetRefs.GUARD_FILES:
		assert_true(path.begins_with("res://tests/"), "%s is a test guard" % path)
		assert_true(FileAccess.file_exists(path), "%s exists" % path)
		var named: PackedStringArray = DownloadedAssetRefs.scan_text(path, FileAccess.get_file_as_string(path))
		assert_false(named.is_empty(), "%s names a download folder, so it needs the exemption" % path)


func test_the_project_file_is_scanned() -> void:
	assert_has(DownloadedAssetRefs.tracked_files(), "res://project.godot")


func test_a_reference_into_a_download_folder_fails_naming_the_file_and_the_path() -> void:
	var text: String = FileAccess.get_file_as_string(FIXTURE_PATH)
	assert_string_contains(text, FIXTURE_TARGET)
	var failures: PackedStringArray = DownloadedAssetRefs.scan_text(FIXTURE_AS, text)
	assert_eq(failures.size(), 1)
	if failures.size() == 1:
		assert_string_contains(failures[0], FIXTURE_AS)
		assert_string_contains(failures[0], FIXTURE_TARGET)


func test_each_download_folder_is_caught() -> void:
	for prefix: String in DownloadedAssetRefs.IGNORED_PREFIXES:
		var text: String = 'var stream: AudioStream = load("%swaves.ogg")\n' % prefix
		assert_eq(DownloadedAssetRefs.scan_text("res://scripts/fixture.gd", text).size(), 1, prefix)


func test_tracked_art_paths_pass() -> void:
	var text: String = '[ext_resource type="Texture2D" path="res://assets/art/ui/panel_tan.png" id="1"]\n'
	assert_eq(DownloadedAssetRefs.scan_text("res://scenes/fixture.tscn", text), PackedStringArray())


func test_the_smoke_run_also_loads_the_art_resources() -> void:
	var roots: Array = _smoke_constant("RESOURCE_ROOTS")
	assert_has(roots, "res://assets/art")
