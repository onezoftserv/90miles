class_name ArtTuning
extends Resource
## Every readable-art number and the palette files, only in res://resources/art_tuning.tres (the
## script has no defaults, like CrossingTuning). design.md D21 and C1 D7: the checks read the
## thresholds, budgets and outline set from here, and the palette textures are referred to by this
## resource like every other tracked image.

const STANDARD_PATH: String = "res://resources/art_tuning.tres"

## Contrast ratio (WCAG) an actor needs against each ground it can be on.
@export var contrast_min: float
## Contrast ratio between any two look slots' mid tones.
@export var slot_contrast_min: float
## Hue difference, in degrees, between any two look slots' mid tones.
@export var slot_hue_min_deg: float
## Unique frames per actor or structure animation (per facing), per creature animation, and per
## character (a part sheet or a composed look), and the fastest frame rate.
@export var max_unique_frames: int
@export var max_creature_frames: int
@export var max_character_frames: int
@export var max_fps: float
## The palette's darkest colours, used for every outline (design.md D7, D8).
@export var outline_colors: PackedColorArray
## Mean colour of each land ground (sand, dune, brush) and each water ground (shallows, deep,
## brackish), measured from the made art in task 4.5 (design.md K47): sand and dune the mean of
## the full-tile picks every whole cell draws, brush its full tile, and each sea step the mean
## world_sea.gdshader draws (the lighter of two water samples, in that step's ramp).
@export var land_grounds: Dictionary[StringName, Color]
@export var water_grounds: Dictionary[StringName, Color]
## One pixel per colour: DawnBringer's 32 and the added colours (at most 64 in all).
@export var master_palette: Texture2D
## Row 0 the clothing key ramp, rows 1-4 the look slots azul, rojo, amarillo and verde; columns
## highlight, base (the mid tone), shade and line.
@export var player_ramps: Texture2D
## Rows 0 claro (the body sheets are drawn in it), 1 trigueño and 2 moreno; same columns.
@export var skin_ramps: Texture2D
## The sea's seamless 32×32 water texture, drawn in the deep ramp's four colours (design.md K38).
@export var sea_water: Texture2D
## Rows 0 deep (the water texture's own colours), 1 shallows and 2 brackish; columns dark to light.
@export var sea_ramps: Texture2D


static func standard() -> ArtTuning:
	return load(STANDARD_PATH) as ArtTuning
