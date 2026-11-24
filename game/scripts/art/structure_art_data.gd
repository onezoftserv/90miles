class_name StructureArtData
extends Resource
## The structures' art and their numbers, only in res://assets/art/structures/structure_art.tres
## (art-pass "Palms", "Camp structures", "Raft site and raft"; design.md D18). Every frame stands
## bottom-centre on its structure's origin (StructureArt.frame_offset); StructureArt picks the frame.

const STANDARD_PATH: String = "res://assets/art/structures/structure_art.tres"

## The palm, 32x48, its trunk base at the bottom-centre. It is palm look 0.
@export var palm: Texture2D
## The redrawn palm looks (art-prop-polish D4, owner QP1 (a)), lit from the upper left like `palm`:
## look i is palm_looks[i - 1]. Each is 32x48 with the same trunk base and its crown round
## `nest_point`, so every look takes the coconut and nest overlays below.
@export var palm_looks: Array[Texture2D] = []
## Overlays on the palm's frame for 1, 2 and 3 coconuts, in that order.
@export var coconut_overlays: Array[Texture2D] = []
## The gull nest overlay, on the palm's frame.
@export var nest: Texture2D
## Where a perched gull stands, from the trunk base: the middle of the nest.
@export var nest_point: Vector2
## FIRE_LIT (a 4-frame flicker) and FIRE_OUT (embers).
@export var fire: SpriteFrames
## CATCHER_EMPTY and CATCHER_WATER.
@export var rain_catcher: SpriteFrames
## RAFT_WHOLE, RAFT_WORN and RAFT_BREAKING, 64x32 each.
@export var raft: SpriteFrames
## The almendrón on its drums on the crossing (vessel-car-board): the raft's three frames, 64x32.
@export var car: SpriteFrames
## One rider's board on the crossing (vessel-car-board): the raft's three frames, 16x32, nose north.
@export var board: SpriteFrames
## One-frame structures by kind: the workbench, the stake marker and the sign post.
@export var stills: Dictionary[StringName, Texture2D] = {}
## A sign's look by IslandSignData.look (art-prop-polish D7): the radio, the crossed sticks, the slogan
## fragment. A sign with no look, or one this does not name, draws the sign board of `stills`.
@export var sign_looks: Dictionary[StringName, Texture2D] = {}
## A build site's stages (SITE_MARKED, SITE_MATERIALS, SITE_HALF_BUILT) by recipe id; any other
## site is the stake marker.
@export var site_frames: Dictionary[StringName, SpriteFrames] = {}
## The drop shadow of each kind: a DropShadow.Size, or -1 for none.
@export var shadows: Dictionary[StringName, int] = {}
## Where each kind's shadow is centred, from its origin.
@export var shadow_offsets: Dictionary[StringName, Vector2] = {}
## A frame's own shadow, a DropShadow.Size or -1, before its kind's (art-terrain-polish D3): the raft
## site casts the WIDE one from its half-built stage on, and none while marked or holding materials.
@export var frame_shadows: Dictionary[StringName, int] = {}
## How far a kind's frame and shadow lean toward land from its origin (art-terrain-polish D3): x
## toward the land side StructureArt.land_side picks, mirrored for east; y as it is. The raft and
## its site lean so the hull rests on the sand instead of hanging over the shallows. Drawing only:
## the structure, its interactable and its prompt stay on the origin, and the crossing deck never
## reads this.
@export var look_offsets: Dictionary[StringName, Vector2] = {}


static func standard() -> StructureArtData:
	return load(STANDARD_PATH) as StructureArtData


## How many palm looks there are: `palm` and the redrawn ones.
func palm_look_count() -> int:
	return 1 + palm_looks.size()


## The frame of palm look `look`; `palm` for a look the table does not hold.
func palm_texture(look: int) -> Texture2D:
	if look >= 1 and look <= palm_looks.size():
		return palm_looks[look - 1]
	return palm


## The one-frame sprite of `kind`, or null when the kind draws nothing of its own.
func still_for(kind: StringName) -> Texture2D:
	return stills.get(kind, null) as Texture2D


## The texture of a sign with `look`: its look, or the sign board.
func sign_texture(look: StringName) -> Texture2D:
	var texture: Texture2D = sign_looks.get(look, null) as Texture2D
	return texture if texture != null else still_for(StructureArt.KIND_SIGN)


## How far `kind` leans toward land on `side` (-1 west, 1 east, 0 none); zero for a kind that does
## not lean.
func look_offset(kind: StringName, side: int) -> Vector2:
	if side == 0:
		return Vector2.ZERO
	var lean: Vector2 = look_offsets.get(kind, Vector2.ZERO)
	return Vector2(lean.x * side, lean.y)


## The shadow of `kind` showing `frame`: the frame's own, else the kind's; -1 for none.
func shadow_for(kind: StringName, frame: StringName) -> int:
	return frame_shadows.get(frame, shadows.get(kind, -1))


## The stages of the site of `recipe_id`, or null for a stake marker.
func site_frames_for(recipe_id: StringName) -> SpriteFrames:
	return site_frames.get(recipe_id, null) as SpriteFrames
