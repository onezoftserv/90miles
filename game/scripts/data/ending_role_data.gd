class_name EndingRoleData
extends DataPart
## Which slot an NPC fills in which ending scene, in which end state, using which of its own
## dialogue states. Embedded in NpcData.ending_roles. See GAME_DESIGN 13, endings-progression.

## The NPC's state at the end of the run.
enum NpcEndState {
	ANY,
	ARRIVED,
	LOST,
	DIED,
	LEFT_BEHIND,
}

## Endings this role applies to; empty means every ending.
@export var endings: Array[DataEnums.Ending] = []
## The NPC's state at the end of the run.
@export var npc_state: NpcEndState = NpcEndState.ANY
## Extra gates (Caridad: if you lit the lamp).
@export var conditions: Array[ConditionData] = []
## Slot marker in the ending DialogueData (beach, credits, narrator, empty_chair ...).
@export var slot: StringName = &""
## State in this NPC's own DialogueData with the slot lines.
@export var dialogue_state: StringName = &""
