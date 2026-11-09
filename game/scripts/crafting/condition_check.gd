class_name ConditionCheck
extends RefCounted
## Tests a ConditionData against one player. Only the kinds crafting-inventory needs are
## interpreted; any other kind is false with one warning, so future data cannot crash a use.
## Scope is read as the player themself: pooled party inventories are not built yet.

static var _warned: Dictionary[int, bool] = {}


static func all_hold(conditions: Array[ConditionData], actor: PlayerBody) -> bool:
	return first_failing(conditions, actor) == null


## The first of `conditions` that does not hold for `actor`, or null when they all do (the HUD
## names the tool it lacks, inventory-hud "Refused uses").
static func first_failing(conditions: Array[ConditionData], actor: PlayerBody) -> ConditionData:
	for condition: ConditionData in conditions:
		if not holds(condition, actor):
			return condition
	return null


static func holds(condition: ConditionData, actor: PlayerBody) -> bool:
	return _evaluate(condition, actor) != condition.negate


static func _evaluate(condition: ConditionData, actor: PlayerBody) -> bool:
	var inventory := actor.inventory
	var K := ConditionData.Kind
	match condition.kind:
		K.ALL_OF:
			for child: DataPart in condition.children:
				if not holds(child as ConditionData, actor):
					return false
			return true
		K.ANY_OF:
			for child: DataPart in condition.children:
				if holds(child as ConditionData, actor):
					return true
			return false
		K.HAS_ITEM:
			return inventory.count_id(condition.ref_id) >= maxi(roundi(condition.amount), 1)
		K.HAS_ITEM_TAG:
			return inventory.count_tag(condition.item_tag) >= maxi(roundi(condition.amount), 1)
		K.HAS_CAPABILITY:
			return inventory.capability_slot(condition.capability) >= 0
		K.LIT_FIRE_NEARBY:
			return _fire_within(actor, condition.radius_tiles * PlayerBody.TILE_SIZE)
		K.WEATHER_IS:
			return actor.climate.weather_id == condition.ref_id
		K.METER_AT_LEAST:
			return actor.meters.value(condition.meter) >= condition.amount
		K.STATUS_ACTIVE:
			return actor.meters.has_status(condition.status)
		K.WEATHER_IS_CLEAR:
			return _weather_is_clear(actor.climate.weather_id)
		K.STRUCTURE_BUILT:
			return _structure_built(actor, condition.ref_id)
		K.PLAYERS_AT_LEAST:
			return actor.get_tree().get_nodes_in_group(PlayerBody.GROUP).size() >= roundi(condition.amount)
	if not _warned.has(condition.kind):
		_warned[condition.kind] = true
		push_warning("ConditionCheck: kind %s is not built yet, treated as false" % ConditionData.Kind.keys()[condition.kind])
	return false


static func _weather_is_clear(weather_id: StringName) -> bool:
	var weather := GameState.content.get_entry(&"weather", weather_id) as WeatherData
	return weather != null and weather.is_clear


# A finished structure of recipe `recipe_id` stands on the island (it joined STRUCTURE_GROUP).
static func _structure_built(actor: PlayerBody, recipe_id: StringName) -> bool:
	for node: Node in actor.get_tree().get_nodes_in_group(PlayerBody.STRUCTURE_GROUP):
		if node.get_meta(&"recipe_id", &"") == recipe_id:
			return true
	return false


static func _fire_within(actor: PlayerBody, within_px: float) -> bool:
	for node: Node in actor.get_tree().get_nodes_in_group(PlayerBody.FIRE_GROUP):
		var fire := node as Node2D
		if fire != null and actor.global_position.distance_to(fire.global_position) <= within_px:
			return true
	return false
