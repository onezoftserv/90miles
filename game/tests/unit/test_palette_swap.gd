extends GutTest
## art-pass "Clothing colours" and "Swimmers at the water line" (design.md D6, D19, C1): the
## reference mapping of the look slot's swap (what player_look.gdshader does to each texel), the
## image form PaletteSwap.swap_rows that the look composer uses for skin rows (one lookup per
## texel, opaque texels only), and source checks on the art shaders: player_look.gdshader's
## uniforms and its cut on a node-local y (never UV, which is atlas space for an AtlasTexture
## frame), and every art shader multiplying by the vertex COLOR carried in a varying, never by the
## fragment's incoming COLOR (task 4.5 adds the sea and shore shaders to MODULATE_SHADERS). The
## ramps are read from the raw PNGs (design.md K15).

const PLAYER_LOOK_SHADER: String = "res://scenes/art/player_look.gdshader"
const WATERLINE_SHADER: String = "res://scenes/art/waterline.gdshader"
## Every art shader that draws a node's texture: each must carry modulate through a varying.
const MODULATE_SHADERS: PackedStringArray = [PLAYER_LOOK_SHADER, WATERLINE_SHADER]
## Every art shader that cuts by row: each must cut on a node-local y.
const WATER_LINE_SHADERS: PackedStringArray = [PLAYER_LOOK_SHADER, WATERLINE_SHADER]
const SHADES: int = 4
const KEY_ROW: int = 0
const SLOT_ROWS: Array[int] = [1, 2, 3, 4]
const SKIN_CLARO: int = 0
const SKIN_TRIGUENO: int = 1
const SKIN_MORENO: int = 2
## Body sheet colours that are never skin (design.md C1 D7), plus a DB32 colour of no ramp.
const NOT_SKIN: PackedStringArray = ["000000", "ffffff", "9badb7", "595652", "8a6f30"]
const INCLUDE_PATTERN: String = "#include\\s+\"([^\"]+)\""


func _tuning() -> ArtTuning:
	return ArtTuning.standard()


func _player_ramps() -> Image:
	return ArtChecks.read_png(_tuning().player_ramps.resource_path)


func _skin_ramps() -> Image:
	return ArtChecks.read_png(_tuning().skin_ramps.resource_path)


func _palette_colors() -> PackedColorArray:
	var image: Image = ArtChecks.read_png(_tuning().master_palette.resource_path)
	var colors: PackedColorArray = []
	for key: int in ArtChecks.palette_from_image(image):
		colors.append(ArtChecks.key_color(key))
	return colors


func _row(ramps: Image, row: int) -> PackedColorArray:
	var colors: PackedColorArray = []
	for shade: int in SHADES:
		colors.append(ramps.get_pixel(shade, row))
	return colors


func _hex(color: Color) -> String:
	return ArtChecks.hex(color)


# --- the reference mapping -----------------------------------------------------------------------

func test_each_key_ramp_colour_maps_to_the_slots_colour() -> void:
	var ramps := _player_ramps()
	var keys := _row(ramps, KEY_ROW)
	for slot_row: int in SLOT_ROWS:
		var slot := _row(ramps, slot_row)
		for shade: int in SHADES:
			var mapped: Color = PaletteSwap.map_color(keys[shade], ramps, slot_row)
			assert_eq(_hex(mapped), _hex(slot[shade]), "key shade %d in slot row %d" % [shade, slot_row])


func test_every_other_palette_colour_is_unchanged() -> void:
	var ramps := _player_ramps()
	var key_hexes: PackedStringArray = []
	for color: Color in _row(ramps, KEY_ROW):
		key_hexes.append(_hex(color))
	var checked: int = 0
	for color: Color in _palette_colors():
		if key_hexes.has(_hex(color)):
			continue
		for slot_row: int in SLOT_ROWS:
			assert_eq(_hex(PaletteSwap.map_color(color, ramps, slot_row)), _hex(color), "%s in slot row %d" % [_hex(color), slot_row])
		checked += 1
	assert_gt(checked, 30, "every palette colour but the key ramp's")


func test_the_mapping_keeps_alpha() -> void:
	var ramps := _player_ramps()
	var key: Color = ramps.get_pixel(1, KEY_ROW)
	key.a = 0.5
	assert_eq(PaletteSwap.map_color(key, ramps, 1).a, 0.5)


# --- swap_rows, the image form -------------------------------------------------------------------

# One row: the four colours of skin row 0, the body's non-skin colours, the clothing key ramp, and
# two transparent texels whose RGB is a skin colour (import rewrites the RGB of transparent texels).
func _body_strip() -> Image:
	var skin := _row(_skin_ramps(), SKIN_CLARO)
	var keys := _row(_player_ramps(), KEY_ROW)
	var colors: PackedColorArray = []
	colors.append_array(skin)
	for hex: String in NOT_SKIN:
		colors.append(Color(hex))
	colors.append_array(keys)
	var hidden_highlight: Color = skin[0]
	hidden_highlight.a = 0.0
	var hidden_line: Color = skin[3]
	hidden_line.a = 0.0
	colors.append(hidden_highlight)
	colors.append(hidden_line)
	var image := Image.create(colors.size(), 1, false, Image.FORMAT_RGBA8)
	for x: int in colors.size():
		image.set_pixel(x, 0, colors[x])
	return image


func _texels(image: Image) -> PackedStringArray:
	var texels: PackedStringArray = []
	for x: int in image.get_width():
		var color: Color = image.get_pixel(x, 0)
		texels.append("%s@%d" % [_hex(color), color.a8])
	return texels


func test_swap_rows_recolours_skin_row_0_to_row_2_on_opaque_texels_only() -> void:
	var ramps := _skin_ramps()
	var strip := _body_strip()
	var before := _texels(strip)
	var swapped: Image = PaletteSwap.swap_rows(strip, ramps, SKIN_CLARO, SKIN_MORENO)
	var expected := before.duplicate()
	var moreno := _row(ramps, SKIN_MORENO)
	for shade: int in SHADES:
		expected[shade] = "%s@255" % _hex(moreno[shade])
	assert_eq(_texels(swapped), expected, "skin to row 2; non-skin, key ramp and transparent texels unchanged")
	assert_eq(_texels(strip), before, "the image passed in is not changed")
	assert_eq(swapped.get_format(), Image.FORMAT_RGBA8)


func test_one_lookup_per_texel_never_a_chain_of_replaces() -> void:
	var ramps := _skin_ramps()
	# #8f563b is row 0's line, row 1's shade and row 2's highlight.
	var to_moreno: Image = PaletteSwap.swap_rows(_body_strip(), ramps, SKIN_CLARO, SKIN_MORENO)
	assert_eq(_hex(to_moreno.get_pixel(0, 0)), "#8f563b", "#ffedde becomes row 2's highlight, not #222034")
	assert_eq(_hex(to_moreno.get_pixel(3, 0)), "#222034", "row 0's line #8f563b becomes row 2's line")
	var to_trigueno: Image = PaletteSwap.swap_rows(_body_strip(), ramps, SKIN_CLARO, SKIN_TRIGUENO)
	assert_eq(_hex(to_trigueno.get_pixel(2, 0)), "#8f563b", "#dca68d becomes row 1's shade, not #45283c")
	assert_eq(_hex(to_trigueno.get_pixel(3, 0)), "#45283c", "row 0's line #8f563b becomes row 1's line")


func test_swap_rows_on_a_whole_sheet_matches_the_texel_mapping() -> void:
	var ramps := _skin_ramps()
	var sheet := Image.create(32, 8, false, Image.FORMAT_RGBA8)
	var skin := _row(ramps, SKIN_CLARO)
	for y: int in sheet.get_height():
		for x: int in sheet.get_width():
			sheet.set_pixel(x, y, skin[(x + y) % SHADES] if (x * y) % 5 != 0 else Color(0, 0, 0, 0))
	var swapped: Image = PaletteSwap.swap_rows(sheet, ramps, SKIN_CLARO, SKIN_TRIGUENO)
	var trigueno := _row(ramps, SKIN_TRIGUENO)
	var wrong: int = 0
	for y: int in sheet.get_height():
		for x: int in sheet.get_width():
			var want: Color = trigueno[(x + y) % SHADES] if (x * y) % 5 != 0 else Color(0, 0, 0, 0)
			if swapped.get_pixel(x, y) != want:
				wrong += 1
	assert_eq(wrong, 0, "every texel of a 32x8 sheet")


# --- the shaders' sources ------------------------------------------------------------------------

# `path`'s source without its comments, which may name UV or COLOR in prose.
func _text(path: String) -> String:
	var text: String = FileAccess.get_file_as_string(path)
	text = RegEx.create_from_string("/\\*[\\s\\S]*?\\*/").sub(text, "", true)
	# Not the "//" of a res:// path in an #include line.
	return RegEx.create_from_string("(?<!:)//[^\\n]*").sub(text, "", true)


# `path`'s source with each #include line replaced by the included file's source.
func _source(path: String) -> String:
	var source: String = _text(path)
	var include := RegEx.create_from_string(INCLUDE_PATTERN)
	var found := include.search(source)
	while found != null:
		source = source.replace(found.get_string(), _source(found.get_string(1)))
		found = include.search(source)
	return source


# The body of the function `name` (any return type and parameters), braces matched.
func _body(source: String, name: String) -> String:
	var found := RegEx.create_from_string("\\b\\w+\\s+%s\\s*\\([^)]*\\)\\s*\\{" % name).search(source)
	if found == null:
		return ""
	var open: int = found.get_end() - 1
	var depth: int = 0
	for i: int in range(open, source.length()):
		if source[i] == "{":
			depth += 1
		elif source[i] == "}":
			depth -= 1
			if depth == 0:
				return source.substr(open + 1, i - open - 1)
	return ""


# The varying of `type` that vertex() assigns from `built_in` (as "name = built_in;"), or "".
func _varying_from(source: String, type: String, built_in: String) -> String:
	var assigned := RegEx.create_from_string("(\\w+)\\s*=\\s*%s\\s*;" % built_in.replace(".", "\\."))
	for found: RegExMatch in assigned.search_all(_body(source, "vertex")):
		var name: String = found.get_string(1)
		if RegEx.create_from_string("varying\\s+%s\\s+%s\\s*;" % [type, name]).search(source) != null:
			return name
	return ""


# Whether `code` holds `expected`, whitespace ignored on both sides.
func _holds(code: String, expected: String) -> bool:
	var space := RegEx.create_from_string("\\s+")
	return space.sub(code, "", true).contains(space.sub(expected, "", true))


func _statements_with(body: String, word: String) -> PackedStringArray:
	var found: PackedStringArray = []
	var pattern := RegEx.create_from_string("\\b%s\\b" % word)
	for statement: String in body.split(";"):
		if pattern.search(statement) != null:
			found.append(statement.strip_edges())
	return found


func test_the_art_shaders_compile_headless() -> void:
	for path: String in MODULATE_SHADERS:
		var shader := load(path) as Shader
		assert_not_null(shader, path)
		if shader != null:
			assert_false(shader.get_shader_uniform_list().is_empty(), "%s compiles and lists its uniforms" % path)


func test_player_look_has_the_slot_and_water_line_uniforms() -> void:
	var shader := load(PLAYER_LOOK_SHADER) as Shader
	assert_not_null(shader)
	if shader == null:
		return
	var types: Dictionary[String, int] = {}
	for entry: Dictionary in shader.get_shader_uniform_list():
		types[entry["name"]] = entry["type"]
	assert_eq(types.get("slot_row", TYPE_NIL), TYPE_INT, "slot_row is an int")
	assert_eq(types.get("water_line_on", TYPE_NIL), TYPE_BOOL, "water_line_on is a bool")
	assert_eq(types.get("water_line_y", TYPE_NIL), TYPE_FLOAT, "water_line_y is a float")


# "Clothing colours" as the game draws it: the shader's swap, which the reference mapping above
# stands for. Each texel is compared with the 4 shades of the key ramp (row 0) and, on a match,
# takes the same shade of the slot's row, keeping its alpha; fragment() swaps every texel to
# slot_row (design.md K24, K32).
func test_the_look_shader_swaps_the_key_ramp_to_the_same_shade_of_the_slot_row() -> void:
	var source: String = _source(PLAYER_LOOK_SHADER)
	assert_true(_holds(source, "const int ART_KEY_ROW = 0;"), "row 0 of the ramps is the key ramp")
	assert_true(_holds(source, "const int ART_SHADES = %d;" % SHADES), "a ramp has %d shades" % SHADES)
	var swap: String = _body(source, "art_swap_key")
	assert_ne(swap, "", "art_swap_key is defined")
	assert_true(_holds(swap, "for (int shade = 0; shade < ART_SHADES; shade++)"), "it tries each shade")
	assert_true(_holds(swap, "art_same_rgb(texel.rgb, texelFetch(ramps, ivec2(shade, ART_KEY_ROW), 0).rgb)"), "against the key ramp's shade, column = shade")
	assert_true(_holds(swap, "return vec4(texelFetch(ramps, ivec2(shade, row), 0).rgb, texel.a);"), "a match takes the same shade of `row`, alpha kept")
	assert_true(_holds(swap, "return texel;"), "any other colour is unchanged")
	assert_true(_holds(_body(source, "fragment"), "art_swap_key(texture(TEXTURE, UV), ramps, slot_row)"), "fragment() swaps every texel to slot_row")


func test_the_water_line_cuts_on_a_node_local_y_never_on_uv() -> void:
	for path: String in WATER_LINE_SHADERS:
		var source: String = _source(path)
		assert_false(source.is_empty(), path)
		var local_y: String = _varying_from(source, "float", "VERTEX.y")
		assert_ne(local_y, "", "%s: vertex() passes VERTEX.y to a float varying" % path)
		var cuts := _statements_with(_body(source, "fragment"), "water_line_y")
		assert_false(cuts.is_empty(), "%s: fragment() cuts at water_line_y" % path)
		for statement: String in cuts:
			assert_true(RegEx.create_from_string("\\b%s\\b" % local_y).search(statement) != null, "%s: '%s' cuts on %s" % [path, statement, local_y])
		var uv_uses: int = RegEx.create_from_string("\\bUV\\b").search_all(source).size()
		var samples: int = RegEx.create_from_string("texture\\(\\s*TEXTURE\\s*,\\s*UV\\s*\\)").search_all(source).size()
		assert_eq(uv_uses, samples, "%s: UV only samples the texture" % path)


func test_art_shaders_multiply_by_the_vertex_colour_in_a_varying() -> void:
	for path: String in MODULATE_SHADERS:
		var source: String = _source(path)
		var modulate: String = _varying_from(source, "vec4", "COLOR")
		assert_ne(modulate, "", "%s: vertex() copies COLOR into a vec4 varying" % path)
		var fragment: String = _body(source, "fragment")
		var writes := RegEx.create_from_string("\\bCOLOR\\b\\s*=(?!=)([^;]*);")
		var uses: int = RegEx.create_from_string("\\bCOLOR\\b").search_all(fragment).size()
		var assignments: Array[RegExMatch] = writes.search_all(fragment)
		assert_gt(assignments.size(), 0, "%s: fragment() writes COLOR" % path)
		assert_eq(uses, assignments.size(), "%s: fragment() never reads its incoming COLOR" % path)
		for assignment: RegExMatch in assignments:
			var value: String = assignment.get_string(1)
			assert_true(RegEx.create_from_string("\\b%s\\b" % modulate).search(value) != null, "%s: COLOR =%s multiplies by %s" % [path, value, modulate])
