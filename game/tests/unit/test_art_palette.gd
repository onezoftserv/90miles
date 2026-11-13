extends GutTest
## art-pass "Master palette", "Clothing colours" ("Four slots read apart") and "Actors stand out
## from the ground" ("An outline colour that blends in") on the shipped palette files and art
## tuning (task 1.4; design.md D6, D7, D21 and C1 D7), and "Scrolling sea" on the sea's water
## texture and its depth ramps (task 4.4; design.md D12, K38).

const DB32: PackedStringArray = [
	"000000", "222034", "45283c", "663931", "8f563b", "df7126", "d9a066", "eec39a",
	"fbf236", "99e550", "6abe30", "37946e", "4b692f", "524b24", "323c39", "3f3f74",
	"306082", "5b6ee1", "639bff", "5fcde4", "cbdbfc", "ffffff", "9badb7", "847e87",
	"696a6a", "595652", "76428a", "ac3232", "d95763", "d77bba", "8f974a", "8a6f30",
]
## design.md C1 D7: skin rows 0 claro, 1 trigueño, 2 moreno; highlight, base, shade, line.
const SKIN_ROWS: Array = [
	["ffedde", "eec39a", "dca68d", "8f563b"],
	["d9a066", "b57251", "8f563b", "45283c"],
	["8f563b", "663931", "45283c", "222034"],
]
## The body sheets' colours that are never skin: eyes, underwear, body_woman's top and lashes.
const BODY_NON_SKIN: PackedStringArray = ["000000", "ffffff", "595652", "9badb7"]
## design.md D6: the four look slots' mid tones, azul, rojo, amarillo and verde.
const SLOT_MIDS: PackedStringArray = ["5b6ee1", "ac3232", "fbf236", "6abe30"]
const MAX_COLORS: int = 64
const SHADES: int = 4
const BASE_SHADE: int = 1
## design.md K38: the sea ramps' rows; each runs dark to light and row 0 is the water texture's own.
const SEA_ROWS: PackedStringArray = ["deep", "shallows", "brackish"]
const DEEP_ROW: int = 0
## The most contrast between the deep ramp's darkest and lightest step (it was 1.95:1, which made
## the open sea busier than the shallows).
const DEEP_SPREAD_MAX: float = 1.5
const SHALLOWS_ROW: int = 1
const WATER_SIZE: Vector2i = Vector2i(32, 32)


func _tuning() -> ArtTuning:
	return load(ArtTuning.STANDARD_PATH) as ArtTuning


func _rows(texture: Texture2D) -> Array[PackedColorArray]:
	var rows: Array[PackedColorArray] = []
	var image: Image = ArtChecks.read_png(texture.resource_path)
	for y: int in image.get_height():
		var row: PackedColorArray = []
		for x: int in image.get_width():
			row.append(image.get_pixel(x, y))
		rows.append(row)
	return rows


func _palette() -> Dictionary:
	return ArtChecks.palette_from_image(ArtChecks.read_png(_tuning().master_palette.resource_path))


func _keys(colors: PackedColorArray) -> Array[int]:
	var keys: Array[int] = []
	for color: Color in colors:
		keys.append(ArtChecks.rgb_key(color))
	return keys


func _hex_keys(hexes: PackedStringArray) -> Array[int]:
	var keys: Array[int] = []
	for hex: String in hexes:
		keys.append(ArtChecks.rgb_key(Color(hex)))
	return keys


# Sorted as text: Array[StringName].sort() does not sort by text.
func _sorted_names(grounds: Dictionary[StringName, Color]) -> PackedStringArray:
	var names: PackedStringArray = PackedStringArray(grounds.keys())
	names.sort()
	return names


func _distinct(keys: Array[int]) -> bool:
	var seen: Dictionary = {}
	for key: int in keys:
		seen[key] = true
	return seen.size() == keys.size()


func test_the_tuning_and_its_three_palette_textures_load() -> void:
	var tuning: ArtTuning = _tuning()
	assert_not_null(tuning)
	if tuning == null:
		return
	assert_eq(tuning.master_palette.resource_path, "res://assets/art/palette/master_palette.png")
	assert_eq(tuning.player_ramps.resource_path, "res://assets/art/palette/player_ramps.png")
	assert_eq(tuning.skin_ramps.resource_path, "res://assets/art/palette/skin_ramps.png")
	assert_true(FileAccess.file_exists("res://assets/art/palette/master_palette.gpl"))


func test_the_sea_ramps_are_three_depth_steps_of_palette_colours() -> void:
	var tuning: ArtTuning = _tuning()
	assert_eq(tuning.sea_ramps.resource_path, "res://assets/art/sea/water_ramps.png")
	var palette: Dictionary = _palette()
	var ramps: Array[PackedColorArray] = _rows(tuning.sea_ramps)
	assert_eq(ramps.size(), SEA_ROWS.size(), "deep, shallows, brackish")
	if ramps.size() != SEA_ROWS.size():
		return
	var seen: Array[int] = []
	for step: int in ramps.size():
		var row: PackedColorArray = ramps[step]
		assert_eq(row.size(), SHADES, SEA_ROWS[step])
		for shade: int in row.size():
			assert_eq(row[shade].a8, 255, "ramp colours are opaque")
			assert_true(palette.has(ArtChecks.rgb_key(row[shade])), "%s %s" % [SEA_ROWS[step], ArtChecks.hex(row[shade])])
			if shade > 0:
				assert_gt(ArtChecks.luminance(row[shade]), ArtChecks.luminance(row[shade - 1]), "%s runs dark to light" % SEA_ROWS[step])
		seen.append_array(_keys(row))
	assert_true(_distinct(seen), "each depth step has colours of its own")
	for shade: int in SHADES:
		assert_gt(ArtChecks.luminance(ramps[SHALLOWS_ROW][shade]), ArtChecks.luminance(ramps[DEEP_ROW][shade]), "shallows are lighter than deep water")
	# Design.md K39 (art round 2): the open sea is calm, its light steps close to its base.
	var deep: PackedColorArray = ramps[DEEP_ROW]
	assert_lte(ArtChecks.contrast_ratio(deep[0], deep[SHADES - 1]), DEEP_SPREAD_MAX, "the deep ramp's lightest step is near its base")


func test_the_water_texture_is_32_px_and_drawn_in_the_deep_ramp() -> void:
	var tuning: ArtTuning = _tuning()
	assert_eq(tuning.sea_water.resource_path, "res://assets/art/sea/water.png")
	var water: Image = ArtChecks.read_png(tuning.sea_water.resource_path)
	assert_eq(water.get_size(), WATER_SIZE)
	var deep: Dictionary = ArtChecks.palette_from_colors(_rows(tuning.sea_ramps)[DEEP_ROW])
	var used: Dictionary = {}
	var holes: int = 0
	for y: int in water.get_height():
		for x: int in water.get_width():
			var color: Color = water.get_pixel(x, y)
			if color.a8 < 255:
				holes += 1
			used[ArtChecks.rgb_key(color)] = true
	assert_eq(holes, 0, "the water has no holes")
	assert_eq(used.size(), SHADES, "all four deep colours are used")
	for key: int in used:
		assert_true(deep.has(key), "water colour #%06x is in the deep ramp" % key)


func test_the_thresholds_and_budgets_are_design_d21s() -> void:
	var tuning: ArtTuning = _tuning()
	assert_eq(tuning.contrast_min, 3.0)
	assert_eq(tuning.slot_contrast_min, 1.3)
	assert_eq(tuning.max_unique_frames, 6)
	assert_eq(tuning.max_creature_frames, 4)
	assert_eq(tuning.max_character_frames, 48)
	assert_eq(tuning.max_fps, 12.0)
	assert_gt(tuning.slot_hue_min_deg, 0.0)


func test_the_master_palette_has_at_most_64_colours_and_all_of_db32() -> void:
	var image: Image = ArtChecks.read_png(_tuning().master_palette.resource_path)
	var palette: Dictionary = ArtChecks.palette_from_image(image)
	assert_lte(palette.size(), MAX_COLORS)
	assert_eq(palette.size(), image.get_width() * image.get_height(), "one pixel per colour, no repeats")
	for key: int in _hex_keys(DB32):
		assert_true(palette.has(key), "DB32 #%06x" % key)


func test_the_outline_set_and_every_ramp_colour_are_in_the_palette() -> void:
	var tuning: ArtTuning = _tuning()
	var palette: Dictionary = _palette()
	assert_eq(tuning.outline_colors.size(), 4)
	for color: Color in tuning.outline_colors:
		assert_true(palette.has(ArtChecks.rgb_key(color)), "outline %s" % ArtChecks.hex(color))
	for texture: Texture2D in [tuning.player_ramps, tuning.skin_ramps]:
		for row: PackedColorArray in _rows(texture):
			for color: Color in row:
				assert_true(palette.has(ArtChecks.rgb_key(color)), "%s %s" % [texture.resource_path.get_file(), ArtChecks.hex(color)])


func test_the_ramp_sheets_have_four_shades_per_row() -> void:
	var tuning: ArtTuning = _tuning()
	var player: Array[PackedColorArray] = _rows(tuning.player_ramps)
	assert_eq(player.size(), 5, "the key ramp and four slots")
	var skin: Array[PackedColorArray] = _rows(tuning.skin_ramps)
	assert_eq(skin.size(), 3, "claro, trigueño, moreno")
	var rows: Array[PackedColorArray] = player.duplicate()
	rows.append_array(skin)
	for row: PackedColorArray in rows:
		assert_eq(row.size(), SHADES)
		for color: Color in row:
			assert_eq(color.a8, 255, "ramp colours are opaque")


func test_the_skin_ramps_are_design_c1s_table() -> void:
	var skin: Array[PackedColorArray] = _rows(_tuning().skin_ramps)
	for row: int in SKIN_ROWS.size():
		assert_eq(_keys(skin[row]), _hex_keys(PackedStringArray(SKIN_ROWS[row])), "skin row %d" % row)


func test_the_key_ramp_is_four_colours_apart_from_skin_and_the_outline_set() -> void:
	var tuning: ArtTuning = _tuning()
	var key_ramp: Array[int] = _keys(_rows(tuning.player_ramps)[0])
	assert_true(_distinct(key_ramp), "four distinct key colours")
	var others: Array[int] = _keys(tuning.outline_colors)
	for row: PackedColorArray in _rows(tuning.skin_ramps):
		others.append_array(_keys(row))
	for key: int in key_ramp:
		assert_false(others.has(key), "key colour #%06x is also a skin or outline colour" % key)


func test_skin_row_0_is_apart_from_the_outline_set_and_the_body_colours() -> void:
	var tuning: ArtTuning = _tuning()
	var row_0: Array[int] = _keys(_rows(tuning.skin_ramps)[0])
	assert_true(_distinct(row_0), "four distinct skin colours")
	var others: Array[int] = _keys(tuning.outline_colors)
	others.append_array(_hex_keys(BODY_NON_SKIN))
	for key: int in row_0:
		assert_false(others.has(key), "skin row 0 colour #%06x is also an outline or body colour" % key)


func test_every_outline_colour_stands_out_on_each_land_ground() -> void:
	var tuning: ArtTuning = _tuning()
	assert_eq(_sorted_names(tuning.land_grounds), PackedStringArray(["brush", "dune", "sand"]))
	assert_eq(_sorted_names(tuning.water_grounds), PackedStringArray(["brackish", "deep", "shallows"]))
	assert_eq(ArtChecks.check_outline_contrast(tuning.outline_colors, tuning.land_grounds, tuning.contrast_min), PackedStringArray())


func test_the_four_slots_read_apart() -> void:
	var tuning: ArtTuning = _tuning()
	var player: Array[PackedColorArray] = _rows(tuning.player_ramps)
	var mids: PackedColorArray = []
	for slot: int in 4:
		mids.append(player[slot + 1][BASE_SHADE])
	assert_eq(_keys(mids), _hex_keys(SLOT_MIDS), "azul, rojo, amarillo, verde; a solo player is slot 0, azul")
	for a: int in mids.size():
		for b: int in range(a + 1, mids.size()):
			var ratio: float = ArtChecks.contrast_ratio(mids[a], mids[b])
			assert_gte(ratio, tuning.slot_contrast_min, "slots %d and %d contrast" % [a, b])
			var hue: float = absf(mids[a].h - mids[b].h) * 360.0
			assert_gte(minf(hue, 360.0 - hue), tuning.slot_hue_min_deg, "slots %d and %d hue" % [a, b])
