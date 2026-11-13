extends GutTest
## art-pass "Layered player look", "Four slots, four looks", "Outlines", "Frame budget" and "Actors
## stand out from the ground" (task 5.3): `LookComposer` builds a look's atlas from its parts at
## load time (design.md C1, C2). The body sheet is swapped from skin row 0 to the look's row, then
## the outfit and hair are blended over it back to front; the key ramp stays (the slot is the
## shader's); looks are cached per catalog root and `cache_key()`; a missing part falls back to the
## default look's part for that layer and is reported; head anchors are measured per animation
## family. The first cases are a solo, offline player's look.

const ROOT: String = "res://assets/art/characters"
const FIXTURE_ROOT: String = "res://tests/fixtures/art/look"
const ART_PATH: String = "res://assets/art/characters/balsero_art.tres"
const RIPPLE_PATH: String = "res://assets/art/fx/dive_ripple.tres"
const CELL: Vector2i = Vector2i(32, 32)
const HAIRS: Array[StringName] = [&"hair_0", &"hair_1", &"hair_2", &"hair_3", &"hair_4", &"hair_5", &"hair_6", &"hair_7"]
const BODIES: Array[StringName] = [&"body_man", &"body_woman"]
const SKIN_ROWS: Array[int] = [0, 1, 2]
const SLOT_ROWS: Array[int] = [1, 2, 3, 4]
## design.md C1 D1: frame row r spans local y r - 27; the swim drop is 12 px.
const FRAME_TOP_Y: int = -27
const SWIM_DROP: int = 12
## design.md C1 D20, measured with hair_0.
const BALSERO_ANCHORS: Dictionary = {&"walk": -28, &"crouch": -22, &"swim": -16, &"downed": -13, &"dead": -13, &"dive": -4}
## The water row: the rows above it are scored on water (the shader's ripple is not counted).
const WATER_ROW: int = 19


func before_each() -> void:
	LookComposer.clear_cache()


func after_all() -> void:
	LookComposer.clear_cache()


func _look(body: StringName, skin_row: int, hair: StringName, outfit: StringName = &"outfit_tee_shorts") -> PlayerLookData:
	var look := PlayerLookData.new()
	look.id = &"test_look"
	look.body_id = body
	look.skin_row = skin_row
	look.outfit_id = outfit
	look.hair_id = hair
	look.item_id = &""
	return look


func _catalog(root: String) -> ContentCatalog:
	return ContentCatalog.new(root, {&"parts": LookPart})


func _sheet(root: String, id: StringName) -> Image:
	var part: LookPart = _catalog(root).get_entry(&"parts", id) as LookPart
	var image: Image = part.sheet.get_image()
	image.convert(Image.FORMAT_RGBA8)
	return image


func _tuning() -> ArtTuning:
	return ArtTuning.standard()


func _art() -> BodyArt:
	return load(ART_PATH) as BodyArt


# The composite the C1 rules call for: the body swapped from skin row 0, then outfit and hair
# blended over it, back to front.
func _expected(root: String, look: PlayerLookData) -> Image:
	var skin: Image = ArtChecks.read_png(_tuning().skin_ramps.resource_path)
	var image: Image = PaletteSwap.swap_rows(_sheet(root, look.body_id), skin, 0, look.skin_row)
	for id: StringName in [look.outfit_id, look.hair_id]:
		var layer: Image = _sheet(root, id)
		image.blend_rect(layer, Rect2i(Vector2i.ZERO, layer.get_size()), Vector2i.ZERO)
	return image


func _image(composed: ComposedLook) -> Image:
	var image: Image = composed.image.duplicate() as Image
	image.convert(Image.FORMAT_RGBA8)
	return image


func _differing(a: Image, b: Image) -> Array[Vector2i]:
	var found: Array[Vector2i] = []
	for y: int in a.get_height():
		for x: int in a.get_width():
			if a.get_pixel(x, y).to_rgba32() != b.get_pixel(x, y).to_rgba32():
				found.append(Vector2i(x, y))
	return found


# 1 px above the topmost opaque row over a family's cells, in body-local px.
func _measured_anchor(image: Image, family: StringName) -> int:
	var top: int = PoseRules.CELL
	for cell: Vector2i in PoseRules.cells(family):
		var used: Rect2i = image.get_region(Rect2i(cell * CELL, CELL)).get_used_rect()
		if used.has_area():
			top = mini(top, used.position.y)
	var drop: int = SWIM_DROP if family == &"swim" else 0
	return top + FRAME_TOP_Y + drop - 1


func test_a_solo_look_stacks_its_parts_on_the_swapped_body() -> void:
	# art-pass "A look built from parts": skin row 2, hair 0, the default outfit and no item.
	var look: PlayerLookData = _look(&"body_man", 2, &"hair_0")
	var composed: ComposedLook = LookComposer.compose(look)
	assert_not_null(composed)
	if composed == null:
		return
	assert_eq(composed.fallbacks, PackedStringArray(), "every part found")
	var image: Image = _image(composed)
	assert_eq(image.get_size(), Vector2i(320, 128))
	var differing: Array[Vector2i] = _differing(image, _expected(ROOT, look))
	assert_eq(differing.size(), 0, "first differing pixels: %s" % str(differing.slice(0, 5)))
	assert_eq(composed.texture.get_size(), Vector2(320.0, 128.0))


func test_the_composite_has_every_walk_crouch_swim_and_downed_cell() -> void:
	var image: Image = _image(LookComposer.compose(_look(&"body_man", 2, &"hair_0")))
	for family: StringName in PoseRules.FAMILIES:
		for cell: Vector2i in PoseRules.cells(family):
			assert_false(image.get_region(Rect2i(cell * CELL, CELL)).is_invisible(), "%s %s" % [family, cell])


func test_changing_only_the_hair_changes_only_pixels_inside_the_two_hairs() -> void:
	var with_0: Image = _image(LookComposer.compose(_look(&"body_man", 2, &"hair_0")))
	var with_3: Image = _image(LookComposer.compose(_look(&"body_man", 2, &"hair_3")))
	var hair_0: Image = _sheet(ROOT, &"hair_0")
	var hair_3: Image = _sheet(ROOT, &"hair_3")
	var differing: Array[Vector2i] = _differing(with_0, with_3)
	assert_gt(differing.size(), 0, "the hair changed")
	var outside: Array[Vector2i] = []
	for pixel: Vector2i in differing:
		if hair_0.get_pixelv(pixel).a8 == 0 and hair_3.get_pixelv(pixel).a8 == 0:
			outside.append(pixel)
	assert_eq(outside.size(), 0, "changed outside both hairs: %s" % str(outside.slice(0, 5)))


func test_the_key_ramp_stays_in_the_composite() -> void:
	var image: Image = _image(LookComposer.compose(_look(&"body_man", 2, &"hair_0")))
	var ramps: Image = ArtChecks.read_png(_tuning().player_ramps.resource_path)
	var key: Dictionary = {}
	for shade: int in PaletteSwap.SHADES:
		key[ArtChecks.rgb_key(ramps.get_pixel(shade, PaletteSwap.KEY_ROW))] = true
	var keyed: int = 0
	for y: int in image.get_height():
		for x: int in image.get_width():
			var color: Color = image.get_pixel(x, y)
			if color.a8 > 0 and key.has(ArtChecks.rgb_key(color)):
				keyed += 1
	assert_gt(keyed, 0, "the slot colour is the shader's job")


func test_the_same_look_is_cached_and_another_look_is_new() -> void:
	var first: ComposedLook = LookComposer.compose(_look(&"body_man", 2, &"hair_0"))
	var again: ComposedLook = LookComposer.compose(_look(&"body_man", 2, &"hair_0"))
	assert_same(first, again, "an equal look, another resource: the cached result")
	var other: ComposedLook = LookComposer.compose(_look(&"body_man", 2, &"hair_3"))
	assert_not_same(first, other)
	assert_ne(_look(&"body_man", 2, &"hair_0").cache_key(), _look(&"body_man", 1, &"hair_0").cache_key(), "the skin row is in the key")


func test_a_fixture_part_reusing_a_shipped_id_composes_from_the_fixture_after_clear_cache() -> void:
	var look: PlayerLookData = _look(&"body_man", 0, &"hair_0")
	var shipped: Image = _image(LookComposer.compose(look))
	LookComposer.clear_cache()
	var fixture: ComposedLook = LookComposer.compose(look, _catalog(FIXTURE_ROOT))
	assert_eq(fixture.fallbacks, PackedStringArray())
	var image: Image = _image(fixture)
	assert_eq(_differing(image, _expected(FIXTURE_ROOT, look)).size(), 0, "built from the fixture parts")
	assert_gt(_differing(image, shipped).size(), 0, "not the shipped parts")


func test_a_missing_part_composes_the_default_looks_part_and_is_reported() -> void:
	var missing: PlayerLookData = _look(&"body_man", 2, &"hair_none_such")
	var composed: ComposedLook = LookComposer.compose(missing)
	assert_not_null(composed)
	if composed == null:
		return
	assert_eq(composed.fallbacks.size(), 1, str(composed.fallbacks))
	if composed.fallbacks.size() == 1:
		assert_string_contains(composed.fallbacks[0], "hair_none_such")
	var default_hair: StringName = _art().default_look.hair_id
	var expected: Image = _expected(ROOT, _look(&"body_man", 2, default_hair))
	assert_eq(_differing(_image(composed), expected).size(), 0, "drawn with the default look's hair")


func test_the_head_anchors_of_the_default_look() -> void:
	var composed: ComposedLook = LookComposer.compose(_art().default_look)
	for family: StringName in BALSERO_ANCHORS:
		assert_eq(composed.head_anchor(family), BALSERO_ANCHORS[family], "balsero %s" % family)


func test_the_other_slot_looks_anchor_1_px_above_their_topmost_row() -> void:
	var art: BodyArt = _art()
	for slot: int in range(1, 4):
		var composed: ComposedLook = LookComposer.compose(art.look_for_slot(slot))
		var image: Image = _image(composed)
		for family: StringName in PoseRules.FAMILIES:
			assert_eq(composed.head_anchor(family), _measured_anchor(image, family), "slot %d %s" % [slot, family])
		assert_eq(composed.head_anchor(&"dive"), art.dive_anchor_y, "slot %d dive" % slot)


func test_the_four_slot_looks_compose_and_differ() -> void:
	# art-pass "Four slots, four looks"; design.md C2.
	var art: BodyArt = _art()
	assert_eq(art.slot_looks.size(), 4)
	var bodies: Array[StringName] = []
	var hairs: Dictionary = {}
	var skins: Dictionary = {}
	for slot: int in 4:
		var look: PlayerLookData = art.look_for_slot(slot)
		assert_not_null(look, "slot %d" % slot)
		if look == null:
			continue
		assert_same(look, art.slot_looks[slot])
		assert_eq(LookComposer.compose(look).fallbacks, PackedStringArray(), "slot %d composes with no fallback" % slot)
		assert_eq(look.outfit_id, &"outfit_tee_shorts")
		assert_eq(look.item_id, &"")
		bodies.append(look.body_id)
		hairs[look.hair_id] = true
		skins[look.skin_row] = true
	assert_eq(bodies, [&"body_man", &"body_woman", &"body_man", &"body_woman"] as Array[StringName])
	assert_eq(hairs.size(), 4, "the four hair ids differ pairwise")
	assert_eq(skins.size(), 3, "all three skin rows are used")
	assert_same(art.slot_looks[0], art.default_look, "slot 0 is the default look")


func test_a_slot_outside_0_to_3_gets_the_default_look() -> void:
	var art: BodyArt = _art()
	assert_same(art.look_for_slot(4), art.default_look)
	assert_same(art.look_for_slot(-1), art.default_look)


func test_every_shipped_body_outfit_and_hair_composes_with_closed_outlines() -> void:
	# art-pass "A layered look is outlined as composed"; skin rows do not change masks.
	var outline: Dictionary = ArtChecks.palette_from_colors(_tuning().outline_colors)
	for body: StringName in BODIES:
		for hair: StringName in HAIRS:
			var image: Image = _image(LookComposer.compose(_look(body, 0, hair)))
			var label: String = "%s + outfit_tee_shorts + %s" % [body, hair]
			assert_eq(ArtChecks.check_outline(label, image, outline, CELL), PackedStringArray())


func test_the_composed_look_keeps_the_frame_budget_with_the_ripple() -> void:
	var ripple: SpriteFrames = load(RIPPLE_PATH) as SpriteFrames
	assert_not_null(ripple)
	if ripple == null:
		return
	var ripple_frames: int = ArtChecks.total_unique_frames(ripple)
	assert_eq(ripple_frames, 2)
	for slot: int in 4:
		var image: Image = _image(LookComposer.compose(_art().look_for_slot(slot)))
		var count: int = ArtChecks.unique_cells(image, CELL) + ripple_frames
		assert_lte(count, _tuning().max_character_frames, "slot %d: %d unique frames with the ripple" % [slot, count])


func test_swimmers_stand_out_on_shallows_and_deep() -> void:
	# Every body, skin row and hair, in every slot's clothing colour, scored on the rows above the
	# water line by the better of outline ring and mean colour.
	var tuning: ArtTuning = _tuning()
	var grounds: Dictionary[StringName, Color] = {&"shallows": tuning.water_grounds[&"shallows"], &"deep": tuning.water_grounds[&"deep"]}
	var ramps: Image = ArtChecks.read_png(tuning.player_ramps.resource_path)
	var failures: PackedStringArray = []
	for body: StringName in BODIES:
		for skin_row: int in SKIN_ROWS:
			for hair: StringName in HAIRS:
				var composite: Image = _image(LookComposer.compose(_look(body, skin_row, hair)))
				for slot_row: int in SLOT_ROWS:
					var drawn: Image = PaletteSwap.swap_rows(composite, ramps, PaletteSwap.KEY_ROW, slot_row)
					for cell: Vector2i in PoseRules.cells(&"swim"):
						var label: String = "%s skin %d %s slot row %d swim %s" % [body, skin_row, hair, slot_row, cell]
						var rect: Rect2i = Rect2i(cell * CELL, Vector2i(CELL.x, WATER_ROW))
						failures.append_array(ArtChecks.check_water_contrast(label, drawn, rect, grounds, tuning.contrast_min))
	assert_eq(failures.size(), 0, "%d failing frames, first: %s" % [failures.size(), str(failures.slice(0, 3))])
