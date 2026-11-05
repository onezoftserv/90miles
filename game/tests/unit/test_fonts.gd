extends GutTest
## docs/ASSETS.md: the pixel fonts must render Spanish (ñ, accents, ¿, ¡).

const FONTS: Array[String] = [
	"res://assets/fonts/PressStart2P-Regular.ttf",
	"res://assets/fonts/PixelifySans[wght].ttf",
]
const SPANISH_CHARS := "ñÑáéíóúüÁÉÍÓÚÜ¿¡"


func test_fonts_cover_spanish_characters() -> void:
	for path: String in FONTS:
		var font: FontFile = load(path) as FontFile
		assert_not_null(font, "%s loads as a font" % path)
		if font == null:
			continue
		var missing := ""
		for ch: String in SPANISH_CHARS:
			if not font.has_char(ch.unicode_at(0)):
				missing += ch
		assert_eq(missing, "", "%s has every Spanish character" % path.get_file())
