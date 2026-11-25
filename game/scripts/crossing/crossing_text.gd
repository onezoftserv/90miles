class_name CrossingText
extends Resource
## The crossing HUD's words (crossing "Crossing HUD and telegraphs"; design.md D11), Spanish then
## English in each pair, only in res://resources/crossing_text.tres. The warning lines are drafts
## for the owner's voice pass: characters shouting on the raft, so Cuban speech.

const STANDARD_PATH: String = "res://resources/crossing_text.tres"

## Shown this many seconds before a squall's hit: the far line, then the near one.
@export var squall_far_s: float
@export var squall_near_s: float
## How long each warning line stays up.
@export var line_s: float
@export var squall_far: PackedStringArray
@export var squall_near: PackedStringArray
@export var fin_west: PackedStringArray
@export var fin_east: PackedStringArray
@export var leak: PackedStringArray
## The vessel's name before its integrity on the strip, by DataEnums.Vessel.
@export var vessel_names: Dictionary[int, PackedStringArray]
## What the strip says for a rider with no vessel (swimming).
@export var swimming: PackedStringArray


static func standard() -> CrossingText:
	return load(STANDARD_PATH) as CrossingText
