class_name DialogueData
extends ContentData
## One handwritten line set, flat in game/resources/dialogue/: <npc_id>, beat_<id>, ending_<id>,
## quick_chat, death_one_liners, hallucinations. es and en sit on the same line, which keys
## lines by NPC id, state and language. Names are optional editor labels. See npcs-dialogue.

## What the set is for.
enum Kind {
	NPC,
	STORY_BEAT,
	ENDING,
	QUICK_CHAT,
	DEATH_LINES,
	HALLUCINATION,
}

## What the set is for.
@export var kind: Kind = Kind.NPC
## Owner NPC (NPC kind; beat_la_captura uses rodriguez).
@export var npc_id: StringName = &""
## Owner boss creature for beat_boss_*.
@export var creature_id: StringName = &""
## Which ending, for the ENDING kind.
@export var ending: DataEnums.Ending = DataEnums.Ending.TODOS
## Lookup returns the highest-priority entry whose state matches and whose conditions pass.
@export var states: Array[DialogueStateData] = []


func get_reference_fields() -> Dictionary[StringName, StringName]:
	return {&"npc_id": &"npcs", &"creature_id": &"creatures"}


## Names are editor labels only, so a dialogue file needs no name_es.
func requires_name() -> bool:
	return false
