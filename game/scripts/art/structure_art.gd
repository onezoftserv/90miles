class_name StructureArt
extends RefCounted
## The pure rules of the structure looks (art-pass "Palms", "Camp structures", "Raft site and
## raft"; design.md D18, T8-T10): which frame a structure shows for the state its peer holds, and
## where a frame stands. No node: the looks read their structure's fields every frame and pass
## them in, so every peer draws the same picture from the state it has.

## A palm draws at most this many coconuts, however many it holds.
const MAX_COCONUTS_SHOWN: int = 3

const FIRE_LIT: StringName = &"lit"
const FIRE_OUT: StringName = &"out"
const CATCHER_EMPTY: StringName = &"empty"
const CATCHER_WATER: StringName = &"water"
## A build site's stages: nothing deposited, any deposit, half the work done.
const SITE_MARKED: StringName = &"marked"
const SITE_MATERIALS: StringName = &"materials"
const SITE_HALF_BUILT: StringName = &"half_built"
const SITE_HALF_PROGRESS: float = 0.5
const RAFT_WHOLE: StringName = &"whole"
const RAFT_WORN: StringName = &"worn"
const RAFT_BREAKING: StringName = &"breaking"
## Above it a raft is whole; above RAFT_BREAKING_MAX and up to it, worn (design.md T8).
const RAFT_WORN_MAX: float = 66.0
const RAFT_BREAKING_MAX: float = 33.0
## No frame: nothing is drawn (a raft at 0, a drink spot).
const NO_FRAME: StringName = &""

## What a structure node is drawn as (StructureArtData keys its stills and shadows by these).
const KIND_PALM: StringName = &"palm"
const KIND_WORKBENCH: StringName = &"workbench"
const KIND_FIRE: StringName = &"fire"
const KIND_RAIN_CATCHER: StringName = &"rain_catcher"
const KIND_STAKE: StringName = &"stake"
const KIND_RAFT_SITE: StringName = &"raft_site"
const KIND_RAFT: StringName = &"raft"
const KIND_SIGN: StringName = &"island_sign"
const KINDS: Array[StringName] = [
	KIND_PALM, KIND_WORKBENCH, KIND_FIRE, KIND_RAIN_CATCHER, KIND_STAKE, KIND_RAFT_SITE, KIND_RAFT, KIND_SIGN,
]


static func coconuts_shown(coconuts: int) -> int:
	return clampi(coconuts, 0, MAX_COCONUTS_SHOWN)


## The nest is layout data, the same on every peer.
static func shows_nest(palm_index: int, nest_palms: Array[int]) -> bool:
	return nest_palms.has(palm_index)


static func fire_frame(lit: bool) -> StringName:
	return FIRE_LIT if lit else FIRE_OUT


static func catcher_frame(cups: int) -> StringName:
	return CATCHER_WATER if cups > 0 else CATCHER_EMPTY


## A site's stage from its item and tag deposits and its progress. An entry holding 0 is no
## deposit (design.md T10). There is no built stage: the structure replaces the site.
static func site_stage(deposited: Dictionary, tags_deposited: Dictionary, progress: float) -> StringName:
	if progress >= SITE_HALF_PROGRESS:
		return SITE_HALF_BUILT
	if _any_above_zero(deposited) or _any_above_zero(tags_deposited):
		return SITE_MATERIALS
	return SITE_MARKED


## A bench-placed site can stay in the tree, built, until the spawner removes it.
static func site_marker_shown(built: bool) -> bool:
	return not built


## Whole above 66, worn above 33, breaking above 0; nothing at 0, where the deck has sunk.
static func raft_frame(integrity: float) -> StringName:
	if integrity > RAFT_WORN_MAX:
		return RAFT_WHOLE
	if integrity > RAFT_BREAKING_MAX:
		return RAFT_WORN
	if integrity > 0.0:
		return RAFT_BREAKING
	return NO_FRAME


## The frame of a crossing vessel at `value` of its route's `nominal` integrity (vessel-car-board
## D4): the raft's thresholds as shares, whole above two thirds and worn above one third. A raft
## (nominal 100) draws as raft_frame does; a car at 95 of 160 is worn, a new board at 60 of 60
## whole. Nothing without a nominal.
static func vessel_frame(value: float, nominal: float) -> StringName:
	if nominal <= 0.0:
		return NO_FRAME
	return raft_frame(value / nominal * 100.0)


## The offset of an uncentred sprite whose frame stands bottom-centre on its node's origin.
static func frame_offset(frame_size: Vector2) -> Vector2:
	return Vector2(-floorf(frame_size.x / 2.0), -frame_size.y)


## The rect a frame covers when it stands bottom-centre on `foot`.
static func foot_rect(foot: Vector2, frame_size: Vector2) -> Rect2:
	return Rect2(foot + frame_offset(frame_size), frame_size)


## The kind a structure node is drawn as; empty for one that draws nothing (a drink spot). A build
## site is a stake marker unless StructureArtData has stages for its recipe.
static func kind_of(node: Node) -> StringName:
	if node is Palm:
		return KIND_PALM
	if node is Workbench:
		return KIND_WORKBENCH
	if node is Fire:
		return KIND_FIRE
	if node is RainCatcher:
		return KIND_RAIN_CATCHER
	if node is BuildSite:
		return KIND_STAKE
	if node is Raft:
		return KIND_RAFT
	if node is IslandSign:
		return KIND_SIGN
	return NO_FRAME


static func _any_above_zero(amounts: Dictionary) -> bool:
	for key: Variant in amounts:
		var amount: Variant = amounts[key]
		if amount is int and int(amount) > 0:
			return true
	return false
