class_name EffectApplier
extends RefCounted
## Applies an EffectData to players. Interpreted: METER_ADD, REVIVE, GIVE_ITEM, TAKE_ITEM, START_ROUTE; any
## other kind is skipped with one warning. Anything that restores hunger is a meal (survival-meters).

static var _warned: Dictionary[int, bool] = {}


## `target` is who a USE_TARGET effect hits (the actor when there is none).
static func apply(effect: EffectData, actor: PlayerBody, target: PlayerBody) -> void:
	var subject: PlayerBody = target if effect.target == EffectData.Target.USE_TARGET and target != null else actor
	match effect.kind:
		EffectData.Kind.METER_ADD:
			_add_meter(effect, subject)
		EffectData.Kind.REVIVE:
			subject.meters.revive()
		EffectData.Kind.GIVE_ITEM:
			subject.inventory.add(effect.ref_id, effect.count)
		EffectData.Kind.TAKE_ITEM:
			subject.inventory.remove_id(effect.ref_id, effect.count)
		EffectData.Kind.START_ROUTE:
			_start_route(effect, actor)
		_:
			if not _warned.has(effect.kind):
				_warned[effect.kind] = true
				push_warning("EffectApplier: kind %s is not built yet, skipped" % EffectData.Kind.keys()[effect.kind])


# Asks the island's routes to start `effect.ref_id` for the actor; they may refuse.
static func _start_route(effect: EffectData, actor: PlayerBody) -> void:
	var routes := actor.get_tree().get_first_node_in_group(IslandRoutes.GROUP) as IslandRoutes
	if routes != null:
		routes.start_for(int(String(actor.name)), effect.ref_id)


static func _add_meter(effect: EffectData, subject: PlayerBody) -> void:
	if effect.meter == DataEnums.Meter.HUNGER and effect.amount > 0.0 and effect.duration_s <= 0.0:
		subject.meters.eat(effect.amount)
	else:
		subject.meters.add_over_time(effect.meter, effect.amount, effect.duration_s)
