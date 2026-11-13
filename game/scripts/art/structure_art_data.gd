class_name StructureArtData
extends Resource
## The structures' art and their numbers, only in res://assets/art/structures/structure_art.tres
## (art-pass "Palms", "Camp structures", "Raft site and raft"; design.md D18). Every frame stands
## bottom-centre on its structure's origin (StructureArt.frame_offset); StructureArt picks the frame.

const STANDARD_PATH: String = "res://assets/art/structures/structure_art.tres"

## The palm, 32x48, its trunk base at the bottom-centre.
@export var palm: Texture2D
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
## One-frame structures by kind: the workbench, the stake marker and the sign post.
@export var stills: Dictionary[StringName, Texture2D] = {}
## A build site's stages (SITE_MARKED, SITE_MATERIALS, SITE_HALF_BUILT) by recipe id; any other
## site is the stake marker.
@export var site_frames: Dictionary[StringName, SpriteFrames] = {}
## The drop shadow of each kind: a DropShadow.Size, or -1 for none.
@export var shadows: Dictionary[StringName, int] = {}
## Where each kind's shadow is centred, from its origin.
@export var shadow_offsets: Dictionary[StringName, Vector2] = {}


static func standard() -> StructureArtData:
	return load(STANDARD_PATH) as StructureArtData


## The one-frame sprite of `kind`, or null when the kind draws nothing of its own.
func still_for(kind: StringName) -> Texture2D:
	return stills.get(kind, null) as Texture2D


## The stages of the site of `recipe_id`, or null for a stake marker.
func site_frames_for(recipe_id: StringName) -> SpriteFrames:
	return site_frames.get(recipe_id, null) as SpriteFrames
