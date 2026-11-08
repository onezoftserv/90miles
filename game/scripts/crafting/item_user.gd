class_name ItemUser
extends RefCounted
## Uses an item from a slot (crafting-inventory "Using items"): checks every condition of the
## ItemUseData, applies its effects in order, spends a use. A failed check changes nothing.
## The use's time_s is for whoever drives the action (the UI holds the button); the effects
## here apply at once, on the host.

## Why a use would be refused (inventory-hud design D5), shared by the host and the HUD. The
## item's own reasons follow `use`'s checks in their order (EMPTY, NO_USE, NOT_TARGETABLE,
## TARGET_DEAD, NOT_DOWNED_TARGET, CONDITION); the acting player's are DOWN, AT_SEA and
## OUT_OF_REACH. OK: nothing stands in the way.
enum Reason {
	OK,
	EMPTY,
	NO_USE,
	NOT_TARGETABLE,
	TARGET_DEAD,
	NOT_DOWNED_TARGET,
	CONDITION,
	DOWN,
	AT_SEA,
	OUT_OF_REACH,
}


## Returns whether the use happened. `target` is a teammate for a can_target_others use; null
## means the user themself. A use that revives needs a target who is downed or in a last stand.
static func use(actor: PlayerBody, slot_index: int, use_index: int, target: PlayerBody = null) -> bool:
	if check(actor, slot_index, use_index, target) != Reason.OK:
		return false
	var slot := actor.inventory.slots[slot_index]
	var item := actor.inventory.item_for(slot.item_id)
	var action: ItemUseData = item.uses[use_index]
	var subject: PlayerBody = target if target != null else actor
	_spend_consumed_tools(action, actor)
	for effect: EffectData in action.effects:
		EffectApplier.apply(effect, actor, subject)
	if action.spends_use and item.durability > 0:
		actor.inventory.spend_use(actor.inventory.slots.find(slot))
	elif action.spends_use:
		actor.inventory.remove_id(slot.item_id, 1)
	return true


## Why `use` would refuse this use, or OK: `use`'s own checks, in its order (the slot and its
## item, the use, who it may go on, a dead subject, a reviving use on someone standing, then the
## use's conditions). It changes nothing, so the HUD runs it on the state its peer sees.
static func check(actor: PlayerBody, slot_index: int, use_index: int, target: PlayerBody = null) -> Reason:
	var item := item_at(actor, slot_index)
	if item == null:
		return Reason.EMPTY
	if use_index < 0 or use_index >= item.uses.size():
		return Reason.NO_USE
	var action: ItemUseData = item.uses[use_index]
	var subject: PlayerBody = target if target != null else actor
	if subject != actor and not action.can_target_others:
		return Reason.NOT_TARGETABLE
	if subject.meters.dead:
		return Reason.TARGET_DEAD
	if action_revives(action) and not (subject.meters.downed or subject.meters.last_stand):
		return Reason.NOT_DOWNED_TARGET
	if not ConditionCheck.all_hold(action.conditions, actor):
		return Reason.CONDITION
	return Reason.OK


## The first condition of the use at `slot_index`/`use_index` that does not hold for `actor`
## (what a CONDITION refusal is about), or null.
static func failed_condition(actor: PlayerBody, slot_index: int, use_index: int) -> ConditionData:
	var item := item_at(actor, slot_index)
	if item == null or use_index < 0 or use_index >= item.uses.size():
		return null
	return ConditionCheck.first_failing(item.uses[use_index].conditions, actor)


## The item in `actor`'s slot `slot_index`, or null for an empty or missing slot.
static func item_at(actor: PlayerBody, slot_index: int) -> ItemData:
	if actor == null or slot_index < 0 or slot_index >= actor.inventory.slots.size():
		return null
	var slot := actor.inventory.slots[slot_index]
	return actor.inventory.item_for(slot.item_id) if not slot.is_empty() else null


## Whether the use at `slot_index`/`use_index` of `actor`'s inventory stands someone up.
static func revives(actor: PlayerBody, slot_index: int, use_index: int) -> bool:
	var item := item_at(actor, slot_index)
	if item == null or use_index < 0 or use_index >= item.uses.size():
		return false
	return action_revives(item.uses[use_index])


## Whether `action` stands someone up (it has a REVIVE effect).
static func action_revives(action: ItemUseData) -> bool:
	for effect: EffectData in action.effects:
		if effect.kind == EffectData.Kind.REVIVE:
			return true
	return false


# A HAS_CAPABILITY condition with consume spends one use of the tool that satisfied it.
static func _spend_consumed_tools(action: ItemUseData, actor: PlayerBody) -> void:
	for condition: ConditionData in action.conditions:
		if condition.kind == ConditionData.Kind.HAS_CAPABILITY and condition.consume and not condition.negate:
			actor.inventory.spend_use(actor.inventory.capability_slot(condition.capability))
