class_name DialogueLineData
extends DataPart
## One handwritten line, embedded in DialogueStateData.lines: speaker, es/en with soft variants,
## an emotion from the same set as the AI JSON, or a slot marker that expands to NPC ending
## lines. See CLAUDE.md dialogue, GAME_DESIGN 15, endings-progression.

## Stable key; the voice clip path follows from it.
@export var id: StringName = &""
## NPC id, player or narrator; empty means the file's owner. Not a content reference.
@export var speaker_id: StringName = &""
## Spanish line.
@export_multiline var text_es: String = ""
## English line, keeping slang.
@export_multiline var text_en: String = ""
## Spanish line used when profanity is soft; empty means already clean.
@export var text_es_soft: String = ""
## English soft version; empty means already clean.
@export var text_en_soft: String = ""
## Same set as the AI {speaker, text, emotion}; picks the portrait and grunt.
@export var emotion: DataEnums.Emotion = DataEnums.Emotion.NEUTRAL
## If set, the line expands to the lines of every NPC whose ending_roles match this ending and slot.
@export var slot: StringName = &""
## The line plays only when all hold.
@export var conditions: Array[ConditionData] = []
