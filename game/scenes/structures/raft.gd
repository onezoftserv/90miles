class_name Raft
extends Node2D
## A built raft lying on the beach (escape-routes "Raft build site"). Using it launches the route
## named by its recipe id for whoever uses it: the host picks the riders. It stays until the
## route starts; the island then puts a fresh build site in its place.

## Seconds the interact button is held to launch (provisional).
const LAUNCH_HOLD_S: float = 1.0

var climate: ClimateState = null
var recipe_id: StringName = &""
var integrity: float = 0.0

@onready var interactable: Interactable = $Interactable


func _ready() -> void:
	interactable.hold_time_s = LAUNCH_HOLD_S
	interactable.interacted.connect(_on_interacted)


## Called by a BuildSite when the build completes.
func on_built(recipe: RecipeData) -> void:
	recipe_id = recipe.id
	integrity = recipe.vessel_integrity
	set_meta(&"recipe_id", recipe_id)
	add_to_group(PlayerBody.STRUCTURE_GROUP)


func _on_interacted(by: Node) -> void:
	var routes := get_tree().get_first_node_in_group(IslandRoutes.GROUP) as IslandRoutes
	if routes != null and by is PlayerBody and multiplayer.is_server():
		routes.start_for(int(String(by.name)), recipe_id)


func _draw() -> void:
	draw_rect(Rect2(-9.0, -5.0, 18.0, 10.0), Color(0.55, 0.4, 0.22))
	draw_rect(Rect2(-9.0, -5.0, 18.0, 10.0), Color(0.3, 0.2, 0.1), false)
