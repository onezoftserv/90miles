class_name Fire
extends Node2D
## A placed fire (crafting-inventory "Fire"). Lighting gives every player within the company
## radius the fire-lit morale bonus; while lit it joins the lit_fires group, which keeps lone
## players company at night, and burns for tuning.fire_burn_s. Any player can put it out with a
## held interaction; a fire that is out stays as embers.

var tuning: CraftingTuning = preload("res://resources/crafting_tuning.tres")
var lit: bool = false
var burn_left_s: float = 0.0

@onready var interactable: Interactable = $Interactable


func _ready() -> void:
	interactable.hold_time_s = tuning.fire_put_out_hold_s
	interactable.enabled = lit
	interactable.interacted.connect(_on_interacted)
	# A client's copy of a fire built on the host arrives lit, with no light() of its own.
	if lit:
		_burn()


## Called by a BuildSite when the build completes: a built fire is lit.
func on_built(_recipe: RecipeData) -> void:
	light()


func light() -> void:
	_burn()
	for node: Node in get_tree().get_nodes_in_group(PlayerBody.GROUP):
		var player := node as PlayerBody
		var radius_px: float = player.meters.tuning.company_radius_tiles * PlayerBody.TILE_SIZE
		if player.global_position.distance_to(global_position) <= radius_px:
			player.meters.morale_event(SurvivalMeters.MoraleEvent.FIRE_LIT)


# Burning from now on: in the lit fires, interactable (its look reads `lit`).
func _burn() -> void:
	lit = true
	burn_left_s = tuning.fire_burn_s
	add_to_group(PlayerBody.FIRE_GROUP)
	interactable.enabled = true


func put_out() -> void:
	lit = false
	burn_left_s = 0.0
	remove_from_group(PlayerBody.FIRE_GROUP)
	interactable.enabled = false


## Burns down by `delta`; goes out at 0.
func advance(delta: float) -> void:
	if not lit:
		return
	burn_left_s -= delta
	if burn_left_s <= 0.0:
		put_out()


func _physics_process(delta: float) -> void:
	if multiplayer.is_server():
		advance(delta)


func _on_interacted(_by: Node) -> void:
	put_out()
