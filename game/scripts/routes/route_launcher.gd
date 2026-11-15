class_name RouteLauncher
extends RefCounted
## Pure rules for starting a route (escape-routes "Riders by capacity"): whether the party
## requirements hold for the player who starts it, and who rides. Requirements read the
## starter's own state, as ConditionCheck does: pooled party inventories are not built yet.


static func can_start(route: RouteData, starter: PlayerBody) -> bool:
	return ConditionCheck.all_hold(route.requirements, starter)


## The riders among `candidates`, the sender first. Only living, standing players within the
## route's boarding radius of `anchor` can ride. An empty list when the sender cannot ride.
static func riders(route: RouteData, sender: PlayerBody, candidates: Array[PlayerBody], anchor: Vector2) -> Array[PlayerBody]:
	var none: Array[PlayerBody] = []
	var radius_px: float = route.board_radius_tiles * PlayerBody.TILE_SIZE
	if not _can_board(sender, anchor, radius_px):
		return none
	var nearby: Array[PlayerBody] = []
	for candidate: PlayerBody in candidates:
		if candidate != sender and _can_board(candidate, anchor, radius_px):
			nearby.append(candidate)
	if route.capacity_mode == RouteData.CapacityMode.PER_SWIMMER:
		if not ConditionCheck.all_hold(route.rider_requirements, sender):
			return none
		nearby = nearby.filter(func(other: PlayerBody) -> bool: return ConditionCheck.all_hold(route.rider_requirements, other))
	elif route.capacity_mode == RouteData.CapacityMode.FIXED:
		nearby.sort_custom(func(a: PlayerBody, b: PlayerBody) -> bool: return a.global_position.distance_to(anchor) < b.global_position.distance_to(anchor))
		nearby = nearby.slice(0, maxi(route.capacity - 1, 0))
	var riders: Array[PlayerBody] = [sender]
	riders.append_array(nearby)
	return riders


## Host, once the route starts (escape-routes "Route items spent at the start"): takes each item a
## top-level requirement of kind HAS_ITEM marked `consume` asks for, `amount` of it, from
## `starter` for the route's requirements and from every rider for its rider requirements. A
## negated condition or one nested in ANY_OF or ALL_OF is never spent. Call it only after every
## check passed, so a refused start spends nothing.
static func spend(route: RouteData, starter: PlayerBody, riders: Array[PlayerBody]) -> void:
	_spend_from(route.requirements, starter)
	for rider: PlayerBody in riders:
		_spend_from(route.rider_requirements, rider)


static func _spend_from(conditions: Array[ConditionData], player: PlayerBody) -> void:
	for condition: ConditionData in conditions:
		if condition.kind == ConditionData.Kind.HAS_ITEM and condition.consume and not condition.negate:
			player.inventory.remove_id(condition.ref_id, maxi(roundi(condition.amount), 1))


static func _can_board(player: PlayerBody, anchor: Vector2, radius_px: float) -> bool:
	if player.meters.dead or player.meters.downed or player.meters.last_stand:
		return false
	return player.global_position.distance_to(anchor) <= radius_px
