class_name DialogueStateData
extends DataPart
## A keyed state in a DialogueData, embedded in DialogueData.states: lines, pick mode,
## choices, effects on entering and the next state. See npcs-dialogue handwritten lines.

## How lines are picked: all in order, one at random, or one per visit.
enum Pick {
	SEQUENCE,
	RANDOM_ONE,
	CYCLE,
}

## Key (greet, <quest_id>_offer, ending_<slot>, a death cause, quick_chat, outcome).
@export var state: StringName = &""
## Variant gate (returning or robbed greetings).
@export var conditions: Array[ConditionData] = []
## Among entries for the same state, the highest passing one wins.
@export var priority: int = 0
## All lines in order, one at random, or one per visit.
@export var pick: Pick = Pick.SEQUENCE
## Embedded lines.
@export var lines: Array[DialogueLineData] = []
## 1-3 choices after the lines.
@export var choices: Array[ChoiceData] = []
## Applied when the state plays; used for automatic outcomes such as the la_captura check.
@export var on_enter_effects: Array[EffectData] = []
## Automatic follow-on state; empty means close.
@export var next_state: StringName = &""
