class_name DecorLook
extends Resource
## One decor cell's look (art-prop-polish D6), an entry of DecorArtData: what a decor id draws on
## a terrain. Drawing only; nothing here touches the simulation.

## The layout decor id this look draws.
@export var decor_id: StringName = &""
## The terrain it is for (DataEnums.Terrain), or -1 for any; a look for the cell's own terrain
## wins over one for any.
@export var terrain: int = -1
## Upright pieces stand on their cell and sort with the actors (DecorView's DecorPieces); flat
## ones lie on the ground under every actor's shadow.
@export var upright: bool = false
## The piece's still frame. A look with neither texture nor frames draws nothing (a drag mark under
## water), which is not the same as having no look (the colour square).
@export var texture: Texture2D
## An upright piece's animation, in place of `texture` (the stub's smoke).
@export var frames: SpriteFrames
## A flat texture under an upright piece, centred on its foot (a post's ripple in the shallows).
@export var foot: Texture2D
## A flat piece two cells wide: a cell whose west neighbour holds the same decor draws the
## texture's east half, any other its west half, so a run of pairs joins up (the drag mark).
@export var pair: bool = false
## Where the piece is drawn from its usual place, in pixels, inside its own cell: the embers sit on
## their cell's north edge, clear of the palm crown that hangs over its south half.
@export var offset: Vector2 = Vector2.ZERO


## Whether the look draws anything at all.
func draws() -> bool:
	return texture != null or frames != null
