class_name ConditionData
extends DataPart
## The single shared boolean test, embedded in route requirements, quest steps, choices, spawn
## rules, counters, effects, item uses, POI gates and dialogue states. A list of conditions is
## AND-ed; OR is an ANY_OF node with children. Sources: escape-routes, npcs-dialogue, CHARACTERS.

enum Kind {
	ALL_OF,
	ANY_OF,
	HAS_ITEM,
	HAS_ITEM_TAG,
	HAS_CAPABILITY,
	FLAG_SET,
	PROFILE_FLAG_SET,
	QUEST_DONE,
	NPC_STATE_IS,
	POI_REACHED,
	POI_PRESENT,
	INTERACT_COUNT,
	MINIGAME_WON,
	BACKGROUND_PRESENT,
	PERK_PRESENT,
	NPC_PRESENT,
	NPC_IN_PARTY,
	SKILL_AT_LEAST,
	METER_AT_LEAST,
	STATUS_ACTIVE,
	COMPANION_STATUS_ACTIVE,
	TRUST_AT_LEAST,
	RETURNING,
	WEATHER_IS,
	WEATHER_IS_CLEAR,
	DAY_PHASE_IS,
	TIME_IN_PHASE,
	TIDE_IS,
	DISTANCE_BAND_IS,
	CHAIN_FAMILY_IS,
	CHAIN_IS,
	ISLAND_INDEX_AT_LEAST,
	PLAYERS_AT_LEAST,
	PLAYERS_NEARBY_AT_LEAST,
	LIT_FIRE_NEARBY,
	STRUCTURE_BUILT,
	CHANCE,
}

enum Scope {
	ACTOR,
	PARTY,
	ANY_PLAYER,
	EACH_PLAYER,
	EACH_RIDER,
	SELF_NPC,
}

## What is tested.
@export var kind: Kind = Kind.FLAG_SET
## Id by kind: item, flag, quest, POI, NPC, background, weather, chain, recipe, minigame...
@export var ref_id: StringName = &""
## Whose state: PARTY (pooled inventories, anyone on this island) or ACTOR (the player themself).
@export var scope: Scope = Scope.PARTY
## Inverts the result.
@export var negate: bool = false

@export_group("Subject")
## Tag for HAS_ITEM_TAG.
@export var item_tag: DataEnums.ItemTag = DataEnums.ItemTag.FOOD
## Capability for HAS_CAPABILITY (a knife or machete opens coconuts).
@export var capability: DataEnums.Capability = DataEnums.Capability.NONE
## Perk for PERK_PRESENT (PLAYS_SONGS counts the Musico or the cassette).
@export var perk: DataEnums.Perk = DataEnums.Perk.NONE
## Meter for METER_AT_LEAST.
@export var meter: DataEnums.Meter = DataEnums.Meter.NONE
## Skill for SKILL_AT_LEAST.
@export var skill: DataEnums.Skill = DataEnums.Skill.NONE
## Status for STATUS_ACTIVE (riders not bleeding).
@export var status: DataEnums.Status = DataEnums.Status.NONE

@export_group("World")
## Phase for DAY_PHASE_IS and TIME_IN_PHASE.
@export var phase: DataEnums.DayPhase = DataEnums.DayPhase.DAWN
## Tide for TIDE_IS.
@export var tide: DataEnums.Tide = DataEnums.Tide.ANY
## Band for DISTANCE_BAND_IS.
@export var band: DataEnums.DistanceBand = DataEnums.DistanceBand.COAST
## Family for CHAIN_FAMILY_IS.
@export var chain_family: DataEnums.ChainFamily = DataEnums.ChainFamily.SANDBAR

@export_group("Thresholds")
## Count, threshold, level, island index, player count or chance (0..1), by kind.
@export var amount: float = 1.0
## Radius in tiles for PLAYERS_NEARBY_AT_LEAST and LIT_FIRE_NEARBY.
@export var radius_tiles: float = 5.0
## TIME_IN_PHASE window, seconds into the phase; negative counts back from its end (1 h = 30 s).
@export var window_s: Vector2 = Vector2.ZERO

@export_group("Counting")
## HAS_ITEM/HAS_ITEM_TAG: remove matched items when the owner fires; HAS_CAPABILITY: spend 1 use.
@export var consume: bool = false
## Counts at most once per in-game day.
@export var distinct_days: bool = false

@export_group("Nested")
## Sub-conditions for ALL_OF and ANY_OF; holds ConditionData entries only.
## Typed as DataPart on purpose: a script whose array is typed with its own class keeps
## itself alive, and Godot 4.7 then reports "resources still in use at exit", which fails CI.
@export var children: Array[DataPart] = []


## ref_id points at items, weather, chains, pois, npcs, backgrounds or recipes depending on kind.
## Flags, quests, minigames, companion statuses and the other kinds are not checked here.
func get_reference_fields() -> Dictionary[StringName, StringName]:
	var folder: StringName = &""
	match kind:
		Kind.HAS_ITEM:
			folder = &"items"
		Kind.WEATHER_IS:
			folder = &"weather"
		Kind.CHAIN_IS:
			folder = &"chains"
		Kind.POI_REACHED, Kind.POI_PRESENT:
			folder = &"pois"
		Kind.NPC_PRESENT, Kind.NPC_IN_PARTY, Kind.NPC_STATE_IS, Kind.TRUST_AT_LEAST:
			folder = &"npcs"
		Kind.BACKGROUND_PRESENT:
			folder = &"backgrounds"
		Kind.STRUCTURE_BUILT:
			folder = &"recipes"
	if folder.is_empty():
		return {}
	return {&"ref_id": folder}
