class_name BodyArt
extends Resource
## How a player's body is drawn (art-pass "Player frames and anchor", "Head anchor", "Player look
## slots"; design.md D1, D19, D20, C1, C2), only in res://assets/art/characters/balsero_art.tres:
## the template frames, the feet line, the water row and swim drop, the head gap and the dive
## anchor, the default look and one look per look slot. Head anchors per pose are measured from
## each composed look, not stored here.

const STANDARD_PATH: String = "res://assets/art/characters/balsero_art.tres"

## The template SpriteFrames: AtlasTexture regions of the frame layout, repointed per look.
@export var frames: SpriteFrames
## The standing frame's lowest opaque row, and where its bottom edge lies below the body's
## position (body-local px).
@export var feet_row: int
@export var feet_y: int
## The frame row a swimmer is cut at, and how far a swimmer is drawn lower (px).
@export var water_row: int
@export var swim_drop_px: int
## The head anchor lies this far above the topmost drawn row (px).
@export var head_gap_px: int
## The head anchor while diving (body-local px): only the ripple shows.
@export var dive_anchor_y: int
## The look for a missing part's layer and for a slot outside the table.
@export var default_look: PlayerLookData
## One look per look slot, index = slot (0-3).
@export var slot_looks: Array[PlayerLookData] = []


static func standard() -> BodyArt:
	return load(STANDARD_PATH) as BodyArt


## The look of look slot `slot`, or the default look (with a warning) for a slot outside the table
## or an empty entry.
func look_for_slot(slot: int) -> PlayerLookData:
	if slot >= 0 and slot < slot_looks.size() and slot_looks[slot] != null:
		return slot_looks[slot]
	push_warning("BodyArt: no look for slot %d, drawing the default look" % slot)
	return default_look
