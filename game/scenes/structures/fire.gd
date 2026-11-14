class_name Fire
extends Node2D
## A placed fire (crafting-inventory "Fire"). Lighting gives every player within the company
## radius the fire-lit morale bonus; while lit it joins the lit_fires group, which keeps lone
## players company at night, and burns for tuning.fire_burn_s. Any player can put it out with a
## held interaction; a fire that is out stays as embers.
## A fire spawned at a bench carries a synchronizer (`attach_sync`): the host's `lit` reaches every
## client, a late joiner included, and wherever `lit` is set the fire joins or leaves the lit fires
## and can or cannot be put out (coop-networking "Structure state on every peer").

## Its synchronizer's node name.
const SYNC_NAME: StringName = &"StateSync"

var tuning: CraftingTuning = preload("res://resources/crafting_tuning.tres")
## Burning now. Setting it (the host's own changes, or the synchronizer on a client) also sets the
## lit fires and the interaction; the morale and the burn time are the host's (light, advance).
var lit: bool = false:
	set(value):
		lit = value
		if is_node_ready():
			_show_lit()
var burn_left_s: float = 0.0

@onready var interactable: Interactable = $Interactable


func _ready() -> void:
	interactable.hold_time_s = tuning.fire_put_out_hold_s
	interactable.interacted.connect(_on_interacted)
	# A fire whose spawn says lit (a client's copy, and the host's own before on_built) burns now.
	if lit:
		_burn()
	_show_lit()


## The session's entity spawner adds it to a fire it spawns: `lit` from the host, with the spawn and
## on each change (structure-state-sync design D3).
func attach_sync() -> void:
	add_child(SitePlacer.state_sync(SYNC_NAME, PackedStringArray([".:lit"])))


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


# Burning from now on, for the whole burn time.
func _burn() -> void:
	lit = true
	burn_left_s = tuning.fire_burn_s


func put_out() -> void:
	lit = false
	burn_left_s = 0.0


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


# In the lit fires and interactable while lit (its look reads `lit` too).
func _show_lit() -> void:
	if lit:
		add_to_group(PlayerBody.FIRE_GROUP)
	elif is_in_group(PlayerBody.FIRE_GROUP):
		remove_from_group(PlayerBody.FIRE_GROUP)
	interactable.enabled = lit


func _on_interacted(_by: Node) -> void:
	put_out()
