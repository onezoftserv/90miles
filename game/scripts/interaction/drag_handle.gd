class_name DragHandle
extends Interactable
## Lets a teammate drag a downed player. Each player has one, enabled only while downed.
## Using it is instant; the dragging lasts until the helper releases interact.

## The player currently dragging, or null.
var dragger: Node2D = null


func _init() -> void:
	hold_time_s = 0.0
	enabled = false


func use(by: Node) -> void:
	if enabled:
		dragger = by as Node2D
		interacted.emit(by)


func release(_by: Node) -> void:
	dragger = null
