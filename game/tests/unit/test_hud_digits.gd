extends GutTest
## hud-window-kit design D6: the 3x5 digit atlas and how HudDigits lays its glyphs out, left or
## right aligned at a 4 px pitch, with the outlines of neighbours overlapping.

const ATLAS: String = "res://assets/art/ui/digits_3x5.png"


func test_the_atlas_has_two_rows_of_twelve_cells() -> void:
	var image: Image = ArtChecks.read_png(ATLAS)
	assert_eq(image.get_size(), Vector2i(60, 14))
	# The "1"'s top pixel of the first row is cream, of the second orange (cell 1, glyph at (1,1)).
	assert_true(image.get_pixel(5 + 2, 1).is_equal_approx(HudStyle.CREAM), "cream row")
	assert_true(image.get_pixel(5 + 2, 7 + 1).is_equal_approx(HudStyle.ORANGE), "orange row")


func test_the_theme_names_the_atlas() -> void:
	var digits := HudDigits.new()
	add_child_autofree(digits)
	assert_eq(digits.atlas().resource_path, ATLAS)
	assert_eq(HudDigits.ATLAS_PATH, ATLAS)


func test_only_atlas_characters_show() -> void:
	assert_true(HudDigits.can_show("0123456789-="))
	assert_false(HudDigits.can_show("ß"))
	var digits := HudDigits.new()
	add_child_autofree(digits)
	digits.show_text("ß")
	assert_eq(digits.text, "", "an unknown key draws nothing")


func test_left_aligned_glyphs_step_by_four() -> void:
	var digits := HudDigits.new()
	add_child_autofree(digits)
	digits.anchor = Vector2(2.0, 2.0)
	digits.show_text("12")
	assert_eq(digits.glyph_rects(), [Rect2(2.0, 2.0, 3.0, 5.0), Rect2(6.0, 2.0, 3.0, 5.0)] as Array[Rect2])


func test_right_aligned_glyphs_end_on_the_anchor() -> void:
	var digits := HudDigits.new()
	add_child_autofree(digits)
	digits.right_aligned = true
	digits.anchor = Vector2(24.0, 20.0)
	digits.show_text("40")
	assert_eq(digits.glyph_rects(), [Rect2(17.0, 20.0, 3.0, 5.0), Rect2(21.0, 20.0, 3.0, 5.0)] as Array[Rect2])
	digits.show_text("7", HudDigits.Tone.ORANGE)
	assert_eq(digits.glyph_rects(), [Rect2(21.0, 20.0, 3.0, 5.0)] as Array[Rect2])
	assert_eq(digits.tone, HudDigits.Tone.ORANGE)
