class_name WorldItem
extends Node2D
## An item lying on the ground (crafting-inventory "Pick-up"). Interacting applies on the host
## (the player's interaction runs there): what fits goes in the player's inventory, the rest
## stays. Set item_id and count before it enters the tree. Its Look child draws it (art-pass,
## `art_view`).

@export var item_id: StringName = &""
@export var count: int = 1
## Uses a tool still has; -1 means a fresh one.
var uses_left: int = -1

@onready var interactable: Interactable = $Interactable


func _ready() -> void:
	interactable.hold_time_s = 0.0
	interactable.interacted.connect(_on_interacted)


## The interact prompt names the item lying here.
func prompt_target(_by: Node, locale: String) -> String:
	var item := GameState.content.get_entry(&"items", item_id) as ItemData
	return item.get_display_name(locale) if item != null else ""


func _on_interacted(by: Node) -> void:
	var player := by as PlayerBody
	if player == null:
		return
	var taken: int = player.inventory.add(item_id, count, uses_left)
	if taken <= 0:
		return
	var item := player.inventory.item_for(item_id)
	for effect: EffectData in item.pickup_effects:
		EffectApplier.apply(effect, player, null)
	count -= taken
	if count <= 0:
		interactable.enabled = false
		queue_free()
