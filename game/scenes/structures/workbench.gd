class_name Workbench
extends Node2D
## A flat rock or a wreck table the level places (crafting-inventory "Workbench"): a player
## within 1 tile can craft workbench recipes here, or place the site of a build-site structure.
## It only marks the spot; Crafter and the session do the work. Its Interactable is made here, so
## every `Workbench.new()` has one: the HUD opens the crafting list when the local player's press
## lands on it, and on the host the press changes nothing (nothing listens to `interacted`).

const INTERACTABLE_NAME: StringName = &"Interactable"
const PROMPT_ID: StringName = &"workbench"

var interactable: Interactable = Interactable.new()


func _init() -> void:
	interactable.name = INTERACTABLE_NAME
	interactable.hold_time_s = 0.0
	interactable.prompt_id = PROMPT_ID
	add_child(interactable)
	# Drawing only (art-pass "Camp structures"; design.md T7): every bench made with new() has it.
	add_child(StructureLook.create())
