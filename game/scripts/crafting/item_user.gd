class_name ItemUser
extends RefCounted
## Uses an item from a slot (crafting-inventory "Using items"): checks every condition of the
## ItemUseData, applies its effects in order, spends a use. A failed check changes nothing.
## The use's time_s is for whoever drives the action (the UI holds the button); the effects
## here apply at once, on the host.


## Returns whether the use happened. `target` is a teammate for a can_target_others use; null
## means the user themself. A use that revives needs a target who is downed or in a last stand.
static func use(actor: PlayerBody, slot_index: int, use_index: int, target: PlayerBody = null) -> bool:
	if slot_index < 0 or slot_index >= actor.inventory.slots.size():
		return false
	var slot := actor.inventory.slots[slot_index]
	var item := actor.inventory.item_for(slot.item_id) if not slot.is_empty() else null
	if item == null or use_index < 0 or use_index >= item.uses.size():
		return false
	var action: ItemUseData = item.uses[use_index]
	var subject: PlayerBody = target if target != null else actor
	if subject != actor and not action.can_target_others:
		return false
	if subject.meters.dead:
		return false
	if _revives(action) and not (subject.meters.downed or subject.meters.last_stand):
		return false
	if not ConditionCheck.all_hold(action.conditions, actor):
		return false
	_spend_consumed_tools(action, actor)
	for effect: EffectData in action.effects:
		EffectApplier.apply(effect, actor, subject)
	if action.spends_use and item.durability > 0:
		actor.inventory.spend_use(actor.inventory.slots.find(slot))
	elif action.spends_use:
		actor.inventory.remove_id(slot.item_id, 1)
	return true


static func _revives(action: ItemUseData) -> bool:
	for effect: EffectData in action.effects:
		if effect.kind == EffectData.Kind.REVIVE:
			return true
	return false


# A HAS_CAPABILITY condition with consume spends one use of the tool that satisfied it.
static func _spend_consumed_tools(action: ItemUseData, actor: PlayerBody) -> void:
	for condition: ConditionData in action.conditions:
		if condition.kind == ConditionData.Kind.HAS_CAPABILITY and condition.consume and not condition.negate:
			actor.inventory.spend_use(actor.inventory.capability_slot(condition.capability))
