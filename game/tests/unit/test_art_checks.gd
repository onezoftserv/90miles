extends GutTest
## art-pass checks on their fixtures (task 1.2): each check fails on its fixture and names the
## file, and passes on the fixture that keeps its rule. The fixtures are in
## res://tests/fixtures/art/; they use DawnBringer's 32 colours (DB32) as their palette, so these
## tests do not depend on the shipped master palette.

const FIXTURES: String = "res://tests/fixtures/art"
const DB32: PackedStringArray = [
	"000000", "222034", "45283c", "663931", "8f563b", "df7126", "d9a066", "eec39a",
	"fbf236", "99e550", "6abe30", "37946e", "4b692f", "524b24", "323c39", "3f3f74",
	"306082", "5b6ee1", "639bff", "5fcde4", "cbdbfc", "ffffff", "9badb7", "847e87",
	"696a6a", "595652", "76428a", "ac3232", "d95763", "d77bba", "8f974a", "8a6f30",
]
const OUTLINE_SET: PackedStringArray = ["000000", "222034", "45283c", "323c39"]
const SAND: Color = Color("d9a066")
const DUNE: Color = Color("eec39a")
const BRUSH: Color = Color("6abe30")
const DEEP: Color = Color("306082")
const SHALLOWS: Color = Color("5fcde4")


func _palette() -> Dictionary:
	return ArtChecks.palette_from_colors(_colors(DB32))


func _outline() -> Dictionary:
	return ArtChecks.palette_from_colors(_colors(OUTLINE_SET))


func _colors(hexes: PackedStringArray) -> PackedColorArray:
	var colors: PackedColorArray = []
	for hex: String in hexes:
		colors.append(Color(hex))
	return colors


func _fixture(relative: String) -> String:
	return FIXTURES.path_join(relative)


func _image(relative: String) -> Image:
	return ArtChecks.read_png(_fixture(relative))


func _assert_one_naming(failures: PackedStringArray, names: Array[String]) -> void:
	assert_eq(failures.size(), 1, "one failure: %s" % [failures])
	if failures.size() != 1:
		return
	for name: String in names:
		assert_string_contains(failures[0], name)


# --- Fixture hygiene (design.md K15) ---------------------------------------------------------

func test_every_fixture_png_is_a_valid_png() -> void:
	var pngs: PackedStringArray = ArtChecks.pngs_under(FIXTURES)
	assert_gt(pngs.size(), 20, "fixture PNGs")
	for path: String in pngs:
		var image: Image = ArtChecks.read_png(path)
		assert_not_null(image, path)
		if image != null:
			assert_eq(image.get_format(), Image.FORMAT_RGBA8, path)


func test_the_lossy_fixture_has_a_tracked_lossy_import() -> void:
	var config: ConfigFile = ConfigFile.new()
	assert_eq(config.load(_fixture("import/lossy.png.import")), OK)
	assert_eq(int(config.get_value("params", "compress/mode", 0)), 1)


func test_no_fixture_script_is_named_like_a_test() -> void:
	var named_like_tests: PackedStringArray = []
	for path: String in ArtChecks.files_under(FIXTURES, ["gd"]):
		if path.get_file().begins_with("test_"):
			named_like_tests.append(path)
	assert_eq(named_like_tests, PackedStringArray())


# --- Licences ("A copy without its licence", "A licence deed is not a source") --------------

func test_a_folder_holding_a_png_without_a_licence_fails_naming_the_folder() -> void:
	var folder: String = _fixture("licence/no_licence")
	_assert_one_naming(ArtChecks.check_licence_folders(folder), [folder, "License.txt"])


func test_a_licence_deed_is_not_a_source() -> void:
	var folder: String = _fixture("licence/deed_only")
	_assert_one_naming(ArtChecks.check_licence_folders(folder), [folder, "Deed Only Pack", "creativecommons.org"])


func test_vendor_text_without_a_block_fails() -> void:
	var folder: String = _fixture("licence/vendor_only")
	_assert_one_naming(ArtChecks.check_licence_folders(folder), [folder, "Pack:"])


func test_the_source_is_read_only_from_the_blocks_own_source_line() -> void:
	var folder: String = _fixture("licence/no_source")
	_assert_one_naming(ArtChecks.check_licence_folders(folder), [folder, "Fixture Pack", "Source:"])


func test_an_own_work_block_names_90_millas_as_its_source() -> void:
	var folder: String = _fixture("licence/own_work_url")
	_assert_one_naming(ArtChecks.check_licence_folders(folder), [folder, "90 Millas (own work)"])


func test_a_good_licence_passes_and_its_vendor_text_is_not_checked() -> void:
	assert_eq(ArtChecks.check_licence_folders(_fixture("licence/good")), PackedStringArray())
	var blocks: Array[Dictionary] = ArtChecks.licence_blocks(FileAccess.get_file_as_string(_fixture("licence/good/License.txt")))
	assert_eq(blocks.size(), 2)
	if blocks.size() == 2:
		assert_eq(blocks[0]["Pack"], "Fixture Pack (1.0)")
		assert_eq(blocks[0]["Source"], "https://example.com/fixture-pack")
		assert_eq(blocks[1]["Work"], "90 Millas recolour of piece.png")
		assert_eq(blocks[1]["Source"], ArtChecks.OWN_WORK_SOURCE)


func test_every_fixture_folder_but_the_licence_cases_has_a_good_licence() -> void:
	for folder: String in ["items", "creatures", "shadows", "decals", "terrain", "import", "refs"]:
		assert_eq(ArtChecks.check_licence_folders(_fixture(folder)), PackedStringArray(), folder)


func test_a_png_no_scene_or_resource_refers_to_fails_naming_it() -> void:
	var pngs: PackedStringArray = [_fixture("refs/referred.png"), _fixture("refs/unreferred.png")]
	var failures: PackedStringArray = ArtChecks.check_referred(pngs, [_fixture("refs")])
	_assert_one_naming(failures, [_fixture("refs/unreferred.png")])


# --- Palette and alpha ("Off-palette pixel", "Partial alpha outside shadows") ----------------

func test_an_off_palette_pixel_fails_naming_the_file_and_the_pixel() -> void:
	var path: String = _fixture("creatures/off_palette.png")
	_assert_one_naming(ArtChecks.check_palette(path, ArtChecks.read_png(path), _palette()), [path, "(7, 8)", "#ff0000"])


func test_an_in_palette_frame_passes() -> void:
	var path: String = _fixture("items/rimmed.png")
	assert_eq(ArtChecks.check_palette(path, ArtChecks.read_png(path), _palette()), PackedStringArray())


func test_partial_alpha_in_an_item_fails_naming_the_file() -> void:
	var path: String = _fixture("items/half_alpha.png")
	_assert_one_naming(ArtChecks.check_alpha(path, ArtChecks.read_png(path), _palette()), [path, "(7, 7)"])


func test_the_same_partial_alpha_passes_under_shadows_and_decals() -> void:
	for relative: String in ["shadows/half_alpha.png", "decals/shade.png"]:
		var path: String = _fixture(relative)
		assert_eq(ArtChecks.check_alpha(path, ArtChecks.read_png(path), _palette()), PackedStringArray(), relative)
		assert_eq(ArtChecks.check_palette(path, ArtChecks.read_png(path), _palette()), PackedStringArray(), relative)


func test_partial_alpha_in_a_shadow_uses_the_darkest_colour() -> void:
	var image: Image = Image.create(4, 4, false, Image.FORMAT_RGBA8)
	image.set_pixel(1, 1, Color(Color("306082"), 0.5))
	var failures: PackedStringArray = ArtChecks.check_alpha("res://x/shadows/blob.png", image, _palette())
	_assert_one_naming(failures, ["res://x/shadows/blob.png", "(1, 1)", "#000000"])


func test_the_darkest_colour_is_black_in_db32() -> void:
	assert_eq(ArtChecks.darkest(_palette()), Color("000000"))


func test_transparent_texels_are_never_judged_by_their_rgb() -> void:
	var image: Image = Image.create(2, 1, false, Image.FORMAT_RGBA8)
	image.set_pixel(0, 0, Color(1.0, 0.0, 0.0, 0.0))
	assert_eq(ArtChecks.check_palette("res://x/a.png", image, _palette()), PackedStringArray())
	assert_eq(ArtChecks.check_alpha("res://x/a.png", image, _palette()), PackedStringArray())


# --- Outline ("A hand-made icon without its rim") ---------------------------------------------

func test_an_icon_without_its_rim_fails_naming_the_file() -> void:
	var path: String = _fixture("items/no_rim.png")
	var failures: PackedStringArray = ArtChecks.check_outline(path, ArtChecks.read_png(path), _outline(), Vector2i(16, 16))
	_assert_one_naming(failures, [path, "edge"])


func test_the_rimmed_icon_passes() -> void:
	var path: String = _fixture("items/rimmed.png")
	assert_eq(ArtChecks.check_outline(path, ArtChecks.read_png(path), _outline(), Vector2i(16, 16)), PackedStringArray())


func test_the_outline_rule_runs_per_frame_cell() -> void:
	# Two 4x4 cells side by side; a fill pixel touching the shared cell border is an edge of its
	# own cell even though the next cell is opaque there.
	var image: Image = Image.create(8, 4, false, Image.FORMAT_RGBA8)
	image.fill(Color("000000"))
	image.set_pixel(3, 1, Color("d9a066"))
	var whole: PackedStringArray = ArtChecks.check_outline("res://x/a.png", image, _outline(), Vector2i(8, 4))
	assert_eq(whole, PackedStringArray(), "one 8x4 cell: interior")
	var cells: PackedStringArray = ArtChecks.check_outline("res://x/a.png", image, _outline(), Vector2i(4, 4))
	_assert_one_naming(cells, ["res://x/a.png", "(3, 1)", "cell (0, 0)"])


# --- Import ("A lossy import") -----------------------------------------------------------------

func test_a_lossy_import_fails_naming_the_file() -> void:
	var path: String = _fixture("import/lossy.png")
	_assert_one_naming(ArtChecks.check_import(path), [path, "compress/mode"])


func test_mipmaps_fail_naming_the_file() -> void:
	var path: String = _fixture("import/mipmapped.png")
	_assert_one_naming(ArtChecks.check_import(path), [path, "mipmaps"])


func test_a_lossless_import_without_mipmaps_passes() -> void:
	assert_eq(ArtChecks.check_import(_fixture("import/lossless.png")), PackedStringArray())


# --- Contrast ("An outline colour that blends in", "A fin that blends in") --------------------

func test_the_contrast_ratio_is_wcags() -> void:
	assert_almost_eq(ArtChecks.contrast_ratio(Color("000000"), Color("ffffff")), 21.0, 0.01)
	assert_almost_eq(ArtChecks.contrast_ratio(Color("000000"), DEEP), 3.12, 0.01)
	assert_almost_eq(ArtChecks.contrast_ratio(DEEP, Color("000000")), 3.12, 0.01)


func test_an_outline_colour_that_blends_into_the_brush_fails_naming_both() -> void:
	var outline: PackedColorArray = _colors(OUTLINE_SET)
	outline.append(Color("4b692f"))
	var grounds: Dictionary[StringName, Color] = {&"sand": SAND, &"dune": DUNE, &"brush": BRUSH}
	var failures: PackedStringArray = ArtChecks.check_outline_contrast(outline, grounds, 3.0)
	var on_brush: PackedStringArray = []
	for failure: String in failures:
		assert_string_contains(failure, "#4b692f")
		if failure.contains("brush"):
			on_brush.append(failure)
	_assert_one_naming(on_brush, ["#4b692f", "brush"])


func test_the_db32_outline_set_stands_out_on_every_land_ground() -> void:
	var grounds: Dictionary[StringName, Color] = {&"sand": SAND, &"dune": DUNE, &"brush": BRUSH}
	assert_eq(ArtChecks.check_outline_contrast(_colors(OUTLINE_SET), grounds, 3.0), PackedStringArray())


func test_a_fin_that_blends_into_deep_water_fails_naming_the_frame_and_the_ground() -> void:
	var path: String = _fixture("creatures/fin_dark.png")
	var image: Image = ArtChecks.read_png(path)
	var grounds: Dictionary[StringName, Color] = {&"shallows": SHALLOWS, &"deep": DEEP}
	var failures: PackedStringArray = ArtChecks.check_water_contrast(path, image, Rect2i(Vector2i.ZERO, image.get_size()), grounds, 3.0)
	_assert_one_naming(failures, [path, "deep"])


func test_a_fin_with_a_black_ring_stands_out_on_water() -> void:
	var path: String = _fixture("creatures/fin_black.png")
	var image: Image = ArtChecks.read_png(path)
	var grounds: Dictionary[StringName, Color] = {&"shallows": SHALLOWS, &"deep": DEEP}
	assert_eq(ArtChecks.check_water_contrast(path, image, Rect2i(Vector2i.ZERO, image.get_size()), grounds, 3.0), PackedStringArray())
	assert_gte(ArtChecks.water_contrast(image, Rect2i(Vector2i.ZERO, image.get_size()), DEEP), 3.0)


# --- Land tiles ("No water in land tiles") ------------------------------------------------------

func test_a_sea_colour_in_a_land_tile_fails_naming_the_file() -> void:
	var path: String = _fixture("terrain/sand_with_sea.png")
	var water: Dictionary = ArtChecks.palette_from_colors(PackedColorArray([DEEP, SHALLOWS]))
	_assert_one_naming(ArtChecks.check_no_water(path, ArtChecks.read_png(path), water), [path, "#306082"])


func test_a_clean_land_tile_passes() -> void:
	var path: String = _fixture("terrain/sand_clean.png")
	var water: Dictionary = ArtChecks.palette_from_colors(PackedColorArray([DEEP, SHALLOWS]))
	assert_eq(ArtChecks.check_no_water(path, ArtChecks.read_png(path), water), PackedStringArray())


# --- Frame budget ("Too many frames") -----------------------------------------------------------

func _strip_frames(animation: StringName, cells: Array[int], fps: float) -> SpriteFrames:
	var strip: Texture2D = load(_fixture("creatures/strip5.png")) as Texture2D
	var frames: SpriteFrames = SpriteFrames.new()
	frames.add_animation(animation)
	frames.set_animation_speed(animation, fps)
	for cell: int in cells:
		var region: AtlasTexture = AtlasTexture.new()
		region.atlas = strip
		region.region = Rect2(cell * 16, 0, 16, 16)
		frames.add_frame(animation, region)
	return frames


func test_a_creature_animation_with_five_unique_frames_fails_naming_both() -> void:
	var frames: SpriteFrames = _strip_frames(&"patrol", [0, 1, 2, 3, 4], 4.0)
	assert_eq(ArtChecks.unique_frames(frames, &"patrol"), 5)
	_assert_one_naming(ArtChecks.check_frame_budget("tiburon_prueba", frames, 4, 12.0), ["tiburon_prueba", "patrol", "5"])


func test_repeated_frames_count_once() -> void:
	var frames: SpriteFrames = _strip_frames(&"move", [0, 1, 2, 3, 0, 1, 2, 3], 8.0)
	assert_eq(ArtChecks.unique_frames(frames, &"move"), 4)
	assert_eq(ArtChecks.check_frame_budget("cangrejo", frames, 4, 12.0), PackedStringArray())


func test_an_animation_faster_than_the_budget_fails_naming_it() -> void:
	var frames: SpriteFrames = _strip_frames(&"move", [0, 1], 15.0)
	_assert_one_naming(ArtChecks.check_frame_budget("cangrejo", frames, 4, 12.0), ["cangrejo", "move", "15"])


func test_a_characters_frames_are_counted_across_animations() -> void:
	var frames: SpriteFrames = _strip_frames(&"walk_down", [0, 1, 2], 8.0)
	var crouch: SpriteFrames = _strip_frames(&"crouch_down", [2, 3, 4], 4.0)
	frames.add_animation(&"crouch_down")
	for index: int in crouch.get_frame_count(&"crouch_down"):
		frames.add_frame(&"crouch_down", crouch.get_frame_texture(&"crouch_down", index))
	assert_eq(ArtChecks.total_unique_frames(frames), 5)
	_assert_one_naming(ArtChecks.check_total_frames("balsero", frames, 4), ["balsero", "5"])
	assert_eq(ArtChecks.check_total_frames("balsero", frames, 48), PackedStringArray())


func test_a_sheet_counts_its_unique_non_empty_cells() -> void:
	assert_eq(ArtChecks.unique_cells(_image("creatures/strip5.png"), Vector2i(16, 16)), 5)
	var twice: Image = Image.create(32, 16, false, Image.FORMAT_RGBA8)
	twice.blit_rect(_image("items/rimmed.png"), Rect2i(0, 0, 16, 16), Vector2i(0, 0))
	twice.blit_rect(_image("items/rimmed.png"), Rect2i(0, 0, 16, 16), Vector2i(16, 0))
	assert_eq(ArtChecks.unique_cells(twice, Vector2i(16, 16)), 1)


# --- Silhouettes ("Two items with one silhouette") ----------------------------------------------

func test_two_items_with_one_silhouette_fail_naming_both() -> void:
	var icons: Dictionary[String, Image] = {
		"twin_a": _image("items/twin_a.png"),
		"twin_b": _image("items/twin_b.png"),
		"rimmed": _image("items/rimmed.png"),
	}
	_assert_one_naming(ArtChecks.check_silhouettes(icons), ["twin_a", "twin_b"])


func test_icons_with_their_own_shapes_pass() -> void:
	var icons: Dictionary[String, Image] = {
		"twin_a": _image("items/twin_a.png"),
		"no_rim": _image("items/no_rim.png"),
		"rimmed": _image("items/rimmed.png"),
	}
	assert_eq(ArtChecks.check_silhouettes(icons), PackedStringArray())
