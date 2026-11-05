class_name NpcHookData
extends DataPart
## An event-to-effect rule embedded in NpcData.hooks: needs, fears, ending flags and
## final-island prompts. No references of its own (ids live in its conditions and effects).
## See npcs-dialogue Companions, CHARACTERS needs.

## What fires the hook.
enum Event {
	MET,
	JOINED,
	DIED,
	LEFT_BEHIND,
	REACHED_LAND,
	ISLAND_ARRIVED,
	FINAL_ISLAND_REACHED,
	DAY_STARTED,
	NIGHT_RESTED,
	THREAT_NEARBY,
	ATTACKED,
	SEARCHLIGHT_HIT,
	SQUAD_LANDED,
	FIRE_LIT,
	SWAM_TILES,
}

## Trigger.
@export var event: Event = Event.JOINED
## Filter for THREAT_NEARBY and ATTACKED; empty means any.
@export var creature_tags: Array[DataEnums.CreatureTag] = []
## Threshold: radius in tiles for THREAT_NEARBY, tiles swum for SWAM_TILES.
@export var amount: float = 0.0
## Checked when the event fires (DAY_PHASE_IS night for El Chino's fire).
@export var conditions: Array[ConditionData] = []
## Applied when the conditions pass.
@export var effects: Array[EffectData] = []
## Applied when the conditions fail.
@export var else_effects: Array[EffectData] = []
## Minimum seconds between firings. TBD.
@export var cooldown_s: float = 0.0
## Fires at most once per run.
@export var once_per_run: bool = false
