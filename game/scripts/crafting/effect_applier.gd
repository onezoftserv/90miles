class_name EffectApplier
extends RefCounted
## Applies an EffectData to players. Interpreted: METER_ADD, CURE_STATUS, REVIVE, GIVE_ITEM, TAKE_ITEM,
## START_ROUTE, SET_FLAG and CLEAR_FLAG (the run flags in the session's RunRecord; nothing outside a
## session); any other kind is skipped with one warning. Anything that restores hunger is a meal
## (survival-meters). An effect with delay_s waits in the subject's meters for that many seconds of
## their own time (frozen while they are out of play), then applies to them.

static var _warned: Dictionary[int, bool] = {}


## `target` is who a USE_TARGET effect hits (the actor when there is none).
static func apply(effect: EffectData, actor: PlayerBody, target: PlayerBody) -> void:
	var subject: PlayerBody = _subject(effect, actor, target)
	if effect.delay_s > 0.0:
		subject.meters.delay_effect(effect, effect.delay_s)
		return
	apply_now(effect, actor, target)


## Applies `effect` at once, whatever its delay (the meters call it when the delay is up).
static func apply_now(effect: EffectData, actor: PlayerBody, target: PlayerBody) -> void:
	var subject: PlayerBody = _subject(effect, actor, target)
	match effect.kind:
		EffectData.Kind.METER_ADD:
			_add_meter(effect, subject)
		EffectData.Kind.CURE_STATUS:
			subject.meters.set_status(effect.status, false)
		EffectData.Kind.REVIVE:
			subject.meters.revive()
		EffectData.Kind.GIVE_ITEM:
			subject.inventory.add(effect.ref_id, effect.count)
		EffectData.Kind.TAKE_ITEM:
			subject.inventory.remove_id(effect.ref_id, effect.count)
		EffectData.Kind.START_ROUTE:
			_start_route(effect, actor)
		EffectData.Kind.SET_FLAG:
			_set_flag(effect, actor, true)
		EffectData.Kind.CLEAR_FLAG:
			_set_flag(effect, actor, false)
		_:
			if not _warned.has(effect.kind):
				_warned[effect.kind] = true
				push_warning("EffectApplier: kind %s is not built yet, skipped" % EffectData.Kind.keys()[effect.kind])


static func _subject(effect: EffectData, actor: PlayerBody, target: PlayerBody) -> PlayerBody:
	return target if effect.target == EffectData.Target.USE_TARGET and target != null else actor


# Asks the island's routes to start `effect.ref_id` for the actor; they may refuse.
static func _start_route(effect: EffectData, actor: PlayerBody) -> void:
	var routes := actor.get_tree().get_first_node_in_group(IslandRoutes.GROUP) as IslandRoutes
	if routes != null:
		routes.start_for(routes.peer_of(actor), effect.ref_id)


# Sets or clears the run flag `effect.ref_id` in the actor's session; a body in no session has no run.
static func _set_flag(effect: EffectData, actor: PlayerBody, on: bool) -> void:
	var session := CoopSession.of(actor)
	if session == null or effect.ref_id.is_empty():
		return
	if on:
		session.run_record.set_flag(effect.ref_id)
	else:
		session.run_record.clear_flag(effect.ref_id)


static func _add_meter(effect: EffectData, subject: PlayerBody) -> void:
	if effect.meter == DataEnums.Meter.HUNGER and effect.amount > 0.0 and effect.duration_s <= 0.0:
		subject.meters.eat(effect.amount)
	else:
		subject.meters.add_over_time(effect.meter, effect.amount, effect.duration_s)
