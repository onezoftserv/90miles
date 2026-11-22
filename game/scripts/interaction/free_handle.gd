class_name FreeHandle
extends Interactable
## guardacostas-capture design.md §7 (spec "Free a captive"): the "Soltar" handle every player body
## carries. It is offered only while its body is a captive that can be freed (led to the dinghy or
## sitting in it; never one hauled aboard the boat) and no soldier is within the guard radius of it.
## A soldier coming within that radius disables it, which cancels a hold under way (InteractionHold
## resets on a disabled target), so the guard coming back stops a rescue. The host frees the captive
## when the hold completes (the body listens to `interacted`); on a client the same rule only shows or
## hides the prompt and its ring. Freeing runs through the ordinary interact intent, so no new client
## message exists for it.

## Shore soldiers join this group on every peer (Creature._ready, for a SEARCH_CAPTURE creature).
const SOLDIER_GROUP: StringName = &"shore_soldiers"

## A soldier within this many tiles of the captive keeps them from being freed (the boat's
## free_guard_radius_tiles, set when the body is captured).
var guard_radius_tiles: float = 3.0


func _init() -> void:
	hold_time_s = 1.0
	prompt_id = &"free_captive"
	enabled = false


func _physics_process(_delta: float) -> void:
	refresh()


## Recomputes whether the handle is offered now (every physics frame on every peer, and from the
## captive body's own step on the host, so a soldier's return cancels a hold in the same tick).
func refresh() -> void:
	enabled = _offered()


## Only another player, who is free, may free a captive.
func usable_by(by: Node) -> bool:
	var player := by as PlayerBody
	var captive := get_parent() as PlayerBody
	return player != null and player != captive and not player.captive and not player.downed and not player.left_island


## The prompt names the captive by the name their peer plays under, as the drag handle does.
func prompt_target(_by: Node, _locale: String) -> String:
	var session := CoopSession.of(self)
	var player := get_parent() as PlayerBody
	if session == null or player == null:
		return ""
	return session.player_name(session.peer_of(player))


## The captive's name tag is cleared under the prompt, as over a downed teammate.
func prompt_player() -> Node2D:
	return get_parent() as Node2D


## Whether a soldier (a member of SOLDIER_GROUP in this body's session) stands within the guard radius
## of the captive. Read from the soldiers' synced positions, so every peer agrees. (The group, not the
## Creature class: the player's scene loads this script early, before the creature scene.)
func guard_near() -> bool:
	var captive := get_parent() as Node2D
	var session := CoopSession.of(self)
	if captive == null or not is_inside_tree():
		return false
	var reach_px: float = guard_radius_tiles * CreatureNav.TILE + 0.000001
	for node: Node in get_tree().get_nodes_in_group(SOLDIER_GROUP):
		var soldier := node as Node2D
		if soldier == null or soldier.is_queued_for_deletion() or CoopSession.of(soldier) != session:
			continue
		if soldier.global_position.distance_to(captive.global_position) <= reach_px:
			return true
	return false


func _offered() -> bool:
	var captive := get_parent() as PlayerBody
	return captive != null and captive.can_be_freed() and not guard_near()
