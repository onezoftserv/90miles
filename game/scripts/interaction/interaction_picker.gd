class_name InteractionPicker
extends RefCounted
## Chooses which interactable a player's interact press goes to: the nearest enabled one
## within 1 tile (16 px).

const REACH_PX: float = 16.0


## `exclude_parent`: interactables that are children of this node (the player's own) are skipped.
static func pick(origin: Vector2, candidates: Array[Interactable], exclude_parent: Node = null) -> Interactable:
	var best: Interactable = null
	var best_distance: float = INF
	for candidate: Interactable in candidates:
		if not is_instance_valid(candidate) or not candidate.enabled:
			continue
		if exclude_parent != null and candidate.get_parent() == exclude_parent:
			continue
		var distance: float = origin.distance_to(candidate.global_position)
		if distance <= REACH_PX and distance < best_distance:
			best = candidate
			best_distance = distance
	return best
