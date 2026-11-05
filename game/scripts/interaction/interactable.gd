class_name Interactable
extends Node2D
## Something a player can use with the interact button: pick up, talk, use, climb, cut a net.
## It only reports that it was used; what that does belongs to whoever listens to `interacted`.

## Emitted when a player completes the interaction (instantly or after the hold time).
signal interacted(by: Node)

## Interactables join this group so a player body can find the ones in reach.
const GROUP: StringName = &"interactables"
## Seconds the button must stay held, unless the interactable sets another time.
const DEFAULT_HOLD_TIME_S: float = 2.0

## Seconds of holding needed; 0 means instant.
@export var hold_time_s: float = DEFAULT_HOLD_TIME_S
## Disabled interactables are skipped by the picker and cannot be used.
var enabled: bool = true


func _enter_tree() -> void:
	add_to_group(GROUP)


## Called when a player completes the interaction.
func use(by: Node) -> void:
	if enabled:
		interacted.emit(by)


## Called when the player lets go after `use` happened. Interactables that last as long as the
## button is held (dragging) override this.
func release(_by: Node) -> void:
	pass
