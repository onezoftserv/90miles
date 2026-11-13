class_name Palm
extends Node2D
## A palm with coconuts (island-generation "Palm climbing"). Holding interact climbs it: the
## host's interaction puts 1 coconut in the climber's inventory and applies the climb cost
## (energy). Nothing happens, and nothing is paid, when the palm is bare or the coconut does not
## fit. The level sets coconuts, climb_effects and hold_s before the palm enters the tree.

const COCONUT_ID: StringName = &"coco"

## Host only: every climb is applied on the host, so a client's copy is not synced (it keeps
## the layout's count). Syncing it is a follow-up for when palms get an empty visual.
@export var coconuts: int = 0
@export var climb_effects: Array[EffectData] = []
## Seconds the interact button is held.
@export var hold_s: float = Interactable.DEFAULT_HOLD_TIME_S

@onready var interactable: Interactable = $Interactable


func _ready() -> void:
	interactable.hold_time_s = hold_s
	interactable.interacted.connect(_on_interacted)


func _on_interacted(by: Node) -> void:
	var player := by as PlayerBody
	if player == null or coconuts <= 0 or player.inventory.add(COCONUT_ID, 1) <= 0:
		return
	coconuts -= 1
	for effect: EffectData in climb_effects:
		EffectApplier.apply(effect, player, null)
