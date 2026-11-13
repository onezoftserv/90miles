class_name IslandSignData
extends DataPart
## A glyph of a handmade island's map that stands for a sign: a wall slogan, a dead radio, two
## crossed sticks. Interacting with it opens a sign note with its line on the reader's HUD; reading changes
## nothing else. One glyph, one cell. Spanish first.

## The character in the layout's rows.
@export var glyph: String = ""
@export_multiline var text_es: String = ""
@export_multiline var text_en: String = ""


## The line in `locale` (Spanish unless it starts with "en" and an English line exists).
func text_for(locale: String = "es") -> String:
	if locale.begins_with("en") and not text_en.is_empty():
		return text_en
	return text_es
