class_name ConditionCheck
extends RefCounted
## Tests a ConditionData against one player. Only the kinds crafting-inventory and the capture
## scene need are interpreted; any other kind is false with one warning, so future data cannot crash
## a use. Item scopes are read as the player themself: pooled party inventories are not built yet.
##
## `party` (guardacostas-capture design.md §9) is the group a scene speaks to: PLAYERS_AT_LEAST counts
## it, PARTY-scoped BACKGROUND_PRESENT looks through it, and a node scoped ANY_PLAYER holds when some
## standing player of it (not downed, in a last stand or dead: one who can speak for the party) passes
## the node as the ACTOR. Without a party those read the actor's session (or the actor alone).

static var _warned: Dictionary[int, bool] = {}


static func all_hold(conditions: Array[ConditionData], actor: PlayerBody, party: Array[PlayerBody] = []) -> bool:
	return first_failing(conditions, actor, party) == null


## The first of `conditions` that does not hold for `actor`, or null when they all do (the HUD
## names the tool it lacks, inventory-hud "Refused uses").
static func first_failing(conditions: Array[ConditionData], actor: PlayerBody, party: Array[PlayerBody] = []) -> ConditionData:
	for condition: ConditionData in conditions:
		if not holds(condition, actor, party):
			return condition
	return null


static func holds(condition: ConditionData, actor: PlayerBody, party: Array[PlayerBody] = []) -> bool:
	if condition.scope == ConditionData.Scope.ANY_PLAYER:
		return (not passing_players(condition, party if not party.is_empty() else _session_party(actor)).is_empty()) != condition.negate
	return _evaluate(condition, actor, party) != condition.negate


## The standing players of `party`, in its order, for whom `condition` holds as the ACTOR (its own
## ANY_PLAYER scope read as ACTOR, its negate ignored): who may speak for the party (the la_captura
## plea's speaker).
static func passing_players(condition: ConditionData, party: Array[PlayerBody]) -> Array[PlayerBody]:
	var passing: Array[PlayerBody] = []
	for player: PlayerBody in party:
		if not is_instance_valid(player) or not can_speak(player):
			continue
		if _evaluate(condition, player, party):
			passing.append(player)
	return passing


## A player who can speak for the party: standing, so not downed, in a last stand or dead.
static func can_speak(player: PlayerBody) -> bool:
	return player.meters == null or not (player.meters.downed or player.meters.last_stand or player.meters.dead)


static func _evaluate(condition: ConditionData, actor: PlayerBody, party: Array[PlayerBody] = []) -> bool:
	var inventory := actor.inventory
	var K := ConditionData.Kind
	match condition.kind:
		K.ALL_OF:
			for child: DataPart in condition.children:
				if not holds(child as ConditionData, actor, party):
					return false
			return true
		K.ANY_OF:
			for child: DataPart in condition.children:
				if holds(child as ConditionData, actor, party):
					return true
			return false
		K.BACKGROUND_PRESENT:
			if condition.scope == ConditionData.Scope.PARTY and not party.is_empty():
				for player: PlayerBody in party:
					if is_instance_valid(player) and player.background_id == condition.ref_id:
						return true
				return false
			return actor.background_id == condition.ref_id
		K.FLAG_SET:
			var session := CoopSession.of(actor)
			return session != null and not condition.ref_id.is_empty() and session.run_record.has_flag(condition.ref_id)
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
			if not party.is_empty():
				return party.size() >= roundi(condition.amount)
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


# The players of the actor's session, in peer order; the actor alone outside a session.
static func _session_party(actor: PlayerBody) -> Array[PlayerBody]:
	var session := CoopSession.of(actor)
	var found: Array[PlayerBody] = []
	if session == null:
		found.append(actor)
		return found
	for peer_id: int in session.peer_ids():
		var player := session.body(peer_id)
		if player != null:
			found.append(player)
	return found
