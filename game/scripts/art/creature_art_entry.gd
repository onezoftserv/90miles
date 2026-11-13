class_name CreatureArtEntry
extends Resource
## How one creature is drawn (art-pass "Creature frames from data"; design.md D16, D19, K1, K4):
## art data, not content, held by CreatureArt under the creature's id. Frames are centred on the
## creature's x; every length is in pixels and every state name in lower case.

## The frame's bottom edge (the feet) this far below the creature's position.
@export var foot_px: float = 5.0
@export var has_shadow: bool = true
@export var shadow_size: DropShadow.Size = DropShadow.Size.SMALL
## The shadow's centre this far below the creature's position, on the ground in every state.
@export var shadow_y_px: float = 4.0
## States drawn in the air: the frames lifted by `air_lift_px`, the shadow left on the ground, and
## `move` frames whatever the motion (SPD CrystalWispSprite).
@export var airborne_states: PackedStringArray = []
@export var air_lift_px: float = 8.0
## The perched state: the feet stand `perch_lift_px` above the creature's position (a gull on its
## palm's crown nest point, the trunk base being its position), with no shadow; the look sorts
## 1 px south of the position (design.md K4).
@export var perch_state: StringName = &""
@export var perch_lift_px: float = 0.0
## Drawn at the water line (waterline.gdshader): the frame's rows from `water_line_px` (counted
## from its top) are the ripple and the fading body under the surface; no shadow.
@export var water_line: bool = false
@export var water_line_px: float = 0.0
## One-shots, keyed by the state entered: the animation plays once as a peer sees the state
## change to that one, then the picked animation again (`retreat` -> `strike`).
@export var one_shots: Dictionary[StringName, StringName] = {}
