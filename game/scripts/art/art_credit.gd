class_name ArtCredit
extends Resource
## One line of the game's credits (design.md D10): a pack, palette or font the game ships files
## from, with what its licence asks for. Kept in res://assets/art/credits.tres (ArtCredits), which
## the credits screen reads and test_art_credits.gd checks against every License.txt under
## res://assets/art and game/assets/CREDITS.md.

## The credits screen's groups, in its order (design.md D10): the CC BY packs whose licence asks
## for the credit, then the courtesy lines (CC0 packs, the palette), then the OFL fonts.
enum Group { ATTRIBUTION, COURTESY, FONT }

const FONT_LICENCE_PREFIX: String = "SIL OFL"

## The pack's name as its author gives it.
@export var pack: String = ""
## Who made it, as its licence or page names them (matched against License.txt and CREDITS.md).
@export var author: String = ""
## "CC BY 4.0", "CC0 1.0", "SIL OFL 1.1", or what the source states.
@export var licence: String = ""
## The licence's address; CC BY 4.0 §3(a)(1) asks for it beside the credit.
@export var licence_url: String = ""
## The pack's page, never a licence deed.
@export var source: String = ""
@export var version: String = ""
## Whether the tracked files were changed (recoloured, cut, edited); the screen marks them.
@export var modified: bool = false
## The licence requires this credit to be shown (CC BY); the others are courtesy lines.
@export var attribution_required: bool = false
## The line the credits screen shows, in Spanish, ending with the source page.
@export var line_es: String = ""


func group() -> Group:
	if attribution_required:
		return Group.ATTRIBUTION
	if licence.begins_with(FONT_LICENCE_PREFIX):
		return Group.FONT
	return Group.COURTESY
