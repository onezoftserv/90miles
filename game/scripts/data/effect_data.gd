class_name EffectData
extends DataPart
## The single shared outcome type, embedded wherever something happens: creature contact, aura or
## sighting, item uses and pickups, quest rewards, choices, hooks, set pieces, POI harvest, route
## start and text reads. Gates (background, weather, capability) are conditions on the affected
## entity; cures live only on the curing item. Sources: ITEMS, CHARACTERS, ISLANDS, BESTIARY.

enum Kind {
	METER_ADD,
	METER_SET,
	RESTORE_ALL_METERS,
	DRAIN_MULTIPLIER,
	APPLY_STATUS,
	CURE_STATUS,
	CAP_STATUS,
	REVIVE,
	GIVE_ITEM,
	TAKE_ITEM,
	TAKE_ITEMS_WITH_CAPABILITY,
	TAKE_ALL_ITEMS,
	DESTROY_UNSEALED_FOOD,
	SET_FLAG,
	CLEAR_FLAG,
	CHANGE_TRUST,
	ADD_SKILL_LEVEL,
	ADD_COMPANION_STATUS,
	REMOVE_COMPANION_STATUS,
	UNLOCK_KEEPSAKE,
	TEACH_RECIPE,
	IDENTIFY_ITEM,
	REVEAL_ROUTES,
	GRANT_ROUTE,
	START_ROUTE,
	REVEAL_POIS,
	REVEAL_POSITION,
	HINT,
	WEATHER_WARNING,
	JOIN_PARTY,
	LEAVE_PARTY,
	START_QUEST,
	OPEN_TEXT,
	PLAY_DIALOGUE,
	SPAWN_CREATURE,
	SPAWN_NPC,
	PASS_TIME,
	TRAVEL_NEXT_ISLAND,
	TRAVEL_PREVIOUS_ISLAND,
	NOISE,
	SMOKE,
	SIGNAL_BOAT,
	ALERT_PATROL,
	DECOY,
	START_FIGHT,
	MULTIPLY_MODIFIER,
	RESPAWN_RESOURCES,
	LIGHTS_OUT,
	NPC_DIVE_DROP_RIDERS,
	NPC_FLEE_TO_WATER,
}

enum Target {
	ACTOR,
	USE_TARGET,
	PARTY,
	NEARBY_PLAYERS,
	ALL_PLAYERS,
	SELF_NPC,
	POSITION,
}

enum Limit {
	NONE,
	ONCE_PER_READER,
	ONCE_PER_DAY,
	ONCE_PER_RUN,
}

enum TimeCost {
	NONE,
	ONE_PHASE,
	UNTIL_DAWN,
	FULL_DAY,
}

## What happens. One effects component interprets it.
@export var kind: Kind = Kind.METER_ADD
## Who: ACTOR (event's player), USE_TARGET (teammate/creature hit), PARTY, ALL_PLAYERS, etc.
@export var target: Target = Target.ACTOR
## Id read by kind: item, flag, route, creature, NPC, quest, recipe, weather, dialogue, keepsake...
@export var ref_id: StringName = &""
## Secondary key: dialogue state (PLAY_DIALOGUE), HINT topic, modifier key (MULTIPLY_MODIFIER).
@export var param: StringName = &""

@export_group("Subject")
## Meter for METER_ADD, METER_SET, DRAIN_MULTIPLIER and meter-bearing statuses.
@export var meter: DataEnums.Meter = DataEnums.Meter.NONE
## Status for APPLY_STATUS, CURE_STATUS and CAP_STATUS.
@export var status: DataEnums.Status = DataEnums.Status.NONE
## Skill for ADD_SKILL_LEVEL.
@export var skill: DataEnums.Skill = DataEnums.Skill.NONE
## Capability for TAKE_ITEMS_WITH_CAPABILITY (fire sources = LIGHT_FIRE).
@export var capability: DataEnums.Capability = DataEnums.Capability.NONE

@export_group("Magnitude")
## Meter delta (total over duration_s), REVIVE health, trust/skill delta, SLOWED speed fraction.
@export var amount: float = 0.0
## Factor for DRAIN_MULTIPLIER, a meter status drain (STUNG thirst x1.5) or MULTIPLY_MODIFIER.
@export var multiplier: float = 1.0
## Units for GIVE_ITEM, TAKE_ITEM and SPAWN_*; number of routes for REVEAL_ROUTES.
@export var count: int = 1

@export_group("Timing")
## Seconds; 0 is instant. Spreads METER_ADD, sets status/drain/decoy length, CAP_STATUS max left.
@export var duration_s: float = 0.0
## Seconds before it applies.
@export var delay_s: float = 0.0
## Time spent, only for PASS_TIME.
@export var time_cost: TimeCost = TimeCost.NONE

@export_group("Odds and area")
## Radius in tiles for NOISE, DECOY and NEARBY_PLAYERS.
@export var radius_tiles: float = 0.0
## Probability 0..1, or this outcome's weight inside its roll_group.
@export_range(0.0, 1.0) var chance: float = 1.0
## 0 rolls alone; a shared positive group makes exclusive outcomes of one roll (rest: nothing).
@export var roll_group: int = 0

@export_group("Gates")
## Repeat cap per reader, per day or per run.
@export var limit: Limit = Limit.NONE
## All must hold for the affected entity when it fires (Pescador exemption, red tide, gloves).
@export var conditions: Array[ConditionData] = []


## ref_id points at items, routes, creatures, npcs, recipes, weather or dialogue depending on
## kind. Flags, quests, companion statuses, keepsakes and other kinds are not checked here.
func get_reference_fields() -> Dictionary[StringName, StringName]:
	var folder: StringName = &""
	match kind:
		# Keepsakes (KeepsakeData) live in items/, so UNLOCK_KEEPSAKE ids are item ids too.
		Kind.GIVE_ITEM, Kind.TAKE_ITEM, Kind.IDENTIFY_ITEM, Kind.OPEN_TEXT, Kind.UNLOCK_KEEPSAKE:
			folder = &"items"
		Kind.REVEAL_ROUTES, Kind.GRANT_ROUTE, Kind.START_ROUTE:
			folder = &"routes"
		Kind.SPAWN_CREATURE:
			folder = &"creatures"
		Kind.SPAWN_NPC, Kind.JOIN_PARTY, Kind.CHANGE_TRUST:
			folder = &"npcs"
		Kind.TEACH_RECIPE:
			folder = &"recipes"
		Kind.WEATHER_WARNING:
			folder = &"weather"
		Kind.PLAY_DIALOGUE:
			folder = &"dialogue"
	if folder.is_empty():
		return {}
	return {&"ref_id": folder}
