class_name FixtureRecipeData
extends ContentData
## Test-only content type with references in all three shapes the validator reads:
## dictionary keys, a single id and an array of ids.

@export var ingredients: Dictionary[StringName, int] = {}
@export var tool: StringName = &""
@export var unlocks: Array[StringName] = []


func get_reference_fields() -> Dictionary[StringName, StringName]:
	return {&"ingredients": &"things", &"tool": &"things", &"unlocks": &"things"}
