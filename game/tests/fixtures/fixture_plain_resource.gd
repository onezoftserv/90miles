class_name FixturePlainResource
extends Resource
## Test-only resource that is NOT content: registering it as a content type is a programming
## error the validator must report instead of crashing.

@export var id: StringName = &""
