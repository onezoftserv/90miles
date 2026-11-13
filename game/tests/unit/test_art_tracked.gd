extends GutTest
## art-pass "Tracked art with its licence", "Master palette", "Outlines", "Pixel-exact import" and
## "Frame budget" over every tracked file in res://assets/art (task 1.3), with the folder rules of
## design.md D9 and D21 as amended by C1:
## - palette and alpha everywhere but art/ui/ (Kenney's 9-slices keep their colours until a UI
##   pass);
## - the outline rule on every frame cell in creatures/, items/ and structures/; characters are
##   outlined as composed (task 5.3), so the part sheets in characters/parts/ get palette, alpha
##   and import only, a hair or outfit alone having open edges by design;
## - frame budgets on every actor and structure SpriteFrames and on every part sheet.

const ART_ROOT: String = "res://assets/art"
const UI_DIR: String = "res://assets/art/ui/"
const OUTLINE_DIRS: PackedStringArray = ["res://assets/art/creatures/", "res://assets/art/items/", "res://assets/art/structures/"]
const ITEMS_DIR: String = "res://assets/art/items/"
const ITEM_CELL: Vector2i = Vector2i(16, 16)
const CREATURES_DIR: String = "res://assets/art/creatures/"
const CHARACTERS_DIR: String = "res://assets/art/characters/"
const PARTS_DIR: String = "res://assets/art/characters/parts/"
const PART_CELL: Vector2i = Vector2i(32, 32)
## Ground art is not an actor animation: the 8-frame shoreline and the sea are exempt.
const BUDGET_EXEMPT_DIRS: PackedStringArray = ["res://assets/art/terrain/", "res://assets/art/sea/", "res://assets/art/decals/"]
## Folders that never refer to tracked art for the game: what refers to a PNG must be a scene or
## resource the game loads.
const REFERRER_SKIPPED: PackedStringArray = [
	"res://addons", "res://.godot", "res://tests",
	"res://assets/kenney", "res://assets/oga", "res://assets/itch", "res://assets/audio/ambience",
]
## Temporary exemptions from the palette and alpha rules. Task 5.7 deleted the Kenney placeholder,
## the last one; a file listed here must exist.
const EXEMPT: PackedStringArray = []


func _tuning() -> ArtTuning:
	return ArtTuning.standard()


func _pngs() -> PackedStringArray:
	return ArtChecks.pngs_under(ART_ROOT)


## Every PNG the palette and alpha rules cover.
func _world_pngs() -> PackedStringArray:
	var world: PackedStringArray = []
	for path: String in _pngs():
		if not path.begins_with(UI_DIR) and not EXEMPT.has(path):
			world.append(path)
	return world


func _palette() -> Dictionary:
	return ArtChecks.palette_from_image(ArtChecks.read_png(_tuning().master_palette.resource_path))


func _outline() -> Dictionary:
	return ArtChecks.palette_from_colors(_tuning().outline_colors)


func _sprite_frames() -> Dictionary[String, SpriteFrames]:
	var found: Dictionary[String, SpriteFrames] = {}
	for path: String in ArtChecks.files_under(ART_ROOT, ["tres"]):
		var frames: SpriteFrames = load(path) as SpriteFrames
		if frames != null:
			found[path] = frames
	return found


func _in_any(path: String, dirs: PackedStringArray) -> bool:
	for dir: String in dirs:
		if path.begins_with(dir):
			return true
	return false


func test_the_tree_has_art_to_check() -> void:
	assert_gt(_pngs().size(), 0)
	assert_has(_pngs(), "res://assets/art/palette/master_palette.png")


func test_the_exemptions_name_existing_files_only() -> void:
	for path: String in EXEMPT:
		assert_true(FileAccess.file_exists(path), "%s is gone: drop it from EXEMPT" % path)


func test_every_folder_holding_a_png_has_a_licence_with_a_source_per_block() -> void:
	assert_eq(ArtChecks.check_licence_folders(ART_ROOT), PackedStringArray())


func test_every_png_is_referred_to_by_a_scene_or_resource() -> void:
	assert_eq(ArtChecks.check_referred(_pngs(), ["res://"], REFERRER_SKIPPED), PackedStringArray())


func test_every_png_imports_lossless_without_mipmaps() -> void:
	var failures: PackedStringArray = []
	for path: String in _pngs():
		failures.append_array(ArtChecks.check_import(path))
	assert_eq(failures, PackedStringArray())


func test_every_world_image_uses_only_palette_colours_and_whole_alpha() -> void:
	var palette: Dictionary = _palette()
	var failures: PackedStringArray = []
	for path: String in _world_pngs():
		var image: Image = ArtChecks.read_png(path)
		if image == null:
			failures.append("%s is not a readable PNG" % path)
			continue
		failures.append_array(ArtChecks.check_palette(path, image, palette))
		failures.append_array(ArtChecks.check_alpha(path, image, palette))
	assert_eq(failures, PackedStringArray())


func test_every_actor_frame_cell_has_its_outline() -> void:
	var outline: Dictionary = _outline()
	var failures: PackedStringArray = []
	var covered: Dictionary = {}
	var frames_by_path: Dictionary[String, SpriteFrames] = _sprite_frames()
	for frames_path: String in frames_by_path:
		if not _in_any(frames_path, OUTLINE_DIRS):
			continue
		var frames: SpriteFrames = frames_by_path[frames_path]
		for animation: StringName in frames.get_animation_names():
			for index: int in frames.get_frame_count(animation):
				var label: String = "%s %s[%d]" % [frames_path, animation, index]
				var frame: Texture2D = frames.get_frame_texture(animation, index)
				var atlas: AtlasTexture = frame as AtlasTexture
				var sheet_path: String = atlas.atlas.resource_path if atlas != null else frame.resource_path
				var region: Rect2i = Rect2i(atlas.region) if atlas != null else Rect2i(Vector2i.ZERO, frame.get_size())
				covered[sheet_path] = true
				var cell: Image = ArtChecks.read_png(sheet_path).get_region(region)
				failures.append_array(ArtChecks.check_outline(label, cell, outline, region.size))
	for path: String in _pngs():
		if covered.has(path) or not _in_any(path, OUTLINE_DIRS):
			continue
		var image: Image = ArtChecks.read_png(path)
		var cell_size: Vector2i = ITEM_CELL if path.begins_with(ITEMS_DIR) else image.get_size()
		failures.append_array(ArtChecks.check_outline(path, image, outline, cell_size))
	assert_eq(failures, PackedStringArray())


func test_every_actor_and_structure_animation_keeps_its_frame_budget() -> void:
	var tuning: ArtTuning = _tuning()
	var failures: PackedStringArray = []
	var frames_by_path: Dictionary[String, SpriteFrames] = _sprite_frames()
	for frames_path: String in frames_by_path:
		if _in_any(frames_path, BUDGET_EXEMPT_DIRS):
			continue
		var frames: SpriteFrames = frames_by_path[frames_path]
		var per_animation: int = tuning.max_creature_frames if frames_path.begins_with(CREATURES_DIR) else tuning.max_unique_frames
		failures.append_array(ArtChecks.check_frame_budget(frames_path, frames, per_animation, tuning.max_fps))
		if frames_path.begins_with(CHARACTERS_DIR):
			failures.append_array(ArtChecks.check_total_frames(frames_path, frames, tuning.max_character_frames))
	assert_eq(failures, PackedStringArray())


func test_every_part_sheet_keeps_the_character_budget() -> void:
	var tuning: ArtTuning = _tuning()
	var failures: PackedStringArray = []
	for path: String in _pngs():
		if not path.begins_with(PARTS_DIR):
			continue
		var count: int = ArtChecks.unique_cells(ArtChecks.read_png(path), PART_CELL)
		if count > tuning.max_character_frames:
			failures.append("%s has %d unique frames, over %d" % [path, count, tuning.max_character_frames])
	assert_eq(failures, PackedStringArray())
