class_name QuestStepData
extends DataPart
## A quest step embedded in QuestData.steps: conditions or a choice, channel time, time limit,
## start and completion effects, and a target POI. See npcs-dialogue Quests, CHARACTERS quests.

## Unique within the quest.
@export var id: StringName = &""
## Journal line.
@export var description_es: String = ""
## Journal line in English.
@export var description_en: String = ""
## All must hold for the step to complete.
@export var conditions: Array[ConditionData] = []
## 1-3 choices; picking one completes the step.
@export var choices: Array[ChoiceData] = []
## Channel time at the target, in seconds.
@export var hold_seconds: float = 0.0
## In-game days to finish; 0 means none.
@export var time_limit_days: float = 0.0
## Applied when the step begins (delay_s schedules hazards).
@export var on_start: Array[EffectData] = []
## Applied when the step completes.
@export var on_complete: Array[EffectData] = []
## POI that marks the step or must be placed.
@export var target_poi_id: StringName = &""
## The target must be at least this many islands after the quest starts.
@export var target_min_island_offset: int = 0


func get_reference_fields() -> Dictionary[StringName, StringName]:
	return {&"target_poi_id": &"pois"}
