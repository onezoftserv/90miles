class_name CreatureCounterData
extends DataPart
## One player counter: a trigger (player action or world condition) mapped to a creature
## response. Embedded in CreatureData.counters. Home of sandals immunity, Pescador/Médico
## reveals and Rodríguez's one-time pass. Sources: BESTIARY "Counters", ITEMS sandals.

## What fires the counter. Enum values are saved as ints: append only.
enum Trigger {
	WEAPON_HIT,
	ITEM_THROWN,
	ITEM_DROPPED,
	ITEM_FED,
	ITEM_WORN,
	ITEM_CARRIED,
	INTERACT,
	POI_INTERACT,
	NOISE,
	FIRE_LIGHT,
	SMOKE,
	FIRE_ON_WATER,
	CONDITION_HOLDS,
	CROUCHING,
	APPROACH_FROM_BEHIND,
	REACH_REEF_LINE,
	GO_DARK,
}

## What the creature does when the counter fires. Saved as ints: append only.
enum Response {
	FLEE,
	DECOY,
	DISPERSE,
	SLEEP,
	CALM,
	NEGATE,
	REVEAL,
	SAFE_TRIGGER,
	REMOVE,
	RETURN_TO_LAIR,
	END_ENCOUNTER,
	LET_PASS,
}

@export_group("Trigger")
## What fires it. CONDITION_HOLDS fires while conditions pass (NPC/background present, weather, flag).
@export var trigger: Trigger = Trigger.WEAPON_HIT
## ItemData ids involved; empty means any item.
@export var item_ids: Array[StringName] = []
## Item tags involved (SHINY dropped as a decoy).
@export var item_tags: Array[DataEnums.ItemTag] = []
## Items needed, fed or thrown.
@export var count: int = 1
## The player must be at least this many tiles away.
@export var min_distance_tiles: float = 0.0
## Minimum noise radius in tiles for the NOISE trigger.
@export var min_noise_radius_tiles: float = 0.0
## PoiData id for POI_INTERACT.
@export var poi_id: StringName = &""
## All must hold (skill, background, NPC present, day phase, weather, flag such as rodriguez_deal).
@export var conditions: Array[ConditionData] = []

@export_group("Response")
## What the creature does.
@export var response: Response = Response.FLEE
## How long the response lasts in seconds; -1 means while the trigger holds or the rest of the encounter.
@export var duration_s: float = 0.0
## Affected radius in tiles (decoy pull, reveal distance).
@export var radius_tiles: float = 0.0
## Run-wide cap on uses; 0 means unlimited.
@export var max_uses_per_run: int = 0


func get_reference_fields() -> Dictionary[StringName, StringName]:
	return {&"item_ids": &"items", &"poi_id": &"pois"}
