class_name CompanionStatusData
extends DataPart
## A temporary companion condition (injured ankle, injured arm), embedded in
## CompanionData.statuses. Separate from DataEnums.Status, which is for players.
## See CHARACTERS Dayana, Yusnavy.

## Unique within the NPC (ADD_/REMOVE_COMPANION_STATUS, COMPANION_STATUS_ACTIVE).
@export var id: StringName = &""
## HUD label.
@export var name_es: String = ""
## HUD label in English.
@export var name_en: String = ""
## Walk speed factor on top of the base speed.
@export var walk_speed_mult: float = 1.0
## Must be carried on crossings while active.
@export var carried_on_crossings: bool = false
## Turns off the companion's modifiers and abilities.
@export var disables_skills: bool = false
## Item ids that are all consumed to cure it.
@export var cure_item_ids: Array[StringName] = []
## Cleared after a night's sleep.
@export var cured_by_night_rest: bool = false


func get_reference_fields() -> Dictionary[StringName, StringName]:
	return {&"cure_item_ids": &"items"}
