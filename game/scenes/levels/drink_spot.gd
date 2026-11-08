class_name DrinkSpot
extends Interactable
## A shore of drinkable water (island-generation "Drinking from the lagoon"): holding interact for
## the layout's hold time applies the layout's drink effects to the drinker. The interaction runs
## on the host (or offline), so the effects are the host's; a delayed one waits in the drinker's
## meters. The water never runs dry.

## What one drink does (IslandLayoutData.drink_effects).
var effects: Array[EffectData] = []


func _ready() -> void:
	interacted.connect(_on_interacted)


func _on_interacted(by: Node) -> void:
	var player := by as PlayerBody
	if player == null or player.meters.dead:
		return
	for effect: EffectData in effects:
		EffectApplier.apply(effect, player, null)


func _draw() -> void:
	draw_rect(Rect2(-4.0, -4.0, 8.0, 8.0), Color(0.35, 0.65, 0.6, 0.5), false)
