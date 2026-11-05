class_name QuestData
extends DataPart
## A quest, encounter, trade, rescue or gift embedded in NpcData.quests (no quests/ folder).
## The id is globally unique, prefixed with the NPC id, for QUEST_DONE, START_QUEST and
## KeepsakeData QUEST_COMPLETED. State is host-authoritative. See npcs-dialogue Quests.

## UI grouping.
enum Kind {
	QUEST,
	ENCOUNTER,
	TRADE,
	RESCUE,
	GIFT,
}

@export_group("Journal")
## <npc_id>_<name> (ramon_las_nasas).
@export var id: StringName = &""
## Journal title ("Las nasas").
@export var name_es: String = ""
## English journal title (slang kept).
@export var name_en: String = ""
## Journal text.
@export_multiline var description_es: String = ""
## Journal text in English.
@export_multiline var description_en: String = ""
## UI grouping.
@export var kind: Kind = Kind.QUEST

@export_group("Flow")
## Starts without talking first.
@export var auto_start: bool = false
## All must hold for it to be offered.
@export var offer_conditions: Array[ConditionData] = []
## Ordered steps, shared by the party.
@export var steps: Array[QuestStepData] = []
## Applied on completion.
@export var rewards: Array[EffectData] = []
## If any holds, the quest fails.
@export var fail_conditions: Array[ConditionData] = []
## Can be done again (trades).
@export var repeatable: bool = false
## DialogueData to play; empty means the owner's. States: <quest_id>_offer, _active, _done, _failed.
@export var dialogue_id: StringName = &""


func get_reference_fields() -> Dictionary[StringName, StringName]:
	return {&"dialogue_id": &"dialogue"}
