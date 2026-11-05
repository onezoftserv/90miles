class_name NpcSpawnRuleData
extends DataPart
## Where, when and how likely an NPC appears, embedded in NpcData.spawn_rules. Separate from
## SpawnEntryData because it carries timing, the island range and bonus chances; it uses the
## same location filter as CreatureSpawnRuleData. See npcs-dialogue spawn rules, ISLANDS POI tables.

## When the rule rolls.
enum Timing {
	ON_GENERATE,
	PHASE_START,
	SUMMONED,
	WITH_PATROL,
}

## ON_GENERATE: island build; PHASE_START: each phase; SUMMONED: effect/route only; WITH_PATROL: aboard its patrol.
@export var timing: Timing = Timing.ON_GENERATE
## Chain families allowed; OR with chain_ids; both empty means any chain.
@export var chain_families: Array[DataEnums.ChainFamily] = []
## Chain variant ids allowed (caridad: lighthouse_caridad only).
@export var chain_ids: Array[StringName] = []
## Camp POI forced into the island when the rule succeeds; empty means any shoreline spot.
@export var poi_id: StringName = &""
## Spawn probability 0..1 (el_chino 0.6, dayana 0.6, papo 0.5, senora 0.5, ramon 0.4, vieja 0.7).
@export_range(0.0, 1.0) var chance: float = 1.0
## First island it may spawn on, 1-based; it never spawns earlier.
@export var min_island: int = 1
## Last island it may spawn on; 0 means no limit.
@export var max_island: int = 0
## All must hold at roll time.
@export var conditions: Array[ConditionData] = []
## When these hold, bonus_chance is added.
@export var bonus_conditions: Array[ConditionData] = []
## Chance added when bonus_conditions hold. TBD.
@export var bonus_chance: float = 0.0
## Instances spawned together, as (min, max).
@export var group_size: Vector2i = Vector2i(1, 1)
## NPC and dialogue state on spawn (vieja_turtle: tangled).
@export var initial_state: StringName = &""


func get_reference_fields() -> Dictionary[StringName, StringName]:
	return {&"chain_ids": &"chains", &"poi_id": &"pois"}
