class_name FixturePartData
extends DataPart
## Test-only embedded part: references an item and can nest more parts.

@export var item: StringName = &""
# Typed as the base class: an array typed with its own class keeps the script alive at exit.
@export var children: Array[DataPart] = []


func get_reference_fields() -> Dictionary[StringName, StringName]:
	return {&"item": &"things"}
