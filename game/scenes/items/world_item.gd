class_name WorldItem
extends Node2D
## An item lying on the ground (crafting-inventory "Pick-up"). Interacting applies on the host
## (the player's interaction runs there): what fits goes in the player's inventory, the rest
## stays. Set item_id and count before it enters the tree.

@export var item_id: StringName = &""
@export var count: int = 1
## Uses a tool still has; -1 means a fresh one.
var uses_left: int = -1

@onready var interactable: Interactable = $Interactable


func _ready() -> void:
	interactable.hold_time_s = 0.0
	interactable.interacted.connect(_on_interacted)


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


func _draw() -> void:
	draw_rect(Rect2(-3.0, -3.0, 6.0, 6.0), Color(0.85, 0.8, 0.5))
