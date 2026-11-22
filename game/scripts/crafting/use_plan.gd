class_name UsePlan
extends RefCounted
## Which use the use button sends for a slot (inventory-hud "Which use the button picks", design
## D5), read from the item's data alone: its first use, on the player themself; during a solo last
## stand its first use that revives; and when a teammate who is downed and not dead is within
## 1 tile and the item has a reviving use that can target others, that use on the nearest such
## teammate; and a first use that can target others and cures a status goes to a standing teammate
## in reach who needs it when the player does not (`cure_target`). A use that is needed but missing
## reads NO_USE. Pure: it sends nothing, and the host and the HUD reach the same plan from the same
## state.

var reason: ItemUser.Reason = ItemUser.Reason.OK
## The item's use to send, or -1.
var use_index: int = -1
## The teammate the use goes to, or null for the player themself.
var target: PlayerBody = null
## The target's peer by `session.peer_of`, or 0 for the player themself.
var target_peer: int = 0


## The plan for `body`'s inventory slot `slot`. Teammates are the session's other players; with
## no session there are none.
static func choose(body: PlayerBody, slot: int, session: CoopSession = null) -> UsePlan:
	var plan := UsePlan.new()
	var item := ItemUser.item_at(body, slot)
	if item == null:
		plan.reason = ItemUser.Reason.EMPTY
		return plan
	if body.meters.last_stand:
		plan.use_index = first_reviving_use(item, false)
	else:
		var revive_others: int = first_reviving_use(item, true)
		var teammate: PlayerBody = nearest_downed_teammate(body, session) if revive_others >= 0 else null
		if teammate != null:
			plan.use_index = revive_others
			plan.target = teammate
			plan.target_peer = session.peer_of(teammate)
		elif not item.uses.is_empty():
			plan.use_index = 0
			var patient: PlayerBody = cure_target(body, item.uses[0], session)
			if patient != null:
				plan.target = patient
				plan.target_peer = session.peer_of(patient)
	if plan.use_index < 0:
		plan.reason = ItemUser.Reason.NO_USE
	return plan


## Why `player` may not use their slot `slot`'s use `use_index` on `target` (null: themself)
## now, or OK (`CoopSession.use_for`'s checks of the acting player, design D5): DOWN when dead,
## downed, or in a last stand and not standing themself up with a reviving use; AT_SEA when
## `departed` on a route (design D11); OUT_OF_REACH for a target beyond reach and its slack.
## "Down" is the meters' state, never `body.downed`, which a solo last stand also sets.
static func actor_reason(player: PlayerBody, departed: bool, slot: int, use: int, on: PlayerBody = null) -> ItemUser.Reason:
	var on_self: bool = on == null or on == player
	if player.meters.dead or player.meters.downed:
		return ItemUser.Reason.DOWN
	if player.meters.last_stand and not (on_self and ItemUser.revives(player, slot, use)):
		return ItemUser.Reason.DOWN
	if departed:
		return ItemUser.Reason.AT_SEA
	if not on_self and player.global_position.distance_to(on.global_position) > PlayerBody.HOLD_REACH_PX:
		return ItemUser.Reason.OUT_OF_REACH
	return ItemUser.Reason.OK


## The index of `item`'s first use that revives (and, with `others_only`, can target others),
## or -1.
static func first_reviving_use(item: ItemData, others_only: bool) -> int:
	for i: int in item.uses.size():
		var use: ItemUseData = item.uses[i]
		if others_only and not use.can_target_others:
			continue
		if ItemUser.action_revives(use):
			return i
	return -1


## Who a cure goes to (inventory-hud "Who a cure goes to", bleeding-and-sabila design D5): for a use
## that can go on others and cures a status on whoever it goes on, the nearest standing teammate
## within 1 tile who has one of those statuses, unless `body` has one itself. Null means the use goes
## on `body`: a use that cures nothing (a cup) never goes to a standing teammate.
static func cure_target(body: PlayerBody, use: ItemUseData, session: CoopSession) -> PlayerBody:
	if session == null or not use.can_target_others:
		return null
	var cured: Array[DataEnums.Status] = cured_statuses(use)
	if cured.is_empty() or _has_any(body, cured):
		return null
	return nearest_teammate_with(body, session, cured)


## The statuses `use` cures on whoever it goes on, in order, each once.
static func cured_statuses(use: ItemUseData) -> Array[DataEnums.Status]:
	var cured: Array[DataEnums.Status] = []
	for effect: EffectData in use.effects:
		if effect.kind == EffectData.Kind.CURE_STATUS and effect.target == EffectData.Target.USE_TARGET and not cured.has(effect.status):
			cured.append(effect.status)
	return cured


## The nearest other player of `session` within 1 tile of `body` who is standing (not downed, not
## dead, not waiting out of play) and has one of `statuses`.
static func nearest_teammate_with(body: PlayerBody, session: CoopSession, statuses: Array[DataEnums.Status]) -> PlayerBody:
	var best: PlayerBody = null
	var best_px: float = INF
	for peer_id: int in session.peer_ids():
		var other := session.body(peer_id)
		if other == null or other == body or other.left_island:
			continue
		if other.meters.dead or other.meters.downed or other.meters.last_stand or not _has_any(other, statuses):
			continue
		var distance_px: float = body.global_position.distance_to(other.global_position)
		if distance_px <= InteractionPicker.REACH_PX and distance_px < best_px:
			best = other
			best_px = distance_px
	return best


static func _has_any(body: PlayerBody, statuses: Array[DataEnums.Status]) -> bool:
	for status: DataEnums.Status in statuses:
		if body.meters.has_status(status):
			return true
	return false


## The nearest other player of `session` who is downed and not dead, within 1 tile of `body`.
static func nearest_downed_teammate(body: PlayerBody, session: CoopSession) -> PlayerBody:
	if session == null:
		return null
	var best: PlayerBody = null
	var best_px: float = INF
	for peer_id: int in session.peer_ids():
		var other := session.body(peer_id)
		if other == null or other == body or other.meters.dead or not other.meters.downed:
			continue
		var distance_px: float = body.global_position.distance_to(other.global_position)
		if distance_px <= InteractionPicker.REACH_PX and distance_px < best_px:
			best = other
			best_px = distance_px
	return best
