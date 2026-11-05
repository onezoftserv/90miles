class_name FixturePartData
extends DataPart
## Test-only embedded part: references an item and can nest more parts.

@export var item: StringName = &""
@export var children: Array[FixturePartData] = []


func get_reference_fields() -> Dictionary[StringName, StringName]:
	return {&"item": &"things"}
