class_name ChoiceData
extends DataPart
## One player choice, shared by quest steps (npcs), dialogue states (dialogue) and set pieces
## (set_pieces). Its id is local to its container. No references of its own: its conditions and
## effects carry theirs. Sources: npcs-dialogue 'Dialogue UI', ISLANDS 'What happens'.

## Unique inside its container (quest step, dialogue state or set piece).
@export var id: StringName = &""
## Spanish button text.
@export var label_es: String = ""
## English button text.
@export var label_en: String = ""
## The choice is shown only when all hold.
@export var conditions: Array[ConditionData] = []
## Applied when picked (time costs are PASS_TIME effects).
@export var effects: Array[EffectData] = []
## Dialogue state to show next; empty means close.
@export var next_state: StringName = &""
## Resolves the set piece or step.
@export var ends_interaction: bool = true
