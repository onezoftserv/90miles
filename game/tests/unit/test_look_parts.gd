extends GutTest
## art-pass "Layered player look" and "Frame budget" on the shipped part sheets (task 5.3), with
## only `LookPart` and the rules of design.md C1 copied into `PoseRules`, never the composer, so it
## passes once the parts are made (task 5.6). Every part is on the 320x128 frame layout with a frame
## in every pose it is not hidden in; a part missing one is refused, naming the part and the pose;
## the bodies share one alpha mask and draw skin only in skin row 0; the clothing key colours are
## only in outfits; each part has at most 48 unique frames; and every rule-made cell keeps the
## invariant of C1 ("The invariant the tests check"). These sheets draw the solo player too.

const ROOT: String = "res://assets/art/characters"
const FIXTURE_ROOT: String = "res://tests/fixtures/art/look"
const SHIPPED: Array[String] = [
	"body_man", "body_woman", "hair_0", "hair_1", "hair_2", "hair_3", "hair_4", "hair_5", "hair_6",
	"hair_7", "outfit_tee_shorts",
]
const BODIES: Array[String] = ["body_man", "body_woman"]
## The body every overlay is rimmed over (look_parts.json "over"); both bodies share its mask.
const OVER: String = "body_man"
const CELL: Vector2i = Vector2i(32, 32)
const SKIN_ROW_REFERENCE: int = 0
## Body colours that are never skin (design.md C1 D7): pupils and outline, whites, underwear and
## top shading.
const NOT_SKIN: PackedStringArray = ["000000", "ffffff", "9badb7", "595652"]


func _catalog(root: String = ROOT) -> ContentCatalog:
	return ContentCatalog.new(root, {&"parts": LookPart})


func _part(id: String, root: String = ROOT) -> LookPart:
	return _catalog(root).get_entry(&"parts", StringName(id)) as LookPart


func _image(part: LookPart) -> Image:
	var image: Image = part.sheet.get_image()
	if image.get_format() != Image.FORMAT_RGBA8:
		image.convert(Image.FORMAT_RGBA8)
	return image


func _tuning() -> ArtTuning:
	return ArtTuning.standard()


func _ramp_row(ramps: Texture2D, row: int) -> Dictionary:
	var image: Image = ArtChecks.read_png(ramps.resource_path)
	var keys: Dictionary = {}
	for shade: int in image.get_width():
		keys[ArtChecks.rgb_key(image.get_pixel(shade, row))] = true
	return keys


func _colours(image: Image) -> Dictionary:
	var keys: Dictionary = {}
	for y: int in image.get_height():
		for x: int in image.get_width():
			var color: Color = image.get_pixel(x, y)
			if color.a8 > 0:
				keys[ArtChecks.rgb_key(color)] = true
	return keys


func test_the_shipped_parts_are_the_two_bodies_eight_hairs_and_one_outfit() -> void:
	var ids: Array[String] = []
	for id: StringName in _catalog().list_ids(&"parts"):
		ids.append(String(id))
	assert_eq(ids, SHIPPED)


func test_each_part_is_a_frame_layout_sheet_with_a_frame_in_every_pose() -> void:
	for id: String in SHIPPED:
		var part: LookPart = _part(id)
		assert_not_null(part, id)
		if part == null:
			continue
		assert_eq(String(part.id), id, "%s: its id is its file name" % id)
		assert_false(part.name_es.is_empty(), "%s has a Spanish name" % id)
		assert_eq(part.sheet.get_size(), Vector2(320.0, 128.0), id)
		assert_eq(part.hidden_in, [] as Array[StringName], "%s: no part ships hidden in a pose" % id)
		assert_eq(part.problems(), PackedStringArray(), id)
		var image: Image = _image(part)
		for family: StringName in PoseRules.FAMILIES:
			for cell: Vector2i in PoseRules.cells(family):
				assert_false(image.get_region(Rect2i(cell * CELL, CELL)).is_invisible(), "%s: %s cell %s has a frame" % [id, family, cell])


func test_the_layers_are_body_outfit_and_hair() -> void:
	for id: String in SHIPPED:
		var part: LookPart = _part(id)
		var expected: LookPart.Layer = LookPart.Layer.HAIR
		if id.begins_with("body_"):
			expected = LookPart.Layer.BODY
		elif id.begins_with("outfit_"):
			expected = LookPart.Layer.OUTFIT
		assert_eq(part.layer, expected, id)


func test_a_hair_with_an_empty_crouch_cell_is_refused_naming_the_part_and_the_pose() -> void:
	var holes: LookPart = _part("hair_holes", FIXTURE_ROOT)
	assert_not_null(holes)
	var problems: PackedStringArray = holes.problems()
	assert_eq(problems.size(), 1, str(problems))
	if problems.size() > 0:
		assert_string_contains(problems[0], "hair_holes")
		assert_string_contains(problems[0], "crouch")
	assert_eq(_part("hair_0", FIXTURE_ROOT).problems(), PackedStringArray(), "the whole fixture hair passes")


func test_a_part_hidden_in_a_pose_must_leave_those_cells_empty() -> void:
	var hair: LookPart = _part("hair_0", FIXTURE_ROOT).duplicate() as LookPart
	hair.hidden_in = [&"swim"] as Array[StringName]
	var problems: PackedStringArray = hair.problems()
	assert_eq(problems.size(), 1, str(problems))
	if problems.size() > 0:
		assert_string_contains(problems[0], "hair_0")
		assert_string_contains(problems[0], "swim")


func test_the_bodies_share_one_alpha_mask() -> void:
	var man: Image = _image(_part("body_man"))
	var woman: Image = _image(_part("body_woman"))
	var differing: Array[Vector2i] = []
	for y: int in man.get_height():
		for x: int in man.get_width():
			if (man.get_pixel(x, y).a8 > 0) != (woman.get_pixel(x, y).a8 > 0):
				differing.append(Vector2i(x, y))
	assert_eq(differing.size(), 0, "first differing pixels: %s" % str(differing.slice(0, 5)))


func test_the_bodies_draw_skin_only_in_skin_row_0() -> void:
	var tuning: ArtTuning = _tuning()
	var reference: Dictionary = _ramp_row(tuning.skin_ramps, SKIN_ROW_REFERENCE)
	var allowed: Dictionary = reference.duplicate()
	for hex: String in NOT_SKIN:
		allowed[ArtChecks.rgb_key(Color.html(hex))] = true
	for id: String in BODIES:
		var colours: Dictionary = _colours(_image(_part(id)))
		var stray: PackedStringArray = []
		for key: int in colours:
			if not allowed.has(key):
				stray.append(ArtChecks.hex(ArtChecks.key_color(key)))
		assert_eq(stray, PackedStringArray(), "%s: colours outside skin row 0 and the non-skin set" % id)
		for key: int in reference:
			assert_true(colours.has(key), "%s draws skin row 0's %s" % [id, ArtChecks.hex(ArtChecks.key_color(key))])


func test_the_clothing_key_colours_appear_only_in_outfits() -> void:
	var key: Dictionary = _ramp_row(_tuning().player_ramps, PaletteSwap.KEY_ROW)
	for id: String in SHIPPED:
		var colours: Dictionary = _colours(_image(_part(id)))
		var keyed: int = 0
		for colour: int in colours:
			if key.has(colour):
				keyed += 1
		if id.begins_with("outfit_"):
			assert_gt(keyed, 0, "%s draws its clothing in the key ramp" % id)
		else:
			assert_eq(keyed, 0, "%s has no key colour" % id)


func test_each_part_has_at_most_48_unique_frames() -> void:
	var budget: int = _tuning().max_character_frames
	for id: String in SHIPPED:
		var count: int = ArtChecks.unique_cells(_image(_part(id)), CELL)
		assert_lte(count, budget, "%s has %d unique frames" % [id, count])
		assert_gt(count, 0, id)


func test_every_made_cell_keeps_the_pose_invariant() -> void:
	var outline: Dictionary = ArtChecks.palette_from_colors(_tuning().outline_colors)
	var body: Image = _image(_part(OVER))
	for id: String in SHIPPED:
		var part: LookPart = _part(id)
		var over: Image = null if part.layer == LookPart.Layer.BODY else body
		var exempt: Dictionary = PoseRules.fix_pixels(id) if part.layer == LookPart.Layer.BODY else {}
		var problems: PackedStringArray = PoseRules.invariant_problems(_image(part), id, outline, over, exempt)
		assert_eq(problems.size(), 0, "%s: %s" % [id, str(problems.slice(0, 4))])


func test_the_invariant_catches_a_broken_cell() -> void:
	# The check can fail: a made crouch cell with one pixel moved off the rule's mask.
	var outline: Dictionary = ArtChecks.palette_from_colors(_tuning().outline_colors)
	var image: Image = _image(_part("hair_0"))
	var broken: Image = image.duplicate() as Image
	var cell: Vector2i = Vector2i(6, 0) * CELL
	broken.set_pixelv(cell + Vector2i(0, 0), Color.BLACK)
	var problems: PackedStringArray = PoseRules.invariant_problems(broken, "hair_0", outline, _image(_part(OVER)))
	assert_gt(problems.size(), 0)
	if problems.size() > 0:
		assert_string_contains(problems[0], "hair_0")
		assert_string_contains(problems[0], "(6, 0)")
