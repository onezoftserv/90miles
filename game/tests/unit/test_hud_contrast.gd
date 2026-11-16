extends GutTest
## hud-window-kit design D12: the contrast helper the HUD and menu tests use agrees with the ratios
## the design quotes (tools/art/palette.py `luminance`).


func test_known_pairs() -> void:
	assert_almost_eq(HudContrast.ratio(Color("#ffedde"), Color("#222034")), 13.91, 0.01, "cream on the dark window")
	assert_almost_eq(HudContrast.ratio(Color("#d95763"), Color("#222034")), 4.15, 0.01, "the alert red")
	assert_almost_eq(HudContrast.ratio(Color("#ffedde"), Color("#ac3232")), 5.66, 0.01, "the error band")
	assert_almost_eq(HudContrast.ratio(Color("#000000"), Color("#847e87")), 5.32, 0.01, "black rims on the well")


func test_order_does_not_matter_and_alpha_is_ignored() -> void:
	var a := Color("#45283c")
	var b := Color("#eec39a")
	assert_almost_eq(HudContrast.ratio(a, b), HudContrast.ratio(b, a), 0.0001)
	assert_almost_eq(HudContrast.ratio(Color(a, 0.3), b), HudContrast.ratio(a, b), 0.0001)
	assert_almost_eq(HudContrast.ratio(Color.WHITE, Color.WHITE), 1.0, 0.0001)
	assert_almost_eq(HudContrast.ratio(Color.WHITE, Color.BLACK), 21.0, 0.0001)


func test_an_unreadable_file_gives_magenta() -> void:
	assert_eq(HudContrast.centre_color("res://no/such/piece.png"), Color.MAGENTA)
