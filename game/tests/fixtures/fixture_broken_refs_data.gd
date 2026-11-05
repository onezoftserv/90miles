class_name FixtureBrokenRefsData
extends ContentData
## Test-only content type whose reference declarations are wrong in three ways: a field of an
## unsupported shape, a field that does not exist, and a target type that is not registered.

@export var count: int = 3
@export var tool: StringName = &"rope"


func get_reference_fields() -> Dictionary[StringName, StringName]:
	return {&"count": &"things", &"ghost": &"things", &"tool": &"nowhere"}
