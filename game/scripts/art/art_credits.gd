class_name ArtCredits
extends Resource
## The game's credits data (design.md D10): every pack, palette and font whose files the game
## ships, in res://assets/art/credits.tres. CREDITS.md and License.txt do not ship in an exported
## build, so this is what the credits screen shows.

const STANDARD_PATH: String = "res://assets/art/credits.tres"

@export var entries: Array[ArtCredit] = []


static func standard() -> ArtCredits:
	return load(STANDARD_PATH) as ArtCredits


func in_screen_order() -> Array[ArtCredit]:
	return entries.duplicate()
