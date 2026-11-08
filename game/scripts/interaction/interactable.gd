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
## The HUD prompt's verb and default label in game/resources/hud_text.tres (inventory-hud
## "Prompt verbs and targets"). Set in the scene, or in code by kinds whose prompt follows their
## state; empty shows the interact key alone.
@export var prompt_id: StringName = &""
## The prompt names only this interactable, never what it holds.
@export var hides_contents: bool = false
## Disabled interactables are skipped by the picker and cannot be used.
var enabled: bool = true


func _enter_tree() -> void:
	add_to_group(GROUP)


## Whether `by` may be offered this interactable (the picker asks). Some belong to one player or
## to everyone else (a swimmer's climb point, a rescue handle).
func usable_by(_by: Node) -> bool:
	return true


## Called when a player completes the interaction.
func use(by: Node) -> void:
	if enabled:
		interacted.emit(by)


## Called when the player lets go after `use` happened. Interactables that last as long as the
## button is held (dragging) override this.
func release(_by: Node) -> void:
	pass


## The prompt id the HUD shows `by` (inventory-hud "Prompt verbs and targets"): `prompt_id`,
## unless a kind's verb follows its state for that player (the crossing's lashing: tie or untie).
func prompt_id_for(_by: Node) -> StringName:
	return prompt_id


## The content name the prompt names for `by` in `locale` (the item lying there, the site's
## recipe, the creature), or "" for none. Asked of the owner, this node's parent, which names its
## own content once per kind; kinds that are Interactables themselves override it.
func prompt_target(by: Node, locale: String) -> String:
	var owner_node := get_parent()
	if owner_node != null and owner_node.has_method(&"prompt_target"):
		return owner_node.call(&"prompt_target", by, locale)
	return ""
