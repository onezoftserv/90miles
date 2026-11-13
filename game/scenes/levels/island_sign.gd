class_name IslandSign
extends Interactable
## A flavour sign (island-generation "Flavour signs"): a wall slogan, a dead radio, two crossed
## sticks. Using it changes nothing: the reader's HUD opens a sign note with its line on the local
## press (`SignNote`), so no peer but the reader sees it. The level places it in the session at the
## same path on every peer.

## Its prompt reads "[E] Mirar": a radio and crossed sticks are looked at as much as read.
const PROMPT_ID: StringName = &"look_sign"

## The two lines, set before it enters the tree.
var line_es: String = ""
var line_en: String = ""


# The level makes signs with new(), so the sign post's look is added here (drawing only).
func _init() -> void:
	add_child(StructureLook.create())


func _ready() -> void:
	hold_time_s = 0.0
	prompt_id = PROMPT_ID


## The line in `locale`.
func line(locale: String = "es") -> String:
	if locale.begins_with("en") and not line_en.is_empty():
		return line_en
	return line_es
