class_name DragHandle
extends Interactable
## Lets a teammate drag a downed player. Each player has one, enabled only while downed.
## Using it is instant; the dragging lasts until the helper releases interact.

## The player currently dragging, or null.
var dragger: Node2D = null


func _init() -> void:
	hold_time_s = 0.0
	enabled = false
	prompt_id = &"drag"


func use(by: Node) -> void:
	if enabled and (dragger == null or not is_instance_valid(dragger) or dragger == by):
		dragger = by as Node2D
		interacted.emit(by)


func release(by: Node) -> void:
	if by == dragger:
		dragger = null


## The prompt names the downed player by the name their peer plays under, never the node name
## (a reclaimed body keeps the name of the peer it first spawned under).
func prompt_target(_by: Node, _locale: String) -> String:
	var session := CoopSession.of(self)
	var player := get_parent() as PlayerBody
	if session == null or player == null:
		return ""
	return session.player_name(session.peer_of(player))
